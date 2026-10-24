import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../theme/pdl_colors.dart';
import '../../theme/pdl_tokens.dart';
import '../../theme/pdl_typography.dart';
import 'pdl_map_attribution.dart';
import 'pdl_map_controller.dart';
import 'pdl_map_marker.dart';
import 'pdl_waypoint_mark.dart';

/// La carte Pédalons.
///
/// Remplace `features/routes/.../route_map.dart`, qui rendait un tracé, une
/// couleur, aucune interaction, avec **des URL de style codées en dur** et un
/// cadrage par `Future.delayed(100 ms)`. Ici :
///
/// * le fond vient de [styleUrl], que l'appelant lit sur `mapStyleProvider` —
///   `ConfigDto.mapStyles[]`, servi et non compilé. **Aucune URL de style n'est
///   écrite dans `lib/`** ;
/// * le cadrage part de `MapEventStyleLoaded`, jamais d'un délai ;
/// * la carte s'ouvre sur [initialCenter] (`ConfigDto.defaultCenter`) avant de
///   savoir ce qu'elle montre ;
/// * plusieurs tracés colorisés cohabitent, chacun sur **sa** couche, et le tap
///   rend l'identifiant du tracé touché.
///
/// Le widget ne connaît aucun DTO : voir [PdlMapTrack].
class PdlMap extends StatefulWidget {
  const PdlMap({
    super.key,
    required this.styleUrl,
    required this.credit,
    this.controller,
    this.tracks = const <PdlMapTrack>[],
    this.waypoints = const <PdlMapWaypoint>[],
    this.focusedWaypoint,
    this.onWaypointTapped,
    this.kmMarkers = const <PdlKmMarker>[],
    this.markers = const <PdlMapMarker>[],
    this.onMarkerTapped,
    this.cursor,
    this.start,
    this.end,
    this.initialCenter,
    this.initialZoom = 5,
    this.fitBox,
    this.fitPadding = const EdgeInsets.all(50),
    this.hillshade,
    this.selectedTrackId,
    this.onTrackSelected,
    this.onMapTapped,
    this.onCameraIdle,
    this.interactive = true,
    this.gestures,
    this.overlays = const <Widget>[],
    this.massTileUrl,
    this.massTileColor,
    this.onMassFeatureTapped,
  });

  /// L'URL du style de fond, **toujours** fournie par l'appelant.
  final String styleUrl;

  /// Le crédit dû aux fournisseurs du fond. **Obligatoire, et volontairement**
  /// : l'app a longtemps n'en affiché aucun, parce que rien n'obligeait un
  /// écran à y penser. Un paramètre requis fait échouer la compilation d'une
  /// carte sans crédit, ce qu'aucune relecture ne garantit.
  final PdlMapCredit credit;

  /// Gabarit d'URL des tuiles vectorielles de masse, ou `null` pour n'en poser
  /// aucune. Une chaîne, jamais un DTO : voir
  /// `features/routes/data/route_tile_urls.dart`.
  final String? massTileUrl;

  /// Couleur du trait de la masse. À défaut, la primaire du thème.
  final Color? massTileColor;

  /// Contrôleur externe, quand l'écran a besoin de piloter la sélection ou de
  /// lire la région visible. À défaut, [PdlMap] en crée un et le possède.
  final PdlMapController? controller;

  final List<PdlMapTrack> tracks;

  /// Les points de parcours, dessinés en couche native (pictogramme typé, nom
  /// à partir du zoom 12). Hors tracé compris : un point n'a pas besoin d'être
  /// sur le tracé pour exister.
  final List<PdlMapWaypoint> waypoints;

  /// Le point allumé (halo) et, selon [PdlWaypointFocus.move], ce que la
  /// caméra en fait. Un nouveau [PdlWaypointFocus.serial] rejoue le geste.
  final PdlWaypointFocus? focusedWaypoint;

  /// Toucher d'un point : la clé est rendue et le toucher **s'arrête là** — ni
  /// sélection de tracé, ni masse, ni [onMapTapped].
  final ValueChanged<String>? onWaypointTapped;

  /// Bornes kilométriques déjà calculées — voir [computePdlKmMarkers].
  final List<PdlKmMarker> kmMarkers;

  /// Marqueurs Flutter posés sur la carte (une pastille, une goutte) — voir
  /// [PdlMapMarker]. Au-dessus des bornes kilométriques, sous les
  /// [overlays]. Pour quelques points (une quinzaine) : chacun est un widget
  /// replacé à chaque mouvement de caméra.
  final List<PdlMapMarker> markers;

  /// Toucher d'un marqueur : son id. Sans lui, les marqueurs ne sont que des
  /// images et laissent passer les gestes à la carte.
  final ValueChanged<String>? onMarkerTapped;

  /// Le réticule posé sur la carte (un point, à la couleur primaire), ou
  /// `null` pour aucun. La forme déclarative de
  /// [PdlMapController.setCursor] : seul un changement de valeur le déplace,
  /// et `null` ne touche pas au réticule qu'un contrôleur externe pilote déjà
  /// (la fiche parcours le promène au doigt sur le profil).
  final PdlMapPoint? cursor;

  final PdlMapPoint? start;
  final PdlMapPoint? end;

  /// L'ombrage du relief, ou `null` pour aucun. La source vient de
  /// `ConfigDto.terrain` via l'écran — **aucune URL n'est écrite ici**, pas plus
  /// que pour le fond de carte.
  final PdlHillshade? hillshade;

  /// Où la carte s'ouvre avant toute donnée (`ConfigDto.defaultCenter`).
  final PdlMapPoint? initialCenter;
  final double initialZoom;

  /// La boîte sur laquelle cadrer dès que le style est chargé. Pour une liste
  /// elle vient de `GET …/routes/bounds` ; pour un tracé unique,
  /// [PdlMapBox.ofTracks] la calcule localement.
  final PdlMapBox? fitBox;
  final EdgeInsets fitPadding;

  final String? selectedTrackId;
  final ValueChanged<String?>? onTrackSelected;

  /// Tap sur la carte, en coordonnées **géographiques** `(lon, lat)`.
  ///
  /// Distinct de [onTrackSelected], qui rend l'identité d'un tracé touché :
  /// ici c'est la position brute, dont l'appelant fait ce qu'il veut — la
  /// fiche parcours en dérive la distance cumulée du réticule.
  final void Function(double lon, double lat)? onMapTapped;

  /// Tap sur la couche de masse, avec les **propriétés brutes** de l'entité de
  /// tuile touchée — ou `null` quand le doigt tombe à côté.
  ///
  /// Une `Map`, pas un DTO : `core/pdl` n'en connaît aucun. Les clés sont
  /// celles que le backend encode dans la tuile (`slug`, `name`, `team_slug`,
  /// `distance`, `elevation_gain`).
  final ValueChanged<Map<String, Object?>?>? onMassFeatureTapped;

  /// Appelé quand la caméra se stabilise, avec la région visible — de quoi
  /// alimenter « Rechercher dans cette zone ».
  final ValueChanged<PdlMapBox>? onCameraIdle;

  /// La carte se laisse-t-elle déplacer et zoomer ?
  ///
  /// `false` pour une carte **encastrée dans une liste qui défile** : le pan y
  /// dispute le doigt au défilement de la page, et le geste finit à moitié dans
  /// l'un, à moitié dans l'autre. Le tap n'est pas concerné — ce n'est pas un
  /// geste de caméra — donc une carte non interactive reste sélectionnable.
  final bool interactive;

  /// Réglage fin des gestes, quand [interactive] est trop grossier. Il l'emporte
  /// sur lui. Réservé à `core/pdl` et aux rares écrans qui importent déjà
  /// MapLibre : le vocabulaire courant est [interactive].
  final MapGestures? gestures;

  /// Surcouches posées **dans** le contexte de la carte : boutons, pilules,
  /// carte flottante. Elles arrivent après la couche de marqueurs, donc
  /// au-dessus.
  final List<Widget> overlays;

  @override
  State<PdlMap> createState() => _PdlMapState();
}

class _PdlMapState extends State<PdlMap> {
  PdlMapController? _owned;
  PdlMapBox? _fittedBox;

  /// La marge avec laquelle [_fittedBox] a été cadrée. Une feuille qui change
  /// de cran ne change pas la boîte visée, seulement la place qu'elle laisse :
  /// sans ce second témoin, le cadrage resterait celui du cran précédent.
  EdgeInsets? _fittedPadding;

  String? _appliedStyleUrl;

  /// Mémo de la boîte des tracés : le calcul parcourt tous les sommets, et
  /// `didUpdateWidget` passe à chaque image.
  List<PdlMapTrack>? _boxedTracks;
  PdlMapBox? _tracksBox;

  /// La dernière taille allouée à la carte, relevée par le `LayoutBuilder` de
  /// [build]. On ne peut **pas** lire `context.size` depuis `didUpdateWidget` :
  /// le framework est alors en phase de construction et lève « Cannot get size
  /// during build ».
  Size? _lastSize;

  /// Vrai dès le premier `idle` — de caméra ou de tuiles : la vue native a
  /// rendu au moins une image, donc elle a une taille, la seule condition sous
  /// laquelle le cadrage fait réellement quelque chose. Voir [_settle] pour
  /// pourquoi il en faut deux.
  bool _settled = false;

  PdlMapController get _controller =>
      widget.controller ?? (_owned ??= PdlMapController());

  @override
  void initState() {
    super.initState();
    _appliedStyleUrl = widget.styleUrl;
    // Avant le style : le contrôleur pose la source du réticule à l'attache,
    // avec la position qu'il connaît alors.
    if (widget.cursor != null) _controller.setCursor(widget.cursor);
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  Brightness? _injectedBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Les couleurs de la carte (anneau, étiquettes) ne sont lues qu'au
    // chargement du style : un changement de thème sur la même URL de fond
    // garderait les anciennes.
    final Brightness brightness = Theme.of(context).brightness;
    if (_injectedBrightness != null && _injectedBrightness != brightness) {
      _injectColors();
      _controller.refreshMarkers();
    }
    _injectedBrightness = brightness;
  }

  void _injectColors() {
    final PdlColors c = context.pdl;
    _controller.setMarkerColors(
      start: c.mapStart,
      end: c.mapEnd,
      waypointRing: c.mapWaypointRing,
      labelBackground: c.overlaySolid,
      labelText: c.text,
      labelStyle: context.pdlText.xs.copyWith(fontWeight: FontWeight.w500),
      stroke: c.surface,
      cursor: c.primary,
      arrow: c.mapArrow,
      arrowRim: c.mapArrowRim,
    );
  }

  @override
  void didUpdateWidget(PdlMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Changer de fond de carte **efface toutes les couches** : on ne fait que
    // demander le style, et `MapEventStyleLoaded` les repose.
    if (widget.styleUrl != _appliedStyleUrl) {
      _appliedStyleUrl = widget.styleUrl;
      _fittedBox = null;
      _controller.detachStyle();
      _controller.map?.setStyle(widget.styleUrl);
    }

    // Comparaison **de valeur**, pas d'identité : les écrans reconstruisent
    // ces listes à chaque `build`, et reposer les couches à chaque image
    // faisait scintiller la carte et bousculait la caméra.
    if (!listEquals(widget.tracks, oldWidget.tracks) ||
        !listEquals(widget.waypoints, oldWidget.waypoints) ||
        widget.start != oldWidget.start ||
        widget.end != oldWidget.end) {
      _pushContent();
    }
    if (widget.hillshade != oldWidget.hillshade) {
      _controller.setHillshade(widget.hillshade);
    }
    if (widget.selectedTrackId != oldWidget.selectedTrackId) {
      _controller.select(widget.selectedTrackId);
    }
    if (widget.cursor != oldWidget.cursor) {
      _controller.setCursor(widget.cursor);
    }
    // `setMassTileUrl` ignore une URL inchangée : c'est ce qui rend cet appel
    // sûr à chaque `didUpdateWidget`, alors qu'un remplacement de source
    // viderait le cache de tuiles à chaque image.
    _pushMassTiles();
    _fit();
    // Dans ce même passage synchrone, après `_fit` : le `moveCamera` du cadrage
    // doit partir **avant** le recentrage sur le point.
    if (widget.focusedWaypoint != oldWidget.focusedWaypoint) {
      _applyFocus(widget.focusedWaypoint);
    }
  }

  /// Allume le point, puis déplace la caméra si le choix vient d'ailleurs que de
  /// la carte.
  void _applyFocus(PdlWaypointFocus? focus) {
    _controller.setWaypointFocus(focus?.key);
    if (focus == null || focus.move == PdlWaypointMove.none) return;
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    _controller.revealWaypoint(
      focus.key,
      onlyIfHidden: focus.move == PdlWaypointMove.ifHidden,
      padding: _padding(),
      animate: animate,
    );
    if (focus.move == PdlWaypointMove.center) {
      // Une vignette dans une page qui défile (étape, sortie) : la ramener à
      // l'écran. Sans `Scrollable` (fiche parcours), rien.
      if (Scrollable.maybeOf(context) != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: animate ? PdlMotion.mapFocus : Duration.zero,
        );
      }
    }
  }

  void _pushMassTiles() {
    _controller.setMassTileUrl(
      widget.massTileUrl,
      colorHex: (widget.massTileColor ?? context.pdl.primary).toHexString(),
    );
  }

  void _pushContent() {
    _controller.setContent(
      tracks: widget.tracks,
      waypoints: widget.waypoints,
      start: widget.start,
      end: widget.end,
    );
  }

  /// La boîte à cadrer : celle qu'impose l'appelant, ou à défaut celle des
  /// tracés.
  ///
  /// Le repli sur les tracés doit être **réévalué à chaque mise à jour**, et
  /// pas seulement au chargement du style : sur la fiche d'une sortie, les
  /// géométries des parcours arrivent d'un provider asynchrone, donc *après*
  /// `MapEventStyleLoaded`. Ne cadrer qu'une fois y laissait la carte sur le
  /// centre par défaut, la France entière, avec le tracé quelque part dedans.
  /// Le repli couvre aussi le départ, l'arrivée et les points de passage : sur
  /// une sortie dont les géométries n'arrivent pas (parcours privé, appel
  /// groupé en échec), cadrer sur les deux lieux vaut infiniment mieux que de
  /// rester sur le centre par défaut — la France entière.
  PdlMapBox? get _targetBox {
    final PdlMapBox? explicit = widget.fitBox;
    if (explicit != null) return explicit;
    if (!identical(_boxedTracks, widget.tracks)) {
      _boxedTracks = widget.tracks;
      _tracksBox = PdlMapBox.ofTracks(widget.tracks);
    }
    final PdlMapBox? points = PdlMapBox.ofPoints(<PdlMapPoint>[
      ?widget.start,
      ?widget.end,
    ]);
    final PdlMapBox? tracks = _tracksBox;
    if (tracks == null) return points;
    return points == null ? tracks : tracks.union(points);
  }

  /// Cadre sur la boîte visée — **jamais avant le premier [MapEventIdle]**.
  ///
  /// `MapEventStyleLoaded` ne dit que « le style est là » : la vue native peut
  /// n'avoir aucune taille utile à cet instant, et `fitBounds` s'y exécute
  /// alors sans erreur *et sans effet* — la caméra reste sur `initCenter`, ou
  /// pire, se cale sur une hauteur utile nulle une fois les 50 px de marge
  /// retirés de chaque côté, et part au zoom minimal. Rien ne le signale. C'est
  /// exactement ce qui rendait le cadrage « capricieux » : il marchait ou non
  /// selon qui gagnait la course entre le style, la mise en page et la donnée.
  ///
  /// `MapEventIdle` est le seul signal qui garantisse le contraire — il veut
  /// dire « toutes les tuiles demandées sont chargées, plus aucune transition
  /// en cours », donc la vue a été rendue, donc elle a une taille. Le cadrage
  /// demandé avant est simplement mémorisé et rejoué là. Pas de boucle, pas de
  /// `Future.delayed` : un seul point de déclenchement, déterministe.
  Future<void> _fit() async {
    final PdlMapBox? box = _targetBox;
    if (box == null) return;
    final EdgeInsets padding = _padding();
    if (box == _fittedBox && padding == _fittedPadding) return;
    // Pas encore prêt : `_fittedBox` reste tel quel, et le premier `idle`
    // rejouera ce même calcul.
    final Size? size = _lastSize;
    if (size == null || !_settled || !_controller.isStyleReady) return;
    // Sur iOS, le premier `CameraIdle` part **avant** que la vue native ait sa
    // taille : sa région visible n'est qu'un point. Cadrer à cet instant règle
    // bien le zoom, mais le centre retombe sur `initCenter` — la France au
    // zoom d'un parcours, sans le tracé — et le cadrage passait pour fait, si
    // bien qu'aucun `idle` suivant ne le rejouait. On attend donc une région
    // d'étendue non nulle ; l'`idle` qui suit arrive vue mesurée. Une région
    // `null` garde l'ancien comportement : c'est celui qui marche sur Android.
    final PdlMapBox? visible = _controller.visibleBox;
    if (visible != null && visible.isPoint) return;
    if (await _controller.fitBox(box, viewSize: size, padding: padding)) {
      _fittedBox = box;
      _fittedPadding = padding;
    }
  }

  /// La marge demandée, ramenée à ce que la carte peut réellement offrir.
  ///
  /// Une marge plus grande que la carte laisse une zone utile nulle, et
  /// `fitBounds` répond alors par le zoom minimal — la planète pour montrer un
  /// parcours. Le plafond porte donc sur **la somme** des deux marges d'un axe,
  /// et non sur chacune : une fiche parcours qui réserve la moitié basse de sa
  /// carte à une feuille est légitime, 50 px de chaque côté sur une carte de
  /// 260 px de haut ne l'est pas. Au-delà, les deux marges de l'axe sont
  /// réduites dans la même proportion, ce qui préserve leur asymétrie — c'est
  /// elle qui décale le tracé au-dessus de la feuille.
  static const double _kMaxPaddingRatio = 0.8;

  EdgeInsets _padding() {
    final Size? size = _lastSize;
    final EdgeInsets p = widget.fitPadding;
    if (size == null || size.isEmpty) return p;
    final double h = _shrink(p.left + p.right, size.width);
    final double v = _shrink(p.top + p.bottom, size.height);
    return EdgeInsets.fromLTRB(
      p.left * h,
      p.top * v,
      p.right * h,
      p.bottom * v,
    );
  }

  /// Le facteur à appliquer aux deux marges d'un axe pour qu'elles laissent au
  /// moins `1 - _kMaxPaddingRatio` de la dimension.
  static double _shrink(double total, double extent) {
    final double max = extent * _kMaxPaddingRatio;
    if (total <= max || total <= 0) return 1;
    return max / total;
  }

  void _onEvent(MapEvent event) {
    switch (event) {
      case MapEventStyleLoaded():
        _onStyleLoaded(event.style);
      case MapEventClick():
        // Un point de parcours touché gagne le toucher.
        if (widget.onWaypointTapped != null) {
          final String? waypoint = _controller.waypointKeyAt(event.screenPoint);
          if (waypoint != null) {
            widget.onWaypointTapped!(waypoint);
            return;
          }
        }
        widget.onMapTapped?.call(event.point.lon, event.point.lat);
        final String? id = _controller.trackIdAt(event.screenPoint);
        if (id != null || _controller.selectedTrackId != null) {
          widget.onTrackSelected?.call(id);
          if (widget.selectedTrackId == null) _controller.select(id);
        }
        // La masse est interrogée **après** les tracés GeoJSON : sur un écran
        // qui affiche les deux, le tracé posé au premier plan gagne le tap,
        // comme il gagne le dessin.
        if (widget.onMassFeatureTapped != null && id == null) {
          widget.onMassFeatureTapped!(
            _controller.massFeatureAt(event.screenPoint),
          );
        }
      case MapEventCameraIdle():
        final PdlMapBox? box = _controller.visibleBox;
        if (box != null) widget.onCameraIdle?.call(box);
        _settle();
      case MapEventIdle():
        _settle();
      default:
        break;
    }
  }

  /// La carte a rendu au moins une image : elle est mesurable, on étalonne
  /// l'échelle une fois puis on rejoue le cadrage mémorisé.
  ///
  /// **Deux événements y mènent, et il en faut bien deux.** `MapEventIdle`
  /// (« plus une tuile en vol ») n'est *jamais* émis par le SDK Android : la
  /// carte n'y produit que `MapCreated`, `StyleLoaded`, `StartMoveCamera` puis
  /// `CameraIdle`. N'attendre que le premier laissait le cadrage mort-né sur
  /// Android — la carte restait sur `initialCenter` au zoom 5, la France
  /// entière, quelle que soit l'emprise servie par le backend. Le symptôme
  /// n'avait rien d'aléatoire : il était total, et invisible en test parce que
  /// rien de tout cela ne tourne hors d'un appareil.
  ///
  /// Les `idle` suivants ne coûtent rien : [_fit] sort aussitôt quand la boîte
  /// et la marge sont déjà celles en place — c'est aussi ce qui empêche un
  /// recadrage de ramener la caméra après un geste de l'utilisateur.
  void _settle() {
    if (!_settled) {
      _settled = true;
      final Size? size = _lastSize;
      if (size != null) _controller.calibrate(size);
    }
    _fit();
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    _injectColors();
    _controller.select(widget.selectedTrackId);
    // Avant `attachStyle` : le contrôleur repose *toutes* les couches à
    // l'attache, et l'ombrage comme la masse doivent être connus à ce
    // moment-là pour sortir sous les tracés plutôt qu'au-dessus.
    await _controller.setHillshade(widget.hillshade);
    if (!mounted) return;
    _pushMassTiles();
    await _controller.setContent(
      tracks: widget.tracks,
      waypoints: widget.waypoints,
      start: widget.start,
      end: widget.end,
    );
    if (!mounted) return;
    await _controller.attachStyle(style);
    if (!mounted) return;
    // Un changement de fond repose les couches : le halo repart du point voulu.
    final PdlWaypointFocus? focus = widget.focusedWaypoint;
    if (focus != null) await _controller.setWaypointFocus(focus.key);
    if (!mounted) return;
    // **Le premier cadrage part d'ici** : c'est le premier moment où la vue
    // native a une taille et un style. Plus de `Future.delayed`. Les suivants
    // partent de `didUpdateWidget`, quand la donnée arrive.
    await _fit();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Relevé ici parce que `context.size` est interdit pendant un build,
        // et que c'est justement là que `_fit` s'exécute.
        if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
          _lastSize = constraints.biggest;
        }
        return _buildMap(context);
      },
    );
  }

  Widget _buildMap(BuildContext context) {
    final PdlMapPoint? center = widget.initialCenter;

    return MapLibreMap(
      options: MapOptions(
        initCenter: center == null
            ? null
            : Geographic(lon: center.lon, lat: center.lat),
        initZoom: widget.initialZoom,
        initStyle: widget.styleUrl,
        gestures:
            widget.gestures ??
            (widget.interactive
                ? const MapGestures.all()
                : const MapGestures.none()),
      ),
      onMapCreated: _controller.attachMap,
      onEvent: _onEvent,
      children: <Widget>[
        if (widget.kmMarkers.isNotEmpty)
          WidgetLayer(
            markers: <Marker>[
              for (final PdlKmMarker m in widget.kmMarkers)
                Marker(
                  point: Geographic(lon: m.lon, lat: m.lat),
                  size: const Size(30, 30),
                  child: _KmBadge(label: m.label),
                ),
            ],
          ),
        if (widget.markers.isNotEmpty)
          // Une couche à part des bornes : celle-ci reçoit les touchers
          // (`allowInteraction`), les bornes, elles, laissent tout passer.
          // Hors des marqueurs, le pan va toujours à la carte.
          WidgetLayer(
            allowInteraction: widget.onMarkerTapped != null,
            markers: <Marker>[
              for (final PdlMapMarker m in widget.markers)
                Marker(
                  point: Geographic(lon: m.lon, lat: m.lat),
                  size: m.targetSize,
                  alignment: m.alignment,
                  // Le marqueur reste droit quand la carte tourne : son
                  // contenu reçoit le cap, pour qu'une direction absolue
                  // (une flèche de vent) le retranche.
                  child: Builder(
                    builder: (BuildContext context) => PdlMapBearing(
                      bearing: MapCamera.maybeOf(context)?.bearing ?? 0,
                      child: PdlMapMarkerTarget(
                        marker: m,
                        onTap: widget.onMarkerTapped == null
                            ? null
                            : () => widget.onMarkerTapped!(m.id),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ...widget.overlays,
        // En dernier : le crédit se lit par-dessus les voiles et les commandes
        // que l'écran ajoute, jamais dessous.
        PdlMapAttribution(credit: widget.credit),
      ],
    );
  }
}

/// Borne kilométrique — pastille **opaque**, jamais du texte nu sur la tuile.
class _KmBadge extends StatelessWidget {
  const _KmBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.overlaySolid,
        shape: BoxShape.circle,
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: context.pdlText.mono.copyWith(color: c.text),
        ),
      ),
    );
  }
}
