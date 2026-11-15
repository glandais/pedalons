import '../../../api/generated/export.dart';

// Ce que la personne peut faire dans une équipe, à partir de son rôle réel
// et de son rôle de plateforme — la reprise de `teamAccess.ts` du site
// (docs/LEDGER_*.md MOB-165).
//
// `TeamDetailDto.role` est l'adhésion réelle, `null` pour qui n'est pas
// membre, admin de plateforme compris (ledger `API-137`). Les droits qu'un
// admin de plateforme a partout viennent de `UserDto.platformRole`, combinés
// ici. Un rôle que cette version de l'app ne connaît pas (`TeamRole.$unknown`)
// n'ouvre rien, comme partout ailleurs.

/// Le rôle réel de l'appelant dans [team], `null` s'il n'en est pas membre.
TeamRole? teamRoleOf(TeamDetailDto team) {
  final String? role = team.role;
  return role == null ? null : TeamRole.fromJson(role);
}

/// Peut agir en organisateur : `ORGANIZER` ou `ADMIN` de l'équipe, ou admin
/// de plateforme.
bool isTeamOrganizer({
  required TeamRole? teamRole,
  bool platformAdmin = false,
}) {
  return platformAdmin ||
      teamRole == TeamRole.organizer ||
      teamRole == TeamRole.admin;
}

/// Peut agir en administrateur : `ADMIN` de l'équipe, ou admin de plateforme.
bool isTeamAdmin({required TeamRole? teamRole, bool platformAdmin = false}) {
  return platformAdmin || teamRole == TeamRole.admin;
}
