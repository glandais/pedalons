import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../routes/presentation/widgets/waypoint_selection.dart';
import '../../../routes/presentation/widgets/waypoint_sheet.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../../../keys.dart';

/// La hauteur de la carte de sortie.
///
/// La maquette la fige à 300 px ; le brief la veut proportionnelle, et c'est
/// lui qui l'emporte (§1.0.4) : 300 px fixes mangent 40 % d'un iPhone SE, et
/// laissent une bande vide sur un grand écran.
double rideMapHeight(double screenHeight) =>
    (screenHeight * 0.44).clamp(260.0, 460.0);

/// La carte multi-tracés de l'écran 12, et la moitié cartographique de la
/// sélection croisée.
///
/// **Une couche par groupe**, toutes adossées à une même source : le SDK
/// MapLibre rend `queryLayers` sans les propriétés de l'entité touchée, donc
/// seul le `layerId` porte l'identité d'un tracé (§1.0.3-7). `PdlMap` s'en
/// charge ; ce widget lui donne les tracés, la couleur de chacun, et reçoit le
/// tap.
///
/// Les géométries sont **dédoublonnées par `routeSlug`** en amont : dix groupes
/// sur trois parcours coûtent trois appels.
class RideGroupsMap extends ConsumerWidget {
  const RideGroupsMap({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.selectedGroupId,
    required this.onSelect,
    this.fullscreen = false,
    this.seedExtent,
  });

  final RideKey rideKey;
  final RideDto ride;
  final String? selectedGroupId;
  final ValueChanged<String> onSelect;

  /// L'emprise que l'écran connaissait au moment de pousser le plein écran.
  ///
  /// La page est une seconde instance, et le lot de géométries est
  /// `autoDispose` : le temps qu'elle le recharge, `extent` y vaut `null` et
  /// la carte se rabattrait sur le lieu de départ — un cadrage serré, puis un
  /// saut jusqu'à l'emprise réelle une fraction de seconde plus tard. Cette
  /// graine **est** l'emprise du backend, relevée un instant plus tôt.
  final BoundsDto? seedExtent;

  /// Vrai dans la page plein écran, que ce widget construit lui-même : la
  /// carte y prend tout l'écran et le bouton devient une sortie. C'est **la**
  /// raison pour laquelle le plein écran reconstruit `RideGroupsMap` au lieu
  /// de recopier son hero — voir `PdlMapHero.fullscreenBuilder`.
  final bool fullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double height = rideMapHeight(MediaQuery.sizeOf(context).height);
    final Brightness brightness = Theme.of(context).brightness;
    final AsyncValue<ResolvedMapStyle?> style = ref.watch(
      mapStyleProvider(brightness),
    );

    final List<String> slugs = distinctRouteSlugs(ride);
    if (slugs.isEmpty) {
      return PdlCard(
        child: PdlEmptyState(
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.route,
          title: 'rides.noRouteTitle'.tr(),
          message: 'rides.noRouteMessage'.tr(),
        ),
      );
    }

    // Une entrée de cache par parcours distinct, et une seule.
    final Map<String, RouteDetailDto> geometries = <String, RouteDetailDto>{};
    for (final String slug in slugs) {
      final RouteDetailDto? route = ref
          .watch(
            rideRouteGeometryProvider(
              RouteRef(
                teamSlug: ride.team.slug,
                rideSlug: rideKey.rideSlug,
                routeSlug: slug,
              ),
            ),
          )
          .value;
      if (route != null) geometries[slug] = route;
    }

    // L'emprise vient du serveur (`RoutesBulkResponse.extent`), pas d'un
    // parcours des sommets : elle arrive **avec** le premier lot, et couvre
    // déjà tous les parcours demandés — y compris ceux dont la géométrie est
    // encore en vol.
    final BoundsDto? extent =
        ref.watch(rideRouteGeometriesProvider(rideKey)).extent ?? seedExtent;

    final String? styleUrl = style.value?.url;
    if (styleUrl == null) {
      return PdlSkeleton(height: height, borderRadius: PdlRadii.mdAll);
    }

    final List<PdlMapTrack> tracks = _tracks(geometries);
    final RideGroupDto? selected = _selectedGroup();

    final Widget hero = PdlMapHero(
      isFullscreen: fullscreen,
      fullscreenBuilder: fullscreen
          ? null
          : (BuildContext context) => RideGroupsMap(
              rideKey: rideKey,
              ride: ride,
              selectedGroupId: selectedGroupId,
              onSelect: onSelect,
              fullscreen: true,
              seedExtent: extent,
            ),
      labels: PdlMapHeroLabels(
        enterFullscreen: 'map.fullscreen'.tr(),
        exitFullscreen: 'map.exitFullscreen'.tr(),
        chooseBackground: 'map.background'.tr(),
        backgroundSheetTitle: 'map.background'.tr(),
        hillshade: 'map.hillshade'.tr(),
      ),
      styles: servedMapStyleOptions(ref),
      hillshadeEnabled: servedHillshadeEnabled(ref),
      onHillshadeChanged: (bool on) =>
          ref.read(hillshadeEnabledProvider.notifier).set(on),
      selectedStyleId: style.value?.style.id,
      onStyleSelected: (String id) =>
          ref.read(mapStyleIdProvider.notifier).select(id),
      mapBuilder: (BuildContext context) => _map(
        context,
        styleUrl,
        servedMapCredit(style.value),
        tracks,
        selected,
        extent,
        ref,
        geometries,
      ),
    );

    // En plein écran la carte prend la page : pas de hauteur imposée.
    return fullscreen ? hero : SizedBox(height: height, child: hero);
  }

  Widget _map(
    BuildContext context,
    String styleUrl,
    PdlMapCredit credit,
    List<PdlMapTrack> tracks,
    RideGroupDto? selected,
    BoundsDto? extent,
    WidgetRef ref,
    Map<String, RouteDetailDto> geometries,
  ) {
    // **La carte encastrée ne se manipule pas.** Elle vit au milieu d'une liste
    // qui défile : un pan y dispute le doigt au défilement de la page, et le
    // geste part à moitié dans l'un, à moitié dans l'autre. Le tap reste — il
    // sélectionne un groupe, et n'est pas un geste de caméra. Pour explorer,
    // le bouton plein écran, où plus rien ne se dispute le doigt.
    final bool fullscreen = PdlMapHero.isFullscreenOf(context);

    // Les points du parcours du groupe sélectionné.
    final String? waypointSlug = selected?.routeSlug ?? ride.routeSlug;
    final List<WaypointDto> waypoints = waypointSlug == null
        ? const <WaypointDto>[]
        : (geometries[waypointSlug]?.waypoints ?? const <WaypointDto>[]);
    final WaypointSelectionController selection = ref.watch(
      rideWaypointSelectionProvider(rideKey),
    );

    return ValueListenableBuilder<WaypointSelection?>(
      valueListenable: selection,
      builder: (BuildContext context, WaypointSelection? picked, _) => PdlMap(
        waypoints: mapWaypointsOf(waypoints),
        focusedWaypoint: picked?.focus,
        onWaypointTapped: (String key) {
          final WaypointDto? w = waypointByKey(waypoints, key);
          if (w == null) return;
          openWaypoint(
            context,
            w,
            selection,
            key,
            units: ref.read(unitSystemProvider),
          );
        },
        styleUrl: styleUrl,
        credit: credit,
        hillshade: servedHillshade(context, ref),
        interactive: fullscreen,
        tracks: tracks,
        start: _point(ride.startPlace),
        end: _point(ride.endPlace),
        initialCenter: _defaultCenter(ref),
        fitBox: extent == null
            ? null
            : PdlMapBox(
                minLon: extent.minLon,
                minLat: extent.minLat,
                maxLon: extent.maxLon,
                maxLat: extent.maxLat,
              ),
        selectedTrackId: selectedGroupId,
        onTrackSelected: (String? id) {
          if (id != null) onSelect(id);
        },
        overlays: <Widget>[
          if (selected != null)
            Positioned(
              left: 12,
              top: 12,
              // En plein écran la carte remonte sous l'heure et la batterie :
              // la pilule doit céder l'encoche. Encastrée dans une liste, elle
              // est déjà loin du haut de l'écran, et un `SafeArea` y ajouterait
              // une gouttière de 59 px sortie de nulle part — `MediaQuery.padding`
              // ne se remet pas à zéro pour un widget au milieu de la page.
              child: fullscreen
                  ? SafeArea(child: _pill(selected))
                  : _pill(selected),
            ),
        ],
      ),
    );
  }

  Widget _pill(RideGroupDto group) => PdlMapPill(
    key: keys.ride.groupsMapPill,
    label: group.name,
    leading: PdlColorTrack(
      color: multiTrackColor(group.sortOrder),
      shape: PdlColorTrackShape.legend,
    ),
  );

  /// Un tracé par groupe — **pas** un par parcours : deux groupes qui partagent
  /// un parcours doivent chacun être sélectionnables, et la carte de groupe
  /// sélectionnée doit s'allumer quel que soit le tracé touché.
  List<PdlMapTrack> _tracks(Map<String, RouteDetailDto> geometries) {
    final List<PdlMapTrack> tracks = <PdlMapTrack>[];
    for (final RideGroupDto group in ride.groups) {
      final String? slug = group.routeSlug ?? ride.routeSlug;
      final RouteDetailDto? route = slug == null ? null : geometries[slug];
      if (route == null) continue;
      tracks.add(
        PdlMapTrack(
          id: group.id,
          lines: <List<List<double>>>[
            for (final TrackDto t in route.tracks) t.line.coordinates,
          ],
          color: multiTrackColor(group.sortOrder),
          label: group.name,
        ),
      );
    }
    // Le tracé sélectionné est dessiné **en dernier** : MapLibre n'a pas de
    // `zIndex` sur les lignes, c'est l'ordre d'ajout qui décide.
    final int index = tracks.indexWhere(
      (PdlMapTrack t) => t.id == selectedGroupId,
    );
    if (index >= 0) tracks.add(tracks.removeAt(index));
    return tracks;
  }

  RideGroupDto? _selectedGroup() {
    for (final RideGroupDto g in ride.groups) {
      if (g.id == selectedGroupId) return g;
    }
    return null;
  }

  PdlMapPoint? _point(PlaceDetailDto? place) {
    final List<double>? c = place?.geometry?.coordinates;
    if (c == null || c.length < 2) return null;
    return PdlMapPoint(lon: c[0], lat: c[1], label: place!.name);
  }

  PdlMapPoint? _defaultCenter(WidgetRef ref) {
    final MapCenterDto? center = ref.watch(defaultCenterProvider).value;
    if (center == null) return null;
    return PdlMapPoint(lon: center.lon, lat: center.lat);
  }
}
