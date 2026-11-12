import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../data/invitations_repository.dart';
import '../data/team_repository.dart';

/// The one source of a team's detail, and therefore the one source of its
/// loading and error state.
///
/// It used to live in `team_detail_page.dart`, a page routed nowhere, while the
/// router watched it through a wrapper of its own — which is how a team section
/// ended up with two owners of the same error. The provider now belongs to the
/// feature, and a single page (`TeamHomePage`) watches it.
final teamDetailProvider = FutureProvider.family<TeamDetailDto, String>((
  ref,
  slug,
) async {
  final repository = ref.watch(teamRepositoryProvider);
  return repository.getTeam(slug);
});

/// Les équipes dont l'utilisateur est membre.
///
/// Vivait dans `teams_page.dart`. Elle en sort parce qu'elle n'est plus la
/// donnée d'un écran mais un **fait transverse** — le rôle ([teamRoleProvider]),
/// et la question qu'un lien profond pose avant de reconstruire une équipe
/// sous une entité (`teamAccessProbeProvider`). Les écrans de détail, eux, ne
/// la lisent plus pour leurs bandeaux et leurs gestes : le bloc `permissions`
/// de l'entité le dit (docs/LEDGER_*.md MOB-137, décision D7).
///
/// **Toutes** les équipes, page après page (`TeamRepository.getMyTeams`) : le
/// rôle, les barres d'outils et le sélecteur d'équipe ne s'arrêtent plus aux
/// vingt premières.
final myTeamsProvider = FutureProvider<List<TeamDetailDto>>((ref) async {
  final repository = ref.watch(teamRepositoryProvider);
  return repository.getMyTeams();
});

/// La portée d'ouverture d'une liste inter-équipes — fil d'accueil, Explorer
/// (règle RL1 des listes, KIT §10), la même que sur le web
/// (`useMembershipDefault`) : « Membre », sauf pour qui n'a aucune équipe, à
/// qui elle ne montrerait qu'une liste vide. Optimiste pendant le chargement :
/// la plupart des personnes ont une équipe.
///
/// Elle ne change que quand ce « aucune équipe » bascule : une liste qui
/// l'observe n'est donc pas remise à zéro par un simple rechargement.
final membershipDefaultScopeProvider = Provider.autoDispose<MinRole?>((ref) {
  final List<TeamDetailDto>? teams = ref.watch(myTeamsProvider).value;
  return teams != null && teams.isEmpty ? null : MinRole.member;
});

/// Mon rôle dans [teamSlug], lu dans « Mes équipes » — aucun appel de plus.
///
/// `null` quand je n'en suis pas membre, ou tant que la liste n'est pas là (ou
/// a échoué). Une valeur que cette version de l'app ne connaît pas rend
/// [TeamRole.$unknown] : l'appelant qui réserve quelque chose aux
/// organisateurs ne l'ouvre donc qu'à `ORGANIZER` et `ADMIN` explicites.
final teamRoleProvider = Provider.family<TeamRole?, String>((
  Ref ref,
  String teamSlug,
) {
  final List<TeamDetailDto>? teams = ref.watch(myTeamsProvider).value;
  if (teams == null) return null;
  for (final TeamDetailDto team in teams) {
    if (team.slug == teamSlug) {
      final String? role = team.role;
      return role == null ? null : TeamRole.fromJson(role);
    }
  }
  return null;
});

/// Les invitations en attente adressées à l'utilisateur, affichées en tête de
/// « Mes équipes ».
///
/// C'est la seule porte d'entrée mobile d'une invitation : une notification
/// `TEAM_INVITATION` mène à la liste des équipes, et quelqu'un invité avant
/// d'avoir un compte n'est inscrit à rien par son inscription.
final myInvitationsProvider = FutureProvider<List<MyInvitationDto>>((ref) {
  return ref.watch(invitationsRepositoryProvider).listMine();
});
