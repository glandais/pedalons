import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';
import 'pdl_avatar.dart';

/// B3 — Ligne d'appartenance : « *avatar* N-Peloton › ».
///
/// C'est le fil qui relie une carte à son équipe, posé au-dessus du titre.
/// 13/500 `textDimmed`, chevron de 14 px, avatar de 16 px — ou une icône, pour
/// la variante « voyage » où la ligne nomme un voyage et non une équipe.
///
/// **Hauteur minimale 24 px, et c'est un écart assumé aux 44 px du contrat**
/// (`.teamline { min-height: 24px }`). La ligne est un lien inline posé dans
/// une carte dont toute la surface est déjà tappable ; la porter à 44
/// écarterait le titre du bandeau média de 20 px sur chaque carte du fil.
/// [minHeight] permet de la remonter là où elle est seule dans son bloc.
class PdlTeamLine extends StatelessWidget {
  const PdlTeamLine({
    super.key,
    required this.label,
    this.imageUrl,
    this.icon,
    this.onTap,
    this.minHeight = 24,
    this.showChevron = true,
  });

  /// Nom de l'équipe ou du voyage. Sert aussi d'initiale et de teinte d'avatar.
  final String label;

  final String? imageUrl;

  /// Variante « voyage » : une icône de 14 px remplace l'avatar.
  final IconData? icon;

  final VoidCallback? onTap;
  final double minHeight;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget leading = icon != null
        ? Icon(icon, size: 14, color: c.textDimmed)
        : PdlAvatar(name: label, imageUrl: imageUrl, size: 16);

    final Widget content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          leading,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.count,
            ),
          ),
          if (showChevron && onTap != null) ...<Widget>[
            const SizedBox(width: 4),
            Icon(PdlIcons.chevronRight, size: 14, color: c.textDimmed),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: content,
        ),
      ),
    );
  }
}
