import 'api/routes_seed.dart';
import 'api/tags_seed.dart';
import 'common.dart';

/// Web counterpart: `tags.e2e.ts`, where an admin creates a tag from the tag manager
/// (`TeamTagsPage`, `TagFormModal`); renaming and deleting have no web end-to-end test.
///
/// In the app (ledger `MOB-169`): a team administrator reaches « Tags » from the hub, finds the
/// vocabulary kind by kind with each tag's usage, creates a tag — a label is required, the kind
/// is the open chip's —, is refused a label already taken (the sheet stays open), renames one,
/// and deletes one a route carries: the confirmation says how many contents lose it, and the
/// route no longer has it. An organizer applies tags but does not write them: the same link
/// reads a refusal.
///
/// Written, not yet run (ledger `MOB-169`).
void main() {
  testApp(
    'An administrator reads the team’s tags by kind, creates one, is refused a duplicate, renames one and deletes one in use',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Tags admin owner');
      final team = await backend.newTeam(owner, 'Equipe vocabulaire');
      final slug = team['slug'] as String;

      final hillyLabel = unique('Vallonné');
      final hilly = await backend.newTag(
        owner,
        slug,
        type: 'ROUTE',
        label: hillyLabel,
        color: 'RED',
      );
      final hillyId = hilly['id'] as String;
      final flatLabel = unique('Plat');
      final flat = await backend.newTag(
        owner,
        slug,
        type: 'ROUTE',
        label: flatLabel,
        color: 'GREEN',
      );
      final flatId = flat['id'] as String;
      final rideTag = await backend.newTag(
        owner,
        slug,
        type: 'RIDE',
        label: unique('Sortie longue'),
      );
      final rideTagId = rideTag['id'] as String;
      // One route carries « Vallonné »: its usage, and what a deletion detaches.
      final route = await backend.newRoute(
        owner,
        slug,
        unique('Parcours tagué'),
        tagIds: [hillyId],
      );
      final routeSlug = route['slug'] as String;

      await openAppSignedIn($, owner);
      await openLink($, Paths.team(slug));
      await modules.teams.waitUntilTeamIsShown();
      await modules.teamAdmin.openFromHeader();
      await modules.teamAdmin.openTags();
      await modules.teamTagsAdmin.waitUntilShown();

      // The first kind is open: rides, with their one tag; routes have two.
      await modules.teamTagsAdmin.waitUntilTagIsShown(rideTagId);
      expect(modules.teamTagsAdmin.kindLabel('RIDE'), 'Sorties (1)');
      expect(modules.teamTagsAdmin.kindLabel('ROUTE'), 'Parcours (2)');
      expect(modules.teamTagsAdmin.showsTag(hillyId), isFalse);

      // Routes: each tag with its usage.
      await modules.teamTagsAdmin.openKind('ROUTE');
      await modules.teamTagsAdmin.waitUntilTagIsShown(hillyId);
      expect(modules.teamTagsAdmin.tagShows(hillyId, hillyLabel), isTrue);
      expect(modules.teamTagsAdmin.tagShows(hillyId, '1 contenu'), isTrue);
      expect(modules.teamTagsAdmin.tagShows(flatId, 'Inutilisé'), isTrue);
      expect(modules.teamTagsAdmin.showsTag(rideTagId), isFalse);
      expect(modules.teamTagsAdmin.limitShows('2 / 100'), isTrue);

      // No label: the field says so, and nothing is created.
      await modules.teamTagsAdmin.openNewForm();
      await modules.teamTagsAdmin.submit();
      expect(await modules.teamTagsAdmin.labelShows('Entre 1 et 32'), isTrue);
      expect((await backend.teamTags(owner, slug, type: 'ROUTE')).length, 2);

      // A label and a colour: a ROUTE tag, the kind of the open chip.
      final gravelLabel = unique('Gravel');
      await modules.teamTagsAdmin.enterLabel(gravelLabel);
      await modules.teamTagsAdmin.pickColor('TEAL');
      expect(modules.teamTagsAdmin.previewShows(gravelLabel), isTrue);
      await modules.teamTagsAdmin.submit();
      await modules.teamTagsAdmin.waitUntilFormIsGone();

      final created = await eventually(
        () => backend.tagLabelled(owner, slug, gravelLabel),
        until: (Json? tag) => tag != null,
        description: 'the tag created from the app',
      );
      expect(created!['type'], 'ROUTE');
      expect(created['color'], 'TEAL');
      expect(created['usageCount'], 0);
      final createdId = created['id'] as String;
      await modules.teamTagsAdmin.waitUntilTagIsShown(createdId);
      await modules.teamTagsAdmin.waitUntilKindReads('ROUTE', 'Parcours (3)');

      // The same label, whatever the case, is taken for this kind: the sheet stays open and
      // says so; nothing is created.
      await modules.teamTagsAdmin.openNewForm();
      await modules.teamTagsAdmin.enterLabel(gravelLabel.toUpperCase());
      await modules.teamTagsAdmin.submit();
      expect(
        await modules.teamTagsAdmin.formErrorShows('déjà ce libellé'),
        isTrue,
      );
      expect((await backend.teamTags(owner, slug, type: 'ROUTE')).length, 3);
      await modules.teamTagsAdmin.closeForm();

      // Renaming keeps the tag's colour and kind, and the route still carries it.
      final renamedLabel = unique('Montagne');
      await modules.teamTagsAdmin.openEditForm(hillyId);
      await modules.teamTagsAdmin.enterLabel(renamedLabel);
      await modules.teamTagsAdmin.submit();
      await modules.teamTagsAdmin.waitUntilFormIsGone();
      await modules.teamTagsAdmin.waitUntilTagShows(hillyId, renamedLabel);
      final renamed = await backend.tagLabelled(owner, slug, renamedLabel);
      expect(renamed!['id'], hillyId);
      expect(renamed['color'], 'RED');
      expect(renamed['type'], 'ROUTE');
      expect(await backend.routeTagLabels(owner, slug, routeSlug), [
        renamedLabel,
      ]);

      // Deleting a tag in use: the confirmation shows the tag and says what loses it.
      await modules.teamTagsAdmin.openDelete(hillyId);
      expect(modules.teamTagsAdmin.deleteChipShows(renamedLabel), isTrue);
      expect(
        modules.teamTagsAdmin.deleteMessageShows('retiré du contenu'),
        isTrue,
      );
      await modules.teamTagsAdmin.confirmDelete(hillyId);

      final left = await backend.teamTags(owner, slug, type: 'ROUTE');
      expect(left.map((Json tag) => tag['id']), isNot(contains(hillyId)));
      expect(left.length, 2);
      expect(await backend.routeTagLabels(owner, slug, routeSlug), isEmpty);
      // The other kind is untouched.
      expect((await backend.teamTags(owner, slug, type: 'RIDE')).length, 1);
      await modules.teamTagsAdmin.waitUntilKindReads('ROUTE', 'Parcours (2)');
    },
  );

  testApp(
    'An organizer is refused the tags screen, which the hub does not offer them; the link opens it for the administrator on the asked kind',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Tags gate owner');
      final organizer = await backend.newUser('Tags gate organizer');
      final team = await backend.newTeam(owner, 'Equipe tags fermee');
      final slug = team['slug'] as String;
      await backend.addMember(slug, organizer, role: 'ORGANIZER');
      final tag = await backend.newTag(
        owner,
        slug,
        type: 'AD',
        label: unique('Occasion'),
      );
      final tagId = tag['id'] as String;

      // An organizer manages places and reports, not the vocabulary.
      await openAppSignedIn($, organizer);
      await openLink($, Paths.team(slug));
      await modules.teams.waitUntilTeamIsShown();
      await modules.teamAdmin.openFromHeader();
      expect(modules.teamAdmin.showsOrganizerRows, isTrue);
      expect(modules.teamAdmin.showsAdminRows, isFalse);
      await openLink($, Paths.teamAdminTags(slug));
      expect(await modules.teamTagsAdmin.showsForbidden(), isTrue);

      // The administrator: `?type=ad` opens the classifieds' tags, as on the site.
      await openAppSignedIn($, owner);
      await openLink($, '${Paths.teamAdminTags(slug)}?type=ad');
      await modules.teamTagsAdmin.waitUntilShown();
      await modules.teamTagsAdmin.waitUntilTagIsShown(tagId);
      expect(modules.teamTagsAdmin.kindLabel('AD'), 'Annonces (1)');
    },
  );
}
