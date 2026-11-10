import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../domain/ride_weather_display.dart';

/// La ligne météo d'une carte (KIT §8, ledger `MOB-134`) : « ☁ 10–13 °C ·
/// → 18 km/h · Pluie 20 % », 14 px gris, icônes 14 px. **Un seul widget** pour
/// toutes les cartes qui portent un `RideWeatherSummaryDto` : carte de sortie
/// (fil, fil d'équipe, « Ma prochaine sortie » : `RideDto.weather` /
/// `PublicationDtoRide.weather`), de voyage (sa prochaine étape,
/// `PublicationDtoTrip.weather`, ledger `API-82`), d'étape
/// (`TripStageWeatherDto.summary`) et de groupe (`WeatherLegDto.summary`, par
/// `RideGroupWeatherLine`).
///
/// Le serveur ne la remplit que pour `OK`, `STALE` et `NOT_YET_AVAILABLE`, au
/// point de départ, sur la fenêtre départ → dernière arrivée estimée. On
/// rend : l'icône de la condition au départ, la plage **min → max**, le vent
/// au départ — sa flèche porte la direction, le texte ne dit que la vitesse —,
/// puis la pluie : l'alerte « Pluie 60 % vers 11:00 » en ton d'alerte quand il
/// y en a une, sinon la plus forte probabilité. Ni ciel en toutes lettres ni
/// badge Face / Dos. Pour `STALE`, la marque « Prévision ancienne » (comme le
/// web) ; pour `NOT_YET_AVAILABLE`, la date d'ouverture de la prévision. Rien
/// pour un statut inconnu, une sortie terminée ou annulée.
///
/// Aucune requête : la ligne de liste porte tout (0 ou 1 requête par page
/// côté serveur, plan météo §1).
class RideWeatherSummaryLine extends StatelessWidget {
  const RideWeatherSummaryLine({
    super.key,
    required this.summary,
    required this.timezone,
    this.finished = false,
    this.cancelled = false,
    this.units,
  });

  /// Les unités du lecteur ; `null` : lues de `unitSystemProvider`. Une carte
  /// qui les reçoit déjà (celle d'un groupe) les passe, et se rend alors sans
  /// `ProviderScope`.
  final UnitSystem? units;

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
  Widget build(BuildContext context) {
    final RideWeatherSummaryDto? s = summary;
    if (s == null || !shows(s, finished: finished, cancelled: cancelled)) {
      return const SizedBox.shrink();
    }
    final UnitSystem? given = units;
    if (given != null) return _line(context, s, given);
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) =>
          _line(context, s, ref.watch(unitSystemProvider)),
    );
  }

  Widget _line(
    BuildContext context,
    RideWeatherSummaryDto s,
    UnitSystem units,
  ) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

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
    // Le lecteur d'écran entend le point cardinal ; à l'écran, la flèche le
    // porte et le texte ne dit que la vitesse (KIT §8).
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
    // L'alerte en ton d'alerte : l'icône dans la teinte d'avertissement, le
    // texte dans la teinte lisible de la même famille (celle du badge
    // « Travers »), qui tient le contraste sur la surface d'une carte.
    final Color alertText = PdlFamily.yellow.soft(c).onSoft;

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
              text: temperature ?? condition,
            ),
            if (wind != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PdlWindArrow(
                    angle: windArrowAngle(wind.direction),
                    size: _iconSize,
                    color: c.textDimmed,
                  ),
                  const SizedBox(width: _iconGap),
                  Flexible(
                    child: Text(
                      AppFormatters.formatSpeed(wind.speed, units),
                      style: t.sub,
                    ),
                  ),
                ],
              ),
            if (alert != null && rain != null)
              _Part(
                key: keys.ride.weatherSummaryRainAlert,
                icon: PdlIcons.warning,
                iconColor: c.warning,
                text: rain,
                textColor: alertText,
              )
            else if (rain != null)
              Text(rain, style: t.sub),
            if (stale)
              Icon(
                PdlIcons.weatherStale,
                key: keys.ride.weatherSummaryStale,
                size: _iconSize,
                color: c.textDimmed,
              ),
          ],
        ),
      ),
    );
  }
}

/// Les icônes de la ligne, 14 px comme celles de la ligne de chiffres.
const double _iconSize = 14;
const double _iconGap = 3;

class _Part extends StatelessWidget {
  const _Part({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String text;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.pdlText.sub;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: _iconSize, color: iconColor ?? context.pdl.textDimmed),
        const SizedBox(width: _iconGap),
        Flexible(
          child: Text(
            text,
            style: textColor == null ? style : style.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}
