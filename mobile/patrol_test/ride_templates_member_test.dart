import 'common.dart';

/// Web counterpart: none — the ride template pages are organizers-only on the server
/// (`RideTemplateAccessChecker`).
/// In the app (ledger `MOB-78`), a plain member who opens the list or the form by hand reads the
/// organizers-only refusal rather than a screen that would end in a 403.
///
/// Written, not yet run (ledger `MOB-77`).
void main() {
  testApp(
    'A plain member gets a refusal from the templates list and from the new template form',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Modele refus owner');
      final member = await backend.newUser('Modele refus membre');
      final team = await backend.newTeam(owner, 'Equipe modele refus');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);

      await openAppSignedIn($, member);
      await openLink($, Paths.rideTemplates(teamSlug));
      expect(await modules.rideTemplates.showsForbidden(), isTrue);

      await openLink($, Paths.rideTemplateNew(teamSlug));
      expect(await modules.rideTemplates.showsForbidden(), isTrue);
    },
  );
}
