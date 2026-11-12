import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// Web counterpart: `rides.e2e.ts` › registration › « a GROUP_FULL answer rolls back and is
/// reported on that group », « a full group shows « Complet » and offers no way to join ».
///
/// The group fills up behind the screen: the page still offers « Rejoindre », the optimistic flip
/// meets a 409 `GROUP_FULL`, and the controller (`ride_registration_controller.dart`, `_fail`)
/// restores the ride as it was, says the failure inside that group's card, then refetches — after which that
/// card says « Complet » and the other group is still open. The failure outlives the refetch:
/// `adopt` keeps `failure`, and the page renders the refreshed value without a skeleton.
void main() {
  testApp(
    'A group that fills up while the ride page is open rolls back and says « Complet » for that group only',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Full owner');
      final rider = await backend.newUser('Full rider');
      final other = await backend.newUser('Full other');
      final team = await backend.newTeam(owner, 'Equipe complet');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, rider);
      await backend.addMember(teamSlug, other);
      final ride = await backend.newRideAt(
        owner,
        teamSlug,
        'Sortie qui se remplit',
        DateTime.now().add(const Duration(days: 2)),
        groups: [
          {'name': 'Groupe plein', 'maxParticipants': 1},
          {'name': 'Groupe libre'},
        ],
      );
      final rideSlug = ride['slug'] as String;
      final fullId = groupIdNamed(ride, 'Groupe plein');
      final freeId = groupIdNamed(ride, 'Groupe libre');

      await openAppSignedIn($, rider);
      await openLink($, Paths.ride(teamSlug, rideSlug));
      await modules.ride.waitUntilShown();
      expect(modules.ride.offersJoin(fullId), isTrue);
      expect(modules.ride.offersJoin(freeId), isTrue);

      // The last seat goes while the page is open.
      await backend.joinGroup(other, teamSlug, rideSlug, fullId);

      await modules.ride.tapJoin(fullId);
      // The failure is said inside that group's card (rule R6, KIT §9).
      expect(
        await modules.ride.waitUntilFailureOn(fullId, 'Groupe plein'),
        isTrue,
      );
      await modules.ride.waitUntilFull(fullId);
      expect(modules.ride.offersJoin(fullId), isFalse);
      expect(modules.ride.offersLeave(fullId), isFalse);
      expect(modules.ride.offersJoin(freeId), isTrue);

      // The refetch has settled, and the failure is still said.
      await modules.ride.settle();
      expect(modules.ride.showsFailure, isTrue);
      expect(modules.ride.offersFull(fullId), isTrue);
      expect(
        await backend.registeredGroupIds(rider, teamSlug, rideSlug),
        <String>[],
      );

      await modules.ride.join(freeId);
      expect(modules.ride.showsFailure, isFalse);
      expect(await backend.registeredGroupIds(rider, teamSlug, rideSlug), [
        freeId,
      ]);
    },
  );
}
