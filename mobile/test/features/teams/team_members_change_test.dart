import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/domain/member_filters.dart';
import 'package:pedalons/features/teams/providers/team_members_provider.dart';

import 'team_fixtures.dart';

/// Ce qu'une liste de membres fait d'un changement qui touche une personne
/// **absente des pages chargées** (ledger `MOB-167`, revue du lot 4) : pas de
/// ligne à reporter, mais un total qui ne doit pas rester d'avant.
class _Teams implements TeamRepository {
  _Teams(this.total);

  int total;
  final List<({int page, TeamRole? role, String? search})> calls =
      <({int page, TeamRole? role, String? search})>[];

  @override
  Future<PageResult<MemberDto>> fetchMembers({
    required MemberFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    calls.add((page: page, role: filters.role, search: filters.search));
    final int offset = page * size;
    return PageResult<MemberDto>(
      items: fixtureMembers((total - offset).clamp(0, size), from: offset),
      total: total,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<(ProviderContainer, _Teams)> open(
    MemberFilters filters, {
    required int total,
  }) async {
    final _Teams teams = _Teams(total);
    final ProviderContainer container = ProviderContainer(
      overrides: [teamRepositoryProvider.overrideWithValue(teams)],
    );
    addTearDown(container.dispose);
    container.listen(teamMembersProvider(filters), (_, _) {});
    await pumpEventQueue();
    return (container, teams);
  }

  const MemberFilters all = MemberFilters(teamSlug: 'n-peloton');

  test('une personne retirée qui n\'est pas chargée : le total perd un, sans '
      'requête', () async {
    final (ProviderContainer container, _Teams teams) = await open(
      all,
      total: 45,
    );
    expect(container.read(teamMembersProvider(all)).total, 45);

    // « u40 » est sur la troisième page, pas encore lue.
    teams.total = 44;
    notifyTeamMembersChanged(
      container,
      const TeamMembersChange.removed('n-peloton', userId: 'u40'),
    );
    await pumpEventQueue();

    final PagedListState<MemberDto> state = container.read(
      teamMembersProvider(all),
    );
    expect(state.total, 44);
    expect(state.items, hasLength(20));
    expect(teams.calls, hasLength(1));
  });

  test('sous un filtre, on ne sait pas si elle en faisait partie : la liste '
      'est relue', () async {
    const MemberFilters searched = MemberFilters(
      teamSlug: 'n-peloton',
      search: 'membre',
    );
    final (ProviderContainer container, _Teams teams) = await open(
      searched,
      total: 45,
    );

    teams.total = 44;
    notifyTeamMembersChanged(
      container,
      const TeamMembersChange.removed('n-peloton', userId: 'u40'),
    );
    await pumpEventQueue();

    expect(teams.calls.map((c) => c.page), <int>[0, 0]);
    expect(container.read(teamMembersProvider(searched)).total, 44);
  });

  test('une liste entièrement lue qui ne la montre pas ne la comptait pas : '
      'rien ne change', () async {
    final (ProviderContainer container, _Teams teams) = await open(
      all,
      total: 5,
    );

    notifyTeamMembersChanged(
      container,
      const TeamMembersChange.removed('n-peloton', userId: 'u40'),
    );
    await pumpEventQueue();

    expect(container.read(teamMembersProvider(all)).total, 5);
    expect(teams.calls, hasLength(1));
  });

  test(
    'sous un filtre de rôle, un changement de rôle sur une page pas '
    'encore lue : la personne en sort peut-être, la liste est relue',
    () async {
      const MemberFilters members = MemberFilters(
        teamSlug: 'n-peloton',
        role: TeamRole.member,
      );
      final (ProviderContainer container, _Teams teams) = await open(
        members,
        total: 45,
      );

      teams.total = 44;
      notifyTeamMembersChanged(
        container,
        const TeamMembersChange.roleChanged(
          'n-peloton',
          userId: 'u40',
          role: TeamRole.organizer,
        ),
      );
      await pumpEventQueue();

      expect(teams.calls.map((c) => c.page), <int>[0, 0]);
      expect(container.read(teamMembersProvider(members)).total, 44);
    },
  );

  test('sans filtre de rôle, un changement de rôle sur une page pas encore '
      'lue ne change rien à la liste', () async {
    final (ProviderContainer container, _Teams teams) = await open(
      all,
      total: 45,
    );

    notifyTeamMembersChanged(
      container,
      const TeamMembersChange.roleChanged(
        'n-peloton',
        userId: 'u40',
        role: TeamRole.organizer,
      ),
    );
    await pumpEventQueue();

    expect(teams.calls, hasLength(1));
    expect(container.read(teamMembersProvider(all)).total, 45);
  });
}
