import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pedalons/api/generated/export.dart' show SurfaceType;
import 'package:pedalons/app.dart';
import 'package:pedalons/features/routes/data/gpx_file_source.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';

import 'module.dart';

/// The route editor (ledger `MOB-79`) and the organizer's gestures on a route page: the « Ajouter »
/// button of the team's Parcours section, the pencil, and the « Gérer le parcours » menu behind
/// `⋯`.
///
/// **The native document picker is never driven.** Patrol cannot choose a file in the iOS Files
/// sheet nor in Android's picker, so [provideGpx] writes the file under the temporary directory
/// and swaps the picker of the running app (`gpxFilePickerProvider`) for one that answers with it.
/// Everything after the choice — the local check, the form, the upload — is the real thing.
final class RouteEditor extends Module {
  RouteEditor(super.$);

  // ── The file ───────────────────────────────────────────────────────────

  /// Writes [content] to a file named [fileName] and makes it the file the next « Choisir un
  /// fichier GPX » (or « Remplacer le GPX ») answers with.
  Future<void> provideGpx({
    required String fileName,
    required String content,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    final gpx = GpxFile(
      path: file.path,
      name: fileName,
      size: await file.length(),
    );
    ProviderScope.containerOf($.tester.element(find.byType(PedalonsApp)))
        .read(gpxFilePickerProvider.notifier)
        .state = _FixedPicker(
      gpx,
    );
  }

  // ── Step 1 ─────────────────────────────────────────────────────────────

  /// The team's Parcours section is on screen once its search field is.
  Future<void> waitUntilTeamRoutesShown() async {
    await $(keys.routes.searchField).waitUntilVisible();
  }

  bool get offersAdd => isShown(keys.routes.addButton);

  /// The team's Parcours section → « Ajouter » → the first step of the creation.
  Future<void> openAddFromTeamRoutes() async {
    await $(keys.routes.addButton).waitUntilVisible();
    await $(keys.routes.addButton).tap();
    await $(keys.routeEditor.pickButton).waitUntilVisible();
  }

  /// « Choisir un fichier GPX » (step 1).
  Future<void> pickGpx() async {
    await $(keys.routeEditor.pickButton).tap();
  }

  /// « Choisir un autre fichier » on the « Fichier refusé » banner.
  Future<void> pickAnother() async {
    await $(keys.routeEditor.pickAnotherButton).tap();
  }

  /// Waits for the « Fichier refusé » banner.
  Future<bool> showsRefused() async {
    await $(keys.routeEditor.refusedBanner).waitUntilExists();
    return isShown(keys.routeEditor.pickAnotherButton);
  }

  /// The refusal a plain member reads instead of the form.
  Future<bool> showsForbidden() async {
    await $(keys.routeEditor.forbidden).waitUntilExists();
    return !isShown(keys.routeEditor.saveButton) &&
        !isShown(keys.routeEditor.pickButton);
  }

  // ── The form ───────────────────────────────────────────────────────────

  Future<void> waitUntilFormShown() async {
    await $(keys.routeEditor.nameField).waitUntilVisible();
  }

  /// Waits until the name field reads [name] — the one the GPX gave, or the one typed.
  Future<void> nameReads(String name) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!shows(keys.routeEditor.nameField, name)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('the name field never read « $name »');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> enterName(String name) async {
    await $(keys.routeEditor.nameField).enterText(name);
  }

  Future<void> chooseSurface(SurfaceType surface) async {
    await (await scrolledTo(keys.routeEditor.surfaceOption(surface))).tap();
  }

  /// « Créer le parcours » or « Enregistrer », then waits for the editor to leave.
  Future<void> save() async {
    await $(keys.routeEditor.saveButton).tap();
    await waitUntilGone(
      keys.routeEditor.saveButton,
      timeout: const Duration(seconds: 30),
    );
  }

  // ── On the route page ──────────────────────────────────────────────────

  /// Waits until the route page's title reads [name] — after a save, the page reloads.
  Future<void> waitUntilRouteTitleIs(String name) async {
    await $(keys.routeDetail.title).waitUntilVisible();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!shows(keys.routeDetail.title, name)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('route title never read « $name »');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  bool get offersEdit => isShown(keys.routeManage.editButton);

  /// The pencil of the route page → the editor, in edit mode.
  Future<void> editFromPencil() async {
    await $(keys.routeManage.editButton).tap();
    await waitUntilFormShown();
  }

  Future<void> openManageMenu() async {
    await $(keys.routeDetail.moreButton).tap();
    await $(keys.routeManage.edit).waitUntilExists();
  }

  /// « Remplacer le fichier GPX »: the editor opens on the picker, which answers with the file
  /// [provideGpx] made ready. Nothing is sent until « Enregistrer ».
  Future<void> replaceGpxFromMenu() async {
    await openManageMenu();
    await $(keys.routeManage.replaceGpx).tap();
    await $(keys.routeEditor.trackReplaceCancel).waitUntilExists();
  }

  /// « Supprimer le parcours », through its confirmation: the page closes.
  Future<void> deleteFromMenu() async {
    await openManageMenu();
    await $(keys.routeManage.delete).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilGone(
      keys.routeDetail.title,
      timeout: const Duration(seconds: 20),
    );
  }

  /// « Restaurer le parcours », on the page of a deleted route.
  Future<void> restoreFromMenu() async {
    await $(keys.routeDetail.moreButton).tap();
    await $(keys.routeManage.restore).waitUntilExists();
    await $(keys.routeManage.restore).tap();
    await waitUntilGone(keys.routeManage.restore);
  }
}

/// A picker that always answers with one file.
final class _FixedPicker implements GpxFilePicker {
  const _FixedPicker(this._file);

  final GpxFile _file;

  @override
  Future<GpxFile?> pick() async => _file;
}
