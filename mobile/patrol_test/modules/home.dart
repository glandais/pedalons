import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/adaptive/navigation_destination.dart';

import 'module.dart';

/// The home tab: « Ma prochaine sortie ».
final class Home extends Module {
  Home(super.$);

  /// Taps the Home tab. From another tab it restores the home where it was left; from the home
  /// tab itself it pops back to its root.
  Future<void> goToHome() async {
    await $(
      keys.navigation.tab(
        kAppDestinations.firstWhere((d) => d.label == 'nav.home'),
      ),
    ).tap();
  }

  /// Waits until the home tab is on screen and can be touched: after a link that pops a page
  /// pushed above the tab shell, the page is still sliding away for a moment.
  Future<void> waitUntilShown() async {
    await $(
      keys.navigation.tab(
        kAppDestinations.firstWhere((d) => d.label == 'nav.home'),
      ),
    ).waitUntilVisible();
  }

  // ── Ma prochaine sortie ─────────────────────────────────────────────────

  /// Waits until « Ma prochaine sortie » names the ride of [rideSlug].
  Future<void> waitUntilNextRideIs(
    String rideSlug, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await $(keys.home.nextRideCard(rideSlug)).waitUntilExists(timeout: timeout);
  }

  /// Waits until the block is replaced by the compact « no upcoming ride » card.
  Future<void> waitUntilNoNextRide({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await $(keys.home.noNextRideCard).waitUntilExists(timeout: timeout);
  }

  bool showsNextRide(String rideSlug) =>
      isShown(keys.home.nextRideCard(rideSlug));

  /// Whether [text] appears on the next-ride card of [rideSlug].
  bool nextRideShows(String rideSlug, String text) =>
      shows(keys.home.nextRideCard(rideSlug), text);

  /// Whether the line under « Départ 09:30 » — « Groupe B · Place de la Mairie », the joined
  /// group then the start place, name only (rule R11) — reads [text].
  bool nextRideGroupLineShows(String text) =>
      shows(keys.home.nextRideGroup, text);

  bool get nextRideOffersLeave => isShown(keys.home.nextRideLeaveButton);

  /// Taps « Se désinscrire » on the next-ride card.
  Future<void> leaveNextRide() async {
    await (await scrolledTo(keys.home.nextRideLeaveButton)).tap();
  }
}
