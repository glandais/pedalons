import 'api/teams_content_seed.dart';
import 'common.dart';

/// No web counterpart: the site's « Lieux » tab (`TeamPlacesPage`, `PlaceList`, `PlaceForm`) has no
/// end-to-end test of its own.
///
/// In the app (ledger `MOB-168`): an organizer reaches « Lieux » from the hub, finds the team's
/// places, adds one — a name is required, a blank address travels absent —, renames another (the
/// update rewrites the whole place: its address must survive), searches, and deletes one after
/// the confirmation. A plain member reads a refusal from the same link.
///
/// Written, not yet run (ledger `MOB-168`).
void main() {
  testApp(
    'An organizer lists the team’s places, adds one, renames one, searches and deletes one',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Places owner');
      final organizer = await backend.newUser('Places organizer');
      final team = await backend.newTeam(owner, 'Equipe lieux');
      final slug = team['slug'] as String;
      await backend.addMember(slug, organizer, role: 'ORGANIZER');
      final station = await backend.newPlace(
        owner,
        slug,
        'Parking de la gare',
        address: '1 place de la Gare',
      );
      final stationId = station['id'] as String;
      final cafe = await backend.newPlace(
        owner,
        slug,
        'Café du col',
        endPlace: false,
      );
      final cafeId = cafe['id'] as String;

      // An organizer — not an administrator — manages the places.
      await openAppSignedIn($, organizer);
      await openLink($, Paths.team(slug));
      await modules.teams.waitUntilTeamIsShown();
      await modules.teamAdmin.openFromHeader();
      await modules.teamAdmin.openPlaces();
      await modules.teamPlaces.waitUntilShown();

      await modules.teamPlaces.waitUntilPlaceIsShown(stationId);
      expect(
        modules.teamPlaces.placeShows(stationId, '1 place de la Gare'),
        isTrue,
      );
      expect(modules.teamPlaces.isStart(stationId), isTrue);
      expect(modules.teamPlaces.isEnd(stationId), isTrue);
      // A start-only place carries no « Arrivée ».
      expect(modules.teamPlaces.showsPlace(cafeId), isTrue);
      expect(modules.teamPlaces.isEnd(cafeId), isFalse);

      // No name: the form says so, and nothing is created.
      await modules.teamPlaces.openNewForm();
      await modules.teamPlaces.submit();
      expect(await modules.teamPlaces.formErrorShows('Vérifiez'), isTrue);
      expect((await backend.places(owner, slug)).length, 2);

      // A name alone, start only: the blank address and link travel absent.
      final name = 'Fontaine ${DateTime.now().microsecondsSinceEpoch}';
      await modules.teamPlaces.enterName(name);
      await modules.teamPlaces.toggleEnd();
      await modules.teamPlaces.submit();
      await modules.teamPlaces.waitUntilFormIsGone();

      final created = await eventually(
        () => backend.placeNamed(owner, slug, name),
        until: (Json? place) => place != null,
        description: 'the place created from the app',
      );
      expect(created!['startPlace'], isTrue);
      expect(created['endPlace'], isFalse);
      expect(created['address'], isNull);
      expect(created['link'], isNull);
      expect(created['geometry'], isNull);
      final createdId = created['id'] as String;
      await modules.teamPlaces.waitUntilPlaceIsShown(createdId);
      expect(modules.teamPlaces.isEnd(createdId), isFalse);

      // Renaming rewrites the whole place: its address and its uses survive.
      await modules.teamPlaces.openEditForm(stationId);
      await modules.teamPlaces.enterName('Gare routière');
      await modules.teamPlaces.submit();
      await modules.teamPlaces.waitUntilFormIsGone();
      await modules.teamPlaces.waitUntilPlaceShows(stationId, 'Gare routière');
      final renamed = await backend.place(owner, slug, stationId);
      expect(renamed['name'], 'Gare routière');
      expect(renamed['address'], '1 place de la Gare');
      expect(renamed['startPlace'], isTrue);
      expect(renamed['endPlace'], isTrue);

      // The search goes to the server: by name, then one that matches nothing.
      await modules.teamPlaces.search('Gare routière');
      await modules.teamPlaces.waitUntilPlaceIsGone(cafeId);
      expect(modules.teamPlaces.showsPlace(stationId), isTrue);
      await modules.teamPlaces.search('zzz-aucun-lieu');
      await modules.teamPlaces.waitUntilSearchIsEmpty();
      await modules.teamPlaces.search('');
      await modules.teamPlaces.waitUntilPlaceIsShown(cafeId);

      // Deleting asks first; the row leaves, the others stay.
      await modules.teamPlaces.delete(cafeId);
      expect(modules.teamPlaces.showsPlace(stationId), isTrue);
      final left = await backend.places(owner, slug);
      expect(left.map((Json place) => place['id']), isNot(contains(cafeId)));
      expect(left.length, 2);
    },
  );

  testApp(
    'A plain member is refused the places screen, and the hub no longer leaves the app for it',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Places gate owner');
      final member = await backend.newUser('Places gate member');
      final team = await backend.newTeam(owner, 'Equipe lieux fermee');
      final slug = team['slug'] as String;
      await backend.addMember(slug, member);
      await backend.newPlace(owner, slug, 'Lieu réservé');

      // A member manages nothing: the link reads a refusal, and no place is shown.
      await openAppSignedIn($, member);
      await openLink($, Paths.teamAdminPlaces(slug));
      expect(await modules.teamPlaces.showsForbidden(), isTrue);

      // The administrator: the link opens the screen, on an empty search.
      await openAppSignedIn($, owner);
      await openLink($, Paths.teamAdminPlaces(slug));
      await modules.teamPlaces.waitUntilShown();
      final place = (await backend.places(owner, slug)).single;
      await modules.teamPlaces.waitUntilPlaceIsShown(place['id'] as String);
    },
  );
}
