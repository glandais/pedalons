import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/features/profile/data/profile_repository.dart';
import 'package:pedalons/features/profile/providers/profile_summary_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import '../teams/team_fixtures.dart';

/// « Mes équipes » s'ouvre par un changement d'onglet : aucun retour de
/// sous-page ne relit le résumé. C'est un changement de mes équipes
/// (`myTeamsProvider` invalidé après avoir rejoint ou quitté) qui doit le
/// faire — et seulement un vrai changement, pas chaque relecture.

class _FakeProfileRepository implements ProfileRepository {
  int summaryCalls = 0;

  @override
  Future<ProfileSummaryDto> profileSummary() async {
    summaryCalls++;
    return const ProfileSummaryDto(
      teams: <ProfileTeamDto>[],
      passkeyCount: 0,
      pairedDevices: <PairedDeviceDto>[],
      blockedUserCount: 0,
      notifications: ProfileNotificationSummaryDto(
        channels: <NotificationChannel>[],
        enabledChannels: <NotificationChannel>[],
        emailDigest: false,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTeamRepository implements TeamRepository {
  List<TeamDetailDto> teams = fixtureTeams(1);

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => teams;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeProfileRepository profile;
  late _FakeTeamRepository teams;
  late ProviderContainer container;

  setUp(() async {
    profile = _FakeProfileRepository();
    teams = _FakeTeamRepository();
    container = ProviderContainer(
      overrides: [
        accessTokenHolderProvider.overrideWith((Ref ref) => 'token'),
        profileRepositoryProvider.overrideWithValue(profile),
        teamRepositoryProvider.overrideWithValue(teams),
      ],
    );
    addTearDown(container.dispose);
    container.listen(profileSummaryProvider, (_, _) {});
    await container.read(profileSummaryProvider.future);
    await container.read(myTeamsProvider.future);
  });

  Future<void> reloadTeams() async {
    container.invalidate(myTeamsProvider);
    await container.read(myTeamsProvider.future);
    await container.read(profileSummaryProvider.future);
  }

  test('rejoindre une équipe relit le résumé du profil', () async {
    expect(profile.summaryCalls, 1);

    teams.teams = fixtureTeams(2);
    await reloadTeams();

    expect(profile.summaryCalls, 2);
  });

  test(
    'une relecture de mes équipes sans changement ne le relit pas',
    () async {
      teams.teams = fixtureTeams(1);
      await reloadTeams();

      expect(profile.summaryCalls, 1);
    },
  );
}
