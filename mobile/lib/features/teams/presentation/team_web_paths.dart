import '../../../config/paths.dart';

/// Les pages **du site** qu'ouvre le tableau de bord d'un organisateur.
///
/// Créer ou modifier une publication ou un voyage, gérer les modèles de
/// sortie, traiter un signalement, gérer les membres et les réglages de
/// l'équipe : l'application n'a d'écran pour aucun de ces gestes. Créer et
/// modifier une **sortie** se fait dans l'app depuis `MOB-76`
/// (`rideNewLocation`, `Paths.rideEdit`). Le tableau de bord les propose
/// néanmoins — parité avec le web —, et les ouvre dans le navigateur de l'appareil
/// par `openWebPage`.
///
/// Les chemins viennent de `contracts/routes.yaml`, où ces routes sont
/// `mobile: true` + `appScreen: false` : un renommage côté web les suit, et
/// ils sont dans la langue de l'app (docs/LEDGER_*.md MOB-54). Seuls les
/// paramètres de requête, qu'aucune route ne porte, sont ajoutés ici.
abstract final class TeamWebPaths {
  static String postNew(String teamSlug) => Paths.postNew(teamSlug);

  static String postEdit(String teamSlug, String postSlug) =>
      Paths.postEdit(teamSlug, postSlug);

  static String tripEdit(String teamSlug, String tripSlug) =>
      Paths.tripEdit(teamSlug, tripSlug);

  static String rideTemplates(String teamSlug) => Paths.rideTemplates(teamSlug);

  static String reports(String teamSlug) => Paths.teamAdminReports(teamSlug);

  static String adminMembers(String teamSlug) =>
      Paths.teamAdminMembers(teamSlug);

  /// La page des membres, dialogue d'invitation ouvert : `TeamMembersPage` lit
  /// `?invite=1` (le web passe `OPEN_INVITE_STATE` en état de routeur).
  static String adminMembersInvite(String teamSlug) =>
      '${Paths.teamAdminMembers(teamSlug)}?invite=1';

  static String settings(String teamSlug) => Paths.teamSettings(teamSlug);
}
