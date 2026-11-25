import 'package:flutter/widgets.dart';

import 'module.dart';

/// The GPX tools (ledger `MOB-178`): the entry of the Explorer tab, the hub, a preview's page and
/// its `⋯` menu. The file reaches the app through `RouteEditor.provideGpx`, which swaps the app's
/// picker — the native document picker is never driven.
final class GpxTools extends Module {
  GpxTools(super.$);

  /// The Explorer tab's « Outils GPX » segment (ledger `MOB-192`) → the hub.
  Future<void> openFromExplorer() async {
    await $(keys.gpxTools.entryButton).waitUntilVisible();
    await $(keys.gpxTools.entryButton).tap();
    await $(keys.gpxTools.viewFileButton).waitUntilVisible();
  }

  /// The hub is on screen.
  Future<void> waitUntilHubShown() async {
    await $(keys.gpxTools.viewFileButton).waitUntilVisible();
  }

  /// « Choisir un fichier »: the file is sent at once, its page opens.
  Future<void> viewFile() async {
    await $(keys.gpxTools.viewFileButton).tap();
    await $(keys.gpxTools.previewTitle)
        .waitUntilVisible(timeout: const Duration(seconds: 30));
  }

  /// The preview's page reads [name] as its title.
  Future<void> waitUntilTitleIs(String name) async {
    await $(keys.gpxTools.previewTitle)
        .$(name)
        .waitUntilVisible(timeout: const Duration(seconds: 20));
  }

  Future<void> _openMenu(Key action) async {
    await $(keys.gpxTools.moreButton).tap();
    await $(action).waitUntilVisible();
    await $(action).tap();
  }

  /// `⋯` → « Dupliquer », with the « Copie de … » name the sheet proposes.
  Future<void> duplicate() async {
    await _openMenu(keys.gpxTools.duplicateAction);
    await $(keys.gpxTools.duplicateSubmit).waitUntilVisible();
    await $(keys.gpxTools.duplicateSubmit).tap();
    await waitUntilGone(keys.gpxTools.duplicateSheet);
  }

  /// `⋯` → « Enregistrer comme parcours » in [teamSlug]: the route's page opens.
  Future<void> saveAsRoute(String teamSlug) async {
    await _openMenu(keys.gpxTools.saveAsRouteAction);
    await $(keys.gpxTools.saveAsRouteTeam(teamSlug)).waitUntilVisible();
    await $(keys.gpxTools.saveAsRouteTeam(teamSlug)).tap();
    await $(keys.gpxTools.saveAsRouteSubmit).tap();
    await $(keys.routeDetail.title)
        .waitUntilVisible(timeout: const Duration(seconds: 30));
  }

  /// `⋯` → « Supprimer », through its confirmation: the page closes.
  Future<void> delete() async {
    await _openMenu(keys.gpxTools.deleteAction);
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilGone(
      keys.gpxTools.previewTitle,
      timeout: const Duration(seconds: 20),
    );
  }
}
