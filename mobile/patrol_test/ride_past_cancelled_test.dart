import 'api/ride_detail_seed.dart';
import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// Web counterparts: `rides.e2e.ts` › a past ride › « a ride of yesterday says « Terminée » and
/// offers no « Rejoindre » in any group », and `flow-rides.e2e.ts` › « an organizer cancels a
/// published ride: it says « Annulé » and takes no more registrations ».
///
/// « Terminée » is judged by the app on the device's clock — once the ride is back
/// (`ridePhase`, ledger `MOB-134`) —, the API keeping the ride `PUBLISHED`. A cancelled ride
/// offers nothing, **not even « Quitter »** — nor « J'y vais » — to a rider still registered in
/// it (`rideGroupAction`, `rideRegistrationControlAction`). The cancelled ride here has a single
/// group: its detail is the group's page, « Personnes inscrites » in place of a card.
void main() {
  testApp(
    'A past ride says « Terminée » and offers no group action; a cancelled one shows its banner and not even « Quitter »',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Past owner');
      final member = await backend.newUser('Past member');
      final team = await backend.newTeam(owner, 'Equipe sorties passees');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);

      final past = await backend.newRideAt(
        owner,
        teamSlug,
        'Sortie passee',
        DateTime.now().subtract(const Duration(days: 1)),
        groups: [
          {'name': 'Groupe A', 'maxParticipants': 10},
          {'name': 'Groupe B', 'maxParticipants': 10},
        ],
      );
      expect(past['status'], 'PUBLISHED');
      final pastGroups = [
        groupIdNamed(past, 'Groupe A'),
        groupIdNamed(past, 'Groupe B'),
      ];

      final cancelled = await backend.newRide(
        owner,
        teamSlug,
        'Sortie annulee',
      );
      final cancelledSlug = cancelled['slug'] as String;
      final cancelledGroup = groupIdNamed(cancelled, 'Groupe A');
      await backend.joinGroup(member, teamSlug, cancelledSlug, cancelledGroup);
      await backend.cancelRide(owner, teamSlug, cancelledSlug);

      await openAppSignedIn($, member);
      await openLink($, Paths.ride(teamSlug, past['slug'] as String));
      await modules.ride.waitUntilShown();
      expect(modules.ride.title, past['name']);
      expect(modules.ride.saysFinished, isTrue);
      expect(modules.ride.saysCancelled, isFalse);
      for (final groupId in pastGroups) {
        await modules.ride.showGroup(groupId);
        expect(modules.ride.offersAnyAction(groupId), isFalse);
      }

      await openLink($, Paths.home());
      await modules.home.waitUntilShown();
      await openLink($, Paths.ride(teamSlug, cancelledSlug));
      await modules.ride.waitUntilCancelled();
      expect(modules.ride.title, cancelled['name']);
      expect(modules.ride.saysFinished, isFalse);
      await modules.ride.showGroup(cancelledGroup);
      // Still registered per the API, and yet no « Quitter »: the ride no longer takes place.
      expect(
        await backend.registeredGroupIds(member, teamSlug, cancelledSlug),
        [cancelledGroup],
      );
      expect(modules.ride.offersAnyAction(cancelledGroup), isFalse);
    },
  );
}
