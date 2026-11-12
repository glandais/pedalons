import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';

/// A8 — Barre de remplissage, dite « barre de places ».
///
/// 6 px de haut, rayon pilule, fond `neutralSoft`. Le remplissage est
/// `primary` tant qu'il reste de la place, `danger` à 100 % : plein est le
/// seul état qui change ce qu'on peut faire (pas de liste d'attente). Plus de
/// vert ni d'orange (règle R5 des cartes, KIT §9, docs/LEDGER_*.md MOB-139) :
/// un groupe à 80 % n'est pas une alerte. L'appelant n'a pas à le calculer.
///
/// Ne porte aucun texte : le « 40/48 » qui l'accompagne dans les maquettes est
/// un libellé posé à côté par le composé appelant.
class PdlProgressBar extends StatelessWidget {
  const PdlProgressBar({
    super.key,
    required this.value,
    this.color,
    this.semanticLabel,
  });

  /// Taux de remplissage, borné à `[0, 1]`.
  final double value;

  /// Couleur imposée — pour les usages qui ne sont pas un remplissage de
  /// places (progression de téléchargement, avancement d'étape).
  final Color? color;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final double ratio = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    final Color fill = color ?? (ratio >= 1.0 ? c.danger : c.primary);

    return Semantics(
      label: semanticLabel,
      value: '${(ratio * 100).round()} %',
      child: ClipRRect(
        borderRadius: PdlRadii.pillAll,
        child: SizedBox(
          height: PdlMetrics.seatsBar,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: c.neutralSoft)),
              FractionallySizedBox(
                widthFactor: ratio,
                heightFactor: 1,
                child: ColoredBox(color: fill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
