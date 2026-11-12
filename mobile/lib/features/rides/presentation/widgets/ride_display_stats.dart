import '../../../../core/pdl/pdl.dart';
import '../../../../api/generated/export.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/utils/formatters.dart';

/// La distance et le D+ d'une sortie sur une carte de liste (règle R3, KIT §9,
/// docs/LEDGER_*.md API-178) : `displayDistance` et `displayElevationGain`,
/// calculés par le serveur **pour la personne qui lit** — le parcours de son
/// groupe si elle est inscrite, sinon le parcours commun, sinon rien.
///
/// Aucune carte ne choisit plus entre la distance de la sortie, celle de son
/// groupe ou celle du premier groupe : elle passe ici ce que le contrat lui
/// donne, et un champ absent ne s'affiche pas. Les cartes de groupe et
/// d'étape gardent la distance de leur propre parcours.
List<PdlStat> rideDisplayStats({
  required double? distance,
  required double? elevationGain,
  required UnitSystem units,
}) => <PdlStat>[
  if (distance != null)
    PdlStat(
      value: AppFormatters.formatDistance(distance, units),
      icon: PdlIcons.distance,
    ),
  if (elevationGain != null)
    PdlStat(
      value: AppFormatters.formatElevation(elevationGain, units),
      icon: PdlIcons.elevationUp,
      trend: PdlStatTrend.up,
    ),
];
