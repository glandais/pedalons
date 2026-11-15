import '../../../config/paths.dart';

/// Les pages **du site** qu'ouvre le hub « Gestion de l'équipe »
/// (`team_admin_page.dart`).
///
/// Gérer les tags et les pages de l'équipe : l'application n'a encore d'écran
/// pour aucun de ces gestes. Ses
/// **paramètres** sont un écran de l'app depuis `MOB-166`
/// (`Paths.teamSettings`), la **gestion des membres** depuis `MOB-167`
/// (`Paths.teamAdminMembers`), ses **lieux** et sa **file de signalements**
/// depuis `MOB-168` (`Paths.teamAdminPlaces`, `Paths.teamAdminReports`). Ils
/// arrivent lot par lot (ledgers `MOB-166` à `MOB-169`,
/// plan `docs/plans/2026-11-15-gestion-equipe-mobile.md`) ; chaque lot retire
/// ici son entrée, et ce fichier disparaît avec le dernier.
/// Créer et modifier une **sortie** se fait dans l'app depuis `MOB-80`
/// (`rideNewLocation`, `Paths.rideEdit`), gérer les **modèles de sortie**
/// depuis `MOB-78` (`Paths.rideTemplates`), créer et modifier une
/// **publication** depuis `MOB-164` (`Paths.postNew`, `Paths.postEdit`), créer et
/// modifier un **voyage** depuis `MOB-162` (`Paths.tripNew`, `Paths.tripEdit`).
/// Le tableau de bord les propose
/// néanmoins — parité avec le web —, et les ouvre dans le navigateur de l'appareil
/// par `openWebPage`.
///
/// Les chemins viennent de `contracts/routes.yaml`, où ces routes sont
/// `mobile: true` + `appScreen: false` : un renommage côté web les suit, et
/// ils sont dans la langue de l'app (docs/LEDGER_*.md MOB-54).
abstract final class TeamWebPaths {
  // Les deux pages que seul le hub ouvre (ledger `MOB-165`).
  static String tags(String teamSlug) => Paths.teamAdminTags(teamSlug);

  static String pages(String teamSlug) => Paths.teamAdminPages(teamSlug);
}
