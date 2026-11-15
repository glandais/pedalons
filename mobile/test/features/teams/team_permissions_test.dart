import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/domain/team_permissions.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import 'team_fixtures.dart';

/// Les droits d'équipe (ledger `MOB-165`) : la règle de `teamAccess.ts`, et
/// des providers qui lisent la **fiche**, pas « Mes équipes ».
class _Teams implements TeamRepository {
  _Teams({this.role, this.fail = false});

  final String? role;
  final bool fail;
  int myTeamsReads = 0;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    if (fail) throw StateError('indisponible');
    return fixtureTeam(slug: slug, role: role);
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async {
    myTeamsReads++;
    return const <TeamDetailDto>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Rights = ({bool? organizer, bool? admin, _Teams teams});

void main() {
  group('la règle', () {
    test('organisateur : ORGANIZER, ADMIN ou admin de plateforme', () {
      expect(isTeamOrganizer(teamRole: null), isFalse);
      expect(isTeamOrganizer(teamRole: TeamRole.member), isFalse);
      expect(isTeamOrganizer(teamRole: TeamRole.organizer), isTrue);
      expect(isTeamOrganizer(teamRole: TeamRole.admin), isTrue);
      expect(isTeamOrganizer(teamRole: null, platformAdmin: true), isTrue);
    });

    test('administrateur : ADMIN ou admin de plateforme', () {
      expect(isTeamAdmin(teamRole: null), isFalse);
      expect(isTeamAdmin(teamRole: TeamRole.member), isFalse);
      expect(isTeamAdmin(teamRole: TeamRole.organizer), isFalse);
      expect(isTeamAdmin(teamRole: TeamRole.admin), isTrue);
      expect(isTeamAdmin(teamRole: null, platformAdmin: true), isTrue);
    });

    test('un rôle inconnu de cette version n\'ouvre rien', () {
      expect(isTeamOrganizer(teamRole: TeamRole.$unknown), isFalse);
      expect(isTeamAdmin(teamRole: TeamRole.$unknown), isFalse);
    });

    test('teamRoleOf lit le rôle réel de la fiche', () {
      expect(teamRoleOf(fixtureTeam()), isNull);
      expect(teamRoleOf(fixtureTeam(role: 'ADMIN')), TeamRole.admin);
      expect(teamRoleOf(fixtureTeam(role: 'OWNER')), TeamRole.$unknown);
    });
  });

  group('les providers', () {
    Future<_Rights> read({
      String? role,
      bool platformAdmin = false,
      bool fail = false,
    }) async {
      final _Teams teams = _Teams(role: role, fail: fail);
      final ProviderContainer container = ProviderContainer(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
      );
      addTearDown(container.dispose);
      container.listen(isTeamOrganizerProvider('n-peloton'), (_, _) {});
      container.listen(isTeamAdminProvider('n-peloton'), (_, _) {});
      // Tant que la fiche charge : ni oui, ni non.
      expect(container.read(isTeamOrganizerProvider('n-peloton')), isNull);
      expect(container.read(isTeamAdminProvider('n-peloton')), isNull);
      try {
        await container.read(teamDetailProvider('n-peloton').future);
      } on StateError {
        // L'échec de la fiche : les droits restent indéterminés.
      }
      return (
        organizer: container.read(isTeamOrganizerProvider('n-peloton')),
        admin: container.read(isTeamAdminProvider('n-peloton')),
        teams: teams,
      );
    }

    test('membre : ni organisateur ni administrateur', () async {
      final _Rights r = await read(role: 'MEMBER');
      expect(r.organizer, isFalse);
      expect(r.admin, isFalse);
    });

    test('organisateur : organisateur, pas administrateur', () async {
      final _Rights r = await read(role: 'ORGANIZER');
      expect(r.organizer, isTrue);
      expect(r.admin, isFalse);
    });

    test('administrateur : les deux', () async {
      final _Rights r = await read(role: 'ADMIN');
      expect(r.organizer, isTrue);
      expect(r.admin, isTrue);
    });

    test('admin de plateforme non membre : les deux, sans lire « Mes '
        'équipes »', () async {
      final _Rights r = await read(platformAdmin: true);
      expect(r.organizer, isTrue);
      expect(r.admin, isTrue);
      expect(r.teams.myTeamsReads, 0);
    });

    test('hors de l\'équipe : rien', () async {
      final _Rights r = await read();
      expect(r.organizer, isFalse);
      expect(r.admin, isFalse);
    });

    test('fiche en échec : indéterminé', () async {
      final _Rights r = await read(role: 'ADMIN', fail: true);
      expect(r.organizer, isNull);
      expect(r.admin, isNull);
    });
  });
}
