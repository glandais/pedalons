import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_button.dart';
import 'pdl_card.dart';

/// B9 — Pied d'une liste à défilement infini.
///
/// Trois états mutuellement exclusifs : la page suivante charge, elle a
/// échoué, ou il n'y a plus rien.
///
/// **Le total est indispensable.** « Chargement… » seul n'informe de rien :
/// l'utilisateur ne sait ni où il en est, ni combien il reste. Le pied affiche
/// donc « 8 participants sur 40 · chargement de la suite... ». C'est
/// [progressLabel] qui porte « 8 participants sur 40 » — `core/pdl` ne traduit
/// rien et ne connaît ni le nom de ce qui est compté, ni son pluriel.
///
/// En fin de liste, « Vous avez tout vu » ferme la lecture, sur la ligne du
/// compteur : sans lui, une liste terminée se confond avec une liste qui n'a
/// pas fini de charger.
class PdlPagedListFooter extends StatelessWidget {
  const PdlPagedListFooter({
    super.key,
    required this.isLoadingNext,
    required this.hasMore,
    required this.isEmpty,
    required this.progressLabel,
    required this.loadingLabel,
    required this.endLabel,
    required this.errorLabel,
    required this.retryLabel,
    this.hasError = false,
    this.onRetry,
    this.skeleton,
  }) : assert(
         progressLabel != '',
         'un compteur sans total n\'informe de rien : « 8 participants sur 40 »',
       );

  final bool isLoadingNext;
  final bool hasMore;

  /// Vrai quand la liste n'a rien du tout : le pied s'efface, c'est l'état
  /// vide qui parle.
  final bool isEmpty;

  /// « 8 participants sur 40 » — construit par l'appelant, total compris.
  final String progressLabel;

  /// « chargement de la suite... »
  final String loadingLabel;

  /// « Vous avez tout vu »
  final String endLabel;

  final String errorLabel;
  final String retryLabel;

  final bool hasError;
  final VoidCallback? onRetry;

  /// Gabarit posé au-dessus du compteur pendant le chargement, pour que la
  /// liste grandisse dans son contenu au lieu de sauter.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: PdlSpacing.section),
        child: PdlCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(errorLabel, textAlign: TextAlign.center, style: t.sub),
              const SizedBox(height: 12),
              PdlButton(
                label: retryLabel,
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      );
    }

    if (isLoadingNext) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: PdlSpacing.sectionTightV),
        child: Column(
          children: <Widget>[
            if (skeleton != null) ...<Widget>[
              skeleton!,
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.textDimmed,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '$progressLabel · $loadingLabel',
                    textAlign: TextAlign.center,
                    style: t.xs,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Un seul pied, une seule ligne : « 47 annonces sur 47 · Vous avez tout
    // vu » (règle RL12 des listes, KIT §10).
    if (!hasMore && !isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          '$progressLabel · $endLabel',
          textAlign: TextAlign.center,
          style: t.xs,
        ),
      );
    }

    return const SizedBox(height: 8);
  }
}
