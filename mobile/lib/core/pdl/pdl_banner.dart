import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Les trois niveaux d'un bandeau. Ils ne disent pas la même chose : `info`
/// renseigne, `warn` prévient d'une limite, `danger` annonce un échec.
enum PdlBannerTone { info, warn, danger }

/// B8 — Bandeau **persistant**.
///
/// **Jamais un snackbar de 4 secondes.** Un échec d'inscription, une équipe à
/// rejoindre, un mode hors ligne : ce sont des états, pas des événements. Ils
/// restent à l'écran tant qu'ils sont vrais, dans le flux, à l'endroit qu'ils
/// concernent.
///
/// Le titre est en gras **dans le flux du texte** (`<b>Inscription
/// impossible.</b> Vous êtes déjà inscrit…`), et non sur une ligne à part : la
/// phrase se lit d'une traite.
///
/// [fullBleed] supprime le rayon et les bordures latérales, pour un bandeau
/// posé bord à bord sous une barre.
class PdlBanner extends StatelessWidget {
  const PdlBanner({
    super.key,
    required this.tone,
    required this.message,
    this.title,
    this.icon,
    this.action,
    this.fullBleed = false,
    this.onDismiss,
    this.dismissSemanticLabel,
  });

  final PdlBannerTone tone;

  /// Corps du message.
  final String message;

  /// Amorce en gras, collée devant [message].
  final String? title;

  final IconData? icon;

  /// Action optionnelle, rendue sous le texte — un `PdlButton(text)` en
  /// général.
  final Widget? action;

  final bool fullBleed;

  /// Renvoie une croix de fermeture. **À réserver aux bandeaux dont l'état
  /// n'est pas vérifiable** : un bandeau qu'on peut fermer alors que la cause
  /// persiste ment.
  final VoidCallback? onDismiss;

  final String? dismissSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    // Les paires de la charte. `warn` emprunte la paire `warning` du §1.1.3 et
    // non l'orange `#fff4e6` de la planche : les deux se valent en clair, mais
    // seule la paire sémantique est définie dans les deux modes.
    final (Color background, Color foreground) = switch (tone) {
      PdlBannerTone.info => (c.primarySoft, c.primaryOnSoft),
      PdlBannerTone.warn => (c.warningSoft, c.warningOnSoft),
      PdlBannerTone.danger => (c.dangerSoft, c.dangerOnSoft),
    };

    final IconData shownIcon =
        icon ??
        switch (tone) {
          PdlBannerTone.info => PdlIcons.info,
          PdlBannerTone.warn => PdlIcons.warning,
          PdlBannerTone.danger => PdlIcons.error,
        };

    final TextStyle body = t.sub.copyWith(color: foreground);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: fullBleed ? null : PdlRadii.mdAll,
        border: Border(
          top: BorderSide(color: foreground.withValues(alpha: 0.25)),
          bottom: BorderSide(color: foreground.withValues(alpha: 0.25)),
          left: fullBleed
              ? BorderSide.none
              : BorderSide(color: foreground.withValues(alpha: 0.25)),
          right: fullBleed
              ? BorderSide.none
              : BorderSide(color: foreground.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(shownIcon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      if (title != null)
                        TextSpan(
                          text: '$title ',
                          style: body.copyWith(fontWeight: FontWeight.w700),
                        ),
                      TextSpan(text: message),
                    ],
                  ),
                  style: body,
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: 4),
                  action!,
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(PdlIcons.close, size: 18, color: foreground),
              tooltip: dismissSemanticLabel,
              constraints: const BoxConstraints.tightFor(
                width: PdlMetrics.tapTarget,
                height: PdlMetrics.tapTarget,
              ),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
