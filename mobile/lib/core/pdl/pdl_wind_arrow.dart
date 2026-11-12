import 'dart:math' as math;

import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';

/// La flèche de vent : une flèche pleine, dessinée **vers le haut** puis
/// tournée de [angle] degrés dans le sens horaire.
///
/// Le composant ne sait rien de ce que l'angle désigne — c'est l'appelant qui
/// le choisit :
///
/// * vent **relatif** au sens de marche : l'angle reçu tel quel (0 = le vent
///   pousse, 180 = il vient de face) ; le haut est alors « devant » ;
/// * vent **absolu** : la direction *vers* laquelle il souffle, nord en haut
///   (la direction d'où il vient + 180).
///
/// Jamais seule à porter l'information : la charte la double toujours d'un
/// libellé (« Vent de face »), ce qui est aussi pourquoi [semanticLabel] est
/// facultatif — la ligne qui l'entoure le dit déjà.
class PdlWindArrow extends StatelessWidget {
  const PdlWindArrow({
    super.key,
    required this.angle,
    this.color,
    this.size = PdlMetrics.windArrow,
    this.semanticLabel,
  });

  /// Degrés, sens horaire, 0 = vers le haut.
  final double angle;

  /// Teinte imposée — celle du vent relatif, d'ordinaire ; `textDimmed`
  /// sinon.
  final Color? color;

  final double size;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget arrow = Transform.rotate(
      angle: angle * math.pi / 180,
      child: Icon(
        PdlIcons.windArrow,
        size: size,
        color: color ?? context.pdl.textDimmed,
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: arrow);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(child: arrow),
    );
  }
}
