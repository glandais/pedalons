import 'module.dart';

/// The `⋯` menus of the detail pages and of the people lists — what the [Moderation] module then
/// reports or blocks from.
final class DetailMenus extends Module {
  DetailMenus(super.$);

  Future<void> openRideMenu() async {
    await $(keys.ride.moreButton).tap();
  }

  Future<void> openTripMenu() async {
    await $(keys.trip.moreButton).tap();
  }

  Future<void> openRouteMenu() async {
    await $(keys.routeDetail.moreButton)
        .waitUntilVisible(timeout: const Duration(seconds: 20));
    await $(keys.routeDetail.moreButton).tap();
  }

  // A detail page closes behind a report: its `⋯` goes with it.

  Future<void> waitUntilRideClosed() => waitUntilGone(keys.ride.moreButton);

  Future<void> waitUntilTripClosed() => waitUntilGone(keys.trip.moreButton);

  Future<void> waitUntilRouteClosed() =>
      waitUntilGone(keys.routeDetail.moreButton);

  Future<void> waitUntilAdClosed() => waitUntilGone(keys.ad.moreButton);

  /// The team's « Membres » section: taps [userId]'s row, which opens its menu.
  Future<void> openMemberMenu(String userId) async {
    await (await scrolledTo(keys.team.memberRow(userId))).tap();
  }

  /// The ride's « Voir la liste » → the participants sheet → [userId]'s row, which opens its menu.
  Future<void> openParticipantMenu(String userId) async {
    await (await scrolledTo(keys.ride.participantsButton)).tap();
    await $(keys.participants.person(userId)).tap();
  }
}
