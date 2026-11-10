import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../../rides/domain/ride_weather_display.dart';
import '../../../rides/presentation/widgets/ride_weather_widgets.dart';
import '../../../rides/presentation/widgets/weather_leg_sections.dart';
import '../../../rides/presentation/widgets/weather_section.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_weather_provider.dart';

/// « Météo du parcours » d'une étape de voyage — poussé depuis la carte
/// météo de l'écran 25.
///
/// Comme celui d'une sortie, poussé par `Navigator.push` et absent de
/// `contracts/routes.yaml` : il prolonge l'écran de l'étape, sans URL à lui.
/// Il pose la section Météo (`WeatherSection`, ledger `MOB-132`) du seul leg
/// de l'étape, dépliée : rien ne la suit. Le lot 11 la déplace dans la page
/// de l'étape et retire celle-ci.
class StageWeatherPage extends ConsumerWidget {
  const StageWeatherPage({
    super.key,
    required this.tripKey,
    required this.stageId,
    required this.stageName,
    required this.timezone,
  });

  final TripKey tripKey;
  final String stageId;
  final String stageName;

  /// Le fuseau de l'étape (`TripStageDto.timezone`) : ses passages s'y lisent
  /// (docs/LEDGER_*.md API-60).
  final String? timezone;

  static Future<void> open(
    BuildContext context,
    TripKey tripKey,
    TripStageDto stage,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => StageWeatherPage(
        tripKey: tripKey,
        stageId: stage.id,
        stageName: stage.name,
        timezone: stage.timezone,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TripWeatherDto> weather = ref.watch(
      tripWeatherProvider(tripKey),
    );
    final bool canSeeNoLocation = watchCanSeeWeatherNoLocation(
      ref,
      tripKey.teamSlug,
    );

    Future<void> refresh() async {
      ref.invalidate(tripWeatherProvider(tripKey));
      try {
        await ref.read(tripWeatherProvider(tripKey).future);
      } catch (_) {
        // L'état d'erreur se rend tout seul ; le geste n'a rien à ajouter.
      }
    }

    void retry() => ref.invalidate(tripWeatherProvider(tripKey));

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'rides.weather.routeTitle'.tr(),
        onBack: () => Navigator.of(context).maybePop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      onRefresh: refresh,
      slivers: <Widget>[
        ...weather.when(
          loading: () => <Widget>[
            const SliverPadding(
              padding: EdgeInsets.all(PdlSpacing.section),
              sliver: SliverToBoxAdapter(
                child: PdlSkeleton(height: 240, borderRadius: PdlRadii.cardAll),
              ),
            ),
          ],
          error: (Object _, StackTrace _) => <Widget>[
            weatherUnavailableSliver(retry),
          ],
          data: (TripWeatherDto dto) =>
              _content(dto, canSeeNoLocation: canSeeNoLocation, onRetry: retry),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  List<Widget> _content(
    TripWeatherDto dto, {
    required bool canSeeNoLocation,
    required VoidCallback onRetry,
  }) {
    // On n'arrive ici que depuis une prévision ; un pull-to-refresh peut
    // pourtant rendre l'étape partie, le voyage annulé, un statut inconnu :
    // un état neutre, jamais un écran blanc.
    final List<Widget> empty = <Widget>[
      SliverToBoxAdapter(
        child: PdlEmptyState(
          key: keys.ride.weatherEmpty,
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.weatherUnknown,
          title: 'trips.weather.emptyTitle'.tr(),
          message: 'trips.weather.emptyMessage'.tr(),
        ),
      ),
    ];

    final TripStageWeatherDto? stageWeather = tripWeatherShowsAnything(dto)
        ? stageWeatherFor(dto, stageId)
        : null;
    if (stageWeather == null) return empty;
    final WeatherLegDto leg = stageWeather.leg;
    final RideWeatherView view = rideWeatherViewOf(
      leg.status,
      canSeeNoLocation: canSeeNoLocation,
    );
    if (!WeatherSection.shows(view)) return empty;

    final String? rawFetchedAt = leg.fetchedAt ?? dto.fetchedAt;
    final String? rawAvailableFrom =
        leg.availableFrom ?? stageWeather.summary?.availableFrom;

    // Dépliée : rien ne suit la section sur cette page. Le départ est celui
    // de l'étape (`TripStageWeatherDto.departure`), à l'heure de son leg.
    return <Widget>[
      WeatherSection.sliver(
        view: view,
        timezone: timezone,
        departure: stageWeather.departure,
        departureAt: leg.startTime,
        leg: leg,
        attribution: dto.attribution,
        fetchedAt: rawFetchedAt == null
            ? null
            : DateTime.tryParse(rawFetchedAt),
        availableFrom: rawAvailableFrom == null
            ? null
            : DateTime.tryParse(rawAvailableFrom),
        speedDefaultKey: 'trips.weather.legSpeedDefault',
        noLocationMessage: 'trips.weather.noLocation'.tr(),
        onRetry: onRetry,
      ),
    ];
  }
}
