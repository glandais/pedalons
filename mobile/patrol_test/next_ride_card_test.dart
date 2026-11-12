import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// Web counterpart: none written — audit P2 « Sorties : « Quitter » depuis la carte « Ma
/// prochaine sortie » »; nearest is `rides.e2e.ts` › registration.
///
/// Guarantee: « Ma prochaine sortie » follows every registration change made in the app. Both
/// registration controllers end a successful call with `notifyParticipationChanged`
/// (`rides/providers/participation_changes.dart`), which invalidates `nextRideProvider` — and that
/// provider now fetches the participation itself, so invalidating it re-reads which ride is next.
/// After « Se désinscrire » on the card, the card goes; after joining from the ride page, it comes
/// back without a pull-to-refresh.
void main() {
  testApp(
    '« Ma prochaine sortie » follows a leave from its own card and a join from the ride page',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Next owner');
      final member = await backend.newUser('Next member');
      final team = await backend.newTeam(owner, 'Equipe prochaine');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);
      final ride = await backend.newRideAt(
        owner,
        teamSlug,
        'Sortie de la semaine',
        DateTime.now().add(const Duration(days: 2)),
        groups: [
          {'name': 'Groupe unique'},
        ],
      );
      final rideSlug = ride['slug'] as String;
      final groupId = groupIdNamed(ride, 'Groupe unique');
      await backend.joinGroup(member, teamSlug, rideSlug, groupId);

      await openAppSignedIn($, member);
      await modules.home.waitUntilNextRideIs(rideSlug);
      expect(
        modules.home.nextRideShows(rideSlug, ride['name'] as String),
        isTrue,
      );
      expect(modules.home.nextRideGroupLineShows('Groupe unique'), isTrue);
      expect(modules.home.nextRideOffersLeave, isTrue);

      await modules.home.leaveNextRide();
      await eventually(
        () => backend.registeredGroupIds(member, teamSlug, rideSlug),
        until: (List<String> ids) => ids.isEmpty,
        description: 'the registration to be withdrawn',
        timeout: const Duration(seconds: 15),
      );
      await modules.home.waitUntilNoNextRide();
      expect(modules.home.showsNextRide(rideSlug), isFalse);

      await openLink($, Paths.ride(teamSlug, rideSlug));
      await modules.ride.waitUntilShown();
      await modules.ride.join(groupId);
      expect(await backend.registeredGroupIds(member, teamSlug, rideSlug), [
        groupId,
      ]);

      // The link pushed the ride above the tab shell: a link to the home brings the tabs back.
      await openLink($, Paths.home());
      await modules.home.waitUntilShown();
      await modules.home.waitUntilNextRideIs(
        rideSlug,
        timeout: const Duration(seconds: 15),
      );
      expect(modules.home.nextRideOffersLeave, isTrue);
    },
  );
}
