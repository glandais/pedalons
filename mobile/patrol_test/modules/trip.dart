import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';

import 'module.dart';

/// A trip's page and its stages.
///
/// The trip's page scrolls (ledger `MOB-134`, lot 9): the registration sits in the departure block
/// at the top — « Rejoindre », or the « J'y vais » badge once registered —, « Se désinscrire » is a
/// link at the foot of « Personnes inscrites », below the stages. The helpers scroll to whichever
/// end they need.
final class Trip extends Module {
  Trip(super.$);

  Future<void> waitUntilShown() async {
    await $(keys.trip.title).waitUntilVisible();
  }

  /// Whether the trip is marked « Terminé ».
  bool get saysFinished => isShown(keys.trip.finishedBadge);

  /// Whether the « Voyage annulé » banner is shown.
  bool get saysCancelled => isShown(keys.trip.cancelledBanner);

  /// Whether the departure block offers « Rejoindre ».
  Future<bool> offersJoin() async {
    await scrolledUpTo(keys.trip.departureBlock);
    return isShown(keys.trip.joinButton);
  }

  /// Whether « Personnes inscrites » ends with « Se désinscrire ».
  Future<bool> offersLeave() async {
    await scrolledIntoView(keys.trip.participants);
    return isShown(keys.trip.leaveButton);
  }

  /// Taps « Rejoindre » and waits for the « J'y vais » badge that replaces it.
  Future<void> join() async {
    await scrolledUpTo(keys.trip.departureBlock);
    await $(keys.trip.joinButton).tap();
    await $(keys.trip.goingBadge).waitUntilVisible();
  }

  /// Taps « Se désinscrire » and waits for « Rejoindre » to come back in the departure block.
  Future<void> leave() async {
    await (await scrolledTo(keys.trip.leaveButton)).tap();
    await waitUntilGone(keys.trip.leaveButton);
    await scrolledUpTo(keys.trip.departureBlock);
    await $(keys.trip.joinButton).waitUntilVisible();
  }

  /// Whether the trip lists a card for the stage of [stageSlug].
  Future<bool> listsStage(String stageSlug) async {
    await scrolledTo(keys.trip.stageCard(stageSlug));
    return isShown(keys.trip.stageCard(stageSlug));
  }

  // ── Stages ──────────────────────────────────────────────────────────────

  /// Taps the card of the stage of [stageSlug], and waits for its page, titled [stageName].
  Future<void> openStage(String stageSlug, String stageName) async {
    await (await scrolledTo(keys.trip.stageCard(stageSlug))).tap();
    await waitUntilStageIs(stageName);
  }

  /// Taps the rail's pill at [index] — 0 is « Aperçu », then one per stage in order.
  ///
  /// The pills carry no key of the feature: `PdlStageRail` gives each a `ValueKey<int>` of its
  /// rank, found inside the rail's own key.
  ///
  /// The rail scrolls sideways to centre the selected pill, so the one asked for may be off
  /// screen: it is scrolled to within the rail first.
  Future<void> tapRail(int index) async {
    final pill = $(keys.trip.stageRail).$(ValueKey<int>(index));
    await pill.waitUntilExists();
    // The rail is a plain `Row` in a scroller: every pill is built, `ensureVisible` scrolls to it
    // whichever side it lies.
    await $.tester.ensureVisible(pill.first);
    await $.pump(const Duration(milliseconds: 400));
    await pill.tap();
  }

  /// Waits until the stage page shown is the one named [stageName] — the rail replaces the page,
  /// so the previous one may still be in the tree for a transition.
  Future<void> waitUntilStageIs(
    String stageName, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final finder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          widget.key == keys.trip.stageTitle &&
          widget.data == stageName,
    );
    await $(finder).waitUntilVisible(timeout: timeout);
    await $.pumpAndTrySettle();
  }

  /// Whether the stage page's top bar reads « Étape [index] sur [total] » — its two numbers, in
  /// that order, whatever the wording around them. The position is the bar's title since ledger
  /// `MOB-134` (lot 11), no longer a badge in the body.
  bool stagePositionIs(int index, int total) {
    if (!$(keys.trip.stagePosition).exists) return false;
    final label = $(keys.trip.stagePosition).$(Text).text ?? '';
    return RegExp('\\b$index\\b.*\\b$total\\b').hasMatch(label);
  }

  /// The stage's departure block as a screen reader reads it: « Départ 08:00 », its date, the
  /// estimated arrival, the timezone mention. The date is in the day box, not written out
  /// (ledger `MOB-134`, lot 11), so it is only found here.
  String stageDepartureLabel() =>
      $.tester
          .widget<PdlDepartureBlock>(find.byKey(keys.trip.stageDepartureBlock))
          .semanticLabel ??
      '';

  /// Pulls the trip's page down to refresh it: its detail is read again from the API.
  ///
  /// The indicator only arms for a drag that starts at the top of the page, so the page is brought
  /// back there first — which may already refresh it, harmlessly.
  Future<void> pullToRefresh() async {
    final title = find.byKey(keys.trip.title);
    await $(keys.trip.title).waitUntilVisible();
    await $.tester.drag(title, const Offset(0, 600));
    await $.pump(const Duration(milliseconds: 800));
    await $.tester.fling(title, const Offset(0, 400), 1000);
    await $.pump(const Duration(seconds: 2));
  }

  /// Waits for the « Voyage annulé » banner.
  Future<void> waitUntilCancelled() async {
    await $(keys.trip.cancelledBanner).waitUntilExists();
  }
}
