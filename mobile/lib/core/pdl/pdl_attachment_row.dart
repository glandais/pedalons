import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_thumb.dart';

/// B11 — Ligne de pièce jointe : icône ou vignette, nom, type, action.
///
/// **Le libellé d'accessibilité du bouton nomme le fichier.** « Télécharger »
/// répété douze fois dans un lecteur d'écran ne permet pas de choisir ; c'est
/// [actionSemanticLabel] qui porte « Télécharger parcours-vosges.gpx », fourni
/// par l'écran.
///
/// Le type est rendu en `mono` capitales — « GPX », « PDF » : une valeur
/// technique, pas un mot de la langue.
class PdlAttachmentRow extends StatelessWidget {
  const PdlAttachmentRow({
    super.key,
    required this.name,
    this.type,
    this.subtitle,
    this.thumbnailUrl,
    this.icon = PdlIcons.attachment,
    this.actionIcon = PdlIcons.gpx,
    this.onAction,
    required this.actionSemanticLabel,
    this.onTap,
    this.showDivider = false,
  });

  final String name;

  /// Extension ou type, rendu en `mono` capitales.
  final String? type;

  /// Poids, date — ce qui aide à choisir sans ouvrir.
  final String? subtitle;

  /// Aperçu : rend un [PdlThumb] de 56 à la place de l'icône.
  final String? thumbnailUrl;

  final IconData icon;
  final IconData actionIcon;
  final VoidCallback? onAction;

  /// Libellé d'accessibilité **nommant le fichier**.
  final String actionSemanticLabel;

  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget leading = thumbnailUrl != null
        ? PdlThumb(
            imageUrl: thumbnailUrl,
            size: PdlMetrics.thumbSm,
            fallbackIcon: icon,
          )
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: PdlRadii.mdAll,
            ),
            child: Icon(icon, size: 20, color: c.textDimmed),
          );

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong,
                ),
                if (type != null || subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      if (type != null)
                        Text(type!.toUpperCase(), style: t.mono),
                      if (type != null && subtitle != null)
                        Text(' · ', style: t.mono),
                      if (subtitle != null)
                        Flexible(
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.xs,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null) ...<Widget>[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onAction,
              icon: Icon(actionIcon, size: 20, color: c.text),
              tooltip: actionSemanticLabel,
              constraints: const BoxConstraints.tightFor(
                width: PdlMetrics.tapTarget,
                height: PdlMetrics.tapTarget,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );

    final Widget body = onTap == null
        ? content
        : Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, child: content),
          );

    if (!showDivider) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: body,
    );
  }
}
