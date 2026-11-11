import 'common.dart';

/// Web counterpart: the anonymous reader of `private-team-public-content.e2e.ts` (ledger
/// `WEB-166`). A private team that a platform admin allowed to publish by link
/// (`publicContentAllowed`) shares one public ride: someone signed in who is not a member reads
/// it, with neither registration nor names, and no way into the team — which would only answer
/// « Équipe indisponible ». Going back leads to the teams tab, not to a rebuilt team page
/// (docs/LEDGER_*.md MOB-137).
void main() {
  testApp(
    'A non-member opens the link of a public ride of a private team, and goes back to the teams tab',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Link owner');
      final outsider = await backend.newUser('Link outsider');
      final team = await backend.newTeam(
        owner,
        'Equipe privee par lien',
        publicContentAllowed: true,
      );
      final teamSlug = team['slug'] as String;
      final ride = await backend.newRide(
        owner,
        teamSlug,
        'Sortie par lien',
        visibility: 'PUBLIC',
      );

      await openAppSignedIn($, outsider);
      await openLink($, Paths.ride(teamSlug, ride['slug'] as String));
      await modules.ride.waitUntilShown();
      final title = modules.ride.title;
      final notMember = modules.ride.saysNotMember;
      final offersTeam = modules.ride.offersTeam;

      await modules.ride.goBack();
      await modules.teams.waitUntilTeamsListIsShown();

      expect(title, ride['name']);
      expect(notMember, isTrue);
      expect(offersTeam, isFalse);
      expect(modules.teams.showsLoadError, isFalse);
    },
  );
}
