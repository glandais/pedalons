import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../widgets/authenticated_image.dart';
import 'pdl_skeleton.dart';

/// B5 — Vignette carrée : miniature de parcours, image d'annonce, pièce
/// jointe.
///
/// Carré de 56 / 64 / 80 ([PdlMetrics.thumbSm], `thumbMd`, `thumbLg`), rayon 8,
/// bordure `borderSubtle`, repli sur une icône de parcours.
///
/// **Le choix clair/sombre se fait sur `Theme.of(context).brightness`, jamais
/// sur la luminosité de la plateforme.** Les miniatures GPX sont rendues côté
/// serveur en deux versions ; une app forcée en sombre alors que le système
/// est clair afficherait sinon une vignette blanche au milieu d'une liste
/// noire (c'est exactement le défaut corrigé par F-TH-8).
class PdlThumb extends StatelessWidget {
  const PdlThumb({
    super.key,
    this.imageUrl,
    this.darkImageUrl,
    this.size = PdlMetrics.thumbLg,
    this.fallbackIcon = PdlIcons.route,
    this.onTap,
    this.semanticLabel,
  });

  /// Miniature du mode clair — et seule miniature quand [darkImageUrl] est nul.
  final String? imageUrl;

  /// Miniature du mode sombre.
  final String? darkImageUrl;

  final double size;
  final IconData fallbackIcon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String? url = (dark ? darkImageUrl : imageUrl) ?? imageUrl;

    final Widget fallback = ColoredBox(
      color: c.surfaceAlt,
      child: Center(
        child: Icon(fallbackIcon, size: size * 0.4, color: c.textPlaceholder),
      ),
    );

    Widget content = url == null
        ? fallback
        : AuthenticatedImage(
            imageUrl: url,
            size: (size * 3).round(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: PdlSkeleton(width: size, height: size),
            errorWidget: fallback,
          );

    content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: PdlRadii.mdAll,
        border: Border.all(color: c.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (onTap == null) {
      return Semantics(label: semanticLabel, image: true, child: content);
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: PdlRadii.mdAll,
          child: content,
        ),
      ),
    );
  }
}
