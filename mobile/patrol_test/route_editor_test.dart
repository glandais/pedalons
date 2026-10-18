import 'package:pedalons/api/generated/export.dart' show SurfaceType;

import 'api/routes_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-routes.e2e.ts` › an organizer creates, edits and deletes a route
/// (`CreateRoutePage`, `EditRoutePage`). In the app since ledger `MOB-79`: the « Ajouter » button
/// of the team's Parcours section, the route editor, the pencil of the route page and its
/// « Gérer le parcours » menu. The track is **imported** from a GPX file, never drawn: the route
/// planner stays on the web. What leaves the app is checked through the API.
///
/// The native document picker is not driven: the file reaches the app through
/// `modules.routeEditor.provideGpx`, which swaps the app's file picker. Not covered here (ledger
/// `MOB-77`): the picker itself, the photo library.
///
/// The member is a team **administrator**, not an organizer: both may create, edit and delete a
/// route, but only an administrator still reads a deleted one (`IncludeDeletedService`), and so
/// can restore it. An organizer's deleted route answers 404.
void main() {
  testApp(
    'A team administrator creates a route from a GPX file, renames it, replaces the file, deletes and restores it',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Parcours owner');
      final organizer = await backend.newUser('Parcours orga');
      final team = await backend.newTeam(owner, 'Equipe parcours');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, organizer, role: 'ADMIN');

      await openAppSignedIn($, organizer);
      await openLink($, Paths.routes(teamSlug));
      // « Ajouter » attendu : openAddFromTeamRoutes patiente jusqu'à son apparition.
      await modules.routeEditor.openAddFromTeamRoutes();

      // A file that is no GPX is refused on the spot, with a way to choose another.
      await modules.routeEditor.provideGpx(
        fileName: 'notes.txt',
        content: 'pas un gpx',
      );
      await modules.routeEditor.pickGpx();
      expect(await modules.routeEditor.showsRefused(), isTrue);

      // A real GPX: the form opens, the name is the one of the file's track.
      final name = unique('Col editeur');
      await modules.routeEditor.provideGpx(
        fileName: 'col-test.gpx',
        content: gpxOf(name, eastward()),
      );
      await modules.routeEditor.pickAnother();
      await modules.routeEditor.waitUntilFormShown();
      await modules.routeEditor.nameReads(name);

      await modules.routeEditor.chooseSurface(SurfaceType.gravel);
      await modules.routeEditor.save();
      await modules.routeEditor.waitUntilRouteTitleIs(name);

      final created = await eventually(
        () => backend.teamRouteNamed(organizer, teamSlug, name),
        until: (route) => route != null,
        description: 'the created route listed',
        timeout: const Duration(seconds: 15),
      );
      final routeSlug = created!['slug'] as String;
      expect(created['surfaceType'], 'GRAVEL');
      expect(created['deleted'], isFalse);

      // The pencil: the name changes, the track stays.
      expect(modules.routeEditor.offersEdit, isTrue);
      await modules.routeEditor.editFromPencil();
      final renamed = unique('Col renomme');
      await modules.routeEditor.enterName(renamed);
      await modules.routeEditor.save();
      await modules.routeEditor.waitUntilRouteTitleIs(renamed);

      final edited = await backend.teamRouteOrNull(
        organizer,
        teamSlug,
        routeSlug,
      );
      expect(edited!['name'], renamed);
      expect(edited['surfaceType'], 'GRAVEL');

      // « Remplacer le fichier GPX »: a track twice as long (8 km against 4) replaces the whole
      // one once saved.
      await modules.routeEditor.provideGpx(
        fileName: 'col-long.gpx',
        content: gpxOf(renamed, eastward(161)),
      );
      await modules.routeEditor.replaceGpxFromMenu();
      await modules.routeEditor.save();
      final longer = await eventually(
        () => backend.teamRouteOrNull(organizer, teamSlug, routeSlug),
        until: (route) => route != null && (route['distance'] as num) > 7000,
        description: 'the longer track stored',
        timeout: const Duration(seconds: 20),
      );
      expect(longer!['name'], renamed);

      // Delete, after confirmation: the page closes, the API says so.
      await modules.routeEditor.deleteFromMenu();
      await eventually(
        () => backend.teamRouteOrNull(organizer, teamSlug, routeSlug),
        until: (route) => route != null && route['deleted'] == true,
        description: 'the route deleted',
        timeout: const Duration(seconds: 15),
      );

      // An administrator still reads it, and restores it from its page.
      await openLink($, Paths.route(teamSlug, routeSlug));
      await modules.routeEditor.waitUntilRouteTitleIs(renamed);
      await modules.routeEditor.restoreFromMenu();
      await eventually(
        () => backend.teamRouteOrNull(organizer, teamSlug, routeSlug),
        until: (route) => route != null && route['deleted'] == false,
        description: 'the route restored',
        timeout: const Duration(seconds: 15),
      );
    },
  );
}
