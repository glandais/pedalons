import 'api/ride_detail_seed.dart';
import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// The ride page's extras (no single web counterpart: `rides.e2e.ts` reads the counts on the
/// cards, `route-maps.e2e.ts` the drawn tracks).
///
/// Two groups, each on a route of its own. The groups map is a MapLibre platform view whose
/// tracks Patrol cannot read: what it checks is the selection the map shares with the cards —
/// the pill naming the selected group follows a tap on another group's card. « Voir la liste »
/// then gathers the riders of **every** group, and nobody else. Last, the group's exports, in the
/// GPS sheet its « GPS » button opens: « Fichier GPX » (and « Fichier FIT » when the route has
/// one) from the route's assets, no « Vers un appareil » but « Connecter un compteur » without a
/// connected GPS service — which the e2e stack cannot connect — and sharing the GPX hands the
/// downloaded file to the system share sheet, found in the native UI tree (it presents a
/// GPX file).
void main() {
  testApp(
    'The groups map follows the selected group, the participants sheet names every group’s riders, and the GPS sheet shares the GPX',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Extras owner');
      final first = await backend.newUser('Extras first rider');
      final second = await backend.newUser('Extras second rider');
      final reader = await backend.newUser('Extras reader');
      final team = await backend.newTeam(owner, 'Equipe carte groupes');
      final teamSlug = team['slug'] as String;
      for (final member in [first, second, reader]) {
        await backend.addMember(teamSlug, member);
      }
      final westRoute = await backend.newRouteWithTrack(
        owner,
        teamSlug,
        'Parcours ouest',
      );
      final eastRoute = await backend.newRouteWithTrack(
        owner,
        teamSlug,
        'Parcours est',
        eastKm: 15,
      );
      final nameA = unique('Groupe ouest');
      final nameB = unique('Groupe est');
      final ride = await backend.newRide(
        owner,
        teamSlug,
        'Sortie deux parcours',
        groups: [
          {'name': nameA, 'routeSlug': westRoute['slug']},
          {'name': nameB, 'routeSlug': eastRoute['slug']},
        ],
      );
      final rideSlug = ride['slug'] as String;
      final groupA = groupIdNamed(ride, nameA);
      final groupB = groupIdNamed(ride, nameB);
      await backend.joinGroup(first, teamSlug, rideSlug, groupA);
      await backend.joinGroup(second, teamSlug, rideSlug, groupB);

      await openAppSignedIn($, reader);
      await openLink($, Paths.ride(teamSlug, rideSlug));
      await modules.ride.waitUntilShown();

      await modules.ride.openParticipants();
      expect(modules.ride.participantsCount, '2');
      expect(modules.ride.participantsListRow(first.id), isTrue);
      expect(modules.ride.participantsListRow(second.id), isTrue);
      expect(modules.ride.participantsListRow(reader.id), isFalse);
      expect(modules.ride.participantsListRow(owner.id), isFalse);
      await modules.ride.closeParticipants();

      // Nobody's own group to start from: the first one is selected.
      await modules.ride.waitUntilMapSelects(nameA);
      await modules.ride.selectGroup(groupB);
      await modules.ride.waitUntilMapSelects(nameB);

      // The exports of a group, in its GPS sheet, follow its route's assets; with no GPS
      // service connected — the e2e stack cannot connect one — there is no « Vers un
      // appareil », and « Connecter un compteur » stands in its place.
      await modules.ride.waitUntilGpsIsOffered(groupB);
      await modules.ride.openGpsSheet(groupB);
      final eastDetail = await backend.get(
        reader,
        '/api/teams/$teamSlug/routes/${eastRoute['slug']}',
      );
      final assets = (eastDetail['media'] as Json)['assets'] as Json;
      expect(modules.ride.gpsSheetOffersFit, assets['fit'] != null);
      expect(modules.ride.gpsSheetOffersSendToDevice, isFalse);
      expect(modules.ride.gpsSheetOffersConnectDevice, isTrue);

      await modules.ride.shareGpxFromGpsSheet();
      expect(await modules.shareSheet.waitUntilSharesGpxFile(), isTrue);
    },
  );
}
