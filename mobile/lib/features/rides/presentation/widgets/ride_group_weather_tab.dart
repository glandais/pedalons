import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../domain/ride_weather_display.dart';
import '../../domain/ride_weather_map.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_weather_provider.dart';
import 'departure_weather_section.dart';
import 'ride_groups_map.dart';
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
/// En tête, quand le leg a une prévision ([showsWindOnMap]) et le groupe un
/// parcours : la carte du groupe, **toujours en mode « Météo »** (ledger
/// `MOB-93`, palier 3 de `docs/plans/2026-10-24-weather-on-map.md`) — le
/// tracé coloré par le vent, la légende et le crédit, sans puce ni pastille.
/// Elle ne se manipule pas ; un toucher ouvre le plein écran, en mode
/// « Météo » lui aussi, avec ses pastilles. Toucher un point de la frise y
/// pose le réticule, à la distance chaînée du point ; le retoucher l'ôte.
///
/// Le mode imposé n'écrit pas `rideMapWindModeProvider` : c'est le choix de
/// la personne dans l'Aperçu, que passer par cet onglet ne doit pas changer.
/// Les deux onglets ne sont jamais montés ensemble (la page n'en construit
/// qu'un) : une seule vue native à la fois.
///
/// Un sliver ([SliverMainAxisGroup]) : la page le pose sous ses onglets.
class RideGroupWeatherTab extends ConsumerStatefulWidget {
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
  ConsumerState<RideGroupWeatherTab> createState() =>
      _RideGroupWeatherTabState();
}

class _RideGroupWeatherTabState extends ConsumerState<RideGroupWeatherTab> {
  /// Le point de la frise dont le réticule est sur la carte : son `index` et
  /// sa distance. `null` : aucun.
  ({int index, double distance})? _cursor;

  RideKey get rideKey => widget.rideKey;
  RideDto get ride => widget.ride;
  String get groupId => widget.groupId;

  @override
  void didUpdateWidget(RideGroupWeatherTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Une autre pastille de groupe : un autre parcours, un autre leg.
    if (oldWidget.groupId != widget.groupId) _cursor = null;
  }

  void _toggleCursor(WeatherCheckpointDto checkpoint) {
    setState(() {
      _cursor = _cursor?.index == checkpoint.indexField
          ? null
          : (index: checkpoint.indexField, distance: checkpoint.distance);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Une sortie terminée ou annulée ne demande pas sa météo — comme le
    // détail et les cartes de groupe : le serveur répondrait `OUT_OF_RANGE`,
    // qui mène au même état neutre, mais au prix d'un appel.
    if (ride.isPast || ride.isCancelled) {
      return SliverMainAxisGroup(slivers: <Widget>[_empty()]);
    }
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
        return <Widget>[_empty()];
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
    final WeatherLegDto? leg = weatherLegOfGroup(dto.legs, groupId);
    RideGroupDto? group;
    for (final RideGroupDto g in ride.groups) {
      if (g.id == groupId) group = g;
    }
    final String? groupName = group?.name;
    // La carte : une prévision sur le leg et un parcours à dessiner.
    final bool showsMap =
        group != null &&
        (group.routeSlug ?? ride.routeSlug) != null &&
        showsWindOnMap(leg);
    final DateTime? fetchedAt = dto.fetchedAt == null
        ? null
        : DateTime.tryParse(dto.fetchedAt!);

    return <Widget>[
      if (showsMap)
        SliverPadding(
          padding: const EdgeInsets.only(top: PdlSpacing.section),
          sliver: SliverToBoxAdapter(
            child: RideGroupsMap(
              key: keys.rideGroup.weatherTabMap,
              rideKey: rideKey,
              ride: ride,
              onlyGroup: group,
              weatherLeg: leg,
              weatherAttribution: dto.attribution,
              forceWeatherMode: true,
              cursorDistance: _cursor?.distance,
            ),
          ),
        ),
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
        ...weatherLegBody(
          leg,
          padded,
          ride.timezone,
          onCheckpointTap: showsMap ? _toggleCursor : null,
          selectedCheckpoint: showsMap ? _cursor?.index : null,
        ),
      ],
      padded(
        WeatherAttributionBlock(
          attribution: dto.attribution,
          fetchedAt: fetchedAt,
        ),
      ),
    ];
  }

  Widget _empty() => SliverToBoxAdapter(
    child: PdlEmptyState(
      key: keys.rideGroup.weatherEmpty,
      variant: PdlEmptyVariant.empty,
      icon: PdlIcons.weatherUnknown,
      title: 'rides.weather.emptyTitle'.tr(),
      message: 'rides.weather.emptyMessage'.tr(),
    ),
  );
}
