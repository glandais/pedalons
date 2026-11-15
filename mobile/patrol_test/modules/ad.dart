import 'module.dart';

/// The ad page, and what it offers depending on who reads it.
final class Ad extends Module {
  Ad(super.$);

  Future<void> waitUntilShown() async {
    await $(keys.ad.title).waitUntilVisible();
  }

  Future<bool> offersContact() async {
    if (isShown(keys.ad.contactButton)) return true;
    // Below the description and the location: scroll before concluding.
    try {
      await scrolledTo(keys.ad.contactButton);
      return true;
    } on Object {
      return false;
    }
  }

  /// Opens the `⋯` menu: what it offers is read with the [Moderation] module, or below for the
  /// « Gérer l'annonce » menu of its author (ledger `MOB-158`).
  Future<void> openMoreMenu() async {
    await $(keys.ad.moreButton).tap();
  }

  /// The « Gérer l'annonce » menu is open: it always offers the deletion to whoever may manage.
  Future<void> waitUntilManageMenuIsShown() async {
    await $(keys.adManage.delete).waitUntilVisible();
  }

  bool get manageMenuOffersReport => isShown(keys.adManage.report);
}
