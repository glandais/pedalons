import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import 'pdl_avatar.dart';
import 'pdl_button.dart';

/// B15 — Avatar de 100 px surmonté de son bouton de modification.
///
/// Le bouton de 44 × 44 **déborde** du disque (`Stack(clipBehavior:
/// Clip.none)`) : posé à l'intérieur, il masquerait le visage qu'il sert à
/// changer. « Supprimer la photo » apparaît sous l'avatar, en `dangerOnSoft`,
/// et **seulement quand il y a une photo à supprimer**.
///
/// **La sélection d'image n'est pas faite ici.** `image_picker` demande une
/// permission, produit des erreurs à traduire et dépend de la plateforme :
/// tout cela appartient à l'écran, qui l'exécute dans [onPick]. `core/pdl`
/// n'effectue aucune entrée-sortie — c'est le même partage que pour les
/// libellés.
class PdlAvatarEditor extends StatelessWidget {
  const PdlAvatarEditor({
    super.key,
    required this.name,
    this.imageUrl,
    required this.onPick,
    required this.pickSemanticLabel,
    this.onRemove,
    this.removeLabel,
    this.size = 100,
    this.busy = false,
  }) : assert(
         onRemove == null || removeLabel != null,
         'le libellé de suppression appartient à l\'écran',
       );

  final String name;
  final String? imageUrl;

  /// Ouvre le sélecteur d'image — implémenté par l'écran.
  final VoidCallback? onPick;

  final String pickSemanticLabel;

  /// `null` masque l'action : il n'y a pas de photo à retirer.
  final VoidCallback? onRemove;

  final String? removeLabel;

  final double size;

  /// Envoi en cours : l'avatar s'estompe et les actions sont coupées.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          // Sans `Clip.none`, le bouton posé en débord serait rogné par la
          // boîte de l'avatar.
          clipBehavior: Clip.none,
          children: <Widget>[
            Opacity(
              opacity: busy ? 0.5 : 1,
              child: PdlAvatar(
                name: name,
                imageUrl: imageUrl,
                size: size,
                isCurrentUser: true,
              ),
            ),
            Positioned(
              right: -6,
              bottom: -6,
              child: Material(
                color: c.surface,
                shape: CircleBorder(side: BorderSide(color: c.border)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: busy ? null : onPick,
                  customBorder: const CircleBorder(),
                  child: Tooltip(
                    message: pickSemanticLabel,
                    child: SizedBox(
                      width: PdlMetrics.tapTarget,
                      height: PdlMetrics.tapTarget,
                      child: Semantics(
                        button: true,
                        label: pickSemanticLabel,
                        child: Icon(PdlIcons.camera, size: 20, color: c.text),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (onRemove != null) ...<Widget>[
          const SizedBox(height: 12),
          PdlButton(
            label: removeLabel!,
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            icon: PdlIcons.delete,
            onPressed: busy ? null : onRemove,
          ),
        ],
      ],
    );
  }
}
