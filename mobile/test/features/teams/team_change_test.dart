import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_change.dart';
import 'package:pedalons/features/teams/providers/team_dashboard_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import '../rides/ride_fixtures.dart';
import 'team_fixtures.dart';

/// `notifyTeamChanged` (ledger `MOB-165`) : ce qu'une écriture sur l'équipe
/// fait relire.
class _Teams implements TeamRepository {
  int teamReads = 0;
  int myTeamsReads = 0;
  int dashboardReads = 0;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    teamReads++;
    return fixtureTeam(slug: slug, role: 'ADMIN');
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async {
    myTeamsReads++;
    return const <TeamDetailDto>[];
  }

  @override
  Future<TeamDashboardDto> getDashboard(String slug) async {
    dashboardReads++;
    throw StateError('sans importance');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rides implements RideRepository {
  int reads = 0;

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async {
    reads++;
    return fixtureRide();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const RideKey rideKey = RideKey(teamSlug: 'n-peloton', rideSlug: 'sortie');

  late _Teams teams;
  late _Rides rides;
  late ProviderContainer container;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    teams = _Teams();
    rides = _Rides();
    container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        teamRepositoryProvider.overrideWithValue(teams),
        rideRepositoryProvider.overrideWithValue(rides),
      ],
    );
    addTearDown(container.dispose);
    container.listen(teamDetailProvider('n-peloton'), (_, _) {});
    container.listen(teamDetailProvider('autre'), (_, _) {});
    container.listen(myTeamsProvider, (_, _) {});
    container.listen(
      teamDashboardProvider('n-peloton'),
      (_, _) {},
      onError: (_, _) {},
    );
    container.listen(rideDetailProvider(rideKey), (_, _) {});
    await settle();
    expect(teams.teamReads, 2);
    expect(teams.myTeamsReads, 1);
    expect(teams.dashboardReads, 1);
    expect(rides.reads, 1);
  });

  test('la fiche de cette équipe, « Mes équipes » et son tableau de bord '
      'sont relus ; pas le contenu', () async {
    notifyTeamChanged(container, 'n-peloton');
    await settle();

    // La fiche de l'autre équipe n'est pas relue.
    expect(teams.teamReads, 3);
    expect(teams.myTeamsReads, 2);
    expect(teams.dashboardReads, 2);
    expect(rides.reads, 1);
  });

  test('visibilité ou fuseau changé : les détails d\'entité aussi', () async {
    notifyTeamChanged(container, 'n-peloton', contentScopeChanged: true);
    await settle();

    expect(teams.teamReads, 3);
    expect(rides.reads, 2);
  });
}
