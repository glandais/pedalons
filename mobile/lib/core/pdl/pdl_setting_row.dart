import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';

/// A17 — Ligne de réglage ou de navigation.
///
/// **52 px de haut au minimum, et la ligne entière est la cible.** C'est la
/// règle qui distingue une liste de réglages utilisable d'une liste où il faut
/// viser le chevron : le `InkWell` couvre toute la largeur, y compris le
/// sous-titre.
///
/// [trailing] accueille indifféremment un badge, une valeur textuelle, un
/// [PdlSwitch] ou rien — auquel cas un chevron apparaît dès que [onTap] existe.
/// Quand la ligne porte un interrupteur, laissez [onTap] à `null` et confiez
/// l'action à l'interrupteur : deux cibles concentriques qui font la même chose
/// se contredisent au premier double-tap.
class PdlSettingRow extends StatelessWidget {
  const PdlSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showDivider = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Une image en tête de ligne — le logo d'un service connecté. Elle remplace
  /// [icon] quand les deux sont fournis ; sa taille est celle de l'appelant.
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Titre et icône en `dangerOnSoft` — déconnexion, suppression de compte.
  final bool destructive;

  final bool showDivider;
  final EdgeInsetsGeometry padding;

  /// Hauteur minimale imposée par la charte.
  static const double minHeight = 52;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Color foreground = destructive ? c.dangerOnSoft : c.text;

    final Widget? end =
        trailing ??
        (onTap != null
            ? Icon(PdlIcons.chevronRight, size: 20, color: c.textPlaceholder)
            : null);

    final Widget content = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: 12),
          ] else if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: t.bodyStrong.copyWith(color: foreground)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.sub),
                ],
              ],
            ),
          ),
          if (end != null) ...<Widget>[const SizedBox(width: 12), end],
        ],
      ),
    );

    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: content,
    );

    final Widget body = onTap == null
        ? row
        : Semantics(
            button: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, child: row),
            ),
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
