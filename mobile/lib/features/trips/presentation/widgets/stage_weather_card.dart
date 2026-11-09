import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../../rides/domain/ride_weather_display.dart';
import '../../../rides/presentation/widgets/ride_weather_card.dart';
import '../../../rides/presentation/widgets/ride_weather_widgets.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_weather_provider.dart';
import '../pages/stage_weather_page.dart';

/// La carte météo compacte d'une étape (écran 25) — les briques de la carte
/// d'une sortie (`ride_weather_card.dart`), alimentées par le leg de l'étape.
///
/// Pas de bloc « départ » propre à l'étape : le premier point de passage de
/// son leg **est** le départ, et c'est sa prévision que la carte résume. Un
/// appui pousse « Météo du parcours » pour ce leg.
///
/// Rien pour un voyage terminé ou annulé — sans même appeler l'API —, pour
/// une étape déjà partie (`OUT_OF_RANGE`) ou un statut inconnu. `NO_LOCATION`
/// (l'étape n'a pas de parcours) n'est dit qu'à qui peut corriger le voyage.
class StageWeatherCard extends ConsumerWidget {
  const StageWeatherCard({
    super.key,
    required this.tripKey,
    required this.trip,
    required this.stage,
    this.embedded = false,
  });

  final TripKey tripKey;
  final TripDto trip;
  final TripStageDto stage;

  /// Posée dans le bloc du parcours (ledger `MOB-118`), qui a déjà ses marges :
  /// seul l'écart au-dessus d'elle reste, et rien du tout sans prévision.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trip.isPast || trip.isCancelled) return const SizedBox.shrink();

    final AsyncValue<TripWeatherDto> weather = ref.watch(
      tripWeatherProvider(tripKey),
    );
    final bool canSeeNoLocation = watchCanSeeWeatherNoLocation(
      ref,
      trip.team.slug,
    );

    Widget padded(Widget child) => Padding(
      padding: embedded
          ? const EdgeInsets.only(top: PdlSpacing.section)
          : const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.section,
            ),
      child: child,
    );

    void retry() => ref.invalidate(tripWeatherProvider(tripKey));

    return weather.when(
      // Rien d'autre ne dit, avant la réponse, ce que l'étape aura : on ne
      // réserve pas de place (venu de l'écran 24, la météo est déjà là).
      loading: () => const SizedBox.shrink(),
      // Un échec réseau se lit comme `UNAVAILABLE` : « Réessayer » suffit.
      error: (Object _, StackTrace _) =>
          padded(WeatherUnavailableCard(onRetry: retry)),
      data: (TripWeatherDto dto) {
        if (!tripWeatherShowsAnything(dto)) return const SizedBox.shrink();
        final TripStageWeatherDto? stageWeather = stageWeatherFor(
          dto,
          stage.id,
        );
        if (stageWeather == null) return const SizedBox.shrink();
        final WeatherLegDto leg = stageWeather.leg;
        switch (rideWeatherViewOf(
          leg.status,
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
                message: 'trips.weather.noLocation'.tr(),
              ),
            );
          case RideWeatherView.unavailable:
            return padded(WeatherUnavailableCard(onRetry: retry));
          case RideWeatherView.notYetAvailable:
            return padded(
              WeatherNotYetAvailableCard(
                availableFrom:
                    leg.availableFrom ?? stageWeather.summary?.availableFrom,
              ),
            );
          case RideWeatherView.forecast:
          case RideWeatherView.stale:
            return padded(
              WeatherForecastCard(
                departure: leg.checkpoints.isEmpty
                    ? null
                    : leg.checkpoints.first.weather,
                attribution: dto.attribution,
                stale:
                    WeatherStatus.fromJson(leg.status) == WeatherStatus.stale,
                leg: leg,
                timezone: stage.timezone,
                onOpen: () => StageWeatherPage.open(context, tripKey, stage),
              ),
            );
        }
      },
    );
  }
}
