import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';

import 'module.dart';

/// The screens around the app's core: the legal pages, « Signaler un problème », and the push
/// activation banner.
final class Peripheral extends Module {
  Peripheral(super.$);

  // ── Legal pages ─────────────────────────────────────────────────────────

  Future<void> openTermsFromSignUp() async {
    await (await scrolledTo(keys.login.termsLink)).tap();
  }

  Future<void> openPrivacyFromSignUp() async {
    await (await scrolledTo(keys.login.privacyLink)).tap();
  }

  /// Waits for the legal page's text, and for it to say [text].
  Future<void> waitUntilLegalPageSays(String text) => _waitUntil(
    () => isShown(keys.legal.content) && shows(keys.legal.content, text),
    'the legal page saying « $text »',
  );

  Future<void> leaveLegalPage() async {
    await $(keys.legal.backButton).tap();
    await waitUntilGone(keys.legal.backButton);
  }

  // ── « Signaler un problème » ────────────────────────────────────────────

  /// Profile → « Aide et à propos » → « Signaler un problème ».
  Future<void> openReportProblemFromProfile() async {
    await _openHelp();
    await (await scrolledTo(keys.profile.reportProblemRow)).tap();
    await $(keys.feedback.messageField).waitUntilVisible();
  }

  Future<void> chooseFeedbackKind(FeedbackKind kind) async {
    await $(keys.feedback.kind(kind)).tap();
  }

  Future<void> typeFeedback(String message) async {
    await $(keys.feedback.messageField).enterText(message);
  }

  bool get feedbackSendIsEnabled =>
      ($(keys.feedback.sendButton).evaluate().single.widget as PdlButton)
          .enabled;

  Future<void> sendFeedback() async {
    await $(keys.feedback.sendButton).tap();
  }

  /// The sheet closed on the server's 204, and the thanks are shown.
  Future<void> waitUntilFeedbackIsSent() async {
    await waitUntilGone(
      keys.feedback.messageField,
      timeout: const Duration(seconds: 20),
    );
    await $(keys.feedback.sentMessage).waitUntilVisible();
  }

  // ── Push activation ─────────────────────────────────────────────────────

  /// The bell, then the inbox — whether it holds anything or not (an empty inbox has no « Tout
  /// marquer lu »).
  Future<void> openInboxFromBell() async {
    await $(keys.notifications.bell).tap();
    await $(keys.notifications.filter).waitUntilVisible();
  }

  /// Whether the push activation banner stays away for [window] — the inbox asks for its
  /// preferences after it is shown, so one look is not enough to call it absent.
  Future<bool> pushActivationBannerStaysHidden({
    Duration window = const Duration(seconds: 4),
  }) async {
    final deadline = DateTime.now().add(window);
    while (DateTime.now().isBefore(deadline)) {
      if (isShown(keys.notifications.pushActivationBanner)) return false;
      await $.pump(const Duration(milliseconds: 200));
    }
    return true;
  }

  Future<void> _waitUntil(
    bool Function() condition,
    String what, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('not shown after $timeout: $what');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// The profile overview's « Aide et à propos », where both entries live.
  Future<void> _openHelp() async {
    await (await scrolledTo(keys.profile.helpRow)).tap();
    await $(keys.profile.appsRow).waitUntilExists();
  }
}
