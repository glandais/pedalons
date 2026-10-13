import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// A ride with a single group (ledger `MOB-69`): its detail is the group's page. No group card and
/// no group page — « Rejoindre » and « Quitter » are in the detail's action bar, and a link to the
/// group's page (shared before, or from the web) lands on the ride.
///
/// Web counterpart: ledger `WEB-79`.
void main() {
  testApp(
    'A single-group ride joins and leaves from its action bar, and a group link opens the ride',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Solo owner');
      final member = await backend.newUser('Solo member');
      final team = await backend.newTeam(owner, 'Equipe sortie solo');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);
      final ride = await backend.newRide(owner, teamSlug, 'Sortie solo');
      final rideSlug = ride['slug'] as String;
      final groupId = groupIdNamed(ride, 'Groupe A');

      await openAppSignedIn($, member);
      await openLink($, Paths.ride(teamSlug, rideSlug));
      await modules.ride.waitUntilShown();
      expect(await modules.ride.isSoloGroupRide(), isTrue);

      await modules.ride.join(groupId);
      expect(await backend.registeredGroupIds(member, teamSlug, rideSlug), [
        groupId,
      ]);
      await modules.ride.leave(groupId);
      expect(
        await backend.registeredGroupIds(member, teamSlug, rideSlug),
        isEmpty,
      );

      // The group's own link: the ride, not a page of its own.
      await openLink($, Paths.home());
      await modules.home.waitUntilShown();
      await openLink($, Paths.rideGroup(teamSlug, rideSlug, groupId));
      await modules.ride.waitUntilShown();
      expect(modules.ride.title, ride['name']);
      expect(await modules.ride.isSoloGroupRide(), isTrue);
    },
  );
}
