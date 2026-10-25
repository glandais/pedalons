import 'module.dart';

/// The page that pairs a Garmin or Karoo device (`/garmin`, `/karoo`).
final class Device extends Module {
  Device(super.$);

  /// Existence, not hit-testing: the success state is a column of spaced blocks, and its centre
  /// can fall on one of the gaps between them — in French on an Android phone it does, and the
  /// column was never « visible » although fully on screen.
  Future<void> waitUntilPaired() async {
    await $(keys.device.success)
        .waitUntilExists(timeout: const Duration(seconds: 10));
  }

  /// The Hammerhead step a Karoo goes on to once authorized (docs/LEDGER_*.md API-63) —
  /// existence, for the same reason as [waitUntilPaired].
  Future<void> waitUntilHammerheadStep() async {
    await $(keys.device.hammerhead)
        .waitUntilExists(timeout: const Duration(seconds: 10));
    await $(keys.device.connectHammerheadButton).waitUntilExists();
  }

  /// Whether the page shows the bare « paired » state — never, for a Karoo without Hammerhead.
  bool get showsPaired => $(keys.device.success).exists;

  /// Whether the Hammerhead step says why the last attempt failed.
  bool get showsHammerheadError => $(keys.device.hammerheadError).exists;

  /// Waits for the Hammerhead step to say why the last attempt failed. A link opened onto a page
  /// already at that step lands a frame or more later: [waitUntilHammerheadStep] would return on
  /// the page underneath.
  Future<void> waitUntilHammerheadError() async {
    await $(keys.device.hammerheadError)
        .waitUntilExists(timeout: const Duration(seconds: 10));
  }

  /// Existence too: the error state is the same kind of spaced column.
  Future<void> waitUntilCodeIsRefused() async {
    await $(keys.device.error)
        .waitUntilExists(timeout: const Duration(seconds: 10));
  }

  /// Waits for the confirmation card, then presses « Autoriser » — the only
  /// way a device gets paired (docs/LEDGER_*.md SEC-2).
  Future<void> authorize() async {
    await $(keys.device.confirm)
        .waitUntilExists(timeout: const Duration(seconds: 10));
    await $(keys.device.authorizeButton).scrollTo();
    await $(keys.device.authorizeButton).tap();
  }

  Future<void> tryAgain() async {
    await $(keys.device.tryAgainButton).tap();
    await $(keys.device.codeField).waitUntilVisible();
  }

  /// Types [code] as the rider reads it off the device, and continues.
  Future<void> enterCode(String code) async {
    await $(keys.device.codeField).enterText(code);
    await $(keys.device.submitButton).tap();
  }

  /// What the code field holds once typed — the field upper-cases as it goes.
  String? get typedCode => $(keys.device.codeField).text;
}
