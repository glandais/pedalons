import 'api/routes_seed.dart';
import 'common.dart';

/// Web counterpart: `gpx-planner.e2e.ts` (the planner in the route form). In the app since ledger
/// `MOB-170`: the site's planner, embedded in a fullscreen WebView, opened from the first step of
/// the creation (« Tracer sur la carte ») and from the Tracé section of the form (« Modifier le
/// tracé »). What leaves the app is checked through the API.
///
/// **Nothing is tapped on the map.** Patrol finds nothing by key inside a WebView and a tap on the
/// map would be a matter of pixels: the control points go through the page's test-only command
/// (`modules.routeEditor.placeAndFinish`), which the page ignores unless the app asked for it at
/// `load`. They are placed as **straight lines**, which send no routing request: the e2e stack
/// calls Stadia for real when it has a key (billed) and fails every routing request without one,
/// and this test must run the same either way. Everything else is the real thing — the page, its
/// `done` message, the bridge, the form, the request, and what the server derives from the state.
///
/// Not covered here (a hand-run recipe on a device): the gestures on the map, routed legs, the
/// GPX import inside the planner, the place search, the quota refusal.
void main() {
  testApp(
    'An organizer draws a route on the map, saves it, then edits its track',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Planif owner');
      final organizer = await backend.newUser('Planif orga');
      final team = await backend.newTeam(
        owner,
        'Equipe planif',
        enableRoutePlanner: true,
      );
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, organizer, role: 'ORGANIZER');

      final quotaBefore = _plannerSaves(
        await backend.team(organizer, teamSlug),
      );

      modules.routeEditor.enablePlannerTestCommands();
      await openAppSignedIn($, organizer);
      await openLink($, Paths.routes(teamSlug));
      await modules.routeEditor.openAddFromTeamRoutes();
      expect(modules.routeEditor.offersDraw, isTrue);

      // Three control points: about 1.6 km east, then 2.2 km north.
      await modules.routeEditor.drawOnMap();
      await modules.routeEditor.placeAndFinish(const [
        (5.00, 45.00),
        (5.02, 45.00),
        (5.02, 45.02),
      ]);
      await modules.routeEditor.waitUntilFormShown();
      await modules.routeEditor.waitUntilDrawnTrackShown();

      final name = unique('Boucle tracee');
      await modules.routeEditor.enterName(name);
      await modules.routeEditor.save();
      await modules.routeEditor.waitUntilRouteTitleIs(name);

      // The server derived the track from the planner state.
      final created = await eventually(
        () => backend.teamRouteNamed(organizer, teamSlug, name),
        until: (route) => route != null,
        description: 'the drawn route listed',
        timeout: const Duration(seconds: 15),
      );
      final routeSlug = created!['slug'] as String;
      final distance = created['distance'] as num;
      expect(
        distance > 3000 && distance < 4600,
        isTrue,
        reason: 'three straight legs of about 3.8 km, got $distance m',
      );

      final statePath = '/api/teams/$teamSlug/routes/$routeSlug/planner-state';
      final saved = (await backend.get(organizer, statePath))['state'] as Json;
      expect(_controlPoints(saved), 3);
      expect(_pieceModes(saved), {'DIRECT'});

      // A drawn track counts against the team's monthly quota (ledger `BILL-10`).
      final quotaAfter = _plannerSaves(await backend.team(organizer, teamSlug));
      if (quotaBefore != null) expect(quotaAfter, quotaBefore + 1);

      // The pencil, « Modifier le tracé »: the planner opens on the saved state; a fourth point,
      // 2.2 km further north, lengthens the stored track.
      await modules.routeEditor.editFromPencil();
      await modules.routeEditor.editTrack();
      await modules.routeEditor.placeAndFinish(const [(5.02, 45.04)]);
      await modules.routeEditor.waitUntilDrawnTrackShown();
      await modules.routeEditor.save();

      final longer = await eventually(
        () => backend.teamRouteOrNull(organizer, teamSlug, routeSlug),
        until: (route) =>
            route != null && (route['distance'] as num) > distance + 1500,
        description: 'the longer drawn track stored',
        timeout: const Duration(seconds: 20),
      );
      final edited = (await backend.get(organizer, statePath))['state'] as Json;
      expect(_controlPoints(edited), 4);

      // Opened and left untouched, then renamed: the page hands back nothing of the track, the
      // form shows no drawn track, and the server keeps the track and its state.
      await modules.routeEditor.editFromPencil();
      await modules.routeEditor.editTrack();
      await modules.routeEditor.placeAndFinish(const []);
      await modules.routeEditor.waitUntilFormShown();
      expect(modules.routeEditor.showsDrawnTrack, isFalse);
      final renamed = unique('Boucle renommee');
      await modules.routeEditor.enterName(renamed);
      await modules.routeEditor.save();
      await modules.routeEditor.waitUntilRouteTitleIs(renamed);

      final kept = await backend.teamRouteOrNull(
        organizer,
        teamSlug,
        routeSlug,
      );
      expect(kept!['name'], renamed);
      expect(kept['distance'], longer!['distance']);
      final untouched =
          (await backend.get(organizer, statePath))['state'] as Json;
      expect(_controlPoints(untouched), 4);
    },
  );
}

/// The saves of a drawn track the team's quota counts this month; null when the team reads none.
int? _plannerSaves(Json team) =>
    ((team['plannerQuota'] as Json?)?['used'] as num?)?.toInt();

int _controlPoints(Json state) => (state['junctions'] as List)
    .cast<Json>()
    .where((junction) => junction['kind'] == 'CONTROL')
    .length;

Set<Object?> _pieceModes(Json state) => {
  for (final piece in (state['pieces'] as List).cast<Json>()) piece['mode'],
};
