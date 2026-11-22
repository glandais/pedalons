import 'api/routes_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-gpx-tools.e2e.ts`. In the app since ledger `MOB-178`: the Explorer
/// tab's « Outils GPX », the hub, a preview's page and its `⋯` menu. What leaves the app is
/// checked through the API.
///
/// The file reaches the app through `modules.routeEditor.provideGpx`, which swaps the app's file
/// picker — the native document picker is never driven.
///
/// Not covered here (a hand-run recipe on a device): drawing from scratch — the e2e stack's
/// default domain keeps the GPX tools' planner closed (`enableGpxPlanner`, as the site's
/// `localhost` does), the planner itself being covered by `route_planner_test.dart` —, the merge
/// (the picker swap answers with one file), the departure date and its weather, the blank map.
void main() {
  testApp(
    'A member views a GPX file, duplicates it, deletes the copy, saves the original as a route',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Outils GPX owner');
      final member = await backend.newUser('Outils GPX orga');
      final team = await backend.newTeam(owner, 'Equipe outils GPX');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member, role: 'ORGANIZER');

      await openAppSignedIn($, member);
      await modules.routes.goToRoutes();
      await modules.gpxTools.openFromExplorer();

      final name = unique('Boucle outils');
      await modules.routeEditor.provideGpx(
        fileName: 'boucle-outils.gpx',
        content: gpxOf(name, eastward()),
      );
      await modules.gpxTools.viewFile();
      await modules.gpxTools.waitUntilTitleIs(name);

      // The preview is the member's, listed in « Mes fichiers ».
      final mine = await backend.get(member, '/api/gpx-previews');
      final previews = (mine['previews'] as List).cast<Json>();
      final original = previews.firstWhere((p) => p['name'] == name);

      // A copy of one's own, opened in place of the original.
      await modules.gpxTools.duplicate();
      await modules.gpxTools.waitUntilTitleIs('Copie de $name');
      final copies = await eventually(
        () async =>
            ((await backend.get(member, '/api/gpx-previews'))['previews']
                    as List)
                .cast<Json>()
                .where((p) => p['name'] == 'Copie de $name')
                .toList(),
        until: (list) => list.isNotEmpty,
        description: 'the copy listed',
      );
      final copyId = copies.single['id'] as String;

      // The copy deleted through its menu: back on the hub, the original kept.
      await modules.gpxTools.delete();
      await modules.gpxTools.waitUntilHubShown();
      expect(
        await backend.status(member, 'GET', '/api/gpx-previews/$copyId'),
        404,
      );

      // The original, opened by its link, becomes a route of the team the member organizes.
      final originalId = original['id'] as String;
      await openLink($, Paths.gpxToolsView(originalId));
      await modules.gpxTools.waitUntilTitleIs(name);
      await modules.gpxTools.saveAsRoute(teamSlug);
      final route = await eventually(
        () => backend.teamRouteNamed(member, teamSlug, name),
        until: (route) => route != null,
        description: 'the route created from the preview',
        timeout: const Duration(seconds: 15),
      );
      expect(route!['surfaceType'], 'ROAD');
      expect(
        await backend.status(member, 'GET', '/api/gpx-previews/$originalId'),
        200,
      );
    },
  );
}
