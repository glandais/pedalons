import 'package:flutter/material.dart';

import '../../theme/pdl_colors.dart';
import '../../theme/pdl_icons.dart';
import '../../theme/pdl_tokens.dart';
import '../../theme/pdl_typography.dart';
import '../pdl_button.dart';
import '../pdl_skeleton.dart';
import 'elevation_area_painter.dart';
import 'elevation_band_painter.dart';
import 'elevation_cursor_painter.dart';
import 'elevation_markers_painter.dart';
import 'elevation_samples.dart';

/// Le libellé d'une graduation de l'axe.
///
/// [isLast] marque la dernière, **seule suffixée de l'unité** :
/// « 0,0 · 11,6 · 23,2 · 34,7 · 46,3 km ».
typedef ElevationAxisLabel = String Function(
  double meters, {
  required bool isLast,
});

/// Le libellé de l'info-bulle : « 28,7 km · 74 m · 4,1 % ».
typedef ElevationTipLabel = String Function(ElevationReading reading);

/// Le profil altimétrique : une aire remplie colorisée par pente, un réticule et
/// une info-bulle.
///
/// **Peinture maison, deux couches** (§1.3.1 du plan), plus la bande de
/// [bandColors] et son réticule quand l'écran en passe une (`MOB-106`). Le painter du bas ne
/// dépend que des données et n'est jamais rappelé pendant un glissement ; le
/// painter du haut écoute un `ValueListenable<double?>` et ne dessine que le
/// trait et la bulle. Chacun est isolé dans son `RepaintBoundary`, sans quoi
/// la peinture du réticule remonterait jusqu'à la première frontière commune
/// et redescendrait repeindre l'aire.
///
/// **`cursorDistance` n'est pas un provider.** C'est un `ValueNotifier` qui vit
/// dans le `State` de l'écran, partagé tel quel avec la carte : on ne
/// reconstruit pas un arbre Riverpod à 60 fps. Le laisser nul fait vivre le
/// réticule en interne, ce qui suffit à un profil qui n'est synchronisé avec
/// rien.
///
/// `core/pdl` ne formate ni ne traduit : [axisLabel] et [tipLabel] rendent les
/// valeurs dans l'unité choisie, et les libellés d'état sont des `String`.
class PdlElevationProfile extends StatefulWidget {
  /// Le profil chargé.
  const PdlElevationProfile({
    super.key,
    required ElevationSamples this.samples,
    required ElevationAxisLabel this.axisLabel,
    required ElevationTipLabel this.tipLabel,
    this.height = PdlMetrics.elevationMedium,
    this.cursorDistance,
    this.onCursorChanged,
    this.credit,
    this.barColors,
    this.bandColors,
    this.bandHeight = PdlMetrics.elevationBand,
    this.markers = const <PdlProfileMarker>[],
    this.selectedMarkerKey,
    this.onMarkerTapped,
  }) : _mode = _ElevationMode.data,
       label = null,
       actionLabel = null,
       onRetry = null;

  /// En cours de chargement : un squelette de la hauteur cible et un libellé.
  ///
  /// **Le titre et les trois statistiques de l'écran s'affichent avant** : le
  /// profil est un enrichissement, il ne retient pas le reste de la page.
  const PdlElevationProfile.loading({
    super.key,
    required String this.label,
    this.height = PdlMetrics.elevationMedium,
  }) : _mode = _ElevationMode.loading,
       samples = null,
       axisLabel = null,
       tipLabel = null,
       cursorDistance = null,
       onCursorChanged = null,
       credit = null,
       barColors = null,
       bandColors = null,
       bandHeight = PdlMetrics.elevationBand,
       markers = const <PdlProfileMarker>[],
       selectedMarkerKey = null,
       onMarkerTapped = null,
       actionLabel = null,
       onRetry = null;

  /// Échec du **seul** profil : une ligne discrète et un « Réessayer ».
  ///
  /// Jamais un écran d'erreur global — la fiche du parcours reste lisible sans
  /// son profil.
  const PdlElevationProfile.failed({
    super.key,
    required String this.label,
    required String this.actionLabel,
    this.onRetry,
    this.height = PdlMetrics.elevationMedium,
  }) : _mode = _ElevationMode.failed,
       samples = null,
       axisLabel = null,
       tipLabel = null,
       cursorDistance = null,
       onCursorChanged = null,
       barColors = null,
       bandColors = null,
       bandHeight = PdlMetrics.elevationBand,
       markers = const <PdlProfileMarker>[],
       selectedMarkerKey = null,
       onMarkerTapped = null,
       credit = null;

  final _ElevationMode _mode;

  final ElevationSamples? samples;

  /// [PdlMetrics.elevationCompact] · [PdlMetrics.elevationMedium] ·
  /// [PdlMetrics.elevationLarge].
  final double height;

  final ElevationAxisLabel? axisLabel;
  final ElevationTipLabel? tipLabel;

  /// Distance survolée, en mètres — **le seul état partagé avec la carte**.
  final ValueNotifier<double?>? cursorDistance;

  /// Notifié à chaque déplacement du réticule, y compris son effacement.
  final ValueChanged<double?>? onCursorChanged;

  /// La source des altitudes, **déjà localisée**, sous les graduations — une
  /// licence peut exiger de la nommer (Licence Ouverte de l'IGN,
  /// docs/LEDGER_*.md LEGAL-18). Nulle : rien.
  final String? credit;

  /// Une couleur par barre de [samples] (autant que `samples.bars`), à la
  /// place de l'échelle de pente : le mode « revêtement » d'une fiche
  /// (`MOB-81`). Une entrée nulle prend la couleur neutre. **Comparée par
  /// identité**, comme [samples] : mémorisez-la.
  final List<Color?>? barColors;

  /// Une bande fine **sous** le graphique, une couleur par barre de
  /// [samples], sur le même axe des distances, que le réticule traverse : le
  /// vent relatif en mode Météo (ledger `MOB-106`). Nulle ou vide : pas de
  /// bande. **Comparée par identité** : mémorisez-la.
  final List<Color>? bandColors;

  /// Hauteur de la bande — [PdlMetrics.elevationBand].
  final double bandHeight;

  bool get _hasBand => bandColors?.isNotEmpty ?? false;

  /// Les repères des points de parcours sur le tracé (ledger `MOB-84`). Comparés
  /// par valeur : une liste neuve à chaque `build` ne repeint pas.
  final List<PdlProfileMarker> markers;

  /// Le repère allumé (trait plein, pictogramme agrandi).
  final String? selectedMarkerKey;

  /// Toucher d'un repère, dans la bande haute du graphique. Le réticule ne
  /// bouge pas ; ailleurs, le toucher le déplace comme avant.
  final ValueChanged<String>? onMarkerTapped;

  /// Libellé de chargement ou d'échec.
  final String? label;

  /// Libellé de l'action de reprise.
  final String? actionLabel;

  final VoidCallback? onRetry;

  @override
  State<PdlElevationProfile> createState() => _PdlElevationProfileState();
}

enum _ElevationMode { data, loading, failed }

class _PdlElevationProfileState extends State<PdlElevationProfile> {
  /// Réticule interne, créé **paresseusement** : quand l'écran fournit le sien,
  /// il n'y a pas de second notifieur à tenir à jour.
  ValueNotifier<double?>? _own;

  ValueNotifier<double?> get _cursor =>
      widget.cursorDistance ?? (_own ??= ValueNotifier<double?>(null));

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _setCursor(double? distance) {
    if (_cursor.value == distance) return;
    _cursor.value = distance;
    widget.onCursorChanged?.call(distance);
  }

  /// La boîte du graphique, dont la géométrie sert à convertir un pointeur
  /// en distance.
  ///
  /// Le repère vient de la boîte elle-même et non d'un `LayoutBuilder` : un
  /// `LayoutBuilder` prend la **plus grande** taille autorisée, et le profil
  /// occuperait alors toute la hauteur disponible.
  final GlobalKey _chartKey = GlobalKey();

  /// Traduit une position en distance cumulée.
  ///
  /// Hors de la boîte — sur l'axe, dans la marge — le réticule s'efface :
  /// c'est « effacement au tap hors profil ».
  void _handlePointer(Offset globalPosition) {
    final RenderObject? object = _chartKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return;

    final Offset local = object.globalToLocal(globalPosition);
    final Size size = object.size;
    // La bande, sous le graphique, déplace le réticule comme lui.
    final double bottom = widget._hasBand
        ? size.height + PdlMetrics.elevationBandGap + widget.bandHeight
        : size.height;
    if (local.dy < 0 || local.dy > bottom) {
      _setCursor(null);
      return;
    }

    final ElevationSamples samples = widget.samples!;
    if (size.width <= 0 || samples.isEmpty) return;
    final double t = (local.dx / size.width).clamp(0.0, 1.0);
    _setCursor(t * samples.totalDistance);
  }

  /// Un toucher sur un repère l'ouvre au lieu de déplacer le réticule.
  bool _tapMarker(Offset globalPosition) {
    final ValueChanged<String>? onTap = widget.onMarkerTapped;
    if (onTap == null || widget.markers.isEmpty) return false;
    final RenderObject? object = _chartKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return false;
    final String? key = ElevationMarkersPainter.markerAt(
      widget.markers,
      widget.samples!.totalDistance,
      object.size.width,
      object.globalToLocal(globalPosition),
    );
    if (key == null) return false;
    onTap(key);
    return true;
  }

  @override
  Widget build(BuildContext context) => switch (widget._mode) {
    _ElevationMode.loading => _buildLoading(context),
    _ElevationMode.failed => _buildFailed(context),
    _ElevationMode.data => _buildData(context),
  };

  Widget _buildLoading(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      PdlSkeleton(height: widget.height, borderRadius: PdlRadii.mdAll),
      const SizedBox(height: 6),
      Text(widget.label!, style: context.pdlText.xs),
    ],
  );

  Widget _buildFailed(BuildContext context) {
    final PdlColors c = context.pdl;
    return Row(
      children: <Widget>[
        Icon(PdlIcons.warning, size: 16, color: c.textDimmed),
        const SizedBox(width: 6),
        Flexible(child: Text(widget.label!, style: context.pdlText.xs)),
        const SizedBox(width: 4),
        PdlButton(
          label: widget.actionLabel!,
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          icon: PdlIcons.refresh,
          onPressed: widget.onRetry,
        ),
      ],
    );
  }

  Widget _buildData(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final ElevationSamples samples = widget.samples!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails d) {
        if (!_tapMarker(d.globalPosition)) _handlePointer(d.globalPosition);
      },
      onHorizontalDragStart: (DragStartDetails d) =>
          _handlePointer(d.globalPosition),
      onHorizontalDragUpdate: (DragUpdateDetails d) =>
          _handlePointer(d.globalPosition),
      // `onHorizontalDragEnd` n'efface rien : le réticule est **persistant
      // après le relâchement**, c'est lui qui garde le marqueur de la carte
      // en place.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: PdlRadii.mdAll,
            child: SizedBox(
              key: _chartKey,
              height: widget.height,
              child: ColoredBox(
                color: c.surfaceAlt,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    RepaintBoundary(
                      child: CustomPaint(
                        isComplex: true,
                        willChange: false,
                        painter: ElevationAreaPainter(
                          samples: samples,
                          neutralColor: slopeNeutral,
                          slopeColorOf: slopeColor,
                          barColors: widget.barColors,
                        ),
                      ),
                    ),
                    if (widget.markers.isNotEmpty)
                      // Exclus de la sémantique : la liste des points est le
                      // chemin accessible.
                      ExcludeSemantics(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: ElevationMarkersPainter(
                              samples: samples,
                              markers: widget.markers,
                              selectedKey: widget.selectedMarkerKey,
                              ring: c.mapWaypointRing,
                            ),
                          ),
                        ),
                      ),
                    RepaintBoundary(
                      child: CustomPaint(
                        willChange: true,
                        painter: ElevationCursorPainter(
                          samples: samples,
                          distance: _cursor,
                          repaint: _cursor,
                          lineColor: c.text.withValues(alpha: 0.7),
                          tipBackground: c.overlaySolid,
                          tipBorder: c.borderSubtle,
                          tipTextStyle: t.monoAxis.copyWith(color: c.text),
                          textScaler: MediaQuery.textScalerOf(context),
                          label: widget.tipLabel!,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget._hasBand)
            // Visuelle seulement : l'info-bulle écrit ce que la bande montre.
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: PdlMetrics.elevationBandGap,
                ),
                child: SizedBox(
                  height: widget.bandHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      RepaintBoundary(
                        child: CustomPaint(
                          willChange: false,
                          painter: ElevationBandPainter(
                            samples: samples,
                            colors: widget.bandColors!,
                          ),
                        ),
                      ),
                      RepaintBoundary(
                        child: CustomPaint(
                          willChange: true,
                          painter: ElevationBandCursorPainter(
                            samples: samples,
                            distance: _cursor,
                            repaint: _cursor,
                            lineColor: c.text.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (int i = 0; i < _axisTicks; i++)
                  Text(
                    widget.axisLabel!(
                      samples.totalDistance * i / (_axisTicks - 1),
                      isLast: i == _axisTicks - 1,
                    ),
                    style: t.monoAxis,
                  ),
              ],
            ),
          ),
          if (widget.credit case final String credit)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                credit,
                textAlign: TextAlign.end,
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ),
        ],
      ),
    );
  }

  /// Cinq graduations, aux quarts de la distance.
  static const int _axisTicks = 5;
}
