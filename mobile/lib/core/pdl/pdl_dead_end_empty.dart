import 'package:flutter/material.dart';

import '../animations/animated_empty_state.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_button.dart';

/// B22 — État vide « cul-de-sac » : le filtre ne laisse rien passer, et on
/// aide à en sortir.
///
/// Généralisation de `RoutesEmptyState` — le meilleur état vide de
/// l'application, et le seul qui fasse les quatre choses qui comptent :
///
/// 1. **citer le terme et les filtres littéralement** — « Aucun parcours ne
///    contient *gravel* » vaut mieux que « Aucun résultat » ;
/// 2. proposer de **retirer le filtre le plus étroit**, nommé
///    ([removeFilterLabel] : « Retirer le filtre Distance ») ;
/// 3. proposer « Tout réinitialiser » en second ;
/// 4. **prouver que l'offre vaut la peine** : sous un filet, trois lignes
///    compactes de ce qui reviendrait sans ce filtre.
///
/// L'aperçu est le point qui change tout : sans lui, « retirer le filtre » est
/// un pari. Avec lui, c'est une décision.
///
/// Tous les libellés sont fournis par l'écran, aperçu compris : `core/pdl` ne
/// traduit rien et ne sait pas interroger une liste.
class PdlDeadEndEmpty extends StatelessWidget {
  const PdlDeadEndEmpty({
    super.key,
    required this.title,
    required this.message,
    required this.resetAllLabel,
    required this.onResetAll,
    this.icon = PdlIcons.emptySearch,
    this.resetAllKey,
    this.removeFilterLabel,
    this.onRemoveFilter,
    this.previewTitle,
    this.preview = const <Widget>[],
    this.previewChild,
    this.padding = const EdgeInsets.fromLTRB(24, 40, 24, 16),
  }) : assert(
         removeFilterLabel == null || onRemoveFilter != null,
         'un filtre nommé doit pouvoir être retiré',
       );

  /// Titre nominal — « Aucun parcours ».
  final String title;

  /// Phrase **citant le terme cherché et les filtres actifs**, construite par
  /// l'écran.
  final String message;

  final String resetAllLabel;
  final VoidCallback onResetAll;

  /// La clé du bouton de [resetAllLabel], pour les tests qui le touchent.
  final Key? resetAllKey;

  final IconData icon;

  /// « Retirer le filtre Distance » — le filtre est **nommé**.
  final String? removeFilterLabel;
  final VoidCallback? onRemoveFilter;

  /// « Sans le filtre Distance » — titre du bloc d'aperçu.
  final String? previewTitle;

  /// Trois lignes compactes, pas plus : c'est un argument, pas une liste.
  final List<Widget> preview;

  /// Bloc d'aperçu complet, quand il se construit lui-même (chargement
  /// asynchrone). Prioritaire sur [preview].
  final Widget? previewChild;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final bool hasPreview =
        previewChild != null || (previewTitle != null && preview.isNotEmpty);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: AnimatedEmptyState(
              child: Icon(icon, size: 48, color: c.textPlaceholder),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.cardTitle.copyWith(color: c.text),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: t.sub),
          const SizedBox(height: 20),
          // Les deux actions côte à côte, et non empilées pleine largeur :
          // « Retirer le filtre X » et « Tout réinitialiser » sont deux issues
          // du même choix, et deux boutons pleine largeur superposés se lisent
          // comme une action principale suivie d'un repentir. Le [Wrap] les
          // repasse en colonne dès que l'agrandissement typographique ne leur
          // laisse plus la largeur.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: PdlSpacing.chipGap,
            runSpacing: PdlSpacing.chipGap,
            children: <Widget>[
              if (removeFilterLabel != null)
                PdlButton(
                  label: removeFilterLabel!,
                  variant: PdlButtonVariant.outline,
                  onPressed: onRemoveFilter,
                ),
              PdlButton(
                key: resetAllKey,
                label: resetAllLabel,
                variant: PdlButtonVariant.outline,
                onPressed: onResetAll,
              ),
            ],
          ),
          if (hasPreview) ...<Widget>[
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: c.borderSubtle),
            const SizedBox(height: 16),
            if (previewChild != null)
              previewChild!
            else ...<Widget>[
              Text(previewTitle!, style: t.count),
              const SizedBox(height: 8),
              for (int i = 0; i < preview.length && i < 3; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: PdlSpacing.feedGap),
                preview[i],
              ],
            ],
          ],
        ],
      ),
    );
  }
}
