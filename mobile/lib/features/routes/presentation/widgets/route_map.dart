import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/pdl/map/pdl_waypoint_mark.dart';
import '../../../../core/pdl/map/pdl_map.dart';
import '../../../../core/pdl/map/pdl_map_controller.dart';
import '../../../../core/pdl/map/pdl_map_hero.dart';
import '../../../../core/pdl/map/pdl_map_marker.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../domain/track_slope_colors.dart';
import '../../domain/track_surfaces.dart';
import 'route_cursor_controller.dart';
import 'waypoint_selection.dart';
import 'waypoint_sheet.dart';

/// Ce qu'un écran pose **en plus** sur la carte d'un parcours, sans que
/// celle-ci sache ce que c'est — le mode « Météo » du détail d'une étape
/// (ledger `MOB-94`) : des couleurs de tracé prioritaires sur la pente et le
/// revêtement, des marqueurs, une légende, un interrupteur de la feuille des
/// couches.
@immutable
class RouteMapLayer {
  const RouteMapLayer({
    this.segmentColors,
    this.markers = const <PdlMapMarker>[],
    this.onMarkerTapped,
    this.foreground,
    this.switches = const <PdlMapHeroSwitch>[],
  });

  /// Une couleur par intervalle des lignes brutes (`PdlMapTrack`), à la place
  /// de la pente ou du revêtement. `null` : la coloration de la carte. Les
  /// bornes kilométriques s'effacent quand elle est posée : le tracé dit
  /// déjà autre chose.
  final List<Color>? segmentColors;

  final List<PdlMapMarker> markers;

  /// Le toucher d'un marqueur, avec le contexte de la carte qui l'a rendu.
  final void Function(BuildContext context, String id)? onMarkerTapped;

  /// Posé au-dessus de la carte, dans la coquille (une légende).
  final Widget? foreground;

  /// Les interrupteurs de la feuille des couches, sous l'ombrage.
  final List<PdlMapHeroSwitch> switches;
}

/// Construit la [RouteMapLayer] d'une carte de parcours. Appelé au `build`
/// de **chaque** carte — l'encastrée, puis le plein écran, qui est une autre
/// instance : c'est ce qui garde ses `ref.watch` vivants là où l'écran
/// recouvert ne se reconstruit plus (voir `PdlMapHero`). `null` : rien.
typedef RouteMapLayerBuilder =
    RouteMapLayer? Function(
      BuildContext context,
      WidgetRef ref,
      RouteDetailDto route, {
      required bool fullscreen,
    });

/// L'adaptateur entre `RouteDetailDto` et [PdlMap].
///
/// C'est tout ce qu'il reste des 276 lignes d'origine : la conversion du DTO
/// vers les types simples de `core/pdl/map`, et le branchement des fonds servis
/// par `ConfigDto.mapStyles[]`. **Aucune URL de style, aucun
/// `Future.delayed`, aucune couleur en dur.**
class RouteMap extends ConsumerStatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.cursor,
    this.onMapTapped,
    this.fitPadding = const EdgeInsets.all(50),
    this.allowFullscreen = false,
    this.fullscreen = false,
    this.colorBy = RouteColorBy.grade,
    this.selection,
    this.layer,
  });

  final RouteDetailDto route;

  /// Le réticule partagé avec le profil altimétrique. `null` sur les écrans qui
  /// n'en ont pas (l'aperçu d'une sortie, par exemple).
  final RouteCursorController? cursor;

  /// Tap sur la carte, converti en distance cumulée par [cursor]. `null`
  /// signifie « hors du tracé », ce qui efface le réticule.
  final ValueChanged<double?>? onMapTapped;

  /// Marge de cadrage. La fiche parcours y réserve la hauteur de sa feuille :
  /// sans cela le tracé est cadré sur toute la carte, dont la feuille masque la
  /// moitié — « bien cadré » et pourtant à moitié invisible.
  final EdgeInsets fitPadding;

  /// Vrai quand la carte est une vignette dans une page qui défile (détail
  /// d'une étape) : elle offre alors le plein écran, et ne se laisse ni
  /// déplacer ni zoomer tant qu'elle n'y est pas — même repli que les groupes
  /// d'une sortie. La fiche parcours, elle, **est** déjà la carte plein écran,
  /// et un bouton de plus n'y mènerait nulle part.
  final bool allowFullscreen;

  /// Vrai dans la page plein écran, que ce widget construit lui-même — voir
  /// `PdlMapHero.fullscreenBuilder`.
  final bool fullscreen;

  /// Ce qui colore le tracé : la pente, ou le revêtement quand il est connu
  /// (`MOB-81`) — la pente sinon.
  final RouteColorBy colorBy;

  /// Le point de parcours choisi, partagé avec le profil et la liste (ledger
  /// `MOB-84`). `null` : les points s'affichent, sans interaction.
  final WaypointSelectionController? selection;

  /// Ce que l'écran pose en plus sur la carte ([RouteMapLayer]), transmis au
  /// plein écran. `null` : rien.
  final RouteMapLayerBuilder? layer;

  /// Vrai dans un test de widget : MapLibre n'y a pas de vue native, et la
  /// carte y est remplacée par [RouteMapProbe], qui garde le `PdlMap`
  /// construit pour qu'on lise ses tracés et ses marqueurs.
  @visibleForTesting
  static bool debugSkipNativeMap = false;

  @override
  ConsumerState<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<RouteMap> {
  final PdlMapController _controller = PdlMapController();

  RouteDetailDto get route => widget.route;

  @override
  void initState() {
    super.initState();
    widget.cursor?.distance.addListener(_pushCursor);
  }

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cursor != widget.cursor) {
      oldWidget.cursor?.distance.removeListener(_pushCursor);
      widget.cursor?.distance.addListener(_pushCursor);
    }
  }

  @override
  void dispose() {
    widget.cursor?.distance.removeListener(_pushCursor);
    _controller.dispose();
    super.dispose();
  }

  /// Profil → carte. **Aucun `setState`** : on pousse la source GeoJSON du
  /// marqueur, l'arbre Flutter ne bouge pas d'un widget.
  void _pushCursor() {
    final RouteCursorController? cursor = widget.cursor;
    if (cursor == null) return;
    _controller.setCursor(cursor.positionFor(cursor.distance.value));
  }

  /// Les LineStrings du parcours, telles quelles.
  List<List<List<double>>> get _lines => <List<List<double>>>[
    for (final TrackDto t in route.tracks) t.line.coordinates,
  ];

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final AsyncValue<ResolvedMapStyle?> style = ref.watch(
      mapStyleProvider(brightness),
    );
    final AsyncValue<MapCenterDto> center = ref.watch(defaultCenterProvider);
    final ResolvedMapStyle? resolved = style.value;

    if (resolved == null) {
      // Pas de style servi, pas de carte : on n'invente pas d'URL de repli.
      return ColoredBox(
        color: context.pdl.surfaceAlt,
        child: Center(
          child: style.hasError
              ? Text('map.unavailable'.tr())
              : const CircularProgressIndicator(),
        ),
      );
    }

    final RouteMapLayer? layer = widget.layer?.call(
      context,
      ref,
      route,
      fullscreen: widget.fullscreen,
    );

    final List<PdlMapTrack> tracks = <PdlMapTrack>[
      PdlMapTrack(
        id: route.id,
        lines: _lines,
        color: context.pdl.mapTrack,
        label: route.name,
        // Colorisation **par segment** : chaque tronçon porte la teinte de sa
        // propre pente (§1.1.5). Le repli `mapTrack` reste la couleur d'un
        // segment sans altitude exploitable.
        // Les couleurs de l'écran passent devant (le vent sur le tracé).
        segmentColors:
            layer?.segmentColors ??
            switch (widget.colorBy) {
              RouteColorBy.surface =>
                surfaceSegmentColors(route.tracks, context.pdl) ??
                    slopeColorsForLines(_lines),
              RouteColorBy.grade => slopeColorsForLines(_lines),
            },
      ),
    ];

    final MapCenterDto? defaultCenter = center.value;

    return PdlMapHero(
      labels: PdlMapHeroLabels(
        enterFullscreen: 'map.fullscreen'.tr(),
        exitFullscreen: 'map.exitFullscreen'.tr(),
        chooseBackground: 'map.chooseBackground'.tr(),
        backgroundSheetTitle: 'map.background'.tr(),
        hillshade: 'map.hillshade'.tr(),
      ),
      showFullscreenButton: widget.allowFullscreen || widget.fullscreen,
      isFullscreen: widget.fullscreen,
      fullscreenBuilder: widget.allowFullscreen && !widget.fullscreen
          ? (BuildContext context) => RouteMap(
              route: route,
              cursor: widget.cursor,
              onMapTapped: widget.onMapTapped,
              fullscreen: true,
              colorBy: widget.colorBy,
              selection: widget.selection,
              layer: widget.layer,
            )
          : null,
      switches: layer?.switches ?? const <PdlMapHeroSwitch>[],
      foreground: layer?.foreground,
      styles: servedMapStyleOptions(ref),
      hillshadeEnabled: servedHillshadeEnabled(ref),
      onHillshadeChanged: (bool on) =>
          ref.read(hillshadeEnabledProvider.notifier).set(on),
      selectedStyleId: resolved.style.id,
      onStyleSelected: (String id) =>
          ref.read(mapStyleIdProvider.notifier).select(id),
      mapBuilder: (BuildContext context) => _selectionBuilder(
        (WaypointSelection? focus) => _map(
          context,
          resolved: resolved,
          tracks: tracks,
          defaultCenter: defaultCenter,
          focus: focus?.focus,
          layer: layer,
        ),
      ),
    );
  }

  /// Écoute la sélection : seule la carte se reconstruit quand elle change.
  Widget _selectionBuilder(Widget Function(WaypointSelection?) builder) {
    final WaypointSelectionController? selection = widget.selection;
    if (selection == null) return builder(null);
    return ValueListenableBuilder<WaypointSelection?>(
      valueListenable: selection,
      builder: (BuildContext context, WaypointSelection? value, _) =>
          builder(value),
    );
  }

  void _openWaypoint(String key) {
    final WaypointDto? w = waypointByKey(route.waypoints, key);
    final WaypointSelectionController? selection = widget.selection;
    if (w == null || selection == null) return;
    openWaypoint(
      context,
      w,
      selection,
      key,
      units: ref.read(unitSystemProvider),
    );
  }

  Widget _map(
    BuildContext context, {
    required ResolvedMapStyle resolved,
    required List<PdlMapTrack> tracks,
    required MapCenterDto? defaultCenter,
    required PdlWaypointFocus? focus,
    required RouteMapLayer? layer,
  }) {
    final void Function(BuildContext, String)? onMarker = layer?.onMarkerTapped;
    return _native(
      PdlMap(
        markers: layer?.markers ?? const <PdlMapMarker>[],
        onMarkerTapped: onMarker == null || (layer?.markers.isEmpty ?? true)
            ? null
            : (String id) => onMarker(context, id),
        hillshade: servedHillshade(context, ref),
        controller: _controller,
        interactive: !widget.allowFullscreen || widget.fullscreen,
        styleUrl: resolved.url,
        credit: servedMapCredit(resolved),
        onMapTapped: widget.onMapTapped == null
            ? null
            : (double lon, double lat) =>
                  widget.onMapTapped!(widget.cursor?.distanceNear(lon, lat)),
        tracks: tracks,
        start: _point(route.start) ?? route.firstPoint,
        end: _point(route.end) ?? route.lastPoint,
        waypoints: mapWaypointsOf(route.waypoints),
        focusedWaypoint: focus,
        onWaypointTapped: widget.selection == null ? null : _openWaypoint,
        kmMarkers: layer?.segmentColors != null
            ? const <PdlKmMarker>[]
            : computePdlKmMarkers(_lines, totalMeters: route.distance),
        initialCenter: defaultCenter == null
            ? null
            : PdlMapPoint(lon: defaultCenter.lon, lat: defaultCenter.lat),
        initialZoom: defaultCenter?.zoom ?? 5,
        fitBox: PdlMapBox.ofTracks(tracks),
        fitPadding: widget.fitPadding,
      ),
    );
  }

  Widget _native(PdlMap map) =>
      RouteMap.debugSkipNativeMap ? RouteMapProbe(map: map) : map;

  /// Le départ et l'arrivée servis par le contrat ; à défaut, les extrémités du
  /// tracé — c'est ce que faisait l'implémentation d'origine.
  PdlMapPoint? _point(GeoJsonPoint? point) {
    if (point != null && point.coordinates.length >= 2) {
      return PdlMapPoint(lon: point.coordinates[0], lat: point.coordinates[1]);
    }
    return null;
  }
}

/// La carte d'un test de widget ([RouteMap.debugSkipNativeMap]) : un fond
/// vide qui porte le `PdlMap` que l'écran aurait rendu.
@visibleForTesting
class RouteMapProbe extends StatelessWidget {
  const RouteMapProbe({super.key, required this.map});

  final PdlMap map;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Les extrémités du tracé, quand `start` / `end` sont absents du DTO.
extension RouteMapEndpoints on RouteDetailDto {
  PdlMapPoint? get firstPoint => _endpoint(first: true);
  PdlMapPoint? get lastPoint => _endpoint(first: false);

  PdlMapPoint? _endpoint({required bool first}) {
    for (final TrackDto t in first ? tracks : tracks.reversed) {
      final List<List<double>> line = t.line.coordinates;
      if (line.isEmpty) continue;
      final List<double> c = first ? line.first : line.last;
      if (c.length < 2) continue;
      return PdlMapPoint(lon: c[0], lat: c[1]);
    }
    return null;
  }
}
