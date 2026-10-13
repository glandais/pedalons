import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'module.dart';

/// The ride page: its groups, their leaders, and joining one.
///
/// A ride with a single group has no group card and no group page (ledger `MOB-69`): its detail
/// *is* the group's page — a group section ([keys.ride.soloGroupSection]) and the group page's
/// action bar (`keys.rideGroup.*`). The group helpers below take the same `groupId` either way and
/// pick the keys of the shape the page has, so a test of joining doesn't care how many groups the
/// ride has. The group page helpers ([openGroup], [selectGroup]) need two groups or more.
final class Ride extends Module {
  Ride(super.$);

  /// Whether the ride on screen is a single-group one: the action bar's places line is there
  /// while no group page is open on top.
  bool get _solo =>
      $(keys.rideGroup.participantsCount).exists &&
      !$(keys.rideGroup.page).exists;

  Key _joinKey(String groupId) =>
      _solo ? keys.rideGroup.joinButton : keys.ride.groupJoinButton(groupId);

  Key _leaveKey(String groupId) =>
      _solo ? keys.rideGroup.leaveButton : keys.ride.groupLeaveButton(groupId);

  Key _fullKey(String groupId) =>
      _solo ? keys.rideGroup.fullBadge : keys.ride.groupFullButton(groupId);

  /// The block of the group: its card, or the single group's section.
  Key _groupKey(String groupId) =>
      _solo ? keys.ride.soloGroupSection : keys.ride.group(groupId);

  /// Whether the page is a single-group ride's: its group section instead of group cards.
  Future<bool> isSoloGroupRide() async {
    await $(keys.ride.title).waitUntilVisible();
    return _solo;
  }

  Future<void> waitUntilShown() async {
    await $(keys.ride.title).waitUntilVisible();
  }

  /// Waits for the page's error state, and returns how long it took to come.
  ///
  /// The error is placed, not tapped: Patrol's « visible » (hit-testable at its centre) doesn't
  /// hold for an empty state, so it is waited for as present in the tree.
  Future<Duration> waitUntilLoadErrorIsShown({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final start = DateTime.now();
    await $(keys.ride.loadError).waitUntilExists(timeout: timeout);
    return DateTime.now().difference(start);
  }

  /// « Réessayer » of the page's error state.
  Future<void> retryLoad() async {
    await $(keys.ride.loadErrorRetryButton).tap();
  }

  /// Whether the error state reads [text].
  bool loadErrorShows(String text) => shows(keys.ride.loadError, text);

  /// The ride's name as the page shows it, or null when no ride is shown.
  String? get title =>
      $(keys.ride.title).exists ? $(keys.ride.title).text : null;

  Key _leaderKey(String groupId) =>
      _solo ? keys.rideGroup.leader : keys.ride.groupLeader(groupId);

  /// The leader line of the group, or null when the card has none.
  Future<bool> showsLeader(String groupId, String name) async {
    final Key leader = _leaderKey(groupId);
    await scrolledTo(_groupKey(groupId));
    return shows(leader, name);
  }

  Future<bool> hasLeaderLine(String groupId) async {
    final Key leader = _leaderKey(groupId);
    await scrolledTo(_groupKey(groupId));
    return isShown(leader);
  }

  /// Whether [text] appears anywhere on the group's card (or the single group's section).
  bool groupShows(String groupId, String text) =>
      shows(_groupKey(groupId), text);

  /// « Rejoindre » on the group's card — or in the action bar of a single-group ride, which is
  /// always in view — then waits for « Quitter ».
  Future<void> join(String groupId) async {
    final Key leave = _leaveKey(groupId);
    await (await _actionButton(_joinKey(groupId))).tap();
    await $(leave).waitUntilVisible();
  }

  /// « Quitter » on the group's card or in the action bar, then waits for « Rejoindre ».
  Future<void> leave(String groupId) async {
    final Key join = _joinKey(groupId);
    await (await _actionButton(_leaveKey(groupId))).tap();
    await $(join).waitUntilVisible();
  }

  /// The button of [key]: the action bar's is pinned and needs no scrolling, a card's does.
  Future<PatrolFinder> _actionButton(Key key) async =>
      _solo ? $(key) : await scrolledTo(key);

  /// Taps « Rejoindre » on [groupId] while registered elsewhere, then takes the banner's way out:
  /// leave the other group and join this one.
  Future<void> switchTo(String groupId) async {
    await (await scrolledTo(keys.ride.groupJoinButton(groupId))).tap();
    await (await scrolledTo(keys.ride.switchGroupButton)).tap();
    await $(keys.ride.groupLeaveButton(groupId)).waitUntilVisible();
  }

  bool offersJoin(String groupId) => isShown(_joinKey(groupId));

  bool offersLeave(String groupId) => isShown(_leaveKey(groupId));

  /// Taps « Rejoindre » on [groupId] and waits for nothing: the answer may be a refusal.
  Future<void> tapJoin(String groupId) async {
    await (await _actionButton(_joinKey(groupId))).tap();
  }

  /// Waits until [groupId] is shown as joined — its « Quitter » is there.
  Future<void> waitUntilRegisteredIn(
    String groupId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await $(_leaveKey(groupId)).waitUntilExists(timeout: timeout);
  }

  /// Waits until the card of [groupId] (or the action bar) shows the disabled « Complet ».
  Future<void> waitUntilFull(String groupId) async {
    await $(_fullKey(groupId)).waitUntilExists();
  }

  bool offersFull(String groupId) => isShown(_fullKey(groupId));

  /// Waits for the registration failure banner, and tells whether it names [groupName].
  Future<bool> waitUntilFailureNames(String groupName) async {
    await $(keys.ride.registrationFailure).waitUntilExists();
    return shows(keys.ride.registrationFailure, groupName);
  }

  bool get showsFailure => isShown(keys.ride.registrationFailure);

  // ── Past and cancelled rides ────────────────────────────────────────────

  /// Whether the ride is marked « Terminée ».
  bool get saysFinished => isShown(keys.ride.finishedBadge);

  /// Whether the « Sortie annulée » banner is shown.
  bool get saysCancelled => isShown(keys.ride.cancelledBanner);

  Future<void> waitUntilCancelled() async {
    await $(keys.ride.cancelledBanner).waitUntilVisible();
  }

  /// Scrolls the card of [groupId] (or the single group's section) into view, for the checks
  /// made on it afterwards.
  Future<void> showGroup(String groupId) async {
    await scrolledTo(_groupKey(groupId));
  }

  /// Whether the card of [groupId] offers any action at all: « Rejoindre », « Quitter » or
  /// « Complet ».
  bool offersAnyAction(String groupId) =>
      offersJoin(groupId) || offersLeave(groupId) || offersFull(groupId);

  // ── Participants ────────────────────────────────────────────────────────

  /// « Voir la liste » of the meta block: the sheet of the whole ride's participants.
  Future<void> openParticipants() async {
    await (await scrolledTo(keys.ride.participantsButton)).tap();
    await $(keys.participants.count).waitUntilVisible();
  }

  /// Closes the participants sheet by flinging it down by its header.
  Future<void> closeParticipants() async {
    await $.tester.fling(
      find.byKey(keys.participants.count),
      const Offset(0, 600),
      2000,
    );
    await waitUntilGone(keys.participants.count);
  }

  /// Whether the open participants sheet has a row for [userId].
  bool participantsListRow(String userId) =>
      isShown(keys.participants.person(userId));

  /// The total the participants sheet reads in its header.
  String? get participantsCount => $(keys.participants.count).$(Text).text;

  // ── Exports ─────────────────────────────────────────────────────────────

  /// Scrolls to the card of [groupId] and waits for its « GPX »: the exports show once the
  /// group's route — loaded with the map's batch — is there.
  Future<void> waitUntilGpxExportIsOffered(String groupId) async {
    final Key gpx = _exportGpxKey(groupId);
    await scrolledTo(_groupKey(groupId));
    await $(gpx).waitUntilExists();
  }

  Key _exportGpxKey(String groupId) =>
      _solo ? keys.rideGroup.exportGpx : keys.ride.groupExportGpx(groupId);

  bool offersFitExport(String groupId) => isShown(
    _solo ? keys.rideGroup.exportFit : keys.ride.groupExportFit(groupId),
  );

  bool offersSendToDevice(String groupId) => isShown(
    _solo ? keys.rideGroup.sendToDevice : keys.ride.groupSendToDevice(groupId),
  );

  /// Taps « GPX » on the card of [groupId]: the app downloads the file, then hands it to the
  /// system share sheet.
  Future<void> exportGpx(String groupId) async {
    await (await scrolledTo(_exportGpxKey(groupId))).tap();
  }

  // ── Groups map ──────────────────────────────────────────────────────────

  /// Waits until the groups map's pill names [groupName] — the selected group.
  Future<void> waitUntilMapSelects(
    String groupName, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!shows(keys.ride.groupsMapPill, groupName)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure(
          'the groups map does not select $groupName after $timeout',
        );
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Taps the card of [groupId], which opens the group's page (ledger `MOB-67`) on its Overview
  /// tab — or on [tab] (`weather`, `participants`) once it is shown. A ride of two groups or more
  /// only: a single group has no card and no page (ledger `MOB-69`).
  Future<void> openGroup(String groupId, {String? tab}) async {
    if (_solo) {
      throw TestFailure('a single-group ride has no group page to open');
    }
    await (await scrolledTo(keys.ride.group(groupId))).tap();
    await $(keys.rideGroup.page).waitUntilExists();
    if (tab != null) await openGroupTab(tab);
  }

  /// Switches the group's page to its `overview`, `weather` or `participants` tab.
  Future<void> openGroupTab(String tab) async {
    await $(switch (tab) {
      'weather' => keys.rideGroup.tabWeather,
      'participants' => keys.rideGroup.tabParticipants,
      _ => keys.rideGroup.tabOverview,
    }).tap();
  }

  /// Whether the group's page is open, on its Weather tab's sections or its empty state.
  Future<void> waitUntilGroupWeatherIsShown() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!$(keys.ride.weatherCheckpoint(0)).exists &&
        !$(keys.rideGroup.weatherEmpty).exists &&
        !$(keys.ride.weatherLegUnavailable).exists &&
        !$(keys.ride.weatherNotYetAvailable).exists &&
        !$(keys.ride.weatherUnavailable).exists) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('the group page shows no weather after 20s');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Back from the group's page to the ride.
  Future<void> closeGroup() async {
    await $(keys.rideGroup.backButton).tap();
    await waitUntilShown();
  }

  /// Whether the group's page names [name] as its leader.
  bool groupPageShowsLeader(String name) => shows(keys.rideGroup.leader, name);

  /// Whether the group's page has a leader row at all.
  bool get groupPageHasLeader => isShown(keys.rideGroup.leader);

  /// « Rejoindre » of the group page's action bar, then waits for « Quitter ».
  Future<void> joinFromGroupPage() async {
    await $(keys.rideGroup.joinButton).tap();
    await $(keys.rideGroup.leaveButton).waitUntilVisible();
  }

  /// Whether the group page says the member is registered in another group.
  bool get groupPageSaysRegisteredElsewhere =>
      isShown(keys.rideGroup.registeredElsewhere);

  bool get groupPageOffersJoin => isShown(keys.rideGroup.joinButton);

  /// Taps the pill of [groupId] on the group's page.
  Future<void> switchGroupPageTo(String groupId) async {
    await $(keys.rideGroup.groupChip(groupId)).tap();
    await $.pump(const Duration(milliseconds: 300));
  }

  /// Selects [groupId] for the map, the legend and the profile: its card opens the group's page,
  /// which shares the selection with the ride, and the way back finds it selected. Two groups or
  /// more: a single group is always the selected one.
  Future<void> selectGroup(String groupId) async {
    await openGroup(groupId);
    await closeGroup();
  }

  /// Lets the refetch that follows a registration settle.
  Future<void> settle() async {
    await $.pump(const Duration(seconds: 2));
    await $.pumpAndTrySettle();
  }
}
