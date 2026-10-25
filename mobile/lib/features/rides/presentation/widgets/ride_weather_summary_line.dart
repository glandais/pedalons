import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../domain/ride_weather_display.dart';

/// La ligne météo d'une carte de sortie (fil, fil d'équipe, « Ma prochaine
/// sortie ») : `RideDto.weather` / `PublicationDtoRide.weather` — et d'une
/// carte de voyage, celle de sa prochaine étape (`PublicationDtoTrip.weather`,
/// ledger `API-82`).
///
/// Le serveur ne la remplit que pour `OK`, `STALE` et `NOT_YET_AVAILABLE`, au
/// point de départ, sur la fenêtre départ → dernière arrivée estimée. On
/// rend : l'icône de la condition au départ, la plage **min → max**, le vent
/// au départ, puis la pluie — l'alerte quand il y en a une, sinon la plus
/// forte probabilité, et pour `STALE` la marque « Prévision ancienne » (comme
/// le web). Pour `NOT_YET_AVAILABLE`, la date d'ouverture de la prévision.
/// Rien pour un statut inconnu, une sortie terminée ou annulée.
///
/// Aucune requête : la ligne de liste porte tout (0 ou 1 requête par page
/// côté serveur, plan météo §1).
class RideWeatherSummaryLine extends ConsumerWidget {
  const RideWeatherSummaryLine({
    super.key,
    required this.summary,
    required this.timezone,
    this.finished = false,
    this.cancelled = false,
  });

  final RideWeatherSummaryDto? summary;

  /// Le fuseau de la sortie ou de l'étape (`RideDto.timezone`…), où se lit
  /// l'heure de l'alerte pluie — sans mention : la carte la porte déjà
  /// (docs/LEDGER_*.md API-60). Celui du résumé (`RideWeatherSummaryDto.timezone`)
  /// l'emporte quand il est là : sur la carte d'un voyage, la ligne est celle
  /// de sa prochaine étape, pas de sa première.
  final String? timezone;
  final bool finished;
  final bool cancelled;

  /// La ligne a-t-elle quelque chose à montrer ? Les cartes s'en servent pour
  /// ne pas réserver d'espacement à une ligne vide.
  static bool shows(
    RideWeatherSummaryDto? summary, {
    bool finished = false,
    bool cancelled = false,
  }) {
    if (finished || cancelled || !showsWeatherSummary(summary)) return false;
    if (WeatherStatus.fromJson(summary!.status) ==
        WeatherStatus.notYetAvailable) {
      return summary.availableFrom != null &&
          DateTime.tryParse(summary.availableFrom!) != null;
    }
    return summary.temperature != null ||
        summary.temperatureMin != null ||
        summary.wind != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RideWeatherSummaryDto? s = summary;
    if (s == null || !shows(s, finished: finished, cancelled: cancelled)) {
      return const SizedBox.shrink();
    }
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);

    if (WeatherStatus.fromJson(s.status) == WeatherStatus.notYetAvailable) {
      final String text = 'rides.weather.summaryAvailableFrom'.tr(
        namedArgs: <String, String>{
          'date': AppFormatters.formatDayMonth(
            DateTime.parse(s.availableFrom!),
          ),
        },
      );
      return Semantics(
        key: keys.ride.weatherSummary,
        container: true,
        label: text,
        child: ExcludeSemantics(
          child: _Part(icon: PdlIcons.weatherUnknown, text: text),
        ),
      );
    }

    final bool stale = WeatherStatus.fromJson(s.status) == WeatherStatus.stale;
    final String condition = weatherConditionOf(s.condition).labelKey.tr();
    final String? temperature =
        s.temperatureMin != null && s.temperatureMax != null
        ? AppFormatters.formatTemperatureRange(
            s.temperatureMin!,
            s.temperatureMax!,
            units,
          )
        : (s.temperature == null
              ? null
              : AppFormatters.formatTemperature(s.temperature!, units));
    final WindDto? wind = s.wind;
    final String? windText = wind == null
        ? null
        : formatWind(wind, units, gusts: false);
    final WeatherRainAlertDto? alert = s.rainAlert;
    final String? rain = alert != null
        ? 'rides.weather.rainAlertShort'.tr(
            namedArgs: <String, String>{
              'probability': AppFormatters.formatPercent(alert.probability),
              'time': formatWeatherTime(alert.time, s.timezone ?? timezone),
            },
          )
        : (s.maxPrecipitationProbability == null
              ? null
              : 'rides.weather.rainChance'.tr(
                  namedArgs: <String, String>{
                    'probability': AppFormatters.formatPercent(
                      s.maxPrecipitationProbability!,
                    ),
                  },
                ));

    return Semantics(
      key: keys.ride.weatherSummary,
      container: true,
      label: <String>[
        'rides.weather.title'.tr(),
        condition,
        ?temperature,
        ?windText,
        ?rain,
        if (stale) 'rides.weather.stale'.tr(),
      ].join(', '),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: PdlSpacing.statsNowrap,
          runSpacing: PdlSpacing.badgeGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _Part(
              icon: weatherConditionOf(s.condition)
                  .icon(daylight: s.daylight ?? true),
              iconColor: c.text,
              text: temperature ?? condition,
            ),
            if (wind != null && windText != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PdlWindArrow(angle: windArrowAngle(wind.direction), size: 14),
                  const SizedBox(width: 2),
                  Flexible(child: Text(windText, style: t.statValue)),
                ],
              ),
            if (rain != null)
              _Part(
                icon: PdlIcons.precipitation,
                iconColor: alert != null ? c.warning : null,
                text: rain,
              ),
            if (stale)
              Icon(
                PdlIcons.weatherStale,
                key: keys.ride.weatherSummaryStale,
                size: 14,
                color: c.textDimmed,
              ),
          ],
        ),
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 16, color: iconColor ?? context.pdl.textDimmed),
      const SizedBox(width: PdlSpacing.badgeGap),
      Flexible(child: Text(text, style: context.pdlText.statValue)),
    ],
  );
}
