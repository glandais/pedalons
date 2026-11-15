import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../feed/providers/publication_feed_provider.dart';
import '../../rides/providers/ride_editor_providers.dart';
import '../../tags/providers/team_tags_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import '../data/post_repository.dart';
import '../domain/post_form.dart';

typedef PostKey = ({String teamSlug, String postSlug});

final postDetailProvider = FutureProvider.family<PostDto, PostKey>((
  ref,
  params,
) async {
  final repository = ref.watch(postRepositoryProvider);
  return repository.getPost(params.teamSlug, params.postSlug);
});

/// L'utilisateur peut-il créer une publication dans [teamSlug] ? `null` tant
/// que « Mes équipes » n'est pas chargé et qu'il n'est pas admin de
/// plateforme : l'écran n'affiche alors ni bouton ni refus (docs/LEDGER_*.md
/// MOB-164).
///
/// La règle est celle du serveur : organisateur ou administrateur, module
/// publications actif — [canManageTeamPosts].
final canManagePostsProvider = Provider.family<bool?, String>(
  (Ref ref, String teamSlug) =>
      teamManagePermission(ref, teamSlug, canManageTeamPosts),
);

/// **Le** point où l'app dit « un organisateur vient de changer une
/// publication » — créée, réécrite, publiée, dépubliée, renommée d'adresse,
/// supprimée ou restaurée (ledger `MOB-164`). Le pendant de
/// `notifyRideChanged`.
///
/// Une publication paraît dans les fils (accueil, équipe), le tableau de bord
/// de l'équipe et les compteurs d'usage des tags ; le détail n'est invalidé
/// que si [postKey] le nomme. Elle n'est ni dans le calendrier ni dans
/// « Cette semaine ».
void notifyPostChanged(
  WidgetRef ref, {
  required String teamSlug,
  PostKey? postKey,
}) {
  if (postKey != null) ref.invalidate(postDetailProvider(postKey));
  ref.invalidate(publicationFeedProvider);
  ref.invalidate(teamDashboardProvider);
  ref.invalidate(teamTagsProvider((teamSlug: teamSlug, type: TagTarget.post)));
}
