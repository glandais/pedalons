import 'api/ads_seed.dart';
import 'common.dart';

/// Web counterpart: `ads-browse.e2e.ts` › « location map » and « no empty section ».
///
/// An ad's position is, in practice, the seller's home: the API only publishes the centre of the
/// ~1 km cell holding it, and every client draws a sector, never a pin (`ad_location_map.dart`).
/// An ad without a place has no « Localisation » block at all — a map centred on a fallback would
/// be one more lie.
void main() {
  testApp('An ad with a place shows a blurred sector captioned as approximate, never a pin; an ad '
      'without one shows no location block', ($, modules, apiClients) async {
    final backend = apiClients.backend;
    final seller = await backend.newUser('Ad map seller');
    final reader = await backend.newUser('Ad map reader');
    final team = await backend.newTeam(seller, 'Equipe carte annonces');
    final teamSlug = team['slug'] as String;
    await backend.addMember(teamSlug, reader);
    // Six decimals, like a geocoded address.
    const exact = [1.487531, 48.446927];
    final located = await backend.newAdWithLocation(
      seller,
      teamSlug,
      'Roue avant',
      locationDescription: 'Près de Chartres',
      lonLat: exact,
    );
    final bare = await backend.newAd(seller, teamSlug, 'Annonce sans lieu');

    await openAppSignedIn($, reader);
    await openLink($, Paths.ad(teamSlug, located['slug'] as String));
    await modules.ad.waitUntilShown();
    await modules.adLocation.waitUntilMapIsShown();
    expect(modules.adLocation.showsSection, isTrue);
    expect(modules.adLocation.descriptionSays('Près de Chartres'), isTrue);
    expect(
      modules.adLocation.captionSays('Localisation approximative'),
      isTrue,
    );
    expect(modules.adLocation.showsSector, isTrue);
    expect(modules.adLocation.mapHasAPin, isFalse);
    // The map is centred on the blurred point the API served, within a cell of the exact one
    // and not on it.
    final [lon, lat] = modules.adLocation.mapCentre;
    expect((lat - exact[1]).abs() < 0.01, isTrue);
    expect((lon - exact[0]).abs() < 0.02, isTrue);
    expect(lon == exact[0] && lat == exact[1], isFalse);

    await openLink($, Paths.ad(teamSlug, bare['slug'] as String));
    await modules.adLocation.waitUntilAdIsShown(bare['name'] as String);
    await modules.adLocation.scrollToSeller();
    expect(modules.adLocation.showsSection, isFalse);
    expect(modules.adLocation.showsMap, isFalse);
    expect(modules.adLocation.showsSector, isFalse);
  });
}
