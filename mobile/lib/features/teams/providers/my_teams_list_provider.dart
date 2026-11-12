import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../data/team_repository.dart';
import 'team_providers.dart';

/// La liste paginée de l'onglet « Mes équipes », pour une recherche (`null`
/// sans recherche).
///
/// [myTeamsProvider] reste le **fait transverse** (rôle, accès d'un lien
/// profond) ; cette liste-ci est celle qu'on lit, page après page, comme
/// Découvrir. Avant elle, l'onglet affichait les vingt premières équipes de
/// [myTeamsProvider] sans dire qu'il en restait, et sa recherche locale ne
/// voyait qu'elles.
///
/// Tout ce qui invalide [myTeamsProvider] — rejoindre, quitter, accepter une
/// invitation — recharge aussi cette liste : elle écoute son rechargement.
final myTeamsListProvider = StateNotifierProvider.autoDispose
    .family<MyTeamsListNotifier, PagedListState<TeamDetailDto>, String?>((
      ref,
      search,
    ) {
      final MyTeamsListNotifier notifier = MyTeamsListNotifier(
        ref.watch(teamRepositoryProvider),
        search,
      );
      ref.listen<AsyncValue<List<TeamDetailDto>>>(myTeamsProvider, (
        AsyncValue<List<TeamDetailDto>>? previous,
        AsyncValue<List<TeamDetailDto>> next,
      ) {
        final bool reloading =
            next.isLoading && previous != null && !previous.isLoading;
        // Déjà en train de se recharger (le tirer-pour-rafraîchir de l'écran
        // recharge les deux) : pas de second appel.
        if (reloading && !notifier.isRefreshing) {
          unawaited(notifier.refresh());
        }
      });
      return notifier;
    });

class MyTeamsListNotifier extends PagedListNotifier<TeamDetailDto> {
  MyTeamsListNotifier(this._repository, this._search);

  final TeamRepository _repository;
  final String? _search;

  @override
  Future<PageResult<TeamDetailDto>> fetchPage(int page) =>
      _repository.fetchMyTeams(search: _search, page: page, size: pageSize);

  @override
  Object? itemKey(TeamDetailDto item) => item.id;

  /// Vrai pendant un rechargement qui garde la liste à l'écran.
  bool get isRefreshing => state.isRefreshing;
}
