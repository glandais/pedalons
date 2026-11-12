import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../widgets/authenticated_image.dart';
import 'pdl_skeleton.dart';

/// Les cinq dégradés de repli, un par famille de contenu (§1.1.5).
///
/// Ils sont **identiques dans les deux modes** : ils portent une icône blanche
/// à 80 %, et une version sombre les rendrait ternes sans rien gagner en
/// contraste.
enum PdlMediaTone { ride, post, trip, team, ad }

/// B6 — Bandeau média en tête de carte.
///
/// Une photo quand il y en a une ; sinon **un dégradé sémantique portant
/// l'icône du type**. C'est ce qui distingue une carte sans image d'une carte
/// cassée : le bandeau dit toujours de quoi il s'agit.
///
/// Hauteurs de la charte : 120 ([PdlMetrics.media120]), 140, 160
/// ([PdlMetrics.media]), 208 ([PdlMetrics.media16x9]).
class PdlCardMedia extends StatelessWidget {
  const PdlCardMedia({
    super.key,
    required this.tone,
    this.imageUrl,
    this.height = PdlMetrics.media,
    this.icon,
    this.overlay,
    this.borderRadius,
    this.semanticLabel,
  });

  final PdlMediaTone tone;

  /// Photo de couverture. Absente, le dégradé prend sa place.
  final String? imageUrl;

  final double height;

  /// Icône de repli, rendue à 48 px. À défaut, celle du [tone].
  final IconData? icon;

  /// Contenu posé par-dessus — badges, voile, titre. Empilé, non contraint.
  final Widget? overlay;

  final BorderRadius? borderRadius;
  final String? semanticLabel;

  LinearGradient get _gradient => switch (tone) {
    PdlMediaTone.ride => PdlGradients.ride,
    PdlMediaTone.post => PdlGradients.post,
    PdlMediaTone.trip => PdlGradients.trip,
    PdlMediaTone.team => PdlGradients.team,
    PdlMediaTone.ad => PdlGradients.ad,
  };

  IconData get _icon =>
      icon ??
      switch (tone) {
        PdlMediaTone.ride => PdlIcons.ride,
        PdlMediaTone.post => PdlIcons.post,
        PdlMediaTone.trip => PdlIcons.trip,
        PdlMediaTone.team => PdlIcons.team,
        PdlMediaTone.ad => PdlIcons.ad,
      };

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    final Widget fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: _gradient),
      child: Center(
        child: Icon(
          _icon,
          size: 48,
          // `.m-ico { opacity: .8 }` — blanc à 80 % sur le dégradé, dans les
          // deux modes.
          color: c.onPrimary.withValues(alpha: 0.8),
        ),
      ),
    );

    final Widget media = imageUrl == null
        ? fallback
        : AuthenticatedImage(
            imageUrl: imageUrl!,
            size: 1080,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            placeholder: PdlSkeleton(width: double.infinity, height: height),
            errorWidget: fallback,
          );

    final Widget body = SizedBox(
      height: height,
      width: double.infinity,
      child: overlay == null
          ? media
          : Stack(fit: StackFit.expand, children: <Widget>[media, overlay!]),
    );

    return Semantics(
      label: semanticLabel,
      image: true,
      child: borderRadius == null
          ? body
          : ClipRRect(borderRadius: borderRadius!, child: body),
    );
  }
}
