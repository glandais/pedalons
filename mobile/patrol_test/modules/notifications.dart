import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'module.dart';

/// The home bell, the inbox, and the profile's « Notifications » settings: the channel chips of
/// each type, the daily digest, the per-team switches, and the way between them and the inbox.
final class Notifications extends Module {
  Notifications(super.$);

  /// The bell's badge once it shows one: the number it reads. The bell polls `unread-count`
  /// as the session starts, then once a minute.
  Future<String> waitForBellBadge() async {
    await $(keys.notifications.bell).waitUntilVisible();
    final badge = $(keys.notifications.bell).$(RegExp(r'^\d+\+?$'));
    await badge.waitUntilExists();
    return badge.text!;
  }

  Future<void> openInboxFromBell() async {
    await $(keys.notifications.bell).tap();
    await $(keys.notifications.markAllReadButton).waitUntilVisible();
  }

  Future<void> waitUntilEntryIsShown(String notificationId) async {
    await scrolledTo(keys.notifications.tile(notificationId));
  }

  /// Whether the entry reads [text] — its title, subject, team or date line.
  bool entryShows(String notificationId, String text) =>
      shows(keys.notifications.tile(notificationId), text);

  Future<void> openEntry(String notificationId) async {
    await $(keys.notifications.tile(notificationId)).tap();
  }

  /// « Notifications » of the profile (`Profile.openNotificationSettings`) → the team's switch
  /// « receive its announcements », toggled.
  Future<void> toggleTeamInProfile(String teamSlug) async {
    await (await scrolledTo(keys.notifications.teamSwitch(teamSlug))).tap();
  }

  /// Whether the type's row carries a chip for [channel] (`EMAIL`, `PUSH`): only the channels the
  /// server declares get one.
  bool showsChannelChip(String type, String channel) =>
      isShown(keys.notifications.channelChip(type, channel));

  /// The chip of [channel] on the row of [type], tapped: it writes that cell alone.
  Future<void> toggleChannelChip(String type, String channel) async {
    await (await scrolledTo(keys.notifications.channelChip(type, channel)))
        .tap();
  }

  /// Scrolls the settings down to the team's switch, their last section: once it shows, the
  /// settings have loaded, whatever channels the server declares.
  Future<void> waitUntilTeamSwitchIsShown(String teamSlug) async {
    await scrolledTo(keys.notifications.teamSwitch(teamSlug));
  }

  /// Back to the top of the settings, where the first family's rows are built.
  Future<void> scrollSettingsToTop() async {
    await scrolledTo(keys.notifications.openInboxRow);
  }

  /// Whether « Résumé quotidien par e-mail » is there — read near the teams' section, just under it.
  bool get showsDigest => isShown(keys.notifications.digestSwitch);

  /// « Ouvrir mes notifications », at the top of the settings: the inbox, in the Accueil branch.
  Future<void> openInboxFromSettings() async {
    await (await scrolledTo(keys.notifications.openInboxRow)).tap();
    await $(keys.notifications.settingsButton).waitUntilVisible();
  }

  /// The inbox's settings button: back to the profile's « Notifications ».
  Future<void> openSettingsFromInbox() async {
    await $(keys.notifications.settingsButton).tap();
    await $(keys.notifications.openInboxRow).waitUntilExists();
  }

  // ── The bell ────────────────────────────────────────────────────────────

  bool get bellShowsBadge => $(keys.notifications.bell).$(_badge).exists;

  /// Waits until the bell carries no badge any more.
  Future<void> waitUntilBellBadgeIsGone({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await $(keys.notifications.bell).waitUntilVisible();
    final deadline = DateTime.now().add(timeout);
    while (bellShowsBadge) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('the bell still shows a badge after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  static final RegExp _badge = RegExp(r'^\d+\+?$');

  // ── The inbox filter ────────────────────────────────────────────────────

  /// « Toutes », the first segment of the filter.
  Future<void> showAll() => _tapFilterSegment(keys.notifications.filterAll);

  /// « Non lues », the second segment.
  Future<void> showUnreadOnly() =>
      _tapFilterSegment(keys.notifications.filterUnread);

  Future<void> _tapFilterSegment(Key segment) async {
    await $(segment).tap();
    await $.pump(const Duration(milliseconds: 500));
  }

  bool isEntryShown(String notificationId) =>
      isShown(keys.notifications.tile(notificationId));

  /// « Tout marquer lu », in the inbox's app bar.
  Future<void> markAllRead() async {
    await $(keys.notifications.markAllReadButton).tap();
    await $.pump(const Duration(milliseconds: 500));
  }

  /// The empty state of the « Non lues » filter — « Aucune non lue » — once it shows.
  Future<void> waitUntilUnreadEmptyStateIsShown({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await $(keys.notifications.unreadEmptyState)
        .waitUntilVisible(timeout: timeout);
  }

  /// The empty state's way out: « Toutes ».
  Future<void> tapShowAllFromEmptyState() async {
    await $(keys.notifications.showAllButton).tap();
  }
}
