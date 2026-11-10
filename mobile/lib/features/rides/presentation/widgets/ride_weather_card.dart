/// Les cartes météo que l'étape de voyage emprunte encore
/// (`stage_weather_card.dart`, jusqu'au lot 11 du ledger `MOB-134`). Les
/// sorties, elles, passent toutes par `WeatherSection` : la carte « Météo au
/// départ » d'une sortie à plusieurs groupes (`RideWeatherCard`) est partie
/// avec le lot 8 (docs/LEDGER_*.md MOB-134).
library;

import 'package:easy_localization/easy_localization.dart';
// `Visibility` est à la fois un widget Flutter et un enum du contrat.
import 'package:flutter/material.dart' hide Visibility;
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
import '../../domain/ride_weather_display.dart';
import '../../../../keys.dart';
import 'ride_weather_widgets.dart';

/// La carte « prévision » : le départ, le vent le long du parcours de [leg]
/// et son alerte pluie, le lien vers l'écran et le crédit — celle de l'étape
/// de voyage (départ = le premier point de passage de son leg).
class WeatherForecastCard extends ConsumerWidget {
  const WeatherForecastCard({
    super.key,
    required this.departure,
    required this.attribution,
    required this.stale,
    required this.leg,
    required this.timezone,
    required this.onOpen,
  });

  final WeatherConditionsDto? departure;
  final WeatherAttributionDto attribution;
  final bool stale;
  final WeatherLegDto? leg;

  /// Le fuseau de la sortie ou de l'étape, où se lit l'heure de l'alerte
  /// pluie (docs/LEDGER_*.md API-60).
  final String? timezone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final WeatherConditionsDto? now = departure;
    final WeatherLegDto? leg = this.leg;
    final WeatherRainAlertDto? rain = leg?.rainAlert;

    return PdlCard(
      key: keys.ride.weatherCard,
      flat: true,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('rides.weather.atDeparture'.tr(), style: t.xs),
              ),
              if (stale)
                PdlBadge(
                  label: 'rides.weather.stale'.tr(),
                  tone: PdlFamily.yellow.soft(c),
                  icon: PdlIcons.warning,
                ),
            ],
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          if (now != null)
            _DepartureSummary(conditions: now, units: units)
          else
            Text('rides.weather.unavailableTitle'.tr(), style: t.sub),
          if (leg != null && leg.segments.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.cardTight),
            WeatherWindSegments(leg: leg, units: units),
          ],
          if (rain != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(PdlIcons.precipitation, size: 16, color: c.warning),
                const SizedBox(width: PdlSpacing.badgeGap),
                Expanded(
                  child: Text(
                    formatRainAlert(rain, units, timezone),
                    style: t.xs.copyWith(color: c.text),
                  ),
                ),
              ],
            ),
          ],
          // Le crédit CC BY 4.0 en légende, à côté du lien vers l'écran qui le
          // rend cliquable ; il passe dessous quand la place manque.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              PdlButton(
                key: keys.ride.weatherOpenButton,
                label: 'rides.weather.viewRoute'.tr(),
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                icon: PdlIcons.chevronRight,
                onPressed: onOpen,
              ),
              Text(
                weatherAttributionLabel(attribution),
                key: keys.ride.weatherAttribution,
                style: t.xs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Icône, température et condition, puis ressenti, pluie et vent.
class _DepartureSummary extends StatelessWidget {
  const _DepartureSummary({required this.conditions, required this.units});

  final WeatherConditionsDto conditions;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final String temperature = AppFormatters.formatTemperature(
      conditions.temperature,
      units,
    );
    final String condition = weatherConditionOf(conditions.condition).labelKey
        .tr();
    final String feelsLike = 'rides.weather.feelsLike'.tr(
      namedArgs: <String, String>{
        'temperature': AppFormatters.formatTemperature(
          conditions.apparentTemperature,
          units,
        ),
      },
    );
    final String? rainChance = conditions.precipitationProbability == null
        ? null
        : 'rides.weather.rainChance'.tr(
            namedArgs: <String, String>{
              'probability': AppFormatters.formatPercent(
                conditions.precipitationProbability!,
              ),
            },
          );
    final String wind = formatWind(conditions.wind, units, gusts: false);

    return Semantics(
      container: true,
      label: <String>[
        'rides.weather.atDeparture'.tr(),
        temperature,
        condition,
        feelsLike,
        ?rainChance,
        wind,
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
                  size: 32,
                ),
                const SizedBox(width: PdlSpacing.chipGap),
                Text(temperature, style: t.statBigValue),
                const SizedBox(width: PdlSpacing.chipGap),
                Expanded(
                  child: Text(
                    condition,
                    style: t.sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PdlSpacing.badgeGap),
            Wrap(
              spacing: PdlSpacing.statsNowrap,
              runSpacing: PdlSpacing.badgeGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(feelsLike, style: t.xs),
                if (rainChance != null) Text(rainChance, style: t.xs),
                WeatherWindLine(
                  wind: conditions.wind,
                  units: units,
                  gusts: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// « Prévision disponible à partir du … », en carte.
class WeatherNotYetAvailableCard extends StatelessWidget {
  const WeatherNotYetAvailableCard({super.key, required this.availableFrom});

  final String? availableFrom;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final DateTime? from = availableFrom == null
        ? null
        : DateTime.tryParse(availableFrom!);
    // Sans date lisible, la règle des sept jours, comme le web.
    return PdlCard(
      key: keys.ride.weatherNotYetAvailable,
      flat: true,
      child: Row(
        children: <Widget>[
          Icon(PdlIcons.weatherUnknown, size: 20, color: c.textDimmed),
          const SizedBox(width: PdlSpacing.chipGap),
          Expanded(child: Text(notYetAvailableMessage(from), style: t.sub)),
        ],
      ),
    );
  }
}

/// « Météo indisponible », avec « Réessayer ».
class WeatherUnavailableCard extends StatelessWidget {
  const WeatherUnavailableCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PdlBanner(
      key: keys.ride.weatherUnavailable,
      tone: PdlBannerTone.info,
      icon: PdlIcons.weatherUnknown,
      title: 'rides.weather.unavailableTitle'.tr(),
      message: 'rides.weather.unavailableMessage'.tr(),
      action: PdlButton(
        key: keys.ride.weatherRetryButton,
        label: 'common.retry'.tr(),
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        onPressed: onRetry,
      ),
    );
  }
}
