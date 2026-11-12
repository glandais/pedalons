import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../data/ad_repository.dart';
import '../domain/ad_filters.dart';

/// Filtres courants de la rubrique Annonces d'une équipe, **keyed par le slug
/// d'équipe** — la portée que l'écran impose, jamais une portée choisie.
final adFiltersProvider = StateProvider.autoDispose.family<AdFilters, String>(
  (ref, teamSlug) => AdFilters(teamSlug: teamSlug),
);

/// La liste paginée pour un jeu de filtres.
///
/// Auto-disposée, comme la parcothèque : abandonner une combinaison la libère,
/// tandis que celle qu'on lit reste vivante tant que l'écran est monté — c'est
/// ce qui restitue les pages chargées et la position de défilement au retour
/// d'une annonce.
final adListProvider = StateNotifierProvider.autoDispose
    .family<AdListNotifier, PagedListState<AdDto>, AdFilters>((ref, filters) {
      return AdListNotifier(ref.watch(adRepositoryProvider), filters);
    });

class AdListNotifier extends PagedListNotifier<AdDto> {
  final AdRepository _repository;
  final AdFilters _filters;

  AdListNotifier(this._repository, this._filters);

  @override
  Future<PageResult<AdDto>> fetchPage(int page) {
    return _repository.fetchAds(
      filters: _filters,
      page: page,
      size: pageSize,
      // Une carte d'annonce se contente d'`excerpt`, de `thumbnailUrl` et
      // d'`images`, tous présents en COMPACT : le markdown, les pièces jointes
      // et les images au-delà de la première restent au serveur.
      view: ListViewMode.compact,
    );
  }

  @override
  Object? itemKey(AdDto item) => item.id;
}

/// Combien d'annonces [filters] laisserait voir : le bouton de la feuille de
/// prix annonce le compte **du serveur** avant qu'on applique.
final adCountProvider = FutureProvider.autoDispose.family<int, AdFilters>(
  (Ref ref, AdFilters filters) =>
      ref.watch(adRepositoryProvider).countAds(filters),
);
