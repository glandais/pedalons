import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-team.e2e.ts` › team settings (`TeamSettingsPage`).
///
/// In the app (ledger `MOB-166`): a team's administrator reaches « Paramètres » from the hub
/// « Gestion de l'équipe », renames the team and switches a module off — the rest of the team is
/// written back untouched —, makes it private after the confirmation, changes its address, is
/// refused a webhook that is not a public https address, and deletes the team. A plain member
/// reads a refusal from the same link.
///
/// Written, not yet run (ledger `MOB-166`).
void main() {
  testApp(
    'A team administrator edits the settings, makes the team private, renames its address and deletes it',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Settings owner');
      final team = await backend.newTeam(
        owner,
        'Equipe reglages',
        visibility: 'PUBLIC',
      );
      final slug = team['slug'] as String;
      final renamed = unique('Equipe renommee');

      await openAppSignedIn($, owner);
      await openLink($, Paths.team(slug));
      await modules.teams.waitUntilTeamIsShown();

      // The hub's « Paramètres » row opens the app's screen, pre-filled.
      await modules.teamAdmin.openFromHeader();
      await modules.teamAdmin.openSettings();
      await modules.teamEditor.waitUntilShown();
      expect(modules.teamEditor.name, team['name']);
      expect(modules.teamEditor.slugShows(slug), isTrue);

      // A new team's administrators may not change its visibility: it is only read.
      expect(await modules.teamEditor.visibilityIsReadOnly(), isTrue);

      // A new name, classifieds off: the PUT rewrites the team, and nothing else moved.
      await modules.teamEditor.enterName(renamed);
      await modules.teamEditor.toggleAds();
      await modules.teamEditor.save();
      await modules.teams.waitUntilTeamIsShown();

      var saved = await backend.team(owner, slug);
      expect(saved['name'], renamed);
      expect(saved['enableAds'], isFalse);
      expect(saved['enableRides'], isTrue);
      expect(saved['enableMemberDirectory'], isTrue);
      expect(saved['visibility'], 'PUBLIC');
      expect(saved['timezone'], team['timezone']);
      expect(
        (saved['about'] as Json)['markdown'],
        (team['about'] as Json)['markdown'],
      );

      // Once the platform lets its administrators change the visibility, going private asks first.
      await backend.allowVisibilityEdit(team);
      await openLink($, Paths.teamSettings(slug));
      await modules.teamEditor.waitUntilShown();
      expect(await modules.teamEditor.visibilityIsReadOnly(), isFalse);
      await modules.teamEditor.pickVisibility('TEAM');
      await modules.teamEditor.save();
      expect(
        await modules.teamEditor.confirmationShows('Équipe uniquement'),
        isTrue,
      );
      // Nothing is written before the confirmation.
      expect((await backend.team(owner, slug))['visibility'], 'PUBLIC');
      await modules.teamEditor.confirm();
      await modules.teams.waitUntilTeamIsShown();
      saved = await backend.team(owner, slug);
      expect(saved['visibility'], 'TEAM');
      expect(saved['name'], renamed);

      // The address has its own call; the screen comes back on the new one.
      final newSlug = unique('equipe-adresse')
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9]+'), '-');
      await openLink($, Paths.teamSettings(slug));
      await modules.teamEditor.waitUntilShown();
      await modules.teamEditor.changeSlug(newSlug);
      await modules.teamEditor.waitUntilShown();
      expect(modules.teamEditor.slugShows(newSlug), isTrue);
      expect((await backend.team(owner, newSlug))['name'], renamed);

      // A webhook that is not a public https address is refused, and nothing is saved.
      await modules.teamEditor.openWebhook();
      expect(modules.teamEditor.webhookIsConfigured, isFalse);
      await modules.teamEditor.enterWebhookUrl('http://localhost/hook');
      await modules.teamEditor.saveWebhook();
      expect(
        await modules.teamEditor.webhookErrorShows(
          'webhook n\'est pas acceptée',
        ),
        isTrue,
      );
      expect(
        (await backend.get(owner, '/api/teams/$newSlug/webhook'))['configured'],
        isFalse,
      );
      await modules.teamEditor.closeWebhook();

      // Deleting the team asks first, then leads back to « Mes équipes », without it.
      await openLink($, Paths.teamSettings(newSlug));
      await modules.teamEditor.waitUntilShown();
      await modules.teamEditor.delete();
      expect(await modules.teamEditor.confirmationShows(renamed), isTrue);
      expect((await backend.myTeams(owner)).length, equals(1));
      await modules.teamEditor.confirm();
      await modules.teams.waitUntilTeamsListIsShown();
      expect(await backend.myTeams(owner), isEmpty);
    },
  );

  testApp('A plain member is refused the team settings', (
    $,
    modules,
    apiClients,
  ) async {
    final backend = apiClients.backend;
    final owner = await backend.newUser('Settings admin');
    final member = await backend.newUser('Settings member');
    final team = await backend.newTeam(owner, 'Equipe reglages refus');
    final slug = team['slug'] as String;
    await backend.addMember(slug, member);

    await openAppSignedIn($, member);
    await openLink($, Paths.team(slug));
    await modules.teams.waitUntilTeamIsShown();
    // No « Gérer l'équipe » for a member, and the link itself is refused.
    expect(modules.teamAdmin.offeredInHeader, isFalse);

    await openLink($, Paths.teamSettings(slug));
    expect(await modules.teamEditor.showsForbidden(), isTrue);
    expect((await backend.team(owner, slug))['name'], team['name']);
  });
}
