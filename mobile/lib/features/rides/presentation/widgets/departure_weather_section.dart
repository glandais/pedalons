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
import '../../domain/ride_weather_display.dart';
import 'ride_weather_widgets.dart';

/// « Météo au départ » : les conditions au point de rendez-vous, à l'heure de
/// la sortie — ressenti, pluie, vent et rafales, lever et coucher du soleil.
///
/// L'onglet Météo de la page d'un groupe s'ouvre sur lui ; la carte du détail
/// de la sortie en rend le bloc [DepartureConditionsBlock] (ledger `MOB-67`).
class DepartureWeatherSection extends ConsumerWidget {
  const DepartureWeatherSection({
    super.key,
    required this.departure,
    required this.timezone,
  });

  final DepartureWeatherDto departure;

  /// Le fuseau de la sortie : lever et coucher du soleil s'y lisent.
  final String? timezone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final WeatherConditionsDto? now = departure.conditions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(title: 'rides.weather.atDeparture'.tr()),
        PdlCard(
          flat: true,
          child: now == null
              ? Text('rides.weather.unavailableTitle'.tr(), style: t.sub)
              : DepartureConditionsBlock(
                  conditions: now,
                  units: units,
                  sunrise: departure.sunrise,
                  sunset: departure.sunset,
                  timezone: timezone,
                ),
        ),
      ],
    );
  }
}

/// Les conditions d'un départ : icône, température et ciel, puis ressenti,
/// pluie, vent avec rafales, lever et coucher du soleil.
class DepartureConditionsBlock extends StatelessWidget {
  const DepartureConditionsBlock({
    super.key,
    required this.conditions,
    required this.units,
    this.sunrise,
    this.sunset,
    this.timezone,
  });

  final WeatherConditionsDto conditions;
  final UnitSystem units;
  final String? sunrise;
  final String? sunset;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final String temperature = AppFormatters.formatTemperature(
      conditions.temperature,
      units,
    );
    final String condition = weatherConditionOf(conditions.condition).labelKey
        .tr();
    final List<String> facts = <String>[
      'rides.weather.feelsLike'.tr(
        namedArgs: <String, String>{
          'temperature': AppFormatters.formatTemperature(
            conditions.apparentTemperature,
            units,
          ),
        },
      ),
      if (conditions.precipitationProbability != null)
        'rides.weather.rainChance'.tr(
          namedArgs: <String, String>{
            'probability': AppFormatters.formatPercent(
              conditions.precipitationProbability!,
            ),
          },
        ),
      if (conditions.precipitation > 0)
        'rides.weather.precipitation'.tr(
          namedArgs: <String, String>{
            'amount': AppFormatters.formatPrecipitation(
              conditions.precipitation,
            ),
          },
        ),
    ];
    final String wind = formatWind(conditions.wind, units);
    final String? rise = sunrise == null
        ? null
        : 'rides.weather.sunrise'.tr(
            namedArgs: <String, String>{
              'time': formatWeatherTime(sunrise!, timezone),
            },
          );
    final String? set = sunset == null
        ? null
        : 'rides.weather.sunset'.tr(
            namedArgs: <String, String>{
              'time': formatWeatherTime(sunset!, timezone),
            },
          );

    return Semantics(
      container: true,
      label: <String>[
        temperature,
        condition,
        ...facts,
        wind,
        ?rise,
        ?set,
      ].join(', '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                WeatherConditionIcon(
                  condition: conditions.condition,
                  daylight: conditions.daylight,
                  size: 40,
                ),
                const SizedBox(width: PdlSpacing.cardTight),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(temperature, style: t.statBigValue),
                      Text(condition, style: t.sub),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PdlSpacing.chipGap),
            Wrap(
              spacing: PdlSpacing.statsNowrap,
              runSpacing: PdlSpacing.badgeGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final String f in facts) Text(f, style: t.xs),
                WeatherWindLine(wind: conditions.wind, units: units),
              ],
            ),
            if (rise != null || set != null) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              Wrap(
                spacing: PdlSpacing.statsNowrap,
                runSpacing: PdlSpacing.badgeGap,
                children: <Widget>[
                  if (rise != null)
                    _IconText(icon: PdlIcons.sunrise, text: rise),
                  if (set != null) _IconText(icon: PdlIcons.sunset, text: set),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 14, color: context.pdl.textDimmed),
      const SizedBox(width: 2),
      Flexible(child: Text(text, style: context.pdlText.xs)),
    ],
  );
}
