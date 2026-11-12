import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../../../core/utils/api_error_handler.dart';
import '../data/team_repository.dart';
import '../domain/team_discovery_filters.dart';
import 'membership_scoped_content.dart';
import 'team_providers.dart';

/// Filtres courants de la découverte.
final teamDiscoveryFiltersProvider =
    StateProvider.autoDispose<TeamDiscoveryFilters>(
      (ref) => const TeamDiscoveryFilters(),
    );

/// L'annuaire paginé pour un jeu de filtres.
final teamDiscoveryProvider = StateNotifierProvider.autoDispose
    .family<
      TeamDiscoveryNotifier,
      PagedListState<TeamDetailDto>,
      TeamDiscoveryFilters
    >((ref, filters) {
      return TeamDiscoveryNotifier(ref.watch(teamRepositoryProvider), filters);
    });

class TeamDiscoveryNotifier extends PagedListNotifier<TeamDetailDto> {
  final TeamRepository _repository;
  final TeamDiscoveryFilters _filters;

  TeamDiscoveryNotifier(this._repository, this._filters);

  @override
  Future<PageResult<TeamDetailDto>> fetchPage(int page) {
    return _repository.fetchTeams(
      filters: _filters,
      page: page,
      size: pageSize,
    );
  }

  @override
  Object? itemKey(TeamDetailDto item) => item.id;
}

/// L'adhésion en cours, et son échec éventuel.
@immutable
class TeamJoinState {
  const TeamJoinState({
    this.pending = const <String>{},
    this.joined = const <String>{},
    this.failure,
  });

  /// Slugs dont l'appel est en vol.
  final Set<String> pending;

  /// Slugs devenus membres pendant cette session d'écran.
  ///
  /// La liste paginée n'est pas rejouée après une adhésion : la carte lit
  /// cette superposition, ce qui évite de refaire toutes les pages chargées
  /// pour un seul champ qui change.
  final Set<String> joined;

  final TeamJoinFailure? failure;

  /// Le rôle à rendre pour [team] : celui du serveur, ou `MEMBER` quand la
  /// bascule optimiste l'a devancé.
  String? roleFor(TeamDetailDto team) =>
      team.role ?? (joined.contains(team.slug) ? 'MEMBER' : null);

  TeamJoinState copyWith({
    Set<String>? pending,
    Set<String>? joined,
    TeamJoinFailure? failure,
    bool clearFailure = false,
  }) => TeamJoinState(
    pending: pending ?? this.pending,
    joined: joined ?? this.joined,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Un échec d'adhésion, **nommé** : quelle équipe, et pourquoi.
@immutable
class TeamJoinFailure {
  const TeamJoinFailure({required this.teamName, required this.message});

  final String teamName;
  final String message;
}

/// L'adhésion à une équipe : bascule optimiste, rétablissement complet et
/// bandeau nommant la cause.
///
/// C'est le même objet que la participation à un voyage — même séquence, même
/// interdiction du `showSnackBar` : un échec est un **état**, pas un événement
/// de quatre secondes.
final teamJoinControllerProvider =
    StateNotifierProvider.autoDispose<TeamJoinController, TeamJoinState>(
      (ref) => TeamJoinController(ref),
    );

class TeamJoinController extends StateNotifier<TeamJoinState> {
  TeamJoinController(this._ref) : super(const TeamJoinState());

  final Ref _ref;

  void dismissFailure() => state = state.copyWith(clearFailure: true);

  Future<void> join(TeamDetailDto team) async {
    if (state.pending.contains(team.slug) ||
        state.joined.contains(team.slug) ||
        team.role != null) {
      return;
    }

    state = state.copyWith(
      pending: <String>{...state.pending, team.slug},
      // Optimiste : la carte passe à « Membre » avant tout aller-retour.
      joined: <String>{...state.joined, team.slug},
      clearFailure: true,
    );

    try {
      await _ref.read(teamRepositoryProvider).joinTeam(team.slug);
      state = state.copyWith(
        pending: <String>{...state.pending}..remove(team.slug),
      );
      // « Mes équipes » vient d'en gagner une.
      _ref.invalidate(myTeamsProvider);
      invalidateMembershipScopedContent((p) => _ref.invalidate(p));
    } catch (error, stackTrace) {
      final ApiError resolved = resolveApiError(error, stackTrace);
      // Rétablissement **complet** avant d'expliquer : la carte revient à ce
      // qu'elle était, sans quoi on lirait un état qui n'a jamais existé côté
      // serveur.
      state = TeamJoinState(
        pending: <String>{...state.pending}..remove(team.slug),
        joined: <String>{...state.joined}..remove(team.slug),
        failure: TeamJoinFailure(
          teamName: team.name,
          message: resolved.message,
        ),
      );
    }
  }
}
