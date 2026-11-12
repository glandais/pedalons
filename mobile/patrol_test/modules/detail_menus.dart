import 'package:flutter/widgets.dart';

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

  /// The team's « Membres » section: taps the `⋯` at the end of [userId]'s row, which opens its
  /// menu (rule R13 — tapping the row does the same, the `⋯` says so).
  Future<void> openMemberMenu(String userId) async {
    await (await scrolledTo(keys.team.memberMore(userId))).tap();
  }

  /// The ride's participants sheet → the `⋯` of [userId]'s row, which opens its menu (rule R13).
  ///
  /// The sheet opens from « Voir toutes les personnes inscrites » at the foot of a single-group
  /// ride's « Personnes inscrites » section (ledger `MOB-134`, lot 7 — the group's own sheet), or,
  /// with [severalGroups], from « Voir les N personnes inscrites » under the group cards.
  Future<void> openParticipantMenu(
    String userId, {
    bool severalGroups = false,
  }) async {
    final Key button = severalGroups
        ? keys.ride.participantsButton
        : keys.rideGroup.viewAllParticipants;
    await (await scrolledTo(button)).tap();
    await $(keys.participants.personMore(userId)).tap();
  }
}
