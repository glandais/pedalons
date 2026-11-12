import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';

/// A1 — Rectangle ou cercle scintillant, brique unique des états de chargement.
///
/// Dégradé `neutralSoft → disabledBg → neutralSoft` posé sur une bande quatre
/// fois plus large que la boîte, translatée en 1400 ms (`PdlMotion.shimmer`).
/// C'est la transcription de `.skel` de `pedalons.css` :
/// `background-size: 400% 100%` + `@keyframes sh` de `100% 0` à `0 0`.
///
/// `PdlMotion.reducedOf` coupe l'animation et laisse l'aplat de base :
/// un scintillement perpétuel est exactement ce que « réduire les animations »
/// demande de supprimer.
class PdlSkeleton extends StatefulWidget {
  const PdlSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = PdlRadii.smAll,
    this.child,
  });

  /// Disque — avatars, pastilles.
  const PdlSkeleton.circle({super.key, required double size, this.child})
    : width = size,
      height = size,
      borderRadius = PdlRadii.pillAll;

  /// Ligne de texte : la hauteur par défaut est celle d'une ligne de corps.
  const PdlSkeleton.text({super.key, required this.width, double? height})
    : height = height ?? 14,
      borderRadius = PdlRadii.smAll,
      child = null;

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  /// Gabarit optionnel posé dans le rectangle — sert à emprunter la forme d'un
  /// contenu réel plutôt qu'à afficher quoi que ce soit.
  final Widget? child;

  @override
  State<PdlSkeleton> createState() => _PdlSkeletonState();
}

class _PdlSkeletonState extends State<PdlSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: PdlMotion.shimmer,
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final bool reduceMotion = PdlMotion.reducedOf(context);

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: c.neutralSoft,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const <double>[0.25, 0.5, 0.75],
            colors: <Color>[c.neutralSoft, c.disabledBg, c.neutralSoft],
            transform: _SlidingGradient(_curve.transform(_controller.value)),
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }

  static final Curve _curve = PdlMotion.shimmerCurve;
}

/// Translate le dégradé de +2 largeurs à −2 largeurs : la bande de 400 % de
/// `.skel` traverse la boîte une fois par cycle.
@immutable
class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (1 - 2 * t) * 2, 0, 0);
}
