import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_membership_controller.dart';

import '../rides/ride_fixtures.dart';
import 'team_fixtures.dart';

/// Les détails d'entité portent des droits calculés pour le rôle de
/// l'appelant (docs/LEDGER_*.md MOB-137) : rejoindre ou quitter l'équipe les
/// relit, sans quoi une sortie déjà ouverte garderait ceux d'avant.
class _Teams implements TeamRepository {
  _Teams({required this.role});

  String? role;

  @override
  Future<TeamDetailDto> getTeam(String slug) async =>
      fixtureTeam(slug: slug, role: role);

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => const <TeamDetailDto>[];

  @override
  Future<MemberDto> joinTeam(String slug) async {
    role = 'MEMBER';
    return fixtureMember(index: 1);
  }

  @override
  Future<void> leaveTeam(String slug) async => role = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rides implements RideRepository {
  int getRideCalls = 0;

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async {
    getRideCalls++;
    return fixtureRide();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'sortie');

  for (final bool join in <bool>[true, false]) {
    test(
      join ? 'rejoindre relit la sortie' : 'quitter relit la sortie',
      () async {
        final _Rides rides = _Rides();
        final ProviderContainer container = ProviderContainer(
          retry: (int _, Object _) => null,
          overrides: [
            teamRepositoryProvider.overrideWithValue(
              _Teams(role: join ? null : 'MEMBER'),
            ),
            rideRepositoryProvider.overrideWithValue(rides),
          ],
        );
        addTearDown(container.dispose);
        container.listen(rideDetailProvider(key), (_, _) {});
        container.listen(
          teamMembershipControllerProvider('n-peloton'),
          (_, _) {},
        );
        await container.read(rideDetailProvider(key).future);
        while (!container
            .read(teamMembershipControllerProvider('n-peloton'))
            .team
            .hasValue) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(rides.getRideCalls, 1);

        final TeamMembershipController controller = container.read(
          teamMembershipControllerProvider('n-peloton').notifier,
        );
        await (join ? controller.join() : controller.leave());
        await container.read(rideDetailProvider(key).future);

        expect(rides.getRideCalls, 2);
      },
    );
  }
}
