import '../../../api/generated/export.dart';

/// Qui peut créer, modifier, publier ou supprimer une sortie — la règle du
/// serveur (`RideAccessChecker` : `teamRole.isOrganizer()`), recopiée pour ne
/// pas montrer un bouton qui finirait en 403 (docs/LEDGER_*.md MOB-76).
///
/// `ORGANIZER` et `ADMIN` seulement : un rôle que cette version de l'app ne
/// connaît pas ([TeamRole.$unknown]) n'ouvre rien, comme partout ailleurs. Le
/// créateur de la sortie n'a **aucun** droit particulier. L'admin de
/// plateforme passe avant tout contrôle côté serveur (`SecurityVerifier`),
/// et l'app le sait déjà pour la météo (`canSeeWeatherNoLocation`).
bool canManageRides({required TeamRole? teamRole, bool platformAdmin = false}) {
  return platformAdmin ||
      teamRole == TeamRole.organizer ||
      teamRole == TeamRole.admin;
}

/// [canManageRides], **et** les deux modules que le serveur exige pour toute
/// action autre que la lecture : une sortie se crée sur un parcours.
bool canManageTeamRides(
  TeamDetailDto team, {
  required TeamRole? teamRole,
  bool platformAdmin = false,
}) {
  return team.enableRides &&
      team.enableRoutes &&
      canManageRides(teamRole: teamRole, platformAdmin: platformAdmin);
}
