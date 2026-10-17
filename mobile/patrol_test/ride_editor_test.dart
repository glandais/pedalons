import 'api/ride_editor_seed.dart';
import 'api/routes_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-rides.e2e.ts` › an organizer creates, edits, publishes and deletes a
/// ride. In the app since ledger `MOB-76`: the ride editor, the pencil of the ride page and its
/// « Gérer la sortie » menu. What leaves the app is checked through the API — the PUT rewrites
/// every field, so an edit must keep the group the creation made.
///
/// Not covered here (ledger `MOB-77`): the photo library and the document picker (native
/// dialogs), the ride's zone from a start place, a template.
void main() {
  testApp(
    'An organizer creates a ride on a route, edits it, publishes it and deletes it',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Editeur owner');
      final organizer = await backend.newUser('Editeur orga');
      final team = await backend.newTeam(owner, 'Equipe editeur');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, organizer, role: 'ORGANIZER');
      final routeName = unique('Boucle editeur');
      final route = await backend.newRoute(owner, teamSlug, routeName);
      final routeSlug = route['slug'] as String;

      await openAppSignedIn($, organizer);
      await openLink($, Paths.rideNew(teamSlug));
      await modules.rideEditor.waitUntilShown();

      // Création : un brouillon d'un groupe, sur le parcours choisi.
      final name = unique('Sortie editee');
      await modules.rideEditor.enterName(name);
      await modules.rideEditor.pickRoute(routeSlug);
      expect(modules.rideEditor.routeRowShows(routeName), isTrue);
      await modules.rideEditor.save();
      await modules.rideEditor.waitUntilRideTitleIs(name);

      final rideSlug = await eventually(
        () => backend.rideSlugNamed(organizer, teamSlug, name),
        until: (slug) => slug != null,
        description: 'the created draft listed',
        timeout: const Duration(seconds: 15),
      );
      final created = await backend.ride(organizer, teamSlug, rideSlug!);
      expect(created['status'], 'DRAFT');
      expect(created['routeSlug'], routeSlug);
      final groups = (created['groups'] as List).cast<Json>();
      expect(groups.length, 1);
      final groupId = groups.single['id'] as String;

      // Modification : le nom change, le groupe reste le même.
      expect(modules.rideEditor.offersEdit, isTrue);
      await modules.rideEditor.openEditor();
      final renamed = unique('Sortie renommee');
      await modules.rideEditor.enterName(renamed);
      await modules.rideEditor.save();
      await modules.rideEditor.waitUntilRideTitleIs(renamed);

      final edited = await backend.ride(organizer, teamSlug, rideSlug);
      expect(edited['name'], renamed);
      expect(edited['routeSlug'], routeSlug);
      expect((edited['groups'] as List).cast<Json>().map((g) => g['id']), [
        groupId,
      ]);

      // Publier depuis « Gérer la sortie ».
      await modules.rideEditor.publish();
      await eventually(
        () => backend.ride(organizer, teamSlug, rideSlug),
        until: (ride) => ride['status'] == 'PUBLISHED',
        description: 'the ride published',
        timeout: const Duration(seconds: 15),
      );

      // Supprimer, après confirmation : la fiche se ferme.
      await modules.rideEditor.delete();
      await eventually(
        () => backend.rideOrNull(organizer, teamSlug, rideSlug),
        until: (ride) => ride == null || ride['deleted'] == true,
        description: 'the ride deleted',
        timeout: const Duration(seconds: 15),
      );
    },
  );
}
