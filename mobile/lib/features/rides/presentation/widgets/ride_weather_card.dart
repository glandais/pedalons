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
import '../../domain/solo_group.dart';
import '../../../../keys.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_weather_provider.dart';
import 'departure_weather_section.dart';
import 'weather_leg_sections.dart';
import 'ride_weather_widgets.dart';

/// La carte météo du détail d'une sortie : « Météo au départ », seulement.
///
/// Les conditions au point de rendez-vous à l'heure de la sortie — ressenti,
/// vent et rafales, pluie, lever et coucher du soleil —, puis le crédit et
/// l'heure de la prévision. Ni lien, ni groupe, ni alerte de groupe : la météo
/// d'un groupe le long de son parcours vit dans l'onglet Météo de sa page, et
/// sa ligne courte sur sa carte (ledger `MOB-67`).
///
/// Exception : une sortie **sans groupe ou à un seul groupe** n'a pas de page
/// de groupe (ledger `MOB-69`) : son leg ([rideOwnLeg] — l'unique leg sans
/// `groupId`, ou celui de son groupe) se déroule ici en entier, sous la météo
/// au départ — horaires, alerte pluie, exposition au vent, frise des points de
/// passage —, sans quoi sa météo du parcours disparaîtrait.
///
/// Rien n'est rendu pour une sortie terminée ou annulée — sans même appeler
/// l'API —, ni pour un statut que l'app ne connaît pas. `NO_LOCATION` n'est
/// dit qu'aux organisateurs : un membre n'y peut rien.
class RideWeatherCard extends ConsumerWidget {
  const RideWeatherCard({super.key, required this.rideKey, required this.ride});

  final RideKey rideKey;
  final RideDto ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ride.isPast || ride.isCancelled) return const SizedBox.shrink();

    final AsyncValue<RideWeatherDto> weather = ref.watch(
      rideWeatherProvider(rideKey),
    );
    final bool canSeeNoLocation = watchCanSeeWeatherNoLocation(
      ref,
      ride.team.slug,
    );

    Widget padded(Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        0,
        PdlSpacing.section,
        PdlSpacing.section,
      ),
      child: child,
    );

    void retry() => ref.invalidate(rideWeatherProvider(rideKey));

    return weather.when(
      loading: () => _loading(padded),
      // Un échec réseau se lit comme `UNAVAILABLE` : un enrichissement ne
      // casse pas l'écran, et « Réessayer » suffit.
      error: (Object _, StackTrace _) =>
          padded(WeatherUnavailableCard(onRetry: retry)),
      data: (RideWeatherDto dto) {
        switch (rideWeatherViewOf(
          dto.status,
          canSeeNoLocation: canSeeNoLocation,
        )) {
          case RideWeatherView.hidden:
            return const SizedBox.shrink();
          case RideWeatherView.noLocation:
            return padded(
              PdlBanner(
                key: keys.ride.weatherNoLocation,
                tone: PdlBannerTone.info,
                icon: PdlIcons.weatherUnknown,
                message: 'rides.weather.noLocation'.tr(),
              ),
            );
          case RideWeatherView.unavailable:
            return padded(WeatherUnavailableCard(onRetry: retry));
          case RideWeatherView.notYetAvailable:
            return padded(
              WeatherNotYetAvailableCard(availableFrom: dto.availableFrom),
            );
          case RideWeatherView.forecast:
          case RideWeatherView.stale:
            return padded(
              RideDepartureWeatherCard(
                weather: dto,
                timezone: ride.timezone,
                // Le leg d'une sortie sans groupe ou solo, seul porteur de sa
                // météo le long du parcours.
                ownLeg: rideOwnLeg(dto, ride),
              ),
            );
        }
      },
    );
  }

  /// Pendant le chargement, on ne réserve que la place d'un bloc qu'on sait
  /// devoir afficher. Le détail porte déjà la ligne de résumé
  /// (`RideDto.weather`, la même que les listes), présente seulement pour
  /// `OK`, `STALE` et `NOT_YET_AVAILABLE` :
  /// - `OK`/`STALE` : la carte prévision suivra, son squelette tient sa place ;
  /// - `NOT_YET_AVAILABLE` : la carte est déjà connue, on la rend telle quelle ;
  /// - pas de résumé (brouillon, `NO_LOCATION`, rien en cache, statut
  ///   inconnu) : rien, comme le web. Le bloc qui apparaît ensuite (bandeau
  ///   aux organisateurs, « indisponible ») ne fait sauter l'écran qu'une fois,
  ///   et le cas le plus courant — un membre, sans lieu — pas du tout.
  Widget _loading(Widget Function(Widget) padded) {
    final RideWeatherSummaryDto? summary = ride.weather;
    if (summary == null) return const SizedBox.shrink();
    return switch (WeatherStatus.fromJson(summary.status)) {
      WeatherStatus.ok || WeatherStatus.stale => padded(
        const PdlSkeleton(height: 96, borderRadius: PdlRadii.cardAll),
      ),
      WeatherStatus.notYetAvailable => padded(
        WeatherNotYetAvailableCard(availableFrom: summary.availableFrom),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// « Météo au départ » d'une sortie, en carte : les conditions au point de
/// rendez-vous ([DepartureConditionsBlock]), la marque « Prévision ancienne »,
/// le crédit et l'heure de la prévision. [ownLeg] déroule dessous le leg
/// d'une sortie sans groupe ou solo, comme l'onglet Météo de la page d'un
/// groupe : en-tête, alerte pluie, exposition, frise des points de passage.
class RideDepartureWeatherCard extends ConsumerWidget {
  const RideDepartureWeatherCard({
    super.key,
    required this.weather,
    required this.timezone,
    this.ownLeg,
  });

  final RideWeatherDto weather;

  /// Le fuseau de la sortie : lever, coucher du soleil et alerte s'y lisent.
  final String? timezone;
  final WeatherLegDto? ownLeg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final WeatherConditionsDto? now = weather.departure.conditions;
    final bool stale =
        WeatherStatus.fromJson(weather.status) == WeatherStatus.stale;
    final WeatherLegDto? leg = ownLeg;
    final DateTime? fetchedAt = weather.fetchedAt == null
        ? null
        : DateTime.tryParse(weather.fetchedAt!);

    final Widget card = PdlCard(
      key: keys.ride.weatherCard,
      flat: true,
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
            DepartureConditionsBlock(
              conditions: now,
              units: units,
              sunrise: weather.departure.sunrise,
              sunset: weather.departure.sunset,
              timezone: timezone,
            )
          else
            Text('rides.weather.unavailableTitle'.tr(), style: t.sub),
          const SizedBox(height: PdlSpacing.cardTight),
          WeatherAttributionBlock(
            key: keys.ride.weatherAttribution,
            attribution: weather.attribution,
            fetchedAt: fetchedAt,
          ),
        ],
      ),
    );
    if (leg == null) return card;

    // Le leg sous la carte, avec les sections de l'onglet Météo de la page
    // d'un groupe — pas un second bloc « Météo au départ ».
    Widget spaced(Widget child) => Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: child,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        card,
        spaced(WeatherLegHeader(leg: leg, title: null, timezone: timezone)),
        ...weatherLegBody(leg, spaced, timezone),
      ],
    );
  }
}

/// La carte « prévision » : le départ, le vent le long du parcours de [leg]
/// et son alerte pluie, le lien vers l'écran et le crédit. Partagée par la
/// sortie (départ au point de rendez-vous) et l'étape de voyage (départ = le
/// premier point de passage de son leg).
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
