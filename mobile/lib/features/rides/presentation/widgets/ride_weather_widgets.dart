import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/ride_weather_display.dart';

/// Les briques de la météo partagées par la carte compacte du détail et
/// l'écran « Météo du parcours ». Elles vivent dans la *feature* et non dans
/// `core/pdl` : elles lisent les DTO météo et traduisent.

/// Peut-on voir le message `NO_LOCATION` de [teamSlug] ?
bool watchCanSeeWeatherNoLocation(WidgetRef ref, String teamSlug) {
  final TeamRole? role = ref.watch(teamRoleProvider(teamSlug));
  final bool platformAdmin = ref.watch(
    authProvider.select(
      (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
    ),
  );
  return canSeeWeatherNoLocation(teamRole: role, platformAdmin: platformAdmin);
}

/// L'angle de la flèche de chaque vent relatif dans une légende : le vent
/// pousse (0), vient de côté (90) ou de face (180).
double relativeWindLegendAngle(RelativeWind wind) => switch (wind) {
  RelativeWind.tail => 0,
  RelativeWind.cross => 90,
  RelativeWind.head => 180,
  RelativeWind.$unknown => 90,
};

/// La teinte d'un vent relatif, `neutral` pour un vent inconnu.
Color relativeWindColor(PdlColors c, RelativeWind? wind) =>
    wind == null ? c.neutral : wind.tone(c).fill;

/// L'icône de la condition, teintée du texte courant.
class WeatherConditionIcon extends StatelessWidget {
  const WeatherConditionIcon({
    super.key,
    required this.condition,
    required this.daylight,
    this.size = 20,
  });

  final String? condition;
  final bool daylight;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(
      weatherConditionOf(condition).icon(daylight: daylight),
      size: size,
      color: context.pdl.text,
    ),
  );
}

/// Le vent le long du parcours d'une étape : un tronçon par segment, teinté
/// face / travers / dos, suivi de l'exposition cumulée en légende.
///
/// La couleur n'est jamais seule : la légende porte libellé, flèche et
/// distance, et la barre se résume pour un lecteur d'écran.
class WeatherWindSegments extends StatelessWidget {
  const WeatherWindSegments({
    super.key,
    required this.leg,
    required this.units,
  });

  final WeatherLegDto leg;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final String summary = exposureSummary(leg.windExposure, units);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PdlSegmentBar(
          semanticLabel: 'rides.weather.segmentsSemantics'.tr(
            namedArgs: <String, String>{'summary': summary},
          ),
          entries: <PdlSegmentBarEntry>[
            for (final WindSegmentDto s in leg.segments)
              PdlSegmentBarEntry(
                extent: s.toDistance - s.fromDistance,
                color: relativeWindColor(c, relativeWindOf(s.relativeWind)),
              ),
          ],
        ),
        const SizedBox(height: PdlSpacing.badgeGap),
        WeatherExposureLegend(exposure: leg.windExposure, units: units),
      ],
    );
  }
}

/// « Face 12,3 km · Travers 30,1 km · Dos 24,0 km », chaque entrée précédée
/// de sa flèche teintée. Une entrée nulle est omise.
class WeatherExposureLegend extends StatelessWidget {
  const WeatherExposureLegend({
    super.key,
    required this.exposure,
    required this.units,
  });

  final WindExposureDto exposure;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final List<(RelativeWind, double)> entries = <(RelativeWind, double)>[
      (RelativeWind.head, exposure.head),
      (RelativeWind.cross, exposure.cross),
      (RelativeWind.tail, exposure.tail),
    ].where(((RelativeWind, double) e) => e.$2 > 0).toList();

    return ExcludeSemantics(
      child: Wrap(
        spacing: PdlSpacing.statsNowrap,
        runSpacing: PdlSpacing.badgeGap,
        children: <Widget>[
          for (final (RelativeWind wind, double meters) in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PdlWindArrow(
                  angle: relativeWindLegendAngle(wind),
                  color: relativeWindColor(c, wind),
                  size: 14,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    'rides.weather.exposure.${wind.name}'.tr(
                      namedArgs: <String, String>{
                        'distance': AppFormatters.formatDistance(meters, units),
                      },
                    ),
                    style: t.xs,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Le résumé textuel de l'exposition, pour les lecteurs d'écran.
String exposureSummary(WindExposureDto exposure, UnitSystem units) => <String>[
  for (final (RelativeWind wind, double meters) in <(RelativeWind, double)>[
    (RelativeWind.head, exposure.head),
    (RelativeWind.cross, exposure.cross),
    (RelativeWind.tail, exposure.tail),
  ])
    if (meters > 0)
      'rides.weather.exposure.${wind.name}'.tr(
        namedArgs: <String, String>{
          'distance': AppFormatters.formatDistance(meters, units),
        },
      ),
].join(', ');

/// Le vent d'une heure : flèche absolue (nord en haut) et « Vent 18 km/h » —
/// la flèche dit d'où il vient, le texte ne répète pas le point cardinal.
class WeatherWindLine extends StatelessWidget {
  const WeatherWindLine({
    super.key,
    required this.wind,
    required this.units,
    this.gusts = true,
  });

  final WindDto wind;
  final UnitSystem units;
  final bool gusts;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PdlWindArrow(angle: windArrowAngle(wind.direction), size: 14),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            formatWind(wind, units, gusts: gusts, compass: false),
            style: t.xs,
          ),
        ),
      ],
    );
  }
}

/// « Prévision disponible à partir du… », ou, sans date lisible, la règle
/// des sept jours (comme le web, `rides.weather.notYetAvailableNoDate`).
String notYetAvailableMessage(DateTime? availableFrom) => availableFrom == null
    ? 'rides.weather.notYetAvailableNoDate'.tr()
    : 'rides.weather.notYetAvailable'.tr(
        namedArgs: <String, String>{
          'date': AppFormatters.formatFullDate(availableFrom),
        },
      );

/// Le crédit que la licence des prévisions demande (CC BY 4.0) : « Prévisions :
/// Open-Meteo.com », en légende. L'écran « Météo du parcours » le rend en lien.
String weatherAttributionLabel(WeatherAttributionDto attribution) =>
    'rides.weather.attribution'.tr(
      namedArgs: <String, String>{'name': attribution.name},
    );
