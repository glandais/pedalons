import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/geo/polyline_index.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../routes/presentation/widgets/waypoint_selection.dart';
import '../../../routes/presentation/widgets/waypoint_sheet.dart';
import '../../domain/ride_route_layers.dart';
import '../../domain/ride_weather_map.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../../../keys.dart';
import 'ride_weather_map_markers.dart';
import 'ride_wind_map_legend.dart';

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
/// Avec [onlyGroup] et son [weatherLeg], la carte peut aussi colorer le tracé
/// par le vent relatif (mode « Météo », ledger `MOB-91`) : dos, travers,
/// face, et une légende en mots. Le mode est exclusif — le gris du travers se
/// confondrait avec un trait superposé — et éteint par défaut
/// ([rideMapWindModeProvider]).
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

  /// Le leg météo du groupe de [onlyGroup], `null` sans prévision chargée.
  /// Il n'a d'effet que sur la page d'un groupe, avec une prévision
  /// ([showsWindOnMap]) : il propose alors le mode « Météo ».
  final WeatherLegDto? weatherLeg;

  /// Le crédit des prévisions (`RideWeatherDto.attribution`), porté par la
  /// légende du mode « Météo », encastrée comme en plein écran.
  final WeatherAttributionDto? weatherAttribution;

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

    // Le vent sur le tracé : la page d'un groupe, une prévision, et le mode
    // choisi. Sinon le trait habituel, même si le mode reste allumé.
    final WeatherLegDto? windLeg = only != null && showsWindOnMap(weatherLeg)
        ? weatherLeg
        : null;
    final bool windMode =
        windLeg != null && ref.watch(rideMapWindModeProvider(rideKey));

    final List<PdlMapTrack> tracks = _tracks(
      layers,
      geometries,
      selectedSlug,
      hidden,
      mainRouteLabel,
      windMode ? windLeg : null,
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
            ),
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
      // En plein écran, le mode « Météo » se bascule dans la feuille, comme
      // l'ombrage ; la carte encastrée a sa puce sous elle (l'Aperçu).
      switches: fullscreen && windLeg != null
          ? <PdlMapHeroSwitch>[
              PdlMapHeroSwitch(
                id: 'wind',
                label: 'rides.weather.mapModeSwitch'.tr(),
                value: windMode,
                onChanged: (bool on) =>
                    ref.read(rideMapWindModeProvider(rideKey).notifier).state =
                        on,
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
      // La légende vit dans la coquille, pas dans les `overlays` de la carte :
      // ceux-ci n'apparaissent qu'une fois la vue native prête, et la légende
      // se lit sans elle. À gauche : le crédit ⓘ tient le coin droit.
      foreground: windMode
          ? Positioned(
              left: PdlSpacing.sectionTightV,
              right: PdlMetrics.tapTarget + PdlSpacing.sectionTightV,
              bottom: PdlSpacing.sectionTightV,
              child: SafeArea(
                top: false,
                left: fullscreen,
                right: false,
                bottom: fullscreen,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: RideWindMapLegend(
                    leg: windLeg,
                    units: ref.watch(unitSystemProvider),
                    attribution: weatherAttribution,
                  ),
                ),
              ),
            )
          : null,
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
    final RouteDetailDto? windRoute = selectedSlug == null
        ? null
        : geometries[selectedSlug];
    final List<PdlMapMarker> weatherMarkers =
        fullscreen && windLeg != null && windRoute != null
        ? _weatherMarkers(windRoute, windLeg, units, ride.timezone)
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
    WeatherLegDto? windLeg,
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
          segmentColors: windLeg == null
              ? null
              : _windColors(route, windLeg, color),
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

  /// Les couleurs du vent, **mémorisées par (parcours, leg, couleur)** :
  /// sur un parcours de plusieurs milliers de sommets, les recalculer à chaque
  /// `build` coûterait une recherche par segment pour un résultat identique.
  /// La mémoire s'accroche au DTO du parcours (même objet tant que le cache du
  /// provider le garde) et part avec lui.
  static List<Color> _windColors(
    RouteDetailDto route,
    WeatherLegDto leg,
    Color fallback,
  ) {
    final _WindColors? memo = _windMemo[route];
    if (memo != null && identical(memo.leg, leg) && memo.fallback == fallback) {
      return memo.colors;
    }
    final List<Color> colors = windSegmentColors<Color>(
      <List<List<double>>>[
        for (final TrackDto t in route.tracks) t.line.coordinates,
      ],
      leg.segments,
      // Un tronçon sans vent connu garde le trait du tracé, jamais le gris —
      // qui dit « travers ».
      (RelativeWind? wind) => wind?.stroke ?? fallback,
    );
    _windMemo[route] = _WindColors(leg, fallback, colors);
    return colors;
  }

  /// Les marqueurs météo. Seules leurs **positions** sont mémorisées, par
  /// (parcours, leg) comme les couleurs : elles chaînent toutes les distances
  /// du parcours. Les libellés, eux, se refont à chaque construction — ils
  /// suivent la langue et le format horaire du téléphone, que la mémoire ne
  /// verrait pas changer.
  static List<PdlMapMarker> _weatherMarkers(
    RouteDetailDto route,
    WeatherLegDto leg,
    UnitSystem units,
    String? timezone,
  ) {
    final _WeatherPoints? memo = _pointsMemo[route];
    final List<LngLat?> points;
    if (memo != null && identical(memo.leg, leg)) {
      points = memo.points;
    } else {
      points = rideWeatherMarkerPoints(<List<List<double>>>[
        for (final TrackDto t in route.tracks) t.line.coordinates,
      ], leg);
      _pointsMemo[route] = _WeatherPoints(leg, points);
    }
    return rideWeatherMapMarkers(
      points: points,
      leg: leg,
      units: units,
      timezone: timezone,
    );
  }

  static final Expando<_WeatherPoints> _pointsMemo = Expando<_WeatherPoints>(
    'rideMapWeatherPoints',
  );

  static final Expando<_WindColors> _windMemo = Expando<_WindColors>(
    'rideMapWindColors',
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

/// Une entrée de la mémoire des couleurs du vent d'un parcours.
class _WindColors {
  const _WindColors(this.leg, this.fallback, this.colors);

  final WeatherLegDto leg;
  final Color fallback;
  final List<Color> colors;
}

/// Une entrée de la mémoire des positions météo d'un parcours.
class _WeatherPoints {
  const _WeatherPoints(this.leg, this.points);

  final WeatherLegDto leg;
  final List<LngLat?> points;
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
