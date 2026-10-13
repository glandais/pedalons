import 'common.dart';

/// The group page (ledger `MOB-67`): a ride's group card opens it, it names the designated leader
/// only — never the ride's creator —, joins from its action bar, shows the group's weather on its
/// Weather tab, and, registered in one group, does not offer to join another: the server allows one
/// group per ride.
void main() {
  testApp(
    'A group card opens its page, which names its leader, joins and shows its weather',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Group page owner');
      final leader = await backend.newUser('Group page leader');
      final member = await backend.newUser('Group page member');
      final team = await backend.newTeam(owner, 'Equipe page groupe');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, leader);
      await backend.addMember(teamSlug, member);
      final ride = await backend.newRide(
        owner,
        teamSlug,
        'Sortie page groupe',
        groups: [
          {'name': 'Groupe mene', 'leaderId': leader.id},
          {'name': 'Groupe libre'},
        ],
      );
      final rideSlug = ride['slug'] as String;
      final groups = (ride['groups'] as List).cast<Json>();
      final ledId =
          groups.firstWhere((g) => g['name'] == 'Groupe mene')['id'] as String;
      final freeId =
          groups.firstWhere((g) => g['name'] == 'Groupe libre')['id'] as String;

      await openAppSignedIn($, member);
      await openLink($, Paths.ride(teamSlug, rideSlug));
      await modules.ride.waitUntilShown();

      await modules.ride.openGroup(ledId);
      expect(modules.ride.groupPageShowsLeader(leader.displayName), isTrue);
      expect(modules.ride.groupPageShowsLeader(owner.displayName), isFalse);

      await modules.ride.joinFromGroupPage();
      expect(await backend.registeredGroupIds(member, teamSlug, rideSlug), [
        ledId,
      ]);

      // The other group: no leader, and no « Rejoindre » while registered here.
      await modules.ride.switchGroupPageTo(freeId);
      expect(modules.ride.groupPageHasLeader, isFalse);
      expect(modules.ride.groupPageSaysRegisteredElsewhere, isTrue);
      expect(modules.ride.groupPageOffersJoin, isFalse);

      await modules.ride.openGroupTab('weather');
      await modules.ride.waitUntilGroupWeatherIsShown();

      await modules.ride.closeGroup();
    },
  );
}
