import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../geo/polyline_index.dart';
import 'pdl_map_camera.dart';
import 'pdl_mass_layer.dart';
import '../../theme/pdl_tokens.dart';
import 'pdl_route_arrow.dart';
import 'pdl_waypoint_mark.dart';

/// Un tracé à dessiner, **sans aucun DTO**.
///
/// `core/pdl/map` ne connaît ni `RouteDetailDto`, ni `RideGroupDto`, ni
/// `TripStageDto` : il ne sait que des listes de coordonnées, une couleur et un
/// identifiant. C'est `features/…` qui convertit. La règle de revue du module
/// (`README.md`) le rend vérifiable.
@immutable
class PdlMapTrack {
  const PdlMapTrack({
    required this.id,
    required this.lines,
    required this.color,
    this.label,
    this.segmentColors,
    this.emphasized = false,
  });

  /// Identité du tracé. Elle finit dans le `layerId` de la couche MapLibre,
  /// parce que **c'est le seul endroit où elle survit** à un `queryLayers` :
  /// `QueriedLayer` ne rend pas les propriétés de l'entité (§1.0.3-7).
  ///
  /// Doit donc être un identifiant stable et sans caractère exotique — un TSID
  /// ou un index suffisent.
  final String id;

  /// Une ou plusieurs LineStrings GeoJSON, chacune `[lon, lat]`,
  /// `[lon, lat, alt]` ou `[lon, lat, alt, m]`.
  final List<List<List<double>>> lines;

  /// Couleur du trait. Vient de `kMultiTrackPalette` pour un groupe ou une
  /// étape, de `PdlColors.mapTrack` pour un tracé unique — jamais d'ici.
  final Color color;

  /// Libellé facultatif, à l'usage de l'appelant (légende, carte flottante).
  /// `core/pdl` ne l'affiche pas et ne le traduit pas.
  final String? label;

  /// Couleur **par segment**, une entrée par intervalle entre deux sommets
  /// consécutifs, `lines` aplaties dans l'ordre.
  ///
  /// C'est la colorisation par pente de la fiche parcours. Elle ne passe pas
  /// par `line-gradient`, qui exige `lineMetrics` sur la source et n'accepte
  /// qu'une progression le long d'**une** ligne : chaque segment devient une
  /// entité GeoJSON portant sa couleur, et la couche lit `['get', 'color']`.
  ///
  /// Une entrée manquante ou une liste trop courte fait retomber le segment sur
  /// [color] — on ne devine pas une teinte.
  final List<Color>? segmentColors;

  bool get isSegmented => segmentColors != null && segmentColors!.isNotEmpty;

  /// Dessiné **comme s'il était sélectionné** — l'opacité et la largeur du
  /// tracé sélectionné —, sans l'être : ni l'ordre de dessin, ni la
  /// sélection ne changent.
  ///
  /// Pour un tracé dont les couleurs portent un sens qu'une légende décrit
  /// (le vent d'une étape, ledger `MOB-94`) : à l'opacité d'un tracé non
  /// sélectionné, ses teintes ressortiraient délavées, loin de celles de la
  /// légende.
  final bool emphasized;

  /// Égalité **de valeur**, avec les géométries comparées par référence.
  ///
  /// Les écrans reconstruisent leur liste de tracés à chaque `build` (une
  /// `List` neuve, des `PdlMapTrack` neufs) mais les coordonnées, elles,
  /// viennent du DTO mis en cache par le provider : ce sont les *mêmes* objets
  /// d'un `build` à l'autre. Comparer les lignes par `identical` coûte donc
  /// quelques nanosecondes là où un `listEquals` profond parcourrait 3 000
  /// sommets, et suffit à ce que [PdlMap] ne repose pas ses couches — donc à ce
  /// que la caméra ne soit pas bousculée — quand rien n'a changé.
  @override
  bool operator ==(Object other) =>
      other is PdlMapTrack &&
      other.id == id &&
      other.color == color &&
      other.label == label &&
      _sameLines(other.lines, lines) &&
      listEquals(other.segmentColors, segmentColors);

  @override
  int get hashCode => Object.hash(id, color, label, lines.length);

  static bool _sameLines(
    List<List<List<double>>> a,
    List<List<List<double>>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i]) && !listEquals(a[i], b[i])) return false;
    }
    return true;
  }
}

/// Un point remarquable : départ, arrivée, point de passage, borne
/// kilométrique.
@immutable
class PdlMapPoint {
  const PdlMapPoint({required this.lon, required this.lat, this.label});

  final double lon;
  final double lat;

  /// Texte déjà localisé par l'appelant, ou `null`.
  final String? label;

  /// Égalité de valeur : les écrans reconstruisent leurs points à chaque
  /// `build`, et sans elle `PdlMap` croirait le départ et l'arrivée changés à
  /// chaque image.
  @override
  bool operator ==(Object other) =>
      other is PdlMapPoint &&
      other.lon == lon &&
      other.lat == lat &&
      other.label == label;

  @override
  int get hashCode => Object.hash(lon, lat, label);
}

/// Une boîte englobante, en degrés WGS84.
///
/// Le pendant DTO-libre de `BoundsDto` : `GET …/routes/bounds` est converti par
/// l'écran, pas par la bibliothèque.
@immutable
class PdlMapBox {
  const PdlMapBox({
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
  });

  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  /// Une boîte réduite à un point — la région visible d'une vue native qui
  /// n'a pas encore de taille.
  bool get isPoint => maxLon <= minLon && maxLat <= minLat;

  /// Boîte englobant les tracés donnés, ou `null` s'ils sont tous vides.
  static PdlMapBox? ofTracks(Iterable<PdlMapTrack> tracks) {
    double? minLon, minLat, maxLon, maxLat;
    for (final PdlMapTrack t in tracks) {
      for (final List<List<double>> line in t.lines) {
        for (final List<double> c in line) {
          if (c.length < 2) continue;
          minLon = minLon == null || c[0] < minLon ? c[0] : minLon;
          maxLon = maxLon == null || c[0] > maxLon ? c[0] : maxLon;
          minLat = minLat == null || c[1] < minLat ? c[1] : minLat;
          maxLat = maxLat == null || c[1] > maxLat ? c[1] : maxLat;
        }
      }
    }
    if (minLon == null) return null;
    return PdlMapBox(
      minLon: minLon,
      minLat: minLat!,
      maxLon: maxLon!,
      maxLat: maxLat!,
    );
  }

  /// Boîte englobant les points donnés, ou `null` s'il n'y en a aucun.
  static PdlMapBox? ofPoints(Iterable<PdlMapPoint> points) {
    double? minLon, minLat, maxLon, maxLat;
    for (final PdlMapPoint p in points) {
      minLon = minLon == null || p.lon < minLon ? p.lon : minLon;
      maxLon = maxLon == null || p.lon > maxLon ? p.lon : maxLon;
      minLat = minLat == null || p.lat < minLat ? p.lat : minLat;
      maxLat = maxLat == null || p.lat > maxLat ? p.lat : maxLat;
    }
    if (minLon == null) return null;
    return PdlMapBox(
      minLon: minLon,
      minLat: minLat!,
      maxLon: maxLon!,
      maxLat: maxLat!,
    );
  }

  /// Vrai si `this` couvre [other], à [slack] degrés près.
  ///
  /// La tolérance absorbe l'arrondi de la projection : `fitBounds` cadre au
  /// pixel, et la région rendue peut manquer la boîte demandée d'un cheveu sans
  /// que rien ne soit mal cadré. 1e-6° ≈ 10 cm.
  bool contains(PdlMapBox other, {double slack = 1e-6}) =>
      minLon <= other.minLon + slack &&
      minLat <= other.minLat + slack &&
      maxLon >= other.maxLon - slack &&
      maxLat >= other.maxLat - slack;

  /// La plus petite boîte contenant `this` et [other].
  PdlMapBox union(PdlMapBox other) => PdlMapBox(
    minLon: minLon < other.minLon ? minLon : other.minLon,
    minLat: minLat < other.minLat ? minLat : other.minLat,
    maxLon: maxLon > other.maxLon ? maxLon : other.maxLon,
    maxLat: maxLat > other.maxLat ? maxLat : other.maxLat,
  );

  /// La même boîte, élargie pour couvrir au moins [minSpan] degrés dans chaque
  /// dimension.
  ///
  /// Une boîte dégénérée — un parcours réduit à un point, un secteur d'annonce,
  /// une sortie dont un seul groupe a une géométrie — a un `span` nul :
  /// `fitBounds` y répond par un zoom maximal, c'est-à-dire une rue au hasard.
  /// 0,004° ≈ 400 m, l'échelle à laquelle un point isolé se lit.
  PdlMapBox expandedToMinSpan([double minSpan = 0.004]) {
    final double dLon = (minSpan - (maxLon - minLon)) / 2;
    final double dLat = (minSpan - (maxLat - minLat)) / 2;
    if (dLon <= 0 && dLat <= 0) return this;
    final double padLon = dLon > 0 ? dLon : 0;
    final double padLat = dLat > 0 ? dLat : 0;
    return PdlMapBox(
      minLon: minLon - padLon,
      minLat: minLat - padLat,
      maxLon: maxLon + padLon,
      maxLat: maxLat + padLat,
    );
  }

  LngLatBounds toLngLatBounds() => LngLatBounds(
    longitudeWest: minLon,
    longitudeEast: maxLon,
    latitudeSouth: minLat,
    latitudeNorth: maxLat,
  );

  static PdlMapBox fromLngLatBounds(LngLatBounds b) => PdlMapBox(
    minLon: b.longitudeWest,
    minLat: b.latitudeSouth,
    maxLon: b.longitudeEast,
    maxLat: b.latitudeNorth,
  );

  @override
  bool operator ==(Object other) =>
      other is PdlMapBox &&
      other.minLon == minLon &&
      other.minLat == minLat &&
      other.maxLon == maxLon &&
      other.maxLat == maxLat;

  @override
  int get hashCode => Object.hash(minLon, minLat, maxLon, maxLat);

  @override
  String toString() => 'PdlMapBox($minLon, $minLat, $maxLon, $maxLat)';
}

/// La source d'élévation dont l'ombrage du relief est tiré, **sans DTO**.
///
/// [url] est une URL de TileJSON, jamais écrite ici : elle vient de
/// `ConfigDto.terrain`, comme les fonds de carte. C'est ce document qui déclare
/// l'encodage du MNT (Terrarium chez Mapterhorn) — le seul canal que lisent les
/// SDK natifs, qui construisent leur source à partir de l'URL de configuration
/// et ignorent l'encodage passé à côté.
@immutable
class PdlHillshade {
  const PdlHillshade({
    required this.url,
    required this.shadowColor,
    required this.highlightColor,
    this.exaggeration = 0.4,
  });

  /// L'URL du TileJSON décrivant des tuiles raster-DEM.
  final String url;

  final Color shadowColor;
  final Color highlightColor;

  /// L'amplitude du relief. 0,4 comme le web : au-delà, le relief écrase le
  /// tracé, qui est ce qu'on est venu regarder.
  final double exaggeration;

  @override
  bool operator ==(Object other) =>
      other is PdlHillshade &&
      other.url == url &&
      other.shadowColor == shadowColor &&
      other.highlightColor == highlightColor &&
      other.exaggeration == exaggeration;

  @override
  int get hashCode =>
      Object.hash(url, shadowColor, highlightColor, exaggeration);
}

/// Épaisseurs et opacités des tracés (§1.3.2).
///
/// MapLibre n'a pas de `zIndex` sur les lignes : c'est **l'ordre de dessin**
/// qui place le tracé sélectionné en dernier, ce dont
/// [PdlMapController.select] se charge.
@immutable
class PdlMapTrackTheme {
  const PdlMapTrackTheme({
    this.selectedWidth = 8,
    this.selectedOpacity = 0.9,
    this.width = 5,
    this.opacity = 0.5,
  });

  final double selectedWidth;
  final double selectedOpacity;
  final double width;
  final double opacity;
}

/// Une borne kilométrique calculée le long d'un tracé.
@immutable
class PdlKmMarker {
  const PdlKmMarker({
    required this.lon,
    required this.lat,
    required this.label,
  });

  final double lon;
  final double lat;

  /// Le nombre de kilomètres, en clair. `core/pdl` ne formate pas d'unité :
  /// c'est l'appelant qui décide s'il écrit « 10 » ou « 6.2 ».
  final String label;
}

/// Pas des bornes kilométriques, en kilomètres, selon la longueur du tracé.
///
/// Repris tel quel de `route_map.dart` : c'est un des deux morceaux que la
/// réécriture devait **conserver**.
int pdlKmMarkerIntervalKm(double distanceKm) {
  if (distanceKm < 10) return 1;
  if (distanceKm < 20) return 2;
  if (distanceKm < 50) return 5;
  return 10;
}

/// Les bornes kilométriques d'un tracé, interpolées sur la polyligne.
///
/// S'appuie sur [PolylineIndex] (F-TE-4), qui sait déjà lire la 4ᵉ composante
/// `G3DM` quand elle porte le cumul et retomber sur la haversine sinon — le
/// calcul recopié dans `route_map.dart` disparaît donc, sans changer le
/// résultat.
List<PdlKmMarker> computePdlKmMarkers(
  Iterable<List<List<double>>> lines, {
  double? totalMeters,
  String Function(int km)? formatKm,
}) {
  final PolylineIndex index = PolylineIndex.fromLineStrings(lines);
  if (index.isEmpty) return const <PdlKmMarker>[];

  final double total = (totalMeters != null && totalMeters > 0)
      ? totalMeters
      : index.totalDistance;
  if (total <= 0) return const <PdlKmMarker>[];

  final double intervalM = pdlKmMarkerIntervalKm(total / 1000) * 1000.0;
  final String Function(int) label = formatKm ?? (int km) => '$km';

  final List<PdlKmMarker> markers = <PdlKmMarker>[];
  for (double d = intervalM; d < total; d += intervalM) {
    final LngLat? p = index.positionAt(d);
    if (p == null) continue;
    markers.add(
      PdlKmMarker(lon: p.lng, lat: p.lat, label: label((d / 1000).round())),
    );
  }
  return markers;
}

/// Le contrôleur d'une carte Pédalons.
///
/// Il porte ce que `MapLibreMap` ne porte pas : les couches de tracés, la
/// sélection, et le cadrage. Il ne construit rien — il est piloté par [PdlMap],
/// qui lui passe le `MapController` et le `StyleController` dès qu'ils
/// existent, et il survit au rechargement d'un style (changement de fond de
/// carte), où **toutes les couches ajoutées sont perdues** et doivent être
/// réappliquées.
class PdlMapController extends ChangeNotifier {
  PdlMapController({
    this.layerPrefix = 'pdl-track',
    this.trackTheme = const PdlMapTrackTheme(),
  });

  /// Préfixe des identifiants de couche. `ride-track` sur l'écran 12,
  /// `stage-track` sur l'écran 24 — le contrat du §1.3.2.
  final String layerPrefix;

  final PdlMapTrackTheme trackTheme;

  MapController? _map;
  StyleController? _style;

  List<PdlMapTrack> _tracks = const <PdlMapTrack>[];
  List<PdlMapWaypoint> _waypoints = const <PdlMapWaypoint>[];
  String? _focusKey;
  PdlMapPoint? _start;
  PdlMapPoint? _end;
  String? _selectedId;
  PdlMapPoint? _cursor;
  PdlHillshade? _hillshade;
  bool _styleReady = false;
  String? _massTileUrl;
  String _massColorHex = '#1D32A8';

  /// Les couches de tracé réellement posées dans le style, dans leur ordre de
  /// dessin. Elles y restent jusqu'au prochain [_applyAll], qui doit les
  /// retirer **avant** leur source : MapLibre refuse de retirer une source
  /// encore employée par une couche (sur iOS, en silence), et l'`addSource`
  /// suivant lève alors « already exists ».
  final List<String> _drawnLayers = <String>[];

  /// La pose en cours, s'il y en a une ; voir [_applyAll].
  Future<void>? _applying;
  bool _applyRequested = false;

  String get _sourceId => '$layerPrefix-src';
  String get _pointsSourceId => '$layerPrefix-points';
  String get _waypointsSourceId => '$layerPrefix-waypoints';
  String get _waypointFocusSourceId => '$layerPrefix-waypoint-focus';
  String get _waypointHaloLayerId => '$layerPrefix-waypoints-halo';
  String get _waypointIconLayerId => '$layerPrefix-waypoints-icon';
  String get _waypointLabelLayerId => '$layerPrefix-waypoints-label';
  String get _cursorSourceId => '$layerPrefix-cursor';
  String get _hillshadeSourceId => '$layerPrefix-hillshade';
  String get _massSourceId => '$layerPrefix-mass-src';
  String get _arrowsSourceId => '$layerPrefix-arrows';
  String get _arrowsLayerId => '$_arrowsSourceId-layer';

  /// L'identifiant de la couche de masse — public parce que l'écran en a besoin
  /// pour interroger les entités sous le doigt.
  String get massLayerId => '$layerPrefix-mass';

  MapController? get map => _map;

  /// Vrai quand un style est chargé et les couches posées : avant cela, tout
  /// appel de dessin est mémorisé mais sans effet visible.
  bool get isStyleReady => _styleReady;

  String? get selectedTrackId => _selectedId;

  List<PdlMapTrack> get tracks => List<PdlMapTrack>.unmodifiable(_tracks);

  /// La région visible, ou `null` avant le premier cadre.
  PdlMapBox? get visibleBox {
    final MapController? m = _map;
    if (m == null) return null;
    try {
      return PdlMapBox.fromLngLatBounds(m.getVisibleRegion());
    } catch (_) {
      // `getVisibleRegion` lève tant que la vue native n'a pas de taille.
      return null;
    }
  }

  void attachMap(MapController controller) {
    _map = controller;
  }

  /// Appelé sur `MapEventStyleLoaded`. Repose l'intégralité des couches : un
  /// changement de fond de carte les efface toutes.
  Future<void> attachStyle(StyleController style) async {
    _style = style;
    _styleReady = false;
    _drawnLayers.clear();
    await _applyAll();
    // L'écran a pu se fermer pendant que les couches se posaient (un lien
    // ouvert juste après, ledger `MOB-79`) : plus personne à prévenir.
    if (_disposed) return;
    _styleReady = true;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void detachStyle() {
    _style = null;
    _styleReady = false;
    _drawnLayers.clear();
  }

  Future<void> setContent({
    required List<PdlMapTrack> tracks,
    List<PdlMapWaypoint> waypoints = const <PdlMapWaypoint>[],
    PdlMapPoint? start,
    PdlMapPoint? end,
  }) async {
    _tracks = tracks;
    _waypoints = waypoints;
    _start = start;
    _end = end;
    if (_selectedId != null &&
        !tracks.any((PdlMapTrack t) => t.id == _selectedId)) {
      _selectedId = null;
    }
    // Un tracé seul est implicitement le tracé sélectionné : sinon il
    // s'afficherait à l'opacité des tracés de fond (0,5), illisible sur une
    // fiche parcours.
    if (_selectedId == null && tracks.length == 1) {
      _selectedId = tracks.first.id;
    }
    if (_style != null) await _applyAll();
    notifyListeners();
  }

  /// Allume ou éteint l'ombrage du relief, ou en change la source.
  ///
  /// Repose toutes les couches : MapLibre n'a pas de `zIndex`, et l'ombrage doit
  /// rester **sous** les tracés — sinon il les voile. C'est le même prix qu'un
  /// changement de contenu, et il n'est payé qu'à la bascule de l'interrupteur.
  Future<void> setHillshade(PdlHillshade? hillshade) async {
    if (_hillshade == hillshade) return;
    _hillshade = hillshade;
    if (_style != null) await _applyAll();
    notifyListeners();
  }

  /// L'URL de la couche de masse, ou `null` pour l'effacer.
  ///
  /// Reçoit une **chaîne**, jamais un DTO : `core/pdl` ne connaît aucune API.
  /// C'est `features/routes/data/route_tile_urls.dart` qui la fabrique.
  ///
  /// La comparaison en tête n'est pas une optimisation. L'URL porte le jeton,
  /// donc elle *est* la clé de cache de MapLibre : sans ce garde-fou, chaque
  /// `build` de l'écran viderait le cache de tuiles et retéléchargerait la vue
  /// entière — plusieurs fois par seconde pendant une animation.
  ///
  /// Le remplacement passe par [_applyAll] plutôt que par un simple
  /// retrait/ajout, et ce n'est pas de la paresse : rajouter une couche la
  /// remonte au sommet du style. Reposer toute la pile est la seule façon de
  /// garantir que le tracé sélectionné, les marqueurs et le réticule restent
  /// **au-dessus** de la masse après un renouvellement de jeton — c'est-à-dire
  /// douze minutes après l'ouverture, ce qu'aucun test de démarrage ne verrait.
  Future<void> setMassTileUrl(String? template, {String? colorHex}) async {
    final String nextColor = colorHex ?? _massColorHex;
    if (template == _massTileUrl && nextColor == _massColorHex) return;
    _massTileUrl = template;
    _massColorHex = nextColor;
    if (_style == null) return;
    await _applyAll();
  }

  String? get massTileUrl => _massTileUrl;

  /// Les propriétés de l'entité de masse sous [screenPoint], ou `null`.
  ///
  /// **Pourquoi pas [trackIdAt]** : celui-ci déduit le tracé du *nom de la
  /// couche*, une couche GeoJSON par tracé. Sur une source vectorielle tous les
  /// parcours sont dans une seule couche, et `QueriedLayer` ne porte aucune
  /// propriété d'entité. `featuresAtPoint` en porte, lui — c'est exactement ce
  /// que fait la carte web, qui lit `event.features[0].properties`.
  ///
  /// Rend la `Map` brute : `core/pdl` ne connaît aucun DTO, c'est l'appelant
  /// qui interprète `slug`, `name`, `team_slug`, `distance`, `elevation_gain`.
  Map<String, Object?>? massFeatureAt(
    Offset screenPoint, {
    double tolerance = 12,
  }) {
    final MapController? m = _map;
    if (m == null || _massTileUrl == null) return null;
    // La même croix de sondage que [trackIdAt] : un trait de quelques pixels
    // ne se touche pas au pixel près, et l'API n'offre pas de tolérance.
    for (final Offset probe in _probesAround(screenPoint, tolerance)) {
      try {
        final List<RenderedFeature> hits = m.featuresAtPoint(
          probe,
          layerIds: <String>[massLayerId],
        );
        if (hits.isNotEmpty) return hits.first.properties;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<Offset> _probesAround(Offset point, double tolerance) => <Offset>[
    point,
    point.translate(-tolerance, 0),
    point.translate(tolerance, 0),
    point.translate(0, -tolerance),
    point.translate(0, tolerance),
  ];

  /// Change le tracé sélectionné.
  ///
  /// **Ne reconstruit pas les couches** : le trait est piloté par une
  /// expression `case` sur la propriété `sel` de l'entité, et il suffit donc de
  /// repousser la source (un seul `updateGeoJsonSource`). Seul l'ordre de
  /// dessin impose de toucher une couche — celle du tracé nouvellement
  /// sélectionné est retirée puis rajoutée pour repasser au-dessus, MapLibre
  /// n'ayant pas de `zIndex` sur les lignes.
  ///
  /// **Écart assumé** : le plan cite `setLayerProperties`, qui **n'existe pas**
  /// sur le `StyleController` de `maplibre 0.3.5` (vérifié : la classe expose
  /// `addSource`, `addLayer`, `updateGeoJsonSource`, `removeLayer`,
  /// `removeSource`, et rien pour muter une couche en place). L'expression
  /// pilotée par la donnée obtient le même résultat en un appel.
  Future<void> select(String? trackId) async {
    if (_selectedId == trackId) return;
    _selectedId = trackId;
    notifyListeners();

    // Une pose en cours retire et rajoute la source : pousser dedans entre les
    // deux lèverait. La pose finira de toute façon sur la sélection à jour.
    await _applying;
    final StyleController? style = _style;
    // Pas de couche de tracé posée, pas de source à mettre à jour.
    if (style == null || _drawnLayers.isEmpty) return;
    await _safe(
      () => style.updateGeoJsonSource(id: _sourceId, data: _tracksGeoJson()),
    );
    if (trackId != null) await _raise(trackId);
  }

  /// Déplace le marqueur de réticule, ou l'efface avec `null`.
  ///
  /// La couche et sa source sont posées **une fois** au chargement du style,
  /// vides ; ce déplacement n'est qu'un `updateGeoJsonSource`. Ajouter et
  /// retirer une couche à chaque frame de glissement ferait scintiller la
  /// carte et fuiterait des couches (§1.3.1).
  Future<void> setCursor(PdlMapPoint? point) async {
    if (_cursor == point) return;
    _cursor = point;
    await _applying;
    final StyleController? style = _style;
    if (style == null) return;
    await _safe(
      () => style.updateGeoJsonSource(
        id: _cursorSourceId,
        data: _cursorGeoJson(),
      ),
    );
  }

  PdlMapPoint? get cursor => _cursor;

  String _cursorGeoJson() {
    final PdlMapPoint? p = _cursor;
    return jsonEncode(<String, Object?>{
      'type': 'FeatureCollection',
      'features': <Map<String, Object?>>[
        if (p != null)
          <String, Object?>{
            'type': 'Feature',
            'properties': <String, Object?>{},
            'geometry': <String, Object?>{
              'type': 'Point',
              'coordinates': <double>[p.lon, p.lat],
            },
          },
      ],
    });
  }

  /// L'identifiant du tracé sous [screenPoint], ou `null`.
  ///
  /// Interroge une petite croix de points autour du doigt : un trait de 5 px
  /// logiques est presque impossible à toucher au pixel près, et `queryLayers`
  /// n'offre pas de tolérance.
  String? trackIdAt(Offset screenPoint, {double tolerance = 12}) {
    final MapController? m = _map;
    if (m == null) return null;
    for (final Offset probe in _probesAround(screenPoint, tolerance)) {
      late final List<QueriedLayer> hits;
      try {
        hits = m.queryLayers(probe);
      } catch (_) {
        return null;
      }
      for (final QueriedLayer hit in hits) {
        final String? id = _trackIdOfLayer(hit.layerId);
        if (id != null) return id;
      }
    }
    return null;
  }

  String? _trackIdOfLayer(String layerId) {
    final String prefix = '$layerPrefix-';
    if (!layerId.startsWith(prefix)) return null;
    final String candidate = layerId.substring(prefix.length);
    return _tracks.any((PdlMapTrack t) => t.id == candidate) ? candidate : null;
  }

  /// Largeur du monde entier, en pixels logiques, au zoom 0.
  ///
  /// 512 est la convention de MapLibre GL ; certaines vues natives comptent en
  /// tuiles de 256, et s'y tromper coûte pile un niveau de zoom. On ne devine
  /// donc pas : [calibrate] la **mesure** sur la carte réelle, une fois.
  double _worldPixelsAtZoom0 = 512;

  double get worldPixelsAtZoom0 => _worldPixelsAtZoom0;

  /// Déduit [worldPixelsAtZoom0] de l'état courant de la carte.
  ///
  /// La largeur visible en longitude, le zoom courant et la largeur de la vue
  /// suffisent : `largeurVue = mondePixels · 2^zoom · fractionDeMondeVisible`.
  /// À appeler quand la carte a rendu au moins une image — avant, la région
  /// visible ne veut rien dire. Sans effet si la lecture échoue : la valeur
  /// précédente reste en place.
  void calibrate(Size viewSize) {
    final MapController? m = _map;
    if (m == null || viewSize.width <= 0) return;
    try {
      final MapCamera camera = m.getCamera();
      final LngLatBounds visible = m.getVisibleRegion();
      final double spanLon = (visible.longitudeEast - visible.longitudeWest)
          .abs();
      if (spanLon <= 0 || spanLon >= 360) return;
      final double world =
          viewSize.width / ((spanLon / 360) * math.pow(2, camera.zoom));
      // Une mesure aberrante (vue pivotée, lecture pendant une transition) ne
      // doit pas empoisonner tous les cadrages suivants.
      if (world.isFinite && world >= 64 && world <= 4096) {
        _worldPixelsAtZoom0 = world;
      }
    } catch (_) {
      // La vue native n'est pas lisible : on garde la valeur en place.
    }
  }

  /// Place la caméra pour montrer [box] dans une vue de [viewSize], en lui
  /// réservant [padding]. Rend `false` si le cadrage n'a pas pu être calculé.
  ///
  /// Remplace `MapController.fitBounds`, qui délègue le calcul à la vue native
  /// et l'exécute sans erreur *ni effet* quand celle-ci n'a pas encore sa
  /// taille — et qui, sur iOS, anime toujours (`animated: true` en dur).
  /// Ici le calcul est fait ici ([pdlCameraForBox]) à partir d'une taille que
  /// Flutter connaît, et `moveCamera` s'y rend sans animation.
  Future<bool> fitBox(
    PdlMapBox box, {
    required Size viewSize,
    EdgeInsets padding = const EdgeInsets.all(50),
  }) async {
    final MapController? m = _map;
    if (m == null) return false;
    final PdlMapCamera? camera = pdlCameraForBox(
      // Une boîte dégénérée ferait plonger la caméra au zoom maximal.
      box.expandedToMinSpan(),
      size: viewSize,
      padding: padding,
      worldPixelsAtZoom0: _worldPixelsAtZoom0,
    );
    if (camera == null) return false;
    await m.moveCamera(
      center: Geographic(lon: camera.lon, lat: camera.lat),
      zoom: camera.zoom,
    );
    return true;
  }

  // ── Pose des couches ──────────────────────────────────────────────────

  /// Repose toutes les couches. **Sérialisé** : `PdlMap` appelle
  /// [setContent] sans l'attendre à chaque mise à jour du widget, et deux
  /// poses entrelacées (l'une retire la source pendant que l'autre la
  /// rajoute) finissaient sur « A Source with the id … already exists »
  /// (`docs/LEDGER_*.md MOB-35`). Une demande qui arrive pendant une pose en
  /// relance une seule autre à la fin, sur l'état le plus récent ; toutes les
  /// demandes de l'intervalle se fondent en elle.
  Future<void> _applyAll() {
    _applyRequested = true;
    return _applying ??= _drainApplies();
  }

  Future<void> _drainApplies() async {
    try {
      while (_applyRequested) {
        _applyRequested = false;
        await _applyOnce();
      }
    } finally {
      // Remis à null ici, dans la même boucle d'événements que la dernière
      // vérification de [_applyRequested] : une demande arrivée après repart
      // sur une pose neuve au lieu d'attendre celle qui s'achève.
      _applying = null;
    }
  }

  Future<void> _applyOnce() async {
    final StyleController? style = _style;
    if (style == null) return;

    await _addHillshadeLayer(style);

    await _safe(() => style.removeLayer(_pointsSourceId));
    // Les couches des points de parcours avant leurs sources (règle iOS).
    await _safe(() => style.removeLayer(_waypointHaloLayerId));
    await _safe(() => style.removeLayer(_waypointIconLayerId));
    await _safe(() => style.removeLayer(_waypointLabelLayerId));

    // La masse juste au-dessus de l'ombrage, et sous tout le reste : c'est un
    // fond, et le tracé sélectionné comme les marqueurs doivent rester lisibles
    // par-dessus.
    await _applyMassLayer(style);

    // Une **seule** source pour tous les tracés (§1.0.3-7) ; c'est le
    // `layerId` qui porte l'identité, chaque couche étant filtrée sur son
    // `trackId`.
    for (final String id in List<String>.of(_drawnLayers)) {
      await _safe(() => style.removeLayer(id));
    }
    _drawnLayers.clear();
    await _safe(() => style.removeLayer(_arrowsLayerId));
    await _safe(() => style.removeSource(_arrowsSourceId));
    await _safe(() => style.removeSource(_sourceId));
    if (_tracks.isNotEmpty) {
      await style.addSource(
        GeoJsonSource(id: _sourceId, data: _tracksGeoJson()),
      );
      for (final PdlMapTrack track in _tracks) {
        if (track.id == _selectedId) continue;
        await _addTrackLayer(style, track);
      }
      // Le sélectionné en dernier : c'est l'ordre de dessin qui fait le
      // premier plan.
      final PdlMapTrack? selected = _selectedTrack;
      if (selected != null) await _addTrackLayer(style, selected);
      await _addArrowLayer(style);
    }

    await _addPointLayers(style);
    await _addWaypointLayers(style);
    await _addCursorLayer(style);
  }

  /// `hillshade-shadow-color` et `hillshade-highlight-color` **tuent le process
  /// sur iOS**, et pas d'une exception qu'on pourrait rattraper : le SDK envoie
  /// `count` au `UIColor` scalaire qu'il vient de fabriquer et l'application
  /// abandonne (`NSInvalidArgumentException`, `-[UIDeviceRGBColor count]`). Les
  /// deux sont typées `colorArray` dans la spec de style, et le convertisseur
  /// `std::vector<T>` de MapLibre iOS ne vérifie pas la classe de la constante
  /// avant de lui demander sa longueur.
  ///
  /// Tant que ce n'est pas corrigé en amont, iOS garde l'ombrage **aux teintes
  /// par défaut** (noir/blanc) plutôt que pas d'ombrage du tout. Android et le
  /// web reçoivent les couleurs de la charte.
  ///
  /// Correctif proposé : https://github.com/josxha/flutter-maplibre/pull/571 —
  /// à sa fusion, remonter `maplibre` dans `pubspec.yaml`, **supprimer ce
  /// drapeau** et le rappel dans `CLAUDE.md`. Constaté sur maplibre 0.3.6
  /// (MapLibre iOS 6.25.1 et 6.29.0).
  static bool get _hillshadeColorsCrashOnIos =>
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Pose — ou retire — l'ombrage du relief, **avant tout le reste**.
  ///
  /// L'ordre compte : ajoutée en premier de nos couches, elle passe au-dessus du
  /// fond de carte (comme sur le web) mais reste sous les tracés, les marqueurs
  /// et le réticule.
  ///
  /// La source est un `RasterDemSource` construit sur l'URL du TileJSON. On ne
  /// lui passe **ni encodage ni plage de zoom** : le greffon ne les applique sur
  /// aucune des deux plateformes (Android construit `RasterDemSource(url,
  /// tileSize)` avec un « TODO apply other properties », iOS passe par
  /// `initWithIdentifier:configurationURL:tileSize:`), c'est le TileJSON qui
  /// fait foi. Conséquence à connaître : si le document ne déclare pas de
  /// `maxzoom`, l'ombrage peut disparaître au-delà du zoom natif du
  /// fournisseur, là où le web le prolonge en le déclarant lui-même.
  ///
  /// `hillshade-method` n'est pas envoyé : c'est une propriété de MapLibre GL
  /// **JS**, absente des SDK natifs, où elle finirait en écriture KVC sur une
  /// clé inconnue.
  ///
  /// **Les deux teintes sont muettes sur iOS** — voir
  /// [_hillshadeColorsCrashOnIos].
  Future<void> _addHillshadeLayer(StyleController style) async {
    await _safe(() => style.removeLayer('$_hillshadeSourceId-layer'));
    await _safe(() => style.removeSource(_hillshadeSourceId));
    final PdlHillshade? hillshade = _hillshade;
    if (hillshade == null) return;
    await _safe(
      () => style.addSource(
        RasterDemSource(id: _hillshadeSourceId, url: hillshade.url),
      ),
    );
    await _safe(
      () => style.addLayer(
        HillshadeStyleLayer(
          id: '$_hillshadeSourceId-layer',
          sourceId: _hillshadeSourceId,
          paint: <String, Object>{
            'hillshade-exaggeration': hillshade.exaggeration,
            if (!_hillshadeColorsCrashOnIos) ...<String, Object>{
              'hillshade-shadow-color': hillshade.shadowColor.toHexString(),
              'hillshade-highlight-color': hillshade.highlightColor
                  .toHexString(),
            },
          },
        ),
      ),
    );
  }

  /// Pose — ou retire — la couche de tuiles vectorielles de masse.
  Future<void> _applyMassLayer(StyleController style) async {
    await _safe(() => style.removeLayer(massLayerId));
    await _safe(() => style.removeSource(_massSourceId));
    final String? template = _massTileUrl;
    if (template == null) return;
    // Un fond qui ne se pose pas ne doit pas emporter le reste de la pile :
    // tracés, marqueurs et réticule viennent après (feedback #8).
    try {
      await style.addSource(
        await PdlMassTiles.platformSource(
          id: _massSourceId,
          tileUrlTemplate: template,
        ),
      );
      await style.addLayer(
        PdlMassTiles.layer(
          id: massLayerId,
          sourceId: _massSourceId,
          colorHex: _massColorHex,
        ),
      );
    } catch (error) {
      debugPrint('Mass layer not drawn: $error');
    }
  }

  /// Pose la couche du réticule, **vide**, une fois pour toutes.
  ///
  /// Elle est ajoutée en dernier pour rester au-dessus des tracés et des
  /// marqueurs. Son contenu ne bouge ensuite que par [setCursor].
  Future<void> _addCursorLayer(StyleController style) async {
    await _safe(() => style.removeLayer('$_cursorSourceId-dot'));
    await _safe(() => style.removeSource(_cursorSourceId));
    await style.addSource(
      GeoJsonSource(id: _cursorSourceId, data: _cursorGeoJson()),
    );
    await style.addLayer(
      CircleStyleLayer(
        id: '$_cursorSourceId-dot',
        sourceId: _cursorSourceId,
        paint: <String, Object>{
          'circle-radius': 7,
          'circle-color': _cursorColor.toHexString(),
          'circle-stroke-width': 3,
          'circle-stroke-color': _pointStroke.toHexString(),
        },
      ),
    );
  }

  PdlMapTrack? get _selectedTrack {
    for (final PdlMapTrack t in _tracks) {
      if (t.id == _selectedId) return t;
    }
    return null;
  }

  Future<void> _addTrackLayer(StyleController style, PdlMapTrack track) async {
    final String id = '$layerPrefix-${track.id}';
    await style.addLayer(
      LineStyleLayer(
        id: id,
        sourceId: _sourceId,
        filter: <Object>[
          '==',
          <Object>['get', 'trackId'],
          track.id,
        ],
        layout: const <String, Object>{
          'line-cap': 'round',
          'line-join': 'round',
        },
        paint: <String, Object>{
          // Lue sur l'entité, jamais figée sur la couche : c'est ce qui permet
          // à un tracé colorisé par pente de tenir sur **une** couche.
          'line-color': <Object>['get', 'color'],
          'line-width': <Object>[
            'case',
            <Object>[
              '==',
              <Object>['get', 'sel'],
              1,
            ],
            trackTheme.selectedWidth,
            trackTheme.width,
          ],
          'line-opacity': <Object>[
            'case',
            <Object>[
              '==',
              <Object>['get', 'sel'],
              1,
            ],
            trackTheme.selectedOpacity,
            trackTheme.opacity,
          ],
        },
      ),
    );
    _drawnLayers.add(id);
  }

  Future<void> _raise(String trackId) async {
    final StyleController? style = _style;
    if (style == null) return;
    final PdlMapTrack? track = _selectedTrack;
    if (track == null || track.id != trackId) return;
    final String id = '$layerPrefix-$trackId';
    if (_drawnLayers.isEmpty || _drawnLayers.last == id) return;
    await _safe(() => style.removeLayer(id));
    _drawnLayers.remove(id);
    await _addTrackLayer(style, track);
    // Le tracé repassé au premier plan recouvrirait ses propres chevrons.
    await _safe(() => style.removeLayer(_arrowsLayerId));
    await _safe(() => _addArrowLayerOnly(style));
  }

  /// Pose les chevrons du sens de parcours, au-dessus de tous les tracés.
  ///
  /// Sur une source **à part**, une entité par ligne entière : un tracé
  /// colorisé par pente est découpé en tronçons de quelques mètres, et un
  /// placement `line` sur ces tronçons poserait les chevrons au hasard des
  /// coupures — le site fait de même (`RouteTrackMap`, ledger `WEB-49`). Le
  /// sens est celui des coordonnées, donc de l'ordre des points du GPX.
  ///
  /// Un échec n'emporte pas le reste de la pile : la carte reste lisible sans
  /// flèches.
  Future<void> _addArrowLayer(StyleController style) async {
    try {
      final Uint8List? png = await _arrowPng();
      if (png == null) return;
      // Un changement de fond de carte remplace le style, et ses images avec :
      // l'image est donc reposée à chaque pose.
      await style.addImage(pdlRouteArrowImageId, png);
      await style.addSource(
        GeoJsonSource(id: _arrowsSourceId, data: _arrowsGeoJson()),
      );
      await _addArrowLayerOnly(style);
    } catch (error) {
      debugPrint('Route arrows not drawn: $error');
    }
  }

  Future<void> _addArrowLayerOnly(StyleController style) => style.addLayer(
    SymbolStyleLayer(
      id: _arrowsLayerId,
      sourceId: _arrowsSourceId,
      layout: pdlRouteArrowLayout,
    ),
  );

  Future<Uint8List?>? _arrowPngCache;
  Color? _arrowPngFill;
  Color? _arrowPngRim;

  Future<Uint8List?> _arrowPng() {
    if (_arrowPngCache == null ||
        _arrowPngFill != _arrowColor ||
        _arrowPngRim != _arrowRimColor) {
      _arrowPngFill = _arrowColor;
      _arrowPngRim = _arrowRimColor;
      _arrowPngCache = pdlRouteArrowPng(fill: _arrowColor, rim: _arrowRimColor);
    }
    return _arrowPngCache!;
  }

  String _arrowsGeoJson() => jsonEncode(<String, Object?>{
    'type': 'FeatureCollection',
    'features': <Map<String, Object?>>[
      for (final PdlMapTrack track in _tracks)
        for (final List<List<double>> line in track.lines)
          if (line.length >= 2)
            <String, Object?>{
              'type': 'Feature',
              'properties': <String, Object?>{'trackId': track.id},
              'geometry': <String, Object?>{
                'type': 'LineString',
                'coordinates': <List<double>>[
                  for (final List<double> c in line) <double>[c[0], c[1]],
                ],
              },
            },
    ],
  });

  Future<void> _addPointLayers(StyleController style) async {
    final List<Map<String, Object?>> features = <Map<String, Object?>>[];
    if (_start != null) {
      features.add(_pointFeature(_start!, 'start'));
    }
    if (_end != null) {
      features.add(_pointFeature(_end!, 'end'));
    }
    await _safe(() => style.removeSource(_pointsSourceId));
    if (features.isNotEmpty) {
      await style.addSource(
        GeoJsonSource(
          id: _pointsSourceId,
          data: jsonEncode(<String, Object?>{
            'type': 'FeatureCollection',
            'features': features,
          }),
        ),
      );
      await style.addLayer(
        CircleStyleLayer(
          id: _pointsSourceId,
          sourceId: _pointsSourceId,
          paint: <String, Object>{
            'circle-radius': 8,
            'circle-color': <Object>['get', 'color'],
            'circle-stroke-width': 2,
            'circle-stroke-color': <Object>['get', 'stroke'],
          },
        ),
      );
    }
  }

  // ── Points de parcours (ledger MOB-84) ────────────────────────────────

  /// Pose les points de parcours : un halo (le point allumé), les pictogrammes,
  /// puis les noms.
  ///
  /// Les **images** (un pictogramme par type, un nom par texte) sont reposées à
  /// chaque pose, comme le chevron : un changement de fond de carte remplace le
  /// style, et ses images avec. Leurs PNG, eux, sont mémorisés. Un échec
  /// n'emporte pas le reste de la pile.
  Future<void> _addWaypointLayers(StyleController style) async {
    await _safe(() => style.removeSource(_waypointsSourceId));
    await _safe(() => style.removeSource(_waypointFocusSourceId));
    if (_waypoints.isEmpty) return;
    try {
      final Set<String> placed = <String>{};
      for (final PdlMapWaypoint w in _waypoints) {
        if (!placed.add(pdlWaypointIconImageId(w.iconId))) continue;
        final Uint8List? png = await _iconPng(w);
        if (png != null) {
          await style.addImage(pdlWaypointIconImageId(w.iconId), png);
        }
      }
      for (final PdlMapWaypoint w in _waypoints) {
        final String? text = w.label;
        if (text == null || text.isEmpty) continue;
        if (!placed.add(pdlWaypointLabelImageId(text))) continue;
        final Uint8List? png = await _labelPng(text);
        if (png != null) {
          await style.addImage(pdlWaypointLabelImageId(text), png);
        }
      }
      await style.addSource(
        GeoJsonSource(id: _waypointsSourceId, data: _waypointsGeoJson()),
      );
      // Posée même vide, comme le réticule : le halo ne fait ensuite que
      // pousser sa source.
      await style.addSource(
        GeoJsonSource(id: _waypointFocusSourceId, data: _focusGeoJson()),
      );
      await style.addLayer(
        CircleStyleLayer(
          id: _waypointHaloLayerId,
          sourceId: _waypointFocusSourceId,
          paint: <String, Object>{
            'circle-radius': 17,
            'circle-color': _cursorColor.toHexString(),
            'circle-opacity': 0.35,
            'circle-stroke-width': 2,
            'circle-stroke-color': _waypointRingColor.toHexString(),
          },
        ),
      );
      await style.addLayer(
        SymbolStyleLayer(
          id: _waypointIconLayerId,
          sourceId: _waypointsSourceId,
          layout: pdlWaypointIconLayout,
        ),
      );
      await style.addLayer(
        SymbolStyleLayer(
          id: _waypointLabelLayerId,
          sourceId: _waypointsSourceId,
          layout: pdlWaypointLabelLayout,
          minZoom: kPdlWaypointLabelMinZoom,
          filter: <Object>[
            '!=',
            <Object>['get', 'label'],
            '',
          ],
        ),
      );
    } catch (error) {
      debugPrint('Waypoints not drawn: $error');
    }
  }

  final Map<String, Future<Uint8List?>> _waypointPngs =
      <String, Future<Uint8List?>>{};

  Future<Uint8List?> _iconPng(PdlMapWaypoint w) => _waypointPngs.putIfAbsent(
    'icon|${w.iconId}|${w.mark.hashCode}|${_waypointRingColor.toARGB32()}',
    () => pdlWaypointIconPng(w.mark, ring: _waypointRingColor),
  );

  Future<Uint8List?> _labelPng(String text) => _waypointPngs.putIfAbsent(
    'label|$text|${_labelBackground.toARGB32()}|${_labelForeground.toARGB32()}'
    '|${_labelStyle.hashCode}',
    () => pdlWaypointLabelPng(
      text,
      style: _labelStyle,
      background: _labelBackground,
      foreground: _labelForeground,
    ),
  );

  /// Une entité par point. Aucun filtre sur la valeur des coordonnées : un
  /// point à `[0, 45]` ou `[3, 0]` est un point (ledger `WEB-108`).
  String _waypointsGeoJson() => jsonEncode(<String, Object?>{
    'type': 'FeatureCollection',
    'features': <Map<String, Object?>>[
      for (final PdlMapWaypoint w in _waypoints)
        <String, Object?>{
          'type': 'Feature',
          'properties': <String, Object?>{
            'key': w.key,
            'icon': pdlWaypointIconImageId(w.iconId),
            'label': (w.label == null || w.label!.isEmpty)
                ? ''
                : pdlWaypointLabelImageId(w.label!),
            'priority': w.priority,
          },
          'geometry': <String, Object?>{
            'type': 'Point',
            'coordinates': <double>[w.lon, w.lat],
          },
        },
    ],
  });

  PdlMapWaypoint? _waypointByKey(String? key) {
    if (key == null) return null;
    for (final PdlMapWaypoint w in _waypoints) {
      if (w.key == key) return w;
    }
    return null;
  }

  String _focusGeoJson() {
    final PdlMapWaypoint? w = _waypointByKey(_focusKey);
    return jsonEncode(<String, Object?>{
      'type': 'FeatureCollection',
      'features': <Map<String, Object?>>[
        if (w != null)
          <String, Object?>{
            'type': 'Feature',
            'properties': <String, Object?>{},
            'geometry': <String, Object?>{
              'type': 'Point',
              'coordinates': <double>[w.lon, w.lat],
            },
          },
      ],
    });
  }

  /// Allume un point (halo), ou éteint avec `null`. Un `updateGeoJsonSource`,
  /// sans repose complète.
  Future<void> setWaypointFocus(String? key) async {
    if (_focusKey == key) return;
    _focusKey = key;
    await _applying;
    final StyleController? style = _style;
    if (style == null || _waypoints.isEmpty) return;
    await _safe(
      () => style.updateGeoJsonSource(
        id: _waypointFocusSourceId,
        data: _focusGeoJson(),
      ),
    );
  }

  /// La clé du point sous [screenPoint], ou `null`. En cas de recouvrement, le
  /// plus prioritaire (celui qu'on voit au-dessus).
  String? waypointKeyAt(
    Offset screenPoint, {
    double extent = PdlMetrics.tapTarget,
  }) {
    final MapController? m = _map;
    if (m == null || _waypoints.isEmpty) return null;
    try {
      final List<RenderedFeature> hits = m.featuresInRect(
        Rect.fromCenter(center: screenPoint, width: extent, height: extent),
        layerIds: <String>[_waypointIconLayerId],
      );
      String? best;
      int bestPriority = -1;
      for (final RenderedFeature f in hits) {
        final Object? key = f.properties['key'];
        if (key is! String) continue;
        // Android convertit les types : un entier peut revenir en double.
        final int priority = (f.properties['priority'] as num?)?.toInt() ?? 0;
        if (priority > bestPriority) {
          best = key;
          bestPriority = priority;
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  /// Amène la caméra sur un point. Avec [onlyIfHidden], rien ne bouge tant que
  /// le point est dans la région visible.
  Future<void> revealWaypoint(
    String key, {
    required bool onlyIfHidden,
    EdgeInsets padding = EdgeInsets.zero,
    bool animate = true,
  }) async {
    final MapController? m = _map;
    final PdlMapWaypoint? w = _waypointByKey(key);
    if (m == null || w == null) return;
    if (onlyIfHidden) {
      final PdlMapBox? visible = visibleBox;
      if (visible != null &&
          !visible.isPoint &&
          visible.contains(
            PdlMapBox(
              minLon: w.lon,
              minLat: w.lat,
              maxLon: w.lon,
              maxLat: w.lat,
            ),
            slack: 0,
          )) {
        return;
      }
    }
    try {
      final double zoom = math.max(m.getCamera().zoom, 13);
      final Geographic center = Geographic(lon: w.lon, lat: w.lat);
      if (animate) {
        await m.animateCamera(
          center: center,
          zoom: zoom,
          padding: padding,
          nativeDuration: PdlMotion.mapFocus,
        );
      } else {
        await m.moveCamera(center: center, zoom: zoom, padding: padding);
      }
    } catch (error) {
      debugPrint('Waypoint not revealed: $error');
    }
  }

  /// Repose toute la pile avec les couleurs courantes (changement de thème).
  Future<void> refreshMarkers() async {
    if (_style != null) await _applyAll();
  }

  /// Couleurs des marqueurs, injectées par [PdlMap] depuis `PdlColors`.
  Color _startColor = const Color(0xFF40C057);
  Color _endColor = const Color(0xFFFA5252);
  Color _waypointRingColor = const Color(0xFFFFFFFF);
  Color _labelBackground = const Color(0xFFFFFFFF);
  Color _labelForeground = const Color(0xFF212529);
  TextStyle _labelStyle = const TextStyle(fontSize: 12);
  Color _pointStroke = const Color(0xFFFFFFFF);
  Color _cursorColor = const Color(0xFF4C6EF5);
  Color _arrowColor = const Color(0xFFFFFFFF);
  Color _arrowRimColor = const Color(0x8C000000);

  /// Injecte les couleurs de marqueur lues sur le thème.
  ///
  /// `core/pdl` interdit les littéraux de couleur : les valeurs par défaut
  /// ci-dessus ne sont qu'un filet avant le premier `build`, et [PdlMap] les
  /// remplace systématiquement par `context.pdl.mapStart` / `mapEnd` /
  /// `mapWaypointRing` / `surface` / `mapArrow` / `mapArrowRim`.
  void setMarkerColors({
    required Color start,
    required Color end,
    required Color waypointRing,
    required Color labelBackground,
    required Color labelText,
    required TextStyle labelStyle,
    required Color stroke,
    Color? cursor,
    Color? arrow,
    Color? arrowRim,
  }) {
    if (cursor != null) _cursorColor = cursor;
    if (arrow != null) _arrowColor = arrow;
    if (arrowRim != null) _arrowRimColor = arrowRim;
    _startColor = start;
    _endColor = end;
    _waypointRingColor = waypointRing;
    _labelBackground = labelBackground;
    _labelForeground = labelText;
    _labelStyle = labelStyle;
    _pointStroke = stroke;
  }

  Map<String, Object?> _pointFeature(PdlMapPoint p, String kind) =>
      <String, Object?>{
        'type': 'Feature',
        'properties': <String, Object?>{
          'kind': kind,
          'color': (kind == 'start' ? _startColor : _endColor).toHexString(),
          'stroke': _pointStroke.toHexString(),
        },
        'geometry': <String, Object?>{
          'type': 'Point',
          'coordinates': <double>[p.lon, p.lat],
        },
      };

  String _tracksGeoJson() {
    final List<Map<String, Object?>> features = <Map<String, Object?>>[];
    for (final PdlMapTrack track in _tracks) {
      // `sel` ne pilote que le trait : un tracé mis en avant le prend aussi.
      final bool selected = track.id == _selectedId || track.emphasized;
      if (track.isSegmented) {
        _appendSegments(features, track, selected);
        continue;
      }
      for (final List<List<double>> line in track.lines) {
        if (line.length < 2) continue;
        features.add(<String, Object?>{
          'type': 'Feature',
          'properties': <String, Object?>{
            'trackId': track.id,
            'sel': selected ? 1 : 0,
            'color': track.color.toHexString(),
          },
          'geometry': <String, Object?>{
            'type': 'LineString',
            // Les composantes au-delà de la latitude (altitude, cumul `M`) ne
            // servent à rien au rendu et pèsent lourd sur un long parcours :
            // on ne pousse que `[lon, lat]`.
            'coordinates': <List<double>>[
              for (final List<double> c in line) <double>[c[0], c[1]],
            ],
          },
        });
      }
    }
    return jsonEncode(<String, Object?>{
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  /// Un segment = une entité, portant sa propre couleur.
  ///
  /// Les segments **consécutifs de même couleur sont fusionnés** : un parcours
  /// de 3 000 sommets produirait sinon 2 999 entités, là où une pente réelle
  /// n'a qu'une poignée de teintes distinctes par kilomètre. La fusion divise
  /// typiquement le nombre d'entités par dix sans changer un pixel.
  void _appendSegments(
    List<Map<String, Object?>> features,
    PdlMapTrack track,
    bool selected,
  ) {
    final List<Color> colors = track.segmentColors!;
    int segment = 0;

    for (final List<List<double>> line in track.lines) {
      if (line.length < 2) {
        segment += line.isEmpty ? 0 : line.length - 1;
        continue;
      }
      List<List<double>> run = <List<double>>[
        <double>[line[0][0], line[0][1]],
      ];
      String runColor =
          (segment < colors.length ? colors[segment] : track.color)
              .toHexString();

      for (int i = 1; i < line.length; i++) {
        final int index = segment + i - 1;
        final String color =
            (index < colors.length ? colors[index] : track.color).toHexString();
        if (color != runColor) {
          features.add(
            _segmentFeature(
              track.id,
              selected,
              runColor,
              List<List<double>>.of(run),
            ),
          );
          // Le nouveau tronçon repart du dernier sommet : sans ce
          // recouvrement, un trou d'un segment apparaîtrait à chaque
          // changement de teinte.
          run = <List<double>>[run.last];
          runColor = color;
        }
        run.add(<double>[line[i][0], line[i][1]]);
      }
      if (run.length >= 2) {
        features.add(_segmentFeature(track.id, selected, runColor, run));
      }
      segment += line.length - 1;
    }
  }

  Map<String, Object?> _segmentFeature(
    String trackId,
    bool selected,
    String color,
    List<List<double>> coordinates,
  ) => <String, Object?>{
    'type': 'Feature',
    'properties': <String, Object?>{
      'trackId': trackId,
      'sel': selected ? 1 : 0,
      'color': color,
    },
    'geometry': <String, Object?>{
      'type': 'LineString',
      'coordinates': coordinates,
    },
  };

  /// Avale l'échec d'un retrait : retirer une couche ou une source absente
  /// lève sur certaines plateformes, et c'est le cas normal au premier
  /// chargement.
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Sans effet : la couche n'existait pas.
    }
  }
}
