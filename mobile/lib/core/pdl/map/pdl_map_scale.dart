import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../theme/pdl_colors.dart';
import '../../theme/pdl_tokens.dart';
import '../../theme/pdl_typography.dart';

/// Une longueur que la barre d'échelle peut représenter : sa valeur au sol,
/// en mètres, et son libellé déjà formaté (« 500 m », « 2 mi »).
@immutable
class PdlMapScaleStep {
  const PdlMapScaleStep(this.meters, this.label);

  final double meters;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is PdlMapScaleStep &&
      other.meters == meters &&
      other.label == label;

  @override
  int get hashCode => Object.hash(meters, label);
}

/// L'échelle d'une [PdlMap] : les longueurs candidates, **croissantes**, dans
/// le système d'unités du lecteur.
///
/// `core/pdl` ne connaît ni `UnitSystem` (un DTO) ni les formateurs : l'écran
/// construit les paliers (`servedMapScale` dans `core/config`) et la barre se
/// contente de choisir le plus long qui tienne.
@immutable
class PdlMapScale {
  const PdlMapScale(this.steps);

  final List<PdlMapScaleStep> steps;

  /// Le palier le plus long dont la barre tient dans [maxWidth] pixels, à
  /// [metersPerPixel] mètres par pixel — le plus court si aucun ne tient.
  /// `null` sans palier ou sans résolution exploitable.
  PdlMapScaleStep? pick(double metersPerPixel, double maxWidth) {
    if (steps.isEmpty || !(metersPerPixel > 0) || !metersPerPixel.isFinite) {
      return null;
    }
    PdlMapScaleStep chosen = steps.first;
    for (final PdlMapScaleStep step in steps) {
      if (step.meters / metersPerPixel > maxWidth) break;
      chosen = step;
    }
    return chosen;
  }

  @override
  bool operator ==(Object other) =>
      other is PdlMapScale && listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hashAll(steps);
}

/// La barre d'échelle, en bas à gauche — le crédit ⓘ tient le coin droit.
///
/// Remplace le `MapScalebar` du paquet, peint en noir sur blanc littéraux :
/// ici la barre suit les jetons de la carte (`overlaySolid`, `text`), donc le
/// mode sombre. Mesurée à la latitude du centre : sur la hauteur d'un écran de
/// téléphone l'écart avec le bas de la carte est négligeable.
class PdlMapScaleBar extends StatelessWidget {
  const PdlMapScaleBar({
    super.key,
    required this.scale,
    this.alignment = Alignment.bottomLeft,
    this.padding = const EdgeInsets.all(PdlSpacing.chipGap),
    this.maxWidth = 100,
  });

  final PdlMapScale scale;
  final Alignment alignment;
  final EdgeInsets padding;

  /// Longueur maximale de la barre, en pixels logiques.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final MapController? controller = MapController.maybeOf(context);
    // Lu pour se reconstruire à chaque mouvement de la caméra
    final MapCamera? camera = MapCamera.maybeOf(context);
    if (controller == null || camera == null) return const SizedBox.shrink();

    final double metersPerPixel = controller.getMetersPerPixelAtLatitude(
      camera.center.lat.toDouble(),
    );
    final PdlMapScaleStep? step = scale.pick(metersPerPixel, maxWidth);
    if (step == null) return const SizedBox.shrink();

    final PdlColors c = context.pdl;
    final BorderSide line = BorderSide(color: c.text, width: 1.5);
    return SafeArea(
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          // Une indication, pas une commande : les gestes passent à la carte.
          child: IgnorePointer(
            child: Container(
              width: step.meters / metersPerPixel,
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.badgeGap,
              ),
              decoration: BoxDecoration(
                color: c.overlaySolid,
                border: Border(left: line, right: line, bottom: line),
              ),
              child: Text(
                step.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: context.pdlText.xs.copyWith(color: c.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
