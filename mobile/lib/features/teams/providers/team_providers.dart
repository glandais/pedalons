import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
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
/// donnée d'un écran mais un **fait transverse** : l'écran 12 s'en sert pour
/// savoir, avant tout appel, s'il doit proposer de rejoindre un groupe ou
/// afficher le bandeau « Rejoignez cette équipe ».
final myTeamsProvider = FutureProvider<List<TeamDetailDto>>((ref) async {
  final repository = ref.watch(teamRepositoryProvider);
  return repository.getMyTeams();
});

/// L'utilisateur est-il membre de [teamSlug] ?
///
/// `null` tant qu'on ne sait pas — la liste n'est pas chargée, ou l'appel a
/// échoué. Le nul est **significatif** : il ne faut ni promettre l'inscription,
/// ni afficher un bandeau « rejoignez cette équipe » à quelqu'un qui en est
/// membre. En cas de doute, l'écran laisse l'API trancher au premier appel et
/// traite un 403 `FORBIDDEN` comme la réponse définitive.
final teamMembershipProvider = Provider.family<bool?, String>((
  Ref ref,
  String teamSlug,
) {
  return ref
      .watch(myTeamsProvider)
      .whenOrNull(
        data: (List<TeamDetailDto> teams) =>
            teams.any((TeamDetailDto t) => t.slug == teamSlug),
      );
});

/// Puis-je voir les noms des membres de [teamSlug] ?
///
/// La même règle que le serveur (`member || platformAdmin`, comme les
/// commentaires) : qui n'est pas membre — visiteur, sans équipe, membre d'une
/// autre équipe — ne reçoit que des **comptes** : pas de noms, pas d'avatars,
/// et la liste des participants lui est refusée. À ne pas déduire de la
/// vacuité d'une liste. Inconnu (`null`) vaut non : on n'offre pas une action
/// que l'API refuserait.
final canSeeMemberNamesProvider = Provider.family<bool, String>((
  Ref ref,
  String teamSlug,
) {
  final bool platformAdmin = ref.watch(
    authProvider.select(
      (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
    ),
  );
  return platformAdmin ||
      (ref.watch(teamMembershipProvider(teamSlug)) ?? false);
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
