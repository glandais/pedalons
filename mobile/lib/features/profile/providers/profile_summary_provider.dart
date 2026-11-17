import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../teams/providers/team_providers.dart';
import '../data/profile_repository.dart';

/// L'état de chaque sujet du profil, pour les lignes d'état de la vue
/// d'ensemble : `GET /api/users/me/profile-summary`, un seul appel à coût SQL
/// fixe. Les préférences d'affichage, `contactableByMembers` et les services
/// connectés restent dans `UserDto` (l'utilisateur de `authProvider`) : le
/// résumé ne les répète pas.
///
/// `null` hors session. Pas d'`autoDispose` : le profil est un onglet, ses
/// lignes restent affichées. Ce qui change un compteur l'invalide — un blocage
/// (`refreshAfterBlockChange`), le retour d'une sous-page du profil, et un
/// changement de mes équipes (ci-dessous).
final profileSummaryProvider = FutureProvider<ProfileSummaryDto?>((ref) async {
  final String? token = ref.watch(accessTokenHolderProvider);
  if (token == null) return null;

  // « Mes équipes » s'ouvre par un changement d'onglet (`go`), sans retour qui
  // relirait le résumé. Rejoindre ou quitter une équipe invalide
  // `myTeamsProvider` (déjà chargé par l'accueil et l'onglet Équipes) : le
  // compteur suit quand l'ensemble de mes équipes a réellement changé — pas à
  // chaque relecture de la liste.
  ref.listen<AsyncValue<List<TeamDetailDto>>>(myTeamsProvider, (
    AsyncValue<List<TeamDetailDto>>? previous,
    AsyncValue<List<TeamDetailDto>> next,
  ) {
    if (next.isLoading || !next.hasValue) return;
    final Set<String>? before = _teamSlugs(previous);
    if (before != null && !setEquals(before, _teamSlugs(next))) {
      ref.invalidateSelf();
    }
  });

  return ref.read(profileRepositoryProvider).profileSummary();
});

Set<String>? _teamSlugs(AsyncValue<List<TeamDetailDto>>? value) =>
    value?.value?.map((TeamDetailDto team) => team.slug).toSet();
