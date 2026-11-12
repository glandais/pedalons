import 'package:photo_view/photo_view.dart';

import '../material.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';

/// B25 — Visionneuse d'image plein écran.
///
/// Pincement pour zoomer, **balayage vertical pour fermer**, transition [Hero]
/// depuis la vignette. Le balayage vertical est le geste attendu d'une
/// visionneuse ; sans lui, il faut viser une croix de 44 px après avoir zoomé.
///
/// L'image arrive **déjà construite** ([imageProvider] ou [child]) : la
/// visionneuse ne sait pas charger une URL authentifiée, c'est
/// `AuthenticatedImage` qui le fait, et lui vit hors de `core/pdl`.
class PdlImageViewer extends StatefulWidget {
  const PdlImageViewer({
    super.key,
    required this.imageProvider,
    this.heroTag,
    required this.closeSemanticLabel,
    this.caption,
  });

  final ImageProvider imageProvider;

  /// Étiquette [Hero] partagée avec la vignette d'origine.
  final Object? heroTag;

  final String closeSemanticLabel;

  /// Légende posée en bas, sur le voile.
  final Widget? caption;

  /// Ouvre la visionneuse en plein écran, barrière comprise.
  static Future<void> show(
    BuildContext context, {
    required ImageProvider imageProvider,
    required String closeSemanticLabel,
    Object? heroTag,
    Widget? caption,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: null,
        pageBuilder: (BuildContext context, _, _) => PdlImageViewer(
          imageProvider: imageProvider,
          heroTag: heroTag,
          closeSemanticLabel: closeSemanticLabel,
          caption: caption,
        ),
      ),
    );
  }

  @override
  State<PdlImageViewer> createState() => _PdlImageViewerState();
}

class _PdlImageViewerState extends State<PdlImageViewer> {
  /// Décalage vertical accumulé pendant le geste de fermeture.
  double _drag = 0;

  /// Course au-delà de laquelle on lâche la vue.
  static const double _dismissThreshold = 120;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    // Le fond s'éclaircit à mesure qu'on tire : le geste montre son effet
    // avant d'être relâché.
    final double progress = (_drag.abs() / (_dismissThreshold * 2)).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      backgroundColor: c.scrim.withValues(alpha: 1 - progress * 0.6),
      body: GestureDetector(
        onVerticalDragUpdate: (DragUpdateDetails d) =>
            setState(() => _drag += d.delta.dy),
        onVerticalDragEnd: (DragEndDetails _) {
          if (_drag.abs() > _dismissThreshold) {
            Navigator.of(context).pop();
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: PhotoView(
                  imageProvider: widget.imageProvider,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  heroAttributes: widget.heroTag == null
                      ? null
                      : PhotoViewHeroAttributes(tag: widget.heroTag!),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.viewPaddingOf(context).top + 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: widget.closeSemanticLabel,
                icon: Icon(PdlIcons.close, color: c.onPrimary),
                constraints: const BoxConstraints.tightFor(
                  width: PdlMetrics.tapTarget,
                  height: PdlMetrics.tapTarget,
                ),
              ),
            ),
            if (widget.caption != null)
              Positioned(
                left: PdlSpacing.section,
                right: PdlSpacing.section,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
                child: widget.caption!,
              ),
          ],
        ),
      ),
    );
  }
}
