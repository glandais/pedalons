import '../../../api/generated/export.dart';

/// L'équipe a-t-elle rempli les places de l'offre gratuite ? — `isTeamFull`
/// du site (`TeamMemberLimit.tsx`).
///
/// `memberLimit` est nul pour une équipe débloquée. À la limite, le serveur
/// refuse une adhésion, un ajout ou une invitation
/// (`TEAM_MEMBER_LIMIT_REACHED`, docs/LEDGER_*.md BILL-10). Les invitations en
/// attente comptent aussi quand on invite : le serveur reste l'autorité, ceci
/// n'épargne que le cas évident. L'administration de la plateforme n'y est pas
/// tenue — à l'appelant de l'en exempter.
bool isTeamFull(TeamDetailDto team) {
  final int? limit = team.memberLimit;
  return limit != null && team.memberCount >= limit;
}
