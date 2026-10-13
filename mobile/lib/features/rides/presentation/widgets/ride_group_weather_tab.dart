import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../domain/ride_weather_display.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_weather_provider.dart';
import 'departure_weather_section.dart';
import 'ride_weather_widgets.dart';
import 'weather_leg_sections.dart';

/// L'onglet Météo de la page d'un groupe — ce que montrait l'écran « Météo du
/// parcours », pour **ce** groupe (ledger `MOB-67`).
///
/// De haut en bas : la marque « Prévision ancienne », la météo au départ (au
/// point de rendez-vous, à l'heure de la sortie), puis le leg du groupe —
/// horaires et vitesse, alerte pluie, exposition, vent le long du parcours,
/// frise des points de passage — et l'attribution. Tout ce qui suit le départ
/// vit dans `weather_leg_sections.dart`, partagé avec l'écran météo d'une
/// étape de voyage.
///
/// Un sliver ([SliverMainAxisGroup]) : la page le pose sous ses onglets.
class RideGroupWeatherTab extends ConsumerWidget {
  const RideGroupWeatherTab({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.groupId,
  });

  final RideKey rideKey;
  final RideDto ride;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RideWeatherDto> weather = ref.watch(
      rideWeatherProvider(rideKey),
    );
    final bool canSeeNoLocation = watchCanSeeWeatherNoLocation(
      ref,
      rideKey.teamSlug,
    );

    return SliverMainAxisGroup(
      slivers: weather.when(
        loading: () => <Widget>[
          const SliverPadding(
            padding: EdgeInsets.all(PdlSpacing.section),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: <Widget>[
                  PdlSkeleton(height: 120, borderRadius: PdlRadii.cardAll),
                  SizedBox(height: PdlSpacing.section),
                  PdlSkeleton(height: 240, borderRadius: PdlRadii.cardAll),
                ],
              ),
            ),
          ),
        ],
        error: (Object _, StackTrace _) => <Widget>[
          weatherUnavailableSliver(
            () => ref.invalidate(rideWeatherProvider(rideKey)),
          ),
        ],
        data: (RideWeatherDto dto) =>
            _content(ref, dto, canSeeNoLocation: canSeeNoLocation),
      ),
    );
  }

  List<Widget> _content(
    WidgetRef ref,
    RideWeatherDto dto, {
    required bool canSeeNoLocation,
  }) {
    Widget padded(Widget child) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.section,
        PdlSpacing.section,
        0,
      ),
      sliver: SliverToBoxAdapter(child: child),
    );

    switch (rideWeatherViewOf(dto.status, canSeeNoLocation: canSeeNoLocation)) {
      case RideWeatherView.hidden:
        // Sortie terminée ou annulée (`OUT_OF_RANGE`), `NO_LOCATION` pour un
        // membre, statut d'une build plus récente : un état neutre, jamais un
        // onglet blanc.
        return <Widget>[
          SliverToBoxAdapter(
            child: PdlEmptyState(
              key: keys.rideGroup.weatherEmpty,
              variant: PdlEmptyVariant.empty,
              icon: PdlIcons.weatherUnknown,
              title: 'rides.weather.emptyTitle'.tr(),
              message: 'rides.weather.emptyMessage'.tr(),
            ),
          ),
        ];
      case RideWeatherView.unavailable:
        return <Widget>[
          weatherUnavailableSliver(
            () => ref.invalidate(rideWeatherProvider(rideKey)),
          ),
        ];
      case RideWeatherView.noLocation:
        return <Widget>[
          padded(
            PdlBanner(
              key: keys.ride.weatherNoLocation,
              tone: PdlBannerTone.info,
              icon: PdlIcons.weatherUnknown,
              message: 'rides.weather.noLocation'.tr(),
            ),
          ),
        ];
      case RideWeatherView.notYetAvailable:
        final DateTime? from = dto.availableFrom == null
            ? null
            : DateTime.tryParse(dto.availableFrom!);
        return <Widget>[
          padded(
            PdlBanner(
              key: keys.ride.weatherNotYetAvailable,
              tone: PdlBannerTone.info,
              icon: PdlIcons.date,
              message: notYetAvailableMessage(from),
            ),
          ),
        ];
      case RideWeatherView.forecast:
      case RideWeatherView.stale:
        break;
    }

    final bool stale =
        WeatherStatus.fromJson(dto.status) == WeatherStatus.stale;
    // Le leg **de ce groupe**, et lui seul : le repli de `weatherLegFor` sur
    // un autre leg prêterait au groupe la météo d'un autre parcours.
    WeatherLegDto? leg;
    for (final WeatherLegDto l in dto.legs) {
      if (l.groupId == groupId) leg = l;
    }
    String? groupName;
    for (final RideGroupDto g in ride.groups) {
      if (g.id == groupId) groupName = g.name;
    }
    final DateTime? fetchedAt = dto.fetchedAt == null
        ? null
        : DateTime.tryParse(dto.fetchedAt!);

    return <Widget>[
      if (stale) padded(WeatherStaleBanner(fetchedAt: fetchedAt)),
      padded(
        DepartureWeatherSection(
          departure: dto.departure,
          timezone: ride.timezone,
        ),
      ),
      if (leg != null) ...<Widget>[
        padded(
          WeatherLegHeader(leg: leg, title: groupName, timezone: ride.timezone),
        ),
        ...weatherLegBody(leg, padded, ride.timezone),
      ],
      padded(
        WeatherAttributionBlock(
          attribution: dto.attribution,
          fetchedAt: fetchedAt,
        ),
      ),
    ];
  }
}
