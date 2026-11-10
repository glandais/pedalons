import 'package:flutter/material.dart';

import '../theme/pdl_typography.dart';

/// A13 — Titre de section, compteur, action.
///
/// Le compteur (13/500 `textDimmed`) est collé au titre et non aligné à droite :
/// « Participants 40 » se lit d'un bloc, « Participants … 40 » demande un
/// aller-retour du regard. L'action, elle, va à droite — c'est un
/// [PdlButton(variant: text)] dans presque tous les cas.
///
/// Les écrans de détail refondus (ledger `MOB-132`, KIT §8 : « titre à
/// gauche, compte à droite en 12 px gris ») posent [countAtEnd] : le compte
/// passe à droite, en `xs`, avant l'action. [subsection] descend le titre au
/// rang de sous-titre (`cardTitle`, 16/700 : « Météo au départ de 09:00 »).
class PdlSectionHeader extends StatelessWidget {
  const PdlSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.action,
    this.padding = const EdgeInsets.only(bottom: 8),
    this.countAtEnd = false,
    this.subsection = false,
  });

  final String title;

  /// Déjà formaté par l'appelant : `core/pdl` ne connaît ni la locale ni le
  /// pluriel de ce qui est compté.
  final String? count;

  final Widget? action;
  final EdgeInsetsGeometry padding;

  /// Compte aligné à droite, en `xs`, plutôt que collé au titre.
  final bool countAtEnd;

  /// Sous-titre de section : `cardTitle` au lieu de `sectionTitle`.
  final bool subsection;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Titre et compteur prennent toute la place que l'action laisse. Un
          // `Flexible` à côté d'un `Spacer` lui en cédait la moitié, et tronquait
          // « Vos prochaines sorties » sur l'écran le plus large.
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subsection ? t.cardTitle : t.sectionTitle,
                  ),
                ),
                if (count != null && !countAtEnd) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(count!, style: t.count),
                ],
              ],
            ),
          ),
          if (count != null && countAtEnd) ...<Widget>[
            const SizedBox(width: 8),
            Text(count!, style: t.xs),
          ],
          if (action != null && count != null && countAtEnd)
            const SizedBox(width: 8),
          ?action,
        ],
      ),
    );
  }
}
