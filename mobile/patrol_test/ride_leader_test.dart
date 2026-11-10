import 'common.dart';

/// Web counterpart: `flow-rides.e2e.ts` › regressions › « a ride whose group leader has left the
/// team… » (audit P0 #3). The app doesn't edit rides: what it owes that ride is to name the
/// leader the group still carries — on that group only, never the ride's creator — and to keep
/// its groups open to members.
void main() {
  testApp(
    'A group whose leader left the team still names them, and members join and switch groups',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Leader owner');
      final leader = await backend.newUser('Leader gone');
      final member = await backend.newUser('Leader member');
      final team = await backend.newTeam(owner, 'Equipe meneur');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, leader);
      await backend.addMember(teamSlug, member);
      final ride = await backend.newRide(
        owner,
        teamSlug,
        'Sortie sans son meneur',
        groups: [
          {'name': 'Groupe mene', 'leaderId': leader.id},
          {'name': 'Groupe libre'},
        ],
      );
      final rideSlug = ride['slug'] as String;
      final groups = (ride['groups'] as List).cast<Json>();
      final led = groups.firstWhere((g) => g['name'] == 'Groupe mene');
      final free = groups.firstWhere((g) => g['name'] == 'Groupe libre');
      final ledId = led['id'] as String;
      final freeId = free['id'] as String;

      await backend.leaveTeam(leader, teamSlug);

      await openAppSignedIn($, member);
      await openLink($, Paths.ride(teamSlug, rideSlug));
      await modules.ride.waitUntilShown();

      expect(await modules.ride.showsLeader(ledId, leader.displayName), isTrue);
      expect(modules.ride.groupShows(ledId, owner.displayName), isFalse);
      expect(await modules.ride.hasLeaderLine(freeId), isFalse);

      await modules.ride.join(ledId);
      expect(await backend.registeredGroupIds(member, teamSlug, rideSlug), [
        ledId,
      ]);

      // « Changer pour » on the other card: one call, no banner (ledger `MOB-134`, lot 8). The
      // card left behind then offers to switch back.
      await modules.ride.switchTo(freeId);
      await modules.ride.showGroup(ledId);
      expect(modules.ride.offersSwitch(ledId), isTrue);
      expect(modules.ride.offersJoin(ledId), isFalse);
      expect(await backend.registeredGroupIds(member, teamSlug, rideSlug), [
        freeId,
      ]);
    },
  );
}
