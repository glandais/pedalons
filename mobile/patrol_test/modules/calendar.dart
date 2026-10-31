import 'package:flutter/services.dart';
import 'package:pedalons/core/adaptive/navigation_destination.dart';

import '../common.dart';
import 'module.dart';

/// The calendar: the tab of all my teams, a team's own section, its agenda cards and the ICS
/// feed's subscription card.
final class Calendar extends Module {
  Calendar(super.$);

  Future<void> goToCalendar() async {
    await $(
      keys.navigation.tab(
        kAppDestinations.firstWhere((d) => d.label == 'nav.calendar'),
      ),
    ).tap();
  }

  /// Moves the calendar, which opens on the current month, to the month of [day].
  Future<void> showMonthOf(DateTime day) async {
    final now = DateTime.now();
    final months = (day.year - now.year) * 12 + day.month - now.month;
    for (var i = 0; i < months; i++) {
      await $(keys.calendar.nextMonthButton).tap();
    }
  }

  /// Waits until the agenda holds the card of [entitySlug], and brings it on screen.
  Future<void> waitUntilEventIsShown(String entitySlug) async {
    await $(keys.calendar.agendaCard(entitySlug))
        .waitUntilExists(timeout: const Duration(seconds: 20));
    await scrolledTo(keys.calendar.agendaCard(entitySlug));
  }

  /// [waitUntilEventIsShown] in a team's Agenda, where the card is brought on screen by
  /// [scrolledIntoView]: on a phone smaller than an iPhone Pro Max the card starts under the tab
  /// bar and the agenda below the month grid is short — dragging it until the card's centre is
  /// hit-testable overshoots the card past the top.
  Future<void> waitUntilTeamEventIsShown(String entitySlug) async {
    await $(keys.calendar.agendaCard(entitySlug))
        .waitUntilExists(timeout: const Duration(seconds: 20));
    await scrolledIntoView(keys.calendar.agendaCard(entitySlug));
  }

  bool showsEvent(String entitySlug) =>
      isShown(keys.calendar.agendaCard(entitySlug));

  bool eventShows(String entitySlug, String text) =>
      shows(keys.calendar.agendaCard(entitySlug), text);

  bool showsRegistered(String entitySlug) =>
      isShown(keys.calendar.agendaRegisteredBadge(entitySlug));

  /// Whether the « Inscrit · groupe » badge reads [text] — a badge renders its label in
  /// capitals.
  bool registeredBadgeShows(String entitySlug, String text) => shows(
    keys.calendar.agendaRegisteredBadge(entitySlug),
    text.toUpperCase(),
  );

  Future<void> openEvent(String entitySlug) async {
    await (await scrolledTo(keys.calendar.agendaCard(entitySlug))).tap();
  }

  /// Taps the copy button of the subscription card, and returns what the clipboard received.
  ///
  /// The clipboard is emptied first, then read until the copy has landed: the notice is no proof of
  /// it on a second copy (it is still there from the first one, or from « Régénérer »), and on
  /// Android the clipboard write can trail the tap.
  Future<String?> copyFeedUrl() async {
    await Clipboard.setData(const ClipboardData(text: ''));
    await (await scrolledTo(keys.calendar.subscriptionCopyButton)).tap();
    await $(keys.calendar.subscriptionNotice).waitUntilExists();
    return eventually(
      () async => (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      until: (String? text) => text != null && text.isNotEmpty,
      description: 'the feed URL in the clipboard',
      timeout: const Duration(seconds: 10),
    );
  }

  /// « Régénérer », then the confirmation of the closed question.
  Future<void> regenerateFeed() async {
    await (await scrolledTo(keys.calendar.subscriptionRegenerateButton)).tap();
    await $(keys.calendar.subscriptionRegenerateConfirmButton).tap();
    await waitUntilGone(keys.calendar.subscriptionRegenerateConfirmButton);
    // Said once the new token is read back: before, the card still holds the old one.
    await $(keys.calendar.subscriptionNotice)
        .$(RegExp("^Lien régénéré"))
        .waitUntilExists();
  }

  bool noticeShows(String text) =>
      shows(keys.calendar.subscriptionNotice, text);
}
