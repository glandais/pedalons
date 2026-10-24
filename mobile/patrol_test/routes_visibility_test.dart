import 'package:pedalons/api/generated/export.dart';

import 'api/routes_seed.dart';
import 'common.dart';

/// Web counterparts: `flow-routes.e2e.ts` › the platform-wide list (members-only routes stay out of
/// it, the search narrows it, the list/map toggle) and › « Utilisée dans » lists only the rides and
/// trips the visitor may read.
///
/// The app has no anonymous visitor: the outsider here is a signed-in rider of no team. The map's
/// tiles and the routing engine may be absent from the e2e stack, so the trace is checked through
/// the elevation profile — drawn from the stored track alone — and the map view by its presence.
void main() {
  testApp(
    'The Explorer tab keeps members-only routes to members, filters and toggles the map; « Utilisée dans » lists only what the viewer may read',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Routes owner');
      final member = await backend.newUser('Routes member');
      final outsider = await backend.newUser('Routes outsider');
      final otherOwner = await backend.newUser('Routes other owner');
      final team = await backend.newTeam(
        owner,
        'Parcours visibilite',
        visibility: 'PUBLIC',
      );
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);
      final privateTeam = await backend.newTeam(otherOwner, 'Parcours privee');

      final tag = unique('Circuit');
      final open = await backend.newRoute(
        owner,
        teamSlug,
        '$tag ouvert',
        visibility: 'PUBLIC',
      );
      final reserved = await backend.newRoute(
        owner,
        teamSlug,
        '$tag reserve',
        surfaceType: 'GRAVEL',
      );
      final ofPrivateTeam = await backend.newRoute(
        otherOwner,
        privateTeam['slug'] as String,
        '$tag equipe privee',
      );
      final openSlug = open['slug'] as String;
      final reservedSlug = reserved['slug'] as String;
      final privateSlug = ofPrivateTeam['slug'] as String;

      final publicRide = await backend.newRideOnRoute(
        owner,
        teamSlug,
        'Sortie ouverte',
        routeSlug: openSlug,
        visibility: 'PUBLIC',
      );
      final membersRide = await backend.newRideOnRoute(
        owner,
        teamSlug,
        'Sortie du club',
        routeSlug: openSlug,
      );
      final stageName = unique('Etape 1');
      final trip = await backend.newTripOnRoute(
        owner,
        teamSlug,
        'Voyage du club',
        stageName: stageName,
        routeSlug: openSlug,
      );
      final unrelated = await backend.newRideOnRoute(
        owner,
        teamSlug,
        'Sortie sans parcours',
        visibility: 'PUBLIC',
      );
      final publicRideSlug = publicRide['slug'] as String;
      final membersRideSlug = membersRide['slug'] as String;
      final tripSlug = trip['slug'] as String;
      final unrelatedSlug = unrelated['slug'] as String;

      // What the API hands each viewer: the outsider reads the public route and ride alone.
      expect(await backend.platformRouteNames(outsider, tag), ['$tag ouvert']);
      expect(await backend.routeUsageSlugs(outsider, teamSlug, openSlug), [
        publicRideSlug,
      ]);

      // The outsider: the public route shows up, the members-only ones don't.
      // The tab opens on the map; the list is one toggle away.
      await openAppSignedIn($, outsider);
      await modules.routes.goToRoutes();
      await modules.routes.switchToList();
      await modules.routes.search(tag);
      await modules.routes.waitUntilListed(openSlug);
      expect(modules.routes.isListed(reservedSlug), isFalse);
      expect(modules.routes.isListed(privateSlug), isFalse);

      // The list/map toggle keeps the search.
      await modules.routes.switchToMap();
      expect(modules.routes.isListed(openSlug), isFalse);
      await modules.routes.switchToList();
      await modules.routes.waitUntilListed(openSlug);
      expect(modules.routes.showsMap, isFalse);

      // Its page: the trace, and the public ride alone in « Utilisée dans ».
      await modules.routes.openRoute(openSlug);
      expect(modules.routes.routeTitleShows('$tag ouvert'), isTrue);
      await modules.routes.waitUntilTraceIsShown();
      await modules.routes.waitUntilUsageIsShown(publicRideSlug);
      expect(modules.routes.usageShows(publicRideSlug, 'Groupe A'), isTrue);
      expect(modules.routes.showsUsage(membersRideSlug), isFalse);
      expect(modules.routes.showsUsage(tripSlug), isFalse);
      expect(modules.routes.showsUsage(unrelatedSlug), isFalse);

      // A member: both of the team's routes, still not the other team's.
      await openAppSignedIn($, member);
      await modules.routes.goToRoutes();
      await modules.routes.switchToList();
      await modules.routes.search(tag);
      await modules.routes.waitUntilListed(openSlug);
      await modules.routes.waitUntilListed(reservedSlug);
      expect(modules.routes.isListed(privateSlug), isFalse);

      // A filter narrows the list; a filter nothing matches ends on the filtered empty state.
      await modules.routes.filterBy(SurfaceType.gravel);
      await modules.routes.waitUntilNotListed(openSlug);
      expect(modules.routes.isListed(reservedSlug), isTrue);
      await modules.routes.filterBy(SurfaceType.mtb);
      await modules.routes.waitUntilFilteredEmpty();
      expect(modules.routes.isListed(reservedSlug), isFalse);

      // « Utilisée dans » for a member: the members-only ride and the trip as well.
      await openLink($, Paths.route(teamSlug, openSlug));
      await modules.routes.waitUntilRouteIsShown();
      await modules.routes.waitUntilUsageIsShown(publicRideSlug);
      await modules.routes.waitUntilUsageIsShown(membersRideSlug);
      await modules.routes.waitUntilUsageIsShown(tripSlug);
      expect(modules.routes.usageShows(tripSlug, stageName), isTrue);
      expect(modules.routes.showsUsage(unrelatedSlug), isFalse);
    },
  );
}
