import 'common.dart';

/// Web counterpart: `EditRidePage` redirects a plain member to the ride. In the app (ledger
/// `MOB-76`), a member reads the ride with no pencil, and an editor link opened by hand shows the
/// organizers-only refusal rather than a form that would end in a 403.
void main() {
  testApp(
    'A plain member gets no pencil on a ride and a refusal from its editor link',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Editeur refus owner');
      final member = await backend.newUser('Editeur refus membre');
      final team = await backend.newTeam(owner, 'Equipe refus');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);
      final ride = await backend.newRide(owner, teamSlug, 'Sortie gardee');
      final rideSlug = ride['slug'] as String;

      await openAppSignedIn($, member);
      await openLink($, Paths.ride(teamSlug, rideSlug));
      await modules.ride.waitUntilShown();
      expect(modules.rideEditor.offersEdit, isFalse);

      await openLink($, Paths.rideEdit(teamSlug, rideSlug));
      expect(await modules.rideEditor.showsForbidden(), isTrue);
    },
  );
}
