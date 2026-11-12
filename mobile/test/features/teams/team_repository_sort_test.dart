import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/domain/member_filters.dart';
import 'package:pedalons/features/teams/domain/team_discovery_filters.dart';

import 'team_fixtures.dart';

/// Retient les paramètres que les listes d'équipes envoient, et sert
/// [total] équipes par pages.
class _RecordingTeamsClient implements TeamsClient {
  _RecordingTeamsClient({this.total = 0});

  final int total;
  TeamSortBy? sortBy;
  SortDirection? sortDir;
  MinRole? minRole;
  final List<int> pages = <int>[];

  @override
  Future<TeamListResponse> listTeams({
    int? page = 0,
    int? size = 20,
    bool? joinable,
    MinRole? minRole,
    String? search,
    TeamSortBy? sortBy,
    SortDirection? sortDir,
  }) async {
    this.sortBy = sortBy;
    this.sortDir = sortDir;
    this.minRole = minRole;
    pages.add(page!);
    final int start = page * size!;
    final int end = (start + size).clamp(0, total);
    return TeamListResponse(
      teams: <TeamDetailDto>[
        for (int i = start; i < end; i++)
          fixtureTeam(slug: 'team-$i', name: 'Équipe $i', role: 'MEMBER'),
      ],
      total: total,
      page: page,
      size: size,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Retient l'ordre que l'annuaire des membres demande.
class _RecordingMembersClient implements TeamMembersClient {
  MemberSortBy? sortBy;
  SortDirection? sortDir;

  @override
  Future<MemberListResponse> getMembers({
    required String teamSlug,
    TeamRole? role,
    String? search,
    MemberSortBy? sortBy,
    SortDirection? sortDir,
    int? page = 0,
    int? size = 50,
  }) async {
    this.sortBy = sortBy;
    this.sortDir = sortDir;
    return const MemberListResponse(
      members: <MemberDto>[],
      total: 0,
      page: 0,
      size: 50,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Règle RL5 des listes (KIT §10) : les équipes selon la portée — par nom sous
/// « Membre », par nombre de membres sous « Toutes » —, les membres par nom.
/// L'écran annonce l'ordre (`docs/LEDGER_*.md API-13`) ; ces tests garantissent
/// qu'il le demande.
void main() {
  test(
    'la découverte demande le tri par nombre de membres, décroissant',
    () async {
      final _RecordingTeamsClient client = _RecordingTeamsClient();
      await TeamRepository(
        client,
        _RecordingMembersClient(),
      ).fetchTeams(filters: const TeamDiscoveryFilters());

      expect(client.sortBy, TeamSortBy.memberCount);
      expect(client.sortDir, SortDirection.desc);
      expect(
        const TeamDiscoveryFilters().sortBy,
        TeamSortBy.memberCount,
        reason: 'l\'écran annonce l\'ordre qu\'il demande',
      );
    },
  );

  test('la découverte sous « Mes équipes » trie par nom, de A à Z', () async {
    final _RecordingTeamsClient client = _RecordingTeamsClient();
    const TeamDiscoveryFilters mine = TeamDiscoveryFilters(
      scope: TeamDiscoveryScope.mine,
    );
    await TeamRepository(
      client,
      _RecordingMembersClient(),
    ).fetchTeams(filters: mine);

    expect(client.sortBy, TeamSortBy.name);
    expect(client.sortDir, SortDirection.asc);
    expect(mine.sortBy, TeamSortBy.name);
  });

  test('« Mes équipes » trie par nom, de A à Z', () async {
    final _RecordingTeamsClient client = _RecordingTeamsClient();
    await TeamRepository(client, _RecordingMembersClient()).fetchMyTeams();

    expect(client.minRole, MinRole.member);
    expect(client.sortBy, TeamSortBy.name);
    expect(client.sortDir, SortDirection.asc);
  });

  test('mes équipes transverses ne s\'arrêtent pas à une page', () async {
    final _RecordingTeamsClient client = _RecordingTeamsClient(
      total: kMyTeamsBatchSize + 30,
    );
    final List<TeamDetailDto> teams = await TeamRepository(
      client,
      _RecordingMembersClient(),
    ).getMyTeams();

    expect(teams, hasLength(kMyTeamsBatchSize + 30));
    expect(client.pages, <int>[0, 1]);
    expect(client.sortBy, TeamSortBy.name);
    expect(client.sortDir, SortDirection.asc);
  });

  test('les membres sont demandés par nom, de A à Z', () async {
    final _RecordingMembersClient members = _RecordingMembersClient();
    await TeamRepository(
      _RecordingTeamsClient(),
      members,
    ).fetchMembers(filters: const MemberFilters(teamSlug: 'vcm'));

    expect(members.sortBy, MemberSortBy.name);
    expect(members.sortDir, SortDirection.asc);
  });
}
