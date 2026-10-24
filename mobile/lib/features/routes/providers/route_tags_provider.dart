import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../tags/providers/team_tags_provider.dart';
import '../domain/route_filters.dart';

/// Les tags `ROUTE` proposables pour [filters] (ledger `MOB-39`).
///
/// Vide hors d'une équipe : le serveur ne filtre par tag que sur les listes
/// d'une équipe (plan des tags, D7), et c'est ce vide qui cache la chip et la
/// ligne de la feuille de filtres — sur l'onglet Explorer comme sur la
/// section d'une équipe sans tag.
List<TagWithUsageDto> routeTagVocabulary(WidgetRef ref, RouteFilters filters) {
  final String? teamSlug = filters.teamSlug;
  if (teamSlug == null) return const <TagWithUsageDto>[];
  return teamTagsOrEmpty(ref, (teamSlug: teamSlug, type: TagTarget.route));
}
