import '../../../api/generated/export.dart';

/// Ce qu'une page libre dit d'elle dans la liste « Pages de l'équipe », la
/// raison la plus restrictive d'abord. Les deux premières n'atteignent que les
/// modérateurs de l'équipe, ses administrateurs et l'admin de plateforme, qui
/// ne doivent pas les prendre pour des pages publiées ; « Membres » n'est dit
/// qu'à qui lit l'équipe sans en être — l'admin de plateforme, qui voit toutes
/// les pages (ledger `API-137`). Un membre sait que les pages de son équipe
/// sont les siennes. Même règle que `pageBadge` du site (docs/LEDGER_*.md
/// WEB-120).
enum TeamPageBadge { hidden, draft, members }

TeamPageBadge? teamPageBadge(
  TeamPageSummaryDto page, {
  required bool isMember,
}) {
  if (page.moderationHidden) return TeamPageBadge.hidden;
  if (page.status == 'DRAFT') return TeamPageBadge.draft;
  if (page.visibility == 'TEAM' && !isMember) return TeamPageBadge.members;
  return null;
}
