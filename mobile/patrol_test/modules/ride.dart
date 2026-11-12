import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';

import 'module.dart';

/// The ride page: its groups, their leaders, and joining one.
///
/// A ride with a single group has no group card and no group page (ledger `MOB-69`): its detail
/// *is* the group's page, laid out like it (ledger `MOB-134`, lot 7) — the registration control
/// in the departure block (« Rejoindre », the « J'y vais » badge, « Complet »), « Quitter le
/// groupe » at the foot of « Personnes inscrites » ([keys.ride.participantsSection]), the GPS
/// button in « Parcours » ([keys.ride.routeSection]); the controls carry the group page's keys
/// (`keys.rideGroup.*`). The group helpers below take the same `groupId` either way and pick the
/// keys of the shape the page has, so a test of joining doesn't care how many groups the ride
/// has. The group page helpers ([openGroup], [selectGroup]) need two groups or more.
///
/// A ride of several groups (ledger `MOB-134`, lot 8) puts the registration on each group card:
/// « Rejoindre » when registered nowhere, « Changer pour A » on the other open cards when
/// registered elsewhere — one call, no banner on the way —, « Complet » disabled; on one's own
/// card the « J'y vais » badge next to the name, the « GPS » button, and « Quitter le groupe » as a
/// discreet link at the foot of the card (never beside the chevron).
final class Ride extends Module {
  Ride(super.$);

  /// Whether a widget of [key] is built, on screen or scrolled out of it: a single-group ride's
  /// controls sit at both ends of a long page, so one of them is always off screen.
  bool _inTree(Key key) =>
      find.byKey(key, skipOffstage: false).evaluate().isNotEmpty;

  /// Whether the ride on screen is a single-group one: its « Personnes inscrites » section is
  /// built — a ride of several groups has cards instead, one with no group has neither — while
  /// no group page is open on top.
  bool get _solo =>
      _inTree(keys.ride.participantsSection) && !$(keys.rideGroup.page).exists;

  Key _joinKey(String groupId) =>
      _solo ? keys.rideGroup.joinButton : keys.ride.groupJoinButton(groupId);

  Key _leaveKey(String groupId) =>
      _solo ? keys.rideGroup.leaveButton : keys.ride.groupLeaveButton(groupId);

  /// What tells a registration took: the « J'y vais » badge — of a single-group ride's departure
  /// block, or next to the group card's name.
  Key _registeredKey(String groupId) =>
      _solo ? keys.rideGroup.goingBadge : keys.ride.groupGoingBadge(groupId);

  Key _fullKey(String groupId) =>
      _solo ? keys.rideGroup.fullBadge : keys.ride.groupFullButton(groupId);

  /// The block of the group: its card, or the single group's « Personnes inscrites ».
  Key _groupKey(String groupId) =>
      _solo ? keys.ride.participantsSection : keys.ride.group(groupId);

  /// Whether a control of [key] is offered: on screen for a group card, anywhere on the page for a
  /// single-group ride.
  bool _offers(Key key) => _solo ? _inTree(key) : isShown(key);

  /// Whether the page is a single-group ride's: its « Personnes inscrites » instead of group
  /// cards.
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

  /// Whether the non-member banner is built: neither registration nor names for the caller.
  bool get saysNotMember => _inTree(keys.ride.notMemberBanner);

  /// Whether the page offers to open the ride's team: the line above the title is a link, or the
  /// non-member banner carries « Voir l'équipe ».
  bool get offersTeam =>
      _inTree(keys.ride.viewTeamButton) ||
      find
          .descendant(
            of: find.byKey(keys.ride.teamLine),
            matching: find.byType(InkWell),
          )
          .evaluate()
          .isNotEmpty;

  /// The back button of the ride's bar.
  Future<void> goBack() async {
    await $(keys.ride.backButton).tap();
  }

  /// The ride's name as the page shows it, or null when no ride is shown.
  String? get title =>
      $(keys.ride.title).exists ? $(keys.ride.title).text : null;

  Key _leaderKey(String groupId) =>
      _solo ? keys.rideGroup.leader : keys.ride.groupLeader(groupId);

  /// The leader line of the group, or null when the card has none.
  Future<bool> showsLeader(String groupId, String name) async {
    final Key leader = _leaderKey(groupId);
    await showGroup(groupId);
    return shows(leader, name);
  }

  Future<bool> hasLeaderLine(String groupId) async {
    final Key leader = _leaderKey(groupId);
    await showGroup(groupId);
    return isShown(leader);
  }

  /// Whether [text] appears anywhere on the group's card (or the single group's « Personnes
  /// inscrites »).
  bool groupShows(String groupId, String text) =>
      shows(_groupKey(groupId), text);

  /// « Rejoindre » on the group's card — or in the departure block of a single-group ride — then
  /// waits for the « J'y vais » badge, on the card or in the block.
  Future<void> join(String groupId) async {
    final Key registered = _registeredKey(groupId);
    await (await scrolledTo(_joinKey(groupId))).tap();
    await $(find.byKey(registered, skipOffstage: false)).waitUntilExists();
  }

  /// « Quitter le groupe » — at the foot of the group's card, or of a single-group ride's
  /// « Personnes inscrites » — then waits for « Rejoindre »: at the top of the card, or back in a
  /// single-group ride's departure block, at the top of the page. Either may be off screen.
  Future<void> leave(String groupId) async {
    final Key join = _joinKey(groupId);
    await (await scrolledTo(_leaveKey(groupId))).tap();
    await $(find.byKey(join, skipOffstage: false)).waitUntilExists();
  }

  /// « Changer pour {group} » on the card of [groupId] while registered in another group of the
  /// ride — one call (ledger `API-171`), no confirmation, no banner — then waits for the card's
  /// « J'y vais » badge.
  Future<void> switchTo(String groupId) async {
    await (await scrolledTo(keys.ride.groupSwitchButton(groupId))).tap();
    await $(find.byKey(keys.ride.groupGoingBadge(groupId), skipOffstage: false))
        .waitUntilExists();
  }

  bool offersJoin(String groupId) => _offers(_joinKey(groupId));

  bool offersLeave(String groupId) => _offers(_leaveKey(groupId));

  /// Whether the card of [groupId] offers « Changer pour {group} » (several groups only).
  bool offersSwitch(String groupId) =>
      !_solo && isShown(keys.ride.groupSwitchButton(groupId));

  /// Whether a single-group ride's departure block says « J'y vais ».
  bool get saysGoing => _inTree(keys.rideGroup.goingBadge);

  /// Taps « Rejoindre » on [groupId] and waits for nothing: the answer may be a refusal.
  Future<void> tapJoin(String groupId) async {
    await (await scrolledTo(_joinKey(groupId))).tap();
  }

  /// Waits until [groupId] is shown as joined — the « J'y vais » badge of its card, or of a
  /// single-group ride's departure block.
  Future<void> waitUntilRegisteredIn(
    String groupId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await $(find.byKey(_registeredKey(groupId), skipOffstage: false))
        .waitUntilExists(timeout: timeout);
  }

  /// Waits until the card of [groupId] (or a single-group ride's departure block) shows the
  /// disabled « Complet ».
  Future<void> waitUntilFull(String groupId) async {
    await $(find.byKey(_fullKey(groupId), skipOffstage: false))
        .waitUntilExists();
  }

  bool offersFull(String groupId) => _offers(_fullKey(groupId));

  /// The registration failure of [groupId]: on a ride of several groups, inside that group's
  /// card (rule R6 of the cards, KIT §9, ledger `MOB-139`) — no longer a banner at the head of
  /// « Groupes »; on a single-group ride, the screen's banner.
  Key _failureKey(String groupId) => _solo
      ? keys.ride.registrationFailure
      : keys.ride.groupRegistrationFailure(groupId);

  /// Waits for the registration failure of [groupId], and tells whether it says so where it
  /// should: inside the card of [groupId] on a ride of several groups — the card names the group,
  /// the sentence no longer does (« Ce groupe est complet. Choisissez un autre groupe. ») —, in the
  /// banner naming [groupName] on a single-group ride.
  Future<bool> waitUntilFailureOn(String groupId, String groupName) async {
    final Key key = _failureKey(groupId);
    await $(find.byKey(key, skipOffstage: false)).waitUntilExists();
    if (_solo) return shows(key, groupName);
    return find
        .descendant(
          of: find.byKey(keys.ride.group(groupId), skipOffstage: false),
          matching: find.byKey(key, skipOffstage: false),
          skipOffstage: false,
        )
        .evaluate()
        .isNotEmpty;
  }

  /// Whether a registration failure is shown — the screen's banner, or one inside any group card.
  bool get showsFailure =>
      isShown(keys.ride.registrationFailure) ||
      find
          .byWidgetPredicate(
            (Widget w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.contains('groupFailure_'),
            skipOffstage: false,
          )
          .evaluate()
          .isNotEmpty;

  // ── Past and cancelled rides ────────────────────────────────────────────

  /// Whether the ride is marked « Terminée ».
  bool get saysFinished => isShown(keys.ride.finishedBadge);

  /// Whether the « Sortie annulée » banner is shown.
  bool get saysCancelled => isShown(keys.ride.cancelledBanner);

  Future<void> waitUntilCancelled() async {
    await $(keys.ride.cancelledBanner).waitUntilVisible();
  }

  /// Scrolls the card of [groupId] (or the single group's « Personnes inscrites ») into view, for
  /// the checks made on it afterwards.
  ///
  /// A card is tapped through its centre, and scrolled to until it is hit-testable there; a
  /// section is only brought into view — its middle may be empty.
  Future<void> showGroup(String groupId) async {
    if (_solo) {
      await scrolledIntoView(_groupKey(groupId));
    } else {
      await scrolledTo(_groupKey(groupId));
    }
  }

  /// Whether the card of [groupId] offers any action at all: « Rejoindre », « Changer pour »,
  /// « Quitter le groupe » or « Complet » — and, on a single-group ride, the « J'y vais » badge.
  bool offersAnyAction(String groupId) =>
      offersJoin(groupId) ||
      offersSwitch(groupId) ||
      offersLeave(groupId) ||
      offersFull(groupId) ||
      (_solo && saysGoing);

  // ── Participants ────────────────────────────────────────────────────────

  /// « Voir les N personnes inscrites » under the group cards (a ride of several groups): the
  /// sheet of the whole ride's participants.
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

  /// The « GPS » button of [groupId]: on its card — one's own group's only —, or in a
  /// single-group ride's « Parcours ».
  Key _gpsKey(String groupId) =>
      _solo ? keys.rideGroup.gps : keys.ride.groupGps(groupId);

  /// Whether the « GPS » button of [groupId] is built — on a ride of several groups, only one's
  /// own group's card has one.
  bool offersGps(String groupId) => _inTree(_gpsKey(groupId));

  /// Scrolls to the card of [groupId] (or a single-group ride's « Parcours ») and waits for its
  /// « GPS » button: it shows once the group's route — loaded with the map's batch — is there
  /// with a file to export.
  Future<void> waitUntilGpsIsOffered(String groupId) async {
    final bool solo = _solo;
    if (solo) {
      await scrolledIntoView(keys.ride.routeSection);
    } else {
      await scrolledTo(_groupKey(groupId));
    }
    await $(_gpsKey(groupId)).waitUntilExists();
  }

  /// Taps « GPS » on the card of [groupId] and waits for the GPS sheet — every export of the
  /// group's route lives there.
  Future<void> openGpsSheet(String groupId) async {
    await (await scrolledTo(_gpsKey(groupId))).tap();
    await $(keys.gpsSheet.sheet).waitUntilVisible();
  }

  /// In the open GPS sheet: whether the FIT section is there (its share row is, on both
  /// platforms — « Envoyer vers une autre app » on Android, « Partager » on iOS).
  bool get gpsSheetOffersFit => isShown(keys.gpsSheet.fitShare);

  /// In the open GPS sheet: whether « Vers un appareil » is there — only with a connected
  /// GPS service.
  bool get gpsSheetOffersSendToDevice => isShown(keys.gpsSheet.toDevice);

  /// In the open GPS sheet: whether « Connecter un compteur » is there — only with no
  /// connected GPS service.
  bool get gpsSheetOffersConnectDevice => isShown(keys.gpsSheet.connectDevice);

  /// In the open GPS sheet, hands the GPX to the system share sheet: « Envoyer vers une autre
  /// app » on Android, « Partager » on iOS — the same key. The sheet closes, then the app
  /// downloads the file.
  Future<void> shareGpxFromGpsSheet() async {
    await $(keys.gpsSheet.gpxShare).tap();
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

  /// Taps the card of [groupId], which opens the group's page (ledgers `MOB-67`, `MOB-134`): one
  /// scrolling page, no tabs. A ride of two groups or more only: a single group has no card and no
  /// page (ledger `MOB-69`).
  Future<void> openGroup(String groupId) async {
    if (_solo) {
      throw TestFailure('a single-group ride has no group page to open');
    }
    await (await scrolledTo(keys.ride.group(groupId))).tap();
    await $(keys.rideGroup.page).waitUntilExists();
  }

  /// Scrolls the group's page down to its Météo section, its last block, and waits until the
  /// forecast has loaded: the section then shows its timeline or one of its states — for
  /// `OUT_OF_RANGE` or a member's `NO_LOCATION`, its title and a line saying there is nothing to
  /// show (ledger `MOB-134`).
  Future<void> waitUntilGroupWeatherIsShown() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    await scrolledIntoView(keys.rideGroup.weatherSection);
    while ($(keys.rideGroup.weatherLoading).exists) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('the group page still loads its weather after 20s');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Back from the group's page to the ride.
  ///
  /// The ride comes back where it was left — scrolled down to the group's card, its title
  /// possibly scrolled out of the tree — so what tells it is back is its app bar's `⋯`, which
  /// no scroll moves, once the group's page is gone.
  Future<void> closeGroup() async {
    await $(keys.rideGroup.backButton).tap();
    await waitUntilGone(keys.rideGroup.page);
    await $(keys.ride.moreButton).waitUntilVisible();
  }

  /// Whether the group's page names [name] as its leader, in « Personnes inscrites » — scrolled
  /// to first: the section is below the route, out of the tree on a phone.
  Future<bool> groupPageShowsLeader(String name) async {
    await scrolledIntoView(keys.rideGroup.participantsSection);
    return shows(keys.rideGroup.leader, name);
  }

  /// Whether the group's page has a leader row at all.
  Future<bool> groupPageHasLeader() async {
    await scrolledIntoView(keys.rideGroup.participantsSection);
    return isShown(keys.rideGroup.leader);
  }

  /// « Rejoindre » of the group page's departure block, then waits for its « J'y vais » badge.
  Future<void> joinFromGroupPage() async {
    await (await scrolledTo(keys.rideGroup.joinButton)).tap();
    await $(keys.rideGroup.goingBadge).waitUntilVisible();
  }

  /// Whether the group page's departure block offers « Changer pour {group} »: registered in
  /// another group of the ride, this one still open.
  Future<bool> groupPageOffersSwitch() async {
    await scrolledIntoView(keys.rideGroup.departureBlock);
    return isShown(keys.rideGroup.switchButton);
  }

  /// Whether the group page's departure block offers « Rejoindre ».
  Future<bool> groupPageOffersJoin() async {
    await scrolledIntoView(keys.rideGroup.departureBlock);
    return isShown(keys.rideGroup.joinButton);
  }

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
