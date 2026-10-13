import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/ride_weather_display.dart';
import 'ride_weather_widgets.dart';

/// La ligne météo d'un groupe — **non cliquable** (ledger `MOB-67`).
///
/// Température et ciel au départ **du groupe** (le premier point de passage
/// de son leg), l'alerte pluie courte quand il y en a une, puis la distance
/// roulée vent de face et vent dans le dos. Les puces Face et Dos sont
/// teintées par `RelativeWind` (`enum_colors.generated.dart`, depuis
/// `contracts/brand-colors.yaml`) et portent toujours leur libellé : la
/// couleur ne dit jamais rien seule.
///
/// Rien n'est rendu sans prévision du leg (`OK`/`STALE`) ni conditions au
/// départ : la carte d'un groupe ne réserve pas de place à une ligne vide.
/// Portée par la carte d'un groupe du détail et par l'aperçu de sa page.
class RideGroupWeatherLine extends StatelessWidget {
  const RideGroupWeatherLine({
    super.key,
    required this.leg,
    required this.timezone,
    required this.units,
  });

  final WeatherLegDto? leg;

  /// Le fuseau de la sortie, où se lit l'heure de l'alerte pluie.
  final String? timezone;
  final UnitSystem units;

  /// La ligne a-t-elle quelque chose à montrer ?
  static bool shows(WeatherLegDto? leg) => _departureOf(leg) != null;

  static WeatherConditionsDto? _departureOf(WeatherLegDto? leg) {
    if (leg == null || leg.checkpoints.isEmpty) return null;
    final WeatherStatus status = WeatherStatus.fromJson(leg.status);
    if (status != WeatherStatus.ok && status != WeatherStatus.stale) {
      return null;
    }
    return leg.checkpoints.first.weather;
  }

  @override
  Widget build(BuildContext context) {
    final WeatherConditionsDto? now = _departureOf(leg);
    if (now == null) return const SizedBox.shrink();
    final WeatherLegDto current = leg!;
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final String temperature = AppFormatters.formatTemperature(
      now.temperature,
      units,
    );
    final String condition = weatherConditionOf(now.condition).labelKey.tr();
    final WeatherRainAlertDto? alert = current.rainAlert;
    final String? rain = alert == null
        ? null
        : 'rides.weather.rainAlertShort'.tr(
            namedArgs: <String, String>{
              'probability': AppFormatters.formatPercent(alert.probability),
              'time': formatWeatherTime(alert.time, timezone),
            },
          );
    final List<(RelativeWind, String)> exposure = <(RelativeWind, String)>[
      for (final (RelativeWind wind, double meters) in <(RelativeWind, double)>[
        (RelativeWind.head, current.windExposure.head),
        (RelativeWind.tail, current.windExposure.tail),
      ])
        if (meters > 0)
          (
            wind,
            'rides.weather.exposure.${wind.name}'.tr(
              namedArgs: <String, String>{
                'distance': AppFormatters.formatDistance(meters, units),
              },
            ),
          ),
    ];

    return Semantics(
      container: true,
      label: <String>[
        'rides.weather.title'.tr(),
        temperature,
        condition,
        ?rain,
        for (final (RelativeWind _, String label) in exposure) label,
      ].join(', '),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: PdlSpacing.chipGap,
          runSpacing: PdlSpacing.badgeGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                WeatherConditionIcon(
                  condition: now.condition,
                  daylight: now.daylight,
                  size: 16,
                ),
                const SizedBox(width: PdlSpacing.badgeGap),
                Text(temperature, style: t.statValue),
                const SizedBox(width: PdlSpacing.badgeGap),
                Flexible(
                  child: Text(
                    condition,
                    style: t.xs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (rain != null)
              PdlBadge(
                label: rain,
                tone: PdlFamily.yellow.soft(c),
                icon: PdlIcons.precipitation,
              ),
            for (final (RelativeWind wind, String label) in exposure)
              PdlBadge(label: label, tone: wind.tone(c)),
          ],
        ),
      ),
    );
  }
}
