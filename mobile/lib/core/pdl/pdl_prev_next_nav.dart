import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Un voisin : sa mention (« Publication précédente ») et son titre.
///
/// Les deux chaînes arrivent traduites : `core/pdl` ne traduit rien.
@immutable
class PdlPrevNextTarget {
  const PdlPrevNextTarget({
    required this.caption,
    required this.title,
    required this.onTap,
  });

  final String caption;
  final String title;
  final VoidCallback onTap;
}

/// C10 — La navigation vers le voisin précédent et le voisin suivant.
///
/// Deux blocs de 64 px séparés par des filets, **le bloc « suivant » inversé** :
/// son texte est aligné à droite et son chevron passe après, parce qu'un
/// utilisateur qui va vers l'avant lit vers la droite.
///
/// Chaque bloc n'est rendu **que si son voisin existe**. Ouvert par un lien
/// froid, un écran n'a pas de voisins et le composant entier disparaît — sans
/// laisser l'espace vide d'un bloc désactivé, qui donnerait à croire à un
/// chargement en cours.
class PdlPrevNextNav extends StatelessWidget {
  const PdlPrevNextNav({super.key, this.previous, this.next});

  final PdlPrevNextTarget? previous;
  final PdlPrevNextTarget? next;

  bool get isEmpty => previous == null && next == null;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final PdlColors c = context.pdl;

    Widget rule() => Container(height: 1, color: c.borderSubtle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        rule(),
        if (previous != null) ...<Widget>[
          _Block(target: previous!, forward: false),
          rule(),
        ],
        if (next != null) ...<Widget>[
          _Block(target: next!, forward: true),
          rule(),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.target, required this.forward});

  final PdlPrevNextTarget target;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget chevron = Icon(
      forward ? PdlIcons.chevronRight : PdlIcons.chevronLeft,
      size: 20,
      color: c.textDimmed,
    );

    final Widget text = Column(
      crossAxisAlignment: forward
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(target.caption, style: t.xs),
        Text(
          target.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: forward ? TextAlign.right : TextAlign.left,
          style: t.bodyStrong,
        ),
      ],
    );

    return Semantics(
      button: true,
      label: '${target.caption} : ${target.title}',
      child: InkWell(
        onTap: target.onTap,
        child: ConstrainedBox(
          // 64 px de plancher, jamais de plafond : deux lignes agrandies à
          // 130 % ne se font pas rogner.
          constraints: const BoxConstraints(minHeight: PdlMetrics.stageRail),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                if (!forward) ...<Widget>[
                  chevron,
                  const SizedBox(width: PdlMetrics.toolbarPadding),
                ],
                Expanded(child: text),
                if (forward) ...<Widget>[
                  const SizedBox(width: PdlMetrics.toolbarPadding),
                  chevron,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
