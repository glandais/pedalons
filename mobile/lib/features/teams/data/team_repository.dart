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

  /// Crée une équipe ; la personne qui la crée en devient l'administratrice
  /// (docs/LEDGER_*.md MOB-165). Le serveur génère le slug.
  Future<TeamDetailDto> createTeam(TeamRequest request) {
    return _teamsClient.createTeam(body: request);
  }

  /// Réécrit l'équipe (docs/LEDGER_*.md MOB-166). **Le PUT réécrit tous les
  /// champs** : la requête vient de `TeamForm.fromTeam(…).toRequest()`, qui
  /// reprend la présentation entière ; une position absente **efface** celle
  /// de l'équipe (`TeamService.updateTeam` : `setGeometry(request.geometry())`).
  Future<TeamDetailDto> updateTeam(String slug, TeamRequest request) {
    return _teamsClient.updateTeam(teamSlug: slug, body: request);
  }

  /// Change l'adresse de l'équipe ; l'ancienne y redirige. `SLUG_TAKEN`,
  /// `INVALID_SLUG`.
  Future<TeamDetailDto> changeTeamSlug(String slug, String newSlug) {
    return _teamsClient.changeTeamSlug(
      teamSlug: slug,
      body: SlugChangeRequest(slug: newSlug),
    );
  }

  /// Supprime l'équipe. Refusé pour une équipe venue de biketeam
  /// (`MIGRATED_TEAM`).
  Future<void> deleteTeam(String slug) {
    return _teamsClient.deleteTeam(teamSlug: slug);
  }

  /// Ce que ferait un changement de fuseau, sans rien écrire (ledger
  /// `API-60`) : les rendez-vous à venir sans lieu de départ gardent leur
  /// heure murale, les passés leur instant.
  Future<TeamTimezoneChangePreviewDto> previewTimezoneChange(
    String slug,
    String timezone,
  ) {
    return _teamsClient.previewTeamTimezoneChange(
      teamSlug: slug,
      timezone: timezone,
    );
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

  /// Change le rôle d'un membre (docs/LEDGER_*.md MOB-167), administration
  /// de l'équipe seulement.
  ///
  /// **[userId] est l'identifiant de la personne** (`member.user.id`), pas
  /// celui de l'adhésion (`member.id`) : c'est ce que le chemin
  /// `…/members/{memberId}` attend, malgré son nom. `LAST_ADMIN` si le
  /// changement laisserait l'équipe sans personne pour l'administrer.
  Future<MemberDto> updateMemberRole(
    String slug, {
    required String userId,
    required TeamRole role,
  }) {
    return _teamMembersClient.updateMemberRole(
      teamSlug: slug,
      memberId: userId,
      body: UpdateMemberRoleRequest(role: role.toJson()),
    );
  }

  /// Retire un membre de l'équipe. [userId] est, là aussi, l'identifiant de
  /// la **personne** (`member.user.id`). `LAST_ADMIN` pour la dernière
  /// personne qui administre l'équipe.
  Future<void> removeMember(String slug, {required String userId}) {
    return _teamMembersClient.removeMember(teamSlug: slug, memberId: userId);
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
