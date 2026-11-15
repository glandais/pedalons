import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-team.e2e.ts` › creating a team (`CreateTeamPage`).
///
/// In the app (ledger `MOB-165`): someone who belongs to no team creates one from « Mes équipes »,
/// becomes its administrator, and reaches « Gestion de l'équipe » from the team header. A second
/// creation is refused by the server — one administers one team at most
/// (`USER_TEAM_LIMIT_REACHED`) — and the form says so, keeping what was typed.
///
/// Written, not yet run (ledger `MOB-165`).
void main() {
  testApp(
    'A rider with no team creates one, administers it, and is refused a second one',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final rider = await backend.newUser('Team creator');
      final name = unique('Equipe creee');

      await openAppSignedIn($, rider);
      await modules.navigation.goToTeams();
      await modules.teams.waitUntilTeamsListIsShown();

      // No team yet: the empty state offers to create one.
      await modules.teamEditor.openFromEmptyTeams();

      // Without a name nothing leaves: the field says why, and no team exists.
      await modules.teamEditor.save();
      await modules.teamEditor.waitUntilErrorIsShown();
      expect(modules.teamEditor.nameShows('Entre 1 et 200 caractères'), isTrue);
      expect(await backend.myTeams(rider), isEmpty);

      // A name, classifieds switched off, and the team is created.
      await modules.teamEditor.enterName(name);
      await modules.teamEditor.toggleAds();
      await modules.teamEditor.save();
      await modules.teams.waitUntilTeamIsShown();

      final created = (await backend.myTeams(rider)).single;
      final slug = created['slug'] as String;
      expect(created['name'], name);
      expect(created['role'], 'ADMIN');
      expect(created['visibility'], 'TEAM');
      expect(created['enableAds'], isFalse);
      expect(created['enableRides'], isTrue);
      expect(created['enableMemberDirectory'], isFalse);
      expect(created['postsAsTeamByDefault'], isTrue);

      // Its creator is a member — « Quitter », not « Rejoindre » — and administers it.
      expect(modules.teams.offersLeave, isTrue);
      expect(modules.teamAdmin.offeredInHeader, isTrue);
      await modules.teamAdmin.openFromHeader();
      expect(modules.teamAdmin.showsOrganizerRows, isTrue);
      expect(modules.teamAdmin.showsAdminRows, isTrue);

      // « Mes équipes » lists the new team, with the creator's real role.
      await openLink($, Paths.teams());
      await modules.teams.waitUntilTeamsListIsShown();
      await modules.teams.waitUntilShowsMyTeam(slug);
      expect(modules.teams.myTeamShowsRole(slug, 'Administrateur'), isTrue);

      // A second team: the server refuses, the banner says why, the name stays.
      final second = unique('Equipe refusee');
      await modules.teamEditor.openFromTeamsBar();
      await modules.teamEditor.enterName(second);
      await modules.teamEditor.save();
      await modules.teamEditor.waitUntilErrorIsShown();
      expect(
        modules.teamEditor.errorShows('Vous administrez déjà une équipe'),
        isTrue,
      );
      expect(modules.teamEditor.name, second);
      expect((await backend.myTeams(rider)).length, equals(1));
    },
  );
}
