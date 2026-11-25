import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-team.e2e.ts` › team pages (`TeamPagesAdminPage`, `TeamPageForm`).
///
/// In the app (ledger `MOB-169`): a team administrator reaches « Pages » from the hub, finds the
/// team's pages in its order, moves one up with the row's button (the site drags), adds a third
/// — a title is required; « Créer une page » is gone at three —, renames one (the update
/// rewrites the whole page: its text must survive), deletes one after the confirmation — a
/// member no longer reads it — and restores it. A plain member reads a refusal from the list's
/// link and from the editor's.
///
/// Written, not yet run (ledger `MOB-169`).
void main() {
  testApp(
    'An administrator reorders the team’s pages, adds a third, renames one, deletes one and restores it',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Pages admin owner');
      final member = await backend.newUser('Pages admin member');
      final team = await backend.newTeam(
        owner,
        'Equipe pages admin',
        visibility: 'PUBLIC',
      );
      final slug = team['slug'] as String;
      await backend.addMember(slug, member);
      final rulesTitle = unique('Règlement');
      final rules = await backend.newTeamPage(
        owner,
        slug,
        rulesTitle,
        markdown: 'Le texte du règlement',
      );
      final rulesId = rules['id'] as String;
      final rulesSlug = rules['slug'] as String;
      final faqTitle = unique('FAQ');
      final faq = await backend.newTeamPage(
        owner,
        slug,
        faqTitle,
        visibility: 'PUBLIC',
        markdown: 'Les questions fréquentes',
      );
      final faqId = faq['id'] as String;
      final faqSlug = faq['slug'] as String;

      await openAppSignedIn($, owner);
      await openLink($, Paths.team(slug));
      await modules.teams.waitUntilTeamIsShown();
      await modules.teamAdmin.openFromHeader();
      await modules.teamAdmin.openPages();
      await modules.teamPagesAdmin.waitUntilShown();

      // Two pages, in the order they were created: the first has no way up, the last no way
      // down.
      await modules.teamPagesAdmin.waitUntilPageIsShown(rulesId);
      await modules.teamPagesAdmin.waitUntilPageIsShown(faqId);
      expect(modules.teamPagesAdmin.countShows('2 pages sur 3'), isTrue);
      expect(modules.teamPagesAdmin.pageShows(rulesId, rulesTitle), isTrue);
      expect(modules.teamPagesAdmin.isAbove(rulesId, faqId), isTrue);
      expect(modules.teamPagesAdmin.canMoveUp(rulesId), isFalse);
      expect(modules.teamPagesAdmin.canMoveDown(rulesId), isTrue);
      expect(modules.teamPagesAdmin.canMoveUp(faqId), isTrue);
      expect(modules.teamPagesAdmin.canMoveDown(faqId), isFalse);
      expect(modules.teamPagesAdmin.offersAdd, isTrue);

      // « Monter » the FAQ: it leads, on screen and for the server.
      await modules.teamPagesAdmin.moveUp(faqId, above: rulesId);
      final reordered = await eventually(
        () => backend.teamPages(owner, slug),
        until: (List<Json> pages) => pages.first['id'] == faqId,
        description: 'the FAQ first in the team’s pages',
      );
      expect(reordered.map((Json page) => page['id']), [faqId, rulesId]);

      // A third page: no title, the form says so and nothing is created.
      await modules.teamPagesAdmin.openNew();
      await modules.teamPagesAdmin.save();
      await modules.teamPagesAdmin.waitUntilEditorErrorIsShown();
      expect(modules.teamPagesAdmin.titleShows('Entre 1 et 100'), isTrue);
      expect((await backend.teamPages(owner, slug)).length, 2);

      // A title alone: created for the team's members — « Équipe » by default —, last in the
      // order, and the list is back.
      final gearTitle = unique('Équipement');
      await modules.teamPagesAdmin.enterTitle(gearTitle);
      await modules.teamPagesAdmin.save();
      await modules.teamPagesAdmin.waitUntilEditorIsGone();
      await modules.teamPagesAdmin.waitUntilShown();

      final created = await eventually(
        () => backend.teamPageTitled(owner, slug, gearTitle),
        until: (Json? page) => page != null,
        description: 'the page created from the app',
      );
      expect(created!['visibility'], 'TEAM');
      expect(created['deleted'], isFalse);
      final gearId = created['id'] as String;
      await modules.teamPagesAdmin.waitUntilPageIsShown(gearId);
      expect(
        (await backend.teamPages(owner, slug)).map((Json page) => page['id']),
        [faqId, rulesId, gearId],
      );
      // Three pages: nothing more to add.
      await modules.teamPagesAdmin.waitUntilCountShows('3 pages sur 3');
      expect(modules.teamPagesAdmin.offersAdd, isFalse);

      // Renaming rewrites the whole page: its text and its visibility survive.
      final charterTitle = unique('Charte');
      await modules.teamPagesAdmin.openEdit(rulesId);
      expect(modules.teamPagesAdmin.title, rulesTitle);
      expect(modules.teamPagesAdmin.slugShows(rulesSlug), isTrue);
      await modules.teamPagesAdmin.enterTitle(charterTitle);
      await modules.teamPagesAdmin.save();
      await modules.teamPagesAdmin.waitUntilEditorIsGone();
      await modules.teamPagesAdmin.waitUntilPageShows(rulesId, charterTitle);
      final renamed = await backend.teamPage(owner, slug, rulesSlug);
      expect(renamed['title'], charterTitle);
      expect(renamed['visibility'], 'TEAM');
      expect((renamed['media'] as Json)['markdown'], 'Le texte du règlement');

      // Deleting asks first and names the page; the row stays, marked, and a member no longer
      // reads the page.
      expect(await backend.teamPageStatus(member, slug, faqSlug), 200);
      await modules.teamPagesAdmin.openDelete(faqId);
      expect(modules.teamPagesAdmin.deleteMessageShows(faqTitle), isTrue);
      await modules.teamPagesAdmin.confirmDelete(faqId);
      expect(modules.teamPagesAdmin.isDeleted(faqId), isTrue);
      expect(await backend.teamPageStatus(member, slug, faqSlug), 404);
      // A deleted page does not count: there is room for one more.
      await modules.teamPagesAdmin.waitUntilCountShows('2 pages sur 3');
      expect(modules.teamPagesAdmin.offersAdd, isTrue);

      // « Restaurer » brings it back for the member.
      await modules.teamPagesAdmin.restore(faqId);
      expect(modules.teamPagesAdmin.isDeleted(faqId), isFalse);
      expect(await backend.teamPageStatus(member, slug, faqSlug), 200);
      await modules.teamPagesAdmin.waitUntilCountShows('3 pages sur 3');
    },
  );

  testApp(
    'A plain member is refused the pages list and the page editor, which open for the administrator',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Pages gate owner');
      final member = await backend.newUser('Pages gate member');
      final team = await backend.newTeam(owner, 'Equipe pages fermee');
      final slug = team['slug'] as String;
      await backend.addMember(slug, member);
      final title = unique('Page réservée');
      final page = await backend.newTeamPage(owner, slug, title);
      final pageId = page['id'] as String;
      final pageSlug = page['slug'] as String;

      // A member reads the page, but manages nothing: the three links read a refusal.
      await openAppSignedIn($, member);
      await openLink($, Paths.teamAdminPages(slug));
      expect(await modules.teamPagesAdmin.showsForbidden(), isTrue);
      await openLink($, Paths.teamAdminPageNew(slug));
      expect(await modules.teamPagesAdmin.editorShowsForbidden(), isTrue);
      await openLink($, Paths.teamAdminPageEdit(slug, pageSlug));
      expect(await modules.teamPagesAdmin.editorShowsForbidden(), isTrue);

      // The administrator: the list's link opens it, the editor's opens the page pre-filled.
      await openAppSignedIn($, owner);
      await openLink($, Paths.teamAdminPages(slug));
      await modules.teamPagesAdmin.waitUntilShown();
      await modules.teamPagesAdmin.waitUntilPageIsShown(pageId);
      await openLink($, Paths.teamAdminPageEdit(slug, pageSlug));
      await modules.teamPagesAdmin.waitUntilEditorIsShown();
      expect(modules.teamPagesAdmin.title, title);
      // A private team that may not publish by link: « Équipe » alone, so no choice is offered.
      expect(modules.teamPagesAdmin.offersVisibility('PUBLIC'), isFalse);
    },
  );
}
