import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../domain/member_filters.dart';
import '../domain/team_discovery_filters.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(
    ref.watch(teamsClientProvider),
    ref.watch(teamMembersClientProvider),
  );
});

/// La taille des pages lues par [TeamRepository.getMyTeams] : une seule
/// requête pour presque tout le monde.
const int kMyTeamsBatchSize = 100;

class TeamRepository {
  final TeamsClient _teamsClient;
  final TeamMembersClient _teamMembersClient;

  TeamRepository(this._teamsClient, this._teamMembersClient);

  /// **Toutes** les équipes dont l'utilisateur est membre, par le nom.
  ///
  /// Page après page jusqu'au total : sans `page` ni `size`, le serveur en
  /// rend vingt, et le rôle, les barres d'outils et le sélecteur d'équipe s'y
  /// arrêtaient sans le dire (lot 0 des listes, ledger `MOB-143`).
  Future<List<TeamDetailDto>> getMyTeams() async {
    final List<TeamDetailDto> teams = <TeamDetailDto>[];
    for (int page = 0; ; page++) {
      final TeamListResponse response = await _teamsClient.listTeams(
        page: page,
        size: kMyTeamsBatchSize,
        minRole: MinRole.member,
        sortBy: TeamSortBy.name,
        sortDir: SortDirection.asc,
      );
      teams.addAll(response.teams);
      if (response.teams.isEmpty || teams.length >= response.total) {
        return teams;
      }
    }
  }

  /// Une page de « Mes équipes » (`minRole=MEMBER`), cherchée **côté
  /// serveur** sur le nom et la présentation.
  ///
  /// **Par le nom**, de A à Z (règle RL5 des listes) : sous la portée
  /// « Membre », la liste est un carnet d'adresses, et l'écran le dit
  /// (« 5 équipes · triées par nom »). Découvrir, lui, trie par nombre de
  /// membres.
  Future<PageResult<TeamDetailDto>> fetchMyTeams({
    String? search,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    final String? query = search?.trim();
    final TeamListResponse response = await _teamsClient.listTeams(
      page: page,
      size: size,
      minRole: MinRole.member,
      search: query == null || query.isEmpty ? null : query,
      sortBy: TeamSortBy.name,
      sortDir: SortDirection.asc,
    );
    return PageResult<TeamDetailDto>(
      items: response.teams,
      total: response.total,
    );
  }

  /// Get public teams (for discovery)
  Future<List<TeamDetailDto>> getPublicTeams({
    int page = 0,
    int size = 20,
    String? search,
  }) async {
    final response = await _teamsClient.listTeams(
      page: page,
      size: size,
      search: search,
    );
    return response.teams;
  }

  /// Get team details
  Future<TeamDetailDto> getTeam(String slug) {
    return _teamsClient.getTeam(teamSlug: slug);
  }

  /// Le tableau de bord de l'équipe : toutes ses sections, filtrées par le
  /// rôle de l'appelant, en **un seul appel** (`GET …/dashboard`).
  Future<TeamDashboardDto> getDashboard(String slug) {
    return _teamsClient.getTeamDashboard(teamSlug: slug);
  }

  /// Join a team
  Future<MemberDto> joinTeam(String slug) {
    return _teamMembersClient.joinTeam(teamSlug: slug);
  }

  /// Leave a team
  Future<void> leaveTeam(String slug) {
    return _teamMembersClient.leaveTeam(teamSlug: slug);
  }

  /// Get team members
  Future<List<MemberDto>> getTeamMembers(String slug) async {
    final response = await _teamMembersClient.getMembers(teamSlug: slug);
    return response.members;
  }

  /// One page of team members, filtered by role and search.
  ///
  /// C'est ce que [getTeamMembers] ne faisait pas : sans `page` ni `size`, le
  /// mobile montrait la page du serveur — vingt membres sur mille neuf cent
  /// quatre-vingt-dix-neuf — **sans le dire**. `total` est la seule chose qui
  /// permette de l'annoncer, et il est déjà dans la réponse.
  Future<PageResult<MemberDto>> fetchMembers({
    required MemberFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    final String? search = filters.search?.trim();
    final MemberListResponse response = await _teamMembersClient.getMembers(
      teamSlug: filters.teamSlug,
      role: filters.role,
      search: search == null || search.isEmpty ? null : search,
      // Par le nom, de A à Z (règle RL5 des listes) : le défaut du serveur
      // depuis le contrat 14.7.0, demandé quand même pour ne pas en dépendre.
      sortBy: MemberSortBy.name,
      sortDir: SortDirection.asc,
      page: page,
      size: size,
    );
    return PageResult<MemberDto>(
      items: response.members,
      total: response.total,
    );
  }

  /// One page of the team directory.
  ///
  /// Triée selon la portée ([TeamDiscoveryFilters.sortBy]) — l'ordre que
  /// l'écran de découverte annonce.
  Future<PageResult<TeamDetailDto>> fetchTeams({
    required TeamDiscoveryFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    final String? search = filters.search?.trim();
    final TeamListResponse response = await _teamsClient.listTeams(
      page: page,
      size: size,
      joinable: filters.scope == TeamDiscoveryScope.joinable ? true : null,
      minRole: filters.scope == TeamDiscoveryScope.mine ? MinRole.member : null,
      search: search == null || search.isEmpty ? null : search,
      sortBy: filters.sortBy,
      sortDir: teamSortDirection(filters.sortBy),
    );
    return PageResult<TeamDetailDto>(
      items: response.teams,
      total: response.total,
    );
  }
}
