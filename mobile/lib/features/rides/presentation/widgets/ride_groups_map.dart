import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/geo/polyline_index.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../routes/domain/route_color_mode.dart';
import '../../../routes/domain/track_slope_colors.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/widgets/route_color_mode_switch.dart';
import '../../../routes/presentation/widgets/waypoint_selection.dart';
import '../../../routes/presentation/widgets/waypoint_sheet.dart';
import '../../domain/ride_route_layers.dart';
import '../../domain/ride_weather_map.dart';
import '../../domain/solo_group.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../../../keys.dart';
import 'ride_weather_map_markers.dart';
import 'ride_wind_map_legend.dart';
import 'weather_map_layer.dart';

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
/// **Une couche par parcours distinct** ([rideRouteLayers]) — plus jamais une
/// par groupe : trois groupes sur un même parcours sont une trace, une
/// couleur, une case de la feuille des couches. Toutes adossées à une même
/// source : le SDK MapLibre rend `queryLayers` sans les propriétés de
/// l'entité touchée, donc seul le `layerId` porte l'identité d'un tracé
/// (§1.0.3-7) — ici le `routeSlug`. `PdlMap` s'en charge ; ce widget lui donne
/// les tracés, la couleur de chacun, et reçoit le tap.
///
/// La sélection est **un parcours**. Toucher une trace la sélectionne (mise en
/// évidence, profil) et n'ouvre aucune page. Le widget lit et écrit lui-même
/// la sélection de l'écran ([resolvedRideRouteSlug], [selectRideRoute]) :
/// c'est ce qui la garde vivante dans la page plein écran, que l'écran masqué
/// ne peut plus nourrir (voir `PdlMapHero`).
///
/// Avec [onlyGroup] — la page d'un groupe —, la carte ne montre que le
/// parcours de ce groupe : ni cases, ni pilule, ni sélection.
///
/// Les géométries sont **dédoublonnées par `routeSlug`** en amont : dix groupes
/// sur trois parcours coûtent trois appels.
///
/// Avec [onlyGroup] — ou sur le détail d'une **sortie solo à un seul
/// parcours** ([rideMapColorsLikeRoute]) —, le tracé se colore **comme celui
/// d'un parcours** (ledger `MOB-105`) : la pente des montées, le revêtement,
/// ou le vent relatif de [weatherLeg] (mode « Météo », ledgers `MOB-91`,
/// `MOB-94`) — dos, travers, face, une légende en mots, les pastilles en
/// plein écran. Le choix est [rideMapColorModeProvider], sur la pente par
/// défaut ; il se fait sous la carte encastrée (`RouteColorModeSwitch`) et,
/// en plein écran, par le même interrupteur posé en bas de la carte. Les
/// modes proposés sont ceux de [rideMapColorModes].
///
/// Une sortie à **plusieurs groupes** garde une couleur par couche — comme
/// ses légendes et sa pilule — et n'a pas de mode « Météo » : chaque groupe
/// l'a sur sa carte. Une **sortie solo dont le groupe roule un autre
/// parcours** que la sortie aussi, comme au site : deux couches à leur
/// couleur ; seul le mode « Météo » du parcours du groupe y reste (la puce
/// sous la carte, l'interrupteur de la feuille des couches en plein écran).
///
/// L'onglet Météo de la page d'un groupe la pose avec [forceWeatherMode] :
/// le mode « Météo » d'office, sans toucher au choix fait dans l'Aperçu, un
/// toucher qui ouvre le plein écran, et le réticule d'un point de la frise
/// ([cursorDistance], ledger `MOB-93`).
class RideGroupsMap extends ConsumerWidget {
  const RideGroupsMap({
    super.key,
    required this.rideKey,
    required this.ride,
    this.onlyGroup,
    this.fullscreen = false,
    this.seedExtent,
    this.weatherLeg,
    this.weatherAttribution,
    this.forceWeatherMode = false,
    this.cursorDistance,
  });

  final RideKey rideKey;
  final RideDto ride;

  /// Le groupe dont la page affiche la carte : seul son parcours est dessiné.
  /// `null` sur la page de la sortie.
  final RideGroupDto? onlyGroup;

  /// L'emprise que l'écran connaissait au moment de pousser le plein écran.
  ///
  /// La page est une seconde instance, et le lot de géométries est
  /// `autoDispose` : le temps qu'elle le recharge, `extent` y vaut `null` et
  /// la carte se rabattrait sur le lieu de départ — un cadrage serré, puis un
  /// saut jusqu'à l'emprise réelle une fraction de seconde plus tard. Cette
  /// graine **est** l'emprise du backend, relevée un instant plus tôt.
  final BoundsDto? seedExtent;

  /// Le leg météo du groupe de [onlyGroup] — ou du groupe unique d'une
  /// sortie solo —, `null` sans prévision chargée. Il n'a d'effet qu'avec
  /// une prévision ([showsWindOnMap]) : il propose alors le mode « Météo ».
  final WeatherLegDto? weatherLeg;

  /// Le crédit des prévisions (`RideWeatherDto.attribution`), porté par la
  /// légende du mode « Météo », encastrée comme en plein écran.
  final WeatherAttributionDto? weatherAttribution;

  /// Le mode « Météo » imposé (l'onglet Météo d'un groupe) : le tracé se
  /// colore d'office dès que le leg a une prévision, sans lire ni écrire
  /// [rideMapColorModeProvider] — celui-ci reste le choix de la personne dans
  /// l'Aperçu. Pas d'interrupteur, et la carte encastrée ouvre le plein écran
  /// au toucher.
  final bool forceWeatherMode;

  /// Le réticule, en mètres le long du parcours du groupe, **distance chaînée
  /// des DTO météo** (traces bout à bout, saut nul : [pointsAtDistances]) —
  /// le point de la frise touché dans l'onglet Météo. `null` : aucun.
  final double? cursorDistance;

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

    final RideGroupDto? only = onlyGroup;
    final String? onlySlug = only == null
        ? null
        : effectiveRouteSlug(ride, only);
    final List<RideRouteLayer> allLayers = rideRouteLayers(ride);
    // Sur la page d'un groupe, la seule couche de son parcours — qui garde la
    // couleur qu'elle a sur la carte de la sortie.
    final List<RideRouteLayer> layers = only == null
        ? allLayers
        : <RideRouteLayer>[
            for (final RideRouteLayer l in allLayers)
              if (l.routeSlug == onlySlug) l,
          ];
    if (layers.isEmpty) {
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
    for (final RideRouteLayer layer in layers) {
      final RouteDetailDto? route = ref
          .watch(
            rideRouteGeometryProvider(
              RouteRef(
                teamSlug: ride.team.slug,
                rideSlug: rideKey.rideSlug,
                routeSlug: layer.routeSlug,
              ),
            ),
          )
          .value;
      if (route != null) geometries[layer.routeSlug] = route;
    }

    final String mainRouteLabel = 'rides.mainRoute'.tr();
    final bool multi = layers.length > 1;
    final String? selectedSlug = only == null
        ? resolvedRideRouteSlug(ref, rideKey, ride)
        : onlySlug;
    final Set<String> hidden = multi
        ? ref.watch(hiddenRideRoutesProvider(rideKey))
        : const <String>{};

    // Le vent sur le tracé : le parcours d'un groupe (sa page, ou le détail
    // d'une sortie solo), une prévision, et le mode choisi. Sinon le trait
    // habituel, même si le mode reste allumé.
    final RideGroupDto? weatherGroup = only ?? soloGroupOf(ride);
    final String? weatherSlug = weatherGroup == null
        ? null
        : effectiveRouteSlug(ride, weatherGroup);
    // Un parcours masqué dans la feuille des couches ne porte plus le vent :
    // ni légende, ni crédit, ni bascule pour un tracé qui n'est pas dessiné.
    final WeatherLegDto? windLeg =
        weatherSlug != null &&
            !hidden.contains(weatherSlug) &&
            showsWindOnMap(weatherLeg)
        ? weatherLeg
        : null;
    // Ce qui colore le parcours du groupe : le choix fait sous la carte, ou
    // la Météo imposée, ramené sur la pente quand il n'est pas proposé.
    final List<RouteColorBy> modes = rideMapColorModes(
      ref,
      rideKey: rideKey,
      ride: ride,
      onlyGroup: onlyGroup,
      weatherLeg: weatherLeg,
    );
    final RouteColorBy colorBy = resolveRouteColorBy(
      forceWeatherMode
          ? RouteColorBy.wind
          : ref.watch(rideMapColorModeProvider(rideKey)),
      modes,
    );
    final bool windMode = windLeg != null && colorBy == RouteColorBy.wind;
    // Le parcours du groupe se colore comme un parcours — pente, revêtement,
    // vent —, ou, sur une carte à deux couches, par le vent seulement.
    final bool likeRoute = rideMapColorsLikeRoute(ride, onlyGroup);
    final RouteColorBy? groupColorBy = weatherGroup == null
        ? null
        : likeRoute
        ? colorBy
        : windMode
        ? RouteColorBy.wind
        : null;

    final List<PdlMapTrack> tracks = _tracks(
      layers,
      geometries,
      selectedSlug,
      hidden,
      mainRouteLabel,
      groupColorBy,
      windMode ? windLeg : null,
      weatherSlug,
      context.pdl,
    );

    // L'emprise vient du serveur (`RoutesBulkResponse.extent`), pas d'un
    // parcours des sommets : elle arrive **avec** le premier lot, et couvre
    // déjà tous les parcours demandés — y compris ceux dont la géométrie est
    // encore en vol. La page d'un groupe, elle, cadre sur son seul tracé :
    // l'emprise du lot couvrirait les parcours des autres groupes.
    final BoundsDto? extent = only == null
        ? ref.watch(rideRouteGeometriesProvider(rideKey)).extent ?? seedExtent
        : null;
    final PdlMapBox? fitBox = only != null
        ? PdlMapBox.ofTracks(tracks)
        : extent == null
        ? null
        : PdlMapBox(
            minLon: extent.minLon,
            minLat: extent.minLat,
            maxLon: extent.maxLon,
            maxLat: extent.maxLat,
          );

    final String? styleUrl = style.value?.url;
    if (styleUrl == null) {
      return PdlSkeleton(height: height, borderRadius: PdlRadii.mdAll);
    }

    RideRouteLayer? selectedLayer;
    for (final RideRouteLayer l in layers) {
      if (l.routeSlug == selectedSlug) selectedLayer = l;
    }

    final Widget hero = PdlMapHero(
      isFullscreen: fullscreen,
      fullscreenBuilder: fullscreen
          ? null
          : (BuildContext context) => RideGroupsMap(
              rideKey: rideKey,
              ride: ride,
              onlyGroup: onlyGroup,
              fullscreen: true,
              seedExtent: extent,
              weatherLeg: weatherLeg,
              weatherAttribution: weatherAttribution,
              forceWeatherMode: forceWeatherMode,
              cursorDistance: cursorDistance,
            ),
      tapOpensFullscreen: forceWeatherMode,
      labels: PdlMapHeroLabels(
        enterFullscreen: 'map.fullscreen'.tr(),
        exitFullscreen: 'map.exitFullscreen'.tr(),
        chooseBackground: 'map.background'.tr(),
        backgroundSheetTitle: 'map.background'.tr(),
        hillshade: 'map.hillshade'.tr(),
        tracks: 'map.tracks'.tr(),
      ),
      styles: servedMapStyleOptions(ref),
      hillshadeEnabled: servedHillshadeEnabled(ref),
      onHillshadeChanged: (bool on) =>
          ref.read(hillshadeEnabledProvider.notifier).set(on),
      // Une carte à deux couches (sortie solo dont le groupe roule un autre
      // parcours) n'a que « Météo » à basculer : en plein écran, dans la
      // feuille, comme l'ombrage. Une carte colorée comme un parcours a
      // l'interrupteur en bas de la carte (`foreground`, ledger `MOB-105`).
      switches: fullscreen && !likeRoute && windLeg != null && !forceWeatherMode
          ? <PdlMapHeroSwitch>[
              weatherMapModeSwitch(
                value: windMode,
                onChanged: (bool on) => setRideMapWindMode(ref, rideKey, on),
              ),
            ]
          : const <PdlMapHeroSwitch>[],
      selectedStyleId: style.value?.style.id,
      onStyleSelected: (String id) =>
          ref.read(mapStyleIdProvider.notifier).select(id),
      // Une case par parcours, seulement quand il y en a plusieurs : masquer
      // l'unique tracé d'une carte n'a pas de sens.
      trackToggles: multi
          ? <PdlMapTrackToggle>[
              for (final RideRouteLayer l in layers)
                PdlMapTrackToggle(
                  id: l.routeSlug,
                  label: l.label(mainRouteLabel),
                  color: multiTrackColor(l.colorIndex),
                  visible: !hidden.contains(l.routeSlug),
                ),
            ]
          : const <PdlMapTrackToggle>[],
      onTrackVisibilityChanged: multi
          ? (String slug, bool visible) {
              final StateController<Set<String>> c = ref.read(
                hiddenRideRoutesProvider(rideKey).notifier,
              );
              c.state = visible
                  ? (<String>{...c.state}..remove(slug))
                  : <String>{...c.state, slug};
            }
          : null,
      // L'interrupteur du plein écran et la légende vivent dans la coquille,
      // pas dans les `overlays` de la carte : ceux-ci n'apparaissent qu'une
      // fois la vue native prête, et ni l'un ni l'autre n'en a besoin. À
      // gauche : le crédit ⓘ tient le coin droit.
      foreground: routeMapBottomLayer(
        fullscreen: fullscreen,
        // En plein écran, le même interrupteur que sous la carte encastrée,
        // sur le même état (ledger `MOB-105`). Pas dans l'onglet Météo, qui
        // reste en Météo.
        modeSwitch:
            fullscreen && likeRoute && !forceWeatherMode && modes.length > 1
            ? RouteColorModeSwitch(
                key: keys.routeDetail.fullscreenColorBy,
                modes: modes,
                value: colorBy,
                overMap: true,
                onChanged: (RouteColorBy v) =>
                    ref.read(rideMapColorModeProvider(rideKey).notifier).state =
                        v,
              )
            : null,
        // Sur la vignette qui s'ouvre au toucher, la légende ne garde pas le
        // doigt pour elle : il va au plein écran.
        passTouches: forceWeatherMode && !fullscreen,
        legend: windMode
            ? RideWindMapLegend(
                leg: windLeg,
                units: ref.watch(unitSystemProvider),
                attribution: weatherAttribution,
              )
            : null,
      ),
      mapBuilder: (BuildContext context) => _map(
        context,
        styleUrl,
        servedMapCredit(style.value),
        tracks,
        multi ? selectedLayer : null,
        selectedSlug,
        fitBox,
        ref,
        geometries,
        mainRouteLabel,
        windMode ? windLeg : null,
        weatherSlug == null || hidden.contains(weatherSlug)
            ? null
            : geometries[weatherSlug],
        _cursor(geometries[selectedSlug]),
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
    RideRouteLayer? pillLayer,
    String? selectedSlug,
    PdlMapBox? fitBox,
    WidgetRef ref,
    Map<String, RouteDetailDto> geometries,
    String mainRouteLabel,
    WeatherLegDto? windLeg,
    RouteDetailDto? windRoute,
    PdlMapPoint? cursor,
  ) {
    // **La carte encastrée ne se manipule pas.** Elle vit au milieu d'une liste
    // qui défile : un pan y dispute le doigt au défilement de la page, et le
    // geste part à moitié dans l'un, à moitié dans l'autre. Le tap reste — il
    // sélectionne un parcours, et n'est pas un geste de caméra. Pour explorer,
    // le bouton plein écran, où plus rien ne se dispute le doigt.
    final bool fullscreen = PdlMapHero.isFullscreenOf(context);

    // Les points du parcours sélectionné.
    final List<WaypointDto> waypoints = selectedSlug == null
        ? const <WaypointDto>[]
        : (geometries[selectedSlug]?.waypoints ?? const <WaypointDto>[]);
    final WaypointSelectionController selection = ref.watch(
      rideWaypointSelectionProvider(rideKey),
    );

    // Les pastilles météo : **plein écran seulement**, en mode « Météo »
    // (ledger `MOB-92`). Encastrée, la carte est trop petite et ne se touche
    // pas ; elle garde le tracé coloré et la légende.
    final UnitSystem units = ref.watch(unitSystemProvider);
    final List<PdlMapMarker> weatherMarkers =
        fullscreen && windLeg != null && windRoute != null
        ? weatherMarkersOnRoute(
            windRoute,
            windLeg,
            units: units,
            timezone: ride.timezone,
          )
        : const <PdlMapMarker>[];

    return ValueListenableBuilder<WaypointSelection?>(
      valueListenable: selection,
      builder: (BuildContext context, WaypointSelection? picked, _) => _native(
        PdlMap(
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
          markers: weatherMarkers,
          onMarkerTapped: weatherMarkers.isEmpty
              ? null
              : (String id) => openWeatherMapMarker(
                  context,
                  id,
                  leg: windLeg!,
                  units: units,
                  timezone: ride.timezone,
                ),
          cursor: cursor,
          styleUrl: styleUrl,
          credit: credit,
          hillshade: servedHillshade(context, ref),
          interactive: fullscreen,
          tracks: tracks,
          start: _point(ride.startPlace),
          end: _point(ride.endPlace),
          initialCenter: _defaultCenter(ref),
          fitBox: fitBox,
          selectedTrackId: selectedSlug,
          // Un tap sur une trace **sélectionne son parcours** — il n'ouvre plus
          // la page d'un groupe. La page d'un groupe n'a qu'un tracé : rien à
          // sélectionner.
          onTrackSelected: onlyGroup != null
              ? null
              : (String? slug) {
                  if (slug != null) selectRideRoute(ref, rideKey, ride, slug);
                },
          overlays: <Widget>[
            if (pillLayer != null)
              Positioned(
                left: 12,
                top: 12,
                // En plein écran la carte remonte sous l'heure et la batterie :
                // la pilule doit céder l'encoche. Encastrée dans une liste, elle
                // est déjà loin du haut de l'écran, et un `SafeArea` y ajouterait
                // une gouttière de 59 px sortie de nulle part — `MediaQuery.padding`
                // ne se remet pas à zéro pour un widget au milieu de la page.
                child: fullscreen
                    ? SafeArea(child: _pill(pillLayer, mainRouteLabel))
                    : _pill(pillLayer, mainRouteLabel),
              ),
          ],
        ),
      ),
    );
  }

  /// Vrai dans un test de widget : MapLibre n'y a pas de vue native, et la
  /// carte y est remplacée par [RideGroupsMapProbe], qui garde le `PdlMap`
  /// construit pour qu'on lise ses tracés.
  @visibleForTesting
  static bool debugSkipNativeMap = false;

  Widget _native(PdlMap map) =>
      debugSkipNativeMap ? RideGroupsMapProbe(map: map) : map;

  Widget _pill(RideRouteLayer layer, String mainRouteLabel) => PdlMapPill(
    key: keys.ride.groupsMapPill,
    label: layer.label(mainRouteLabel),
    leading: PdlColorTrack(
      color: multiTrackColor(layer.colorIndex),
      shape: PdlColorTrackShape.legend,
    ),
  );

  /// Un tracé par parcours — **pas** un par groupe : les groupes qui le
  /// partagent s'allument ensemble, puisque leur trace est la même.
  List<PdlMapTrack> _tracks(
    List<RideRouteLayer> layers,
    Map<String, RouteDetailDto> geometries,
    String? selectedSlug,
    Set<String> hidden,
    String mainRouteLabel,
    RouteColorBy? colorBy,
    WeatherLegDto? windLeg,
    String? weatherSlug,
    PdlColors c,
  ) {
    final List<PdlMapTrack> tracks = <PdlMapTrack>[];
    for (final RideRouteLayer layer in layers) {
      if (hidden.contains(layer.routeSlug)) continue;
      final RouteDetailDto? route = geometries[layer.routeSlug];
      if (route == null) continue;
      final Color color = multiTrackColor(layer.colorIndex);
      tracks.add(
        PdlMapTrack(
          id: layer.routeSlug,
          lines: <List<List<double>>>[
            for (final TrackDto t in route.tracks) t.line.coordinates,
          ],
          color: color,
          label: layer.label(mainRouteLabel),
          // Seul le parcours du groupe se colore : sur le détail d'une sortie
          // solo à deux parcours, le parcours principal que personne ne roule
          // garde son trait, et une sortie à plusieurs groupes une couleur par
          // couche.
          segmentColors: colorBy == null || layer.routeSlug != weatherSlug
              ? null
              : _segmentColors(route, colorBy, windLeg, c),
          // Le tracé coloré par le vent garde l'opacité et la largeur du
          // tracé sélectionné, même quand l'autre parcours l'est : délavé, il
          // ne ressemblerait plus à sa légende.
          emphasized: windLeg != null && layer.routeSlug == weatherSlug,
        ),
      );
    }
    // Le tracé sélectionné est dessiné **en dernier** : MapLibre n'a pas de
    // `zIndex` sur les lignes, c'est l'ordre d'ajout qui décide.
    final int index = tracks.indexWhere(
      (PdlMapTrack t) => t.id == selectedSlug,
    );
    if (index >= 0) tracks.add(tracks.removeAt(index));
    return tracks;
  }

  /// Les couleurs du parcours du groupe dans le mode [colorBy] — déjà résolu :
  /// le vent seulement avec un leg, le revêtement seulement s'il est connu.
  static List<Color> _segmentColors(
    RouteDetailDto route,
    RouteColorBy colorBy,
    WeatherLegDto? windLeg,
    PdlColors c,
  ) => switch (colorBy) {
    RouteColorBy.wind when windLeg != null => weatherTrackColors(
      route,
      windLeg,
    ),
    RouteColorBy.surface =>
      surfaceSegmentColors(route.tracks, c) ?? climbSegmentColors(route.tracks),
    _ => climbSegmentColors(route.tracks),
  };

  /// Le réticule de [cursorDistance] sur le parcours, mémorisé par
  /// (parcours, distance) : il chaîne toutes les distances du tracé.
  PdlMapPoint? _cursor(RouteDetailDto? route) {
    final double? distance = cursorDistance;
    if (route == null || distance == null) return null;
    final _CursorPoint? memo = _cursorMemo[route];
    if (memo != null && memo.distance == distance) return memo.point;
    final LngLat? at = pointsAtDistances(routeLinesOf(route), <double>[
      distance,
    ]).single;
    final PdlMapPoint? point = at == null
        ? null
        : PdlMapPoint(lon: at.lng, lat: at.lat);
    _cursorMemo[route] = _CursorPoint(distance, point);
    return point;
  }

  static final Expando<_CursorPoint> _cursorMemo = Expando<_CursorPoint>(
    'rideMapCursor',
  );

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

/// Une entrée de la mémoire du réticule d'un parcours.
class _CursorPoint {
  const _CursorPoint(this.distance, this.point);

  final double distance;
  final PdlMapPoint? point;
}

/// La carte d'un test de widget ([RideGroupsMap.debugSkipNativeMap]) : un
/// fond vide qui porte le `PdlMap` que l'écran aurait rendu.
@visibleForTesting
class RideGroupsMapProbe extends StatelessWidget {
  const RideGroupsMapProbe({super.key, required this.map});

  final PdlMap map;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Vrai quand la carte colore le parcours du groupe **comme un parcours**
/// (ledger `MOB-105`) : la page d'un groupe ([onlyGroup]), ou une sortie solo
/// dont la sortie et le groupe roulent le même parcours — la règle du site
/// (`soloRouteSlug` de `RideDetailPage.tsx`). Une sortie solo à deux
/// parcours, comme une sortie à plusieurs groupes, garde une couleur par
/// couche.
bool rideMapColorsLikeRoute(RideDto ride, RideGroupDto? onlyGroup) =>
    onlyGroup != null ||
    (soloGroupOf(ride) != null && rideRouteLayers(ride).length == 1);

/// Les modes que propose la carte d'une sortie (ledger `MOB-105`), pour son
/// interrupteur et pour la carte elle-même, qui doivent dire la même chose.
///
/// Carte colorée comme un parcours ([rideMapColorsLikeRoute]) : la pente
/// toujours ; le revêtement quand le parcours du groupe l'a ; Météo quand
/// [weatherLeg] a une prévision à montrer. Sortie solo à deux parcours : la
/// pente — c'est-à-dire la couleur des couches — et Météo, quand le parcours
/// du groupe a une prévision et est dessiné (pas décoché dans la feuille des
/// couches) ; pas de revêtement, la carte ne le montre pas. Sortie à
/// plusieurs groupes : la pente seule.
List<RouteColorBy> rideMapColorModes(
  WidgetRef ref, {
  required RideKey rideKey,
  required RideDto ride,
  RideGroupDto? onlyGroup,
  WeatherLegDto? weatherLeg,
}) {
  final RideGroupDto? group = onlyGroup ?? soloGroupOf(ride);
  final String? slug = group == null ? null : effectiveRouteSlug(ride, group);
  if (slug == null) return const <RouteColorBy>[RouteColorBy.grade];
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
  // La feuille des couches n'a de cases que sur une carte à plusieurs tracés,
  // et jamais sur la page d'un groupe.
  final bool hidden =
      onlyGroup == null &&
      rideRouteLayers(ride).length > 1 &&
      ref.watch(hiddenRideRoutesProvider(rideKey)).contains(slug);
  return routeColorModes(
    surfaces:
        rideMapColorsLikeRoute(ride, onlyGroup) &&
        route != null &&
        hasTrackSurfaces(route.tracks),
    wind: !hidden && showsWindOnMap(weatherLeg),
  );
}
