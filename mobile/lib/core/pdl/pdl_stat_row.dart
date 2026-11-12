import '../material.dart';

import '../theme/pdl_tokens.dart';
import 'pdl_stat.dart';

/// A7 — Rangée de [PdlStat].
///
/// Deux régimes : repliable (`.stats`, gouttières 4 × 16) et non repliable
/// (`.stats--nowrap`, gouttière 12) pour les barres denses d'une ligne.
///
/// Le régime non repliable **cède** dès que la place manque : quatre
/// statistiques sur une ligne ne tiennent pas toujours dans 402 pt, et se
/// feraient rogner. La rangée repasse alors en repli, ce qui coûte une ligne de
/// haut au lieu d'un texte tronqué.
///
/// Ce repli est celui de [Wrap], pas un seuil deviné : `textScaler` ne dit rien
/// de la *longueur* des valeurs, et une carte de groupe portant
/// « 19:30 · 22 km/h · 47,0 km · 231 m » débordait de un à deux pixels à
/// l'échelle typographique par défaut — le liseré rayé rouge en bas de la
/// carte. `Wrap` garde tout sur une ligne tant que ça tient et passe à la
/// suivante sinon : même rendu quand il y a la place, plus de débordement
/// quand il n'y en a pas. Seule la gouttière distingue encore les deux
/// régimes.
class PdlStatRow extends StatelessWidget {
  const PdlStatRow({super.key, required this.stats, this.nowrap = false});

  final List<PdlStat> stats;

  /// Régime dense : gouttière serrée, une seule ligne **tant que ça tient**.
  final bool nowrap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: nowrap ? PdlSpacing.statsNowrap : PdlSpacing.statsWrapH,
      runSpacing: PdlSpacing.statsWrapV,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: stats,
    );
  }
}
