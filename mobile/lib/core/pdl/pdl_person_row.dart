import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';
import 'pdl_avatar.dart';

/// B10 — Ligne de personne : avatar 40, nom, sous-titre, badge de rôle.
///
/// Minimum 56 px, filet bas optionnel.
///
/// **[organizerFlag] : `false` ⇒ rien n'est rendu.** La pastille
/// « Organisateur » est *conditionnelle*, parce que la plupart des groupes
/// n'ont pas de meneur désigné. L'appelant l'alimente en comparant
/// l'identifiant du meneur du groupe (`RideGroupDto.leader`, livré en 1.5.0) à
/// celui de la personne rendue — `core/pdl` ne connaît aucun DTO, il reçoit un
/// `bool` déjà calculé.
///
/// **Jamais de repli sur `createdBy`.** Le créateur de la sortie est le même
/// pour *tous* ses groupes : l'utiliser afficherait un organisateur faux dans
/// neuf groupes sur dix. C'est précisément le défaut que la colonne `leader`
/// corrige.
class PdlPersonRow extends StatelessWidget {
  const PdlPersonRow({
    super.key,
    required this.name,
    this.imageUrl,
    this.isCurrentUser = false,
    this.subtitle,
    this.roleBadge,
    this.trailing,
    this.organizerFlag = false,
    this.organizerLabel,
    this.onTap,
    this.showDivider = false,
    this.avatarSize = 40,
  }) : assert(
         !organizerFlag || organizerLabel != null,
         'le libellé « Organisateur » appartient à l\'écran, pas à core/pdl',
       );

  final String name;
  final String? imageUrl;
  final bool isCurrentUser;

  /// Deuxième ligne — équipe, dernière participation, adresse.
  final String? subtitle;

  /// Badge de rôle (`PdlBadge`), aligné à droite du nom.
  final Widget? roleBadge;

  /// Fin de ligne — bouton, chevron, compteur.
  final Widget? trailing;

  /// Vrai **uniquement** quand cette personne est le meneur désigné du groupe
  /// rendu. Faux ⇒ aucune mention n'apparaît.
  final bool organizerFlag;

  /// Libellé de la mention, fourni par l'écran (« Organisateur du groupe »).
  final String? organizerLabel;

  final VoidCallback? onTap;
  final bool showDivider;
  final double avatarSize;

  /// Hauteur minimale imposée par la charte.
  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          PdlAvatar(
            name: name,
            imageUrl: imageUrl,
            isCurrentUser: isCurrentUser,
            size: avatarSize,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong,
                      ),
                    ),
                    if (roleBadge != null) ...<Widget>[
                      const SizedBox(width: 8),
                      roleBadge!,
                    ],
                  ],
                ),
                if (organizerFlag) ...<Widget>[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(PdlIcons.admin, size: 12, color: c.textDimmed),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          organizerLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.xs,
                        ),
                      ),
                    ],
                  ),
                ],
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.xs,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            trailing!,
          ],
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
