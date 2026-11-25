import 'package:flutter/widgets.dart';

class _GpxToolsKey extends ValueKey<String> {
  const _GpxToolsKey(String value) : super('gpxTools_$value');
}

/// Les outils GPX (docs/LEDGER_*.md MOB-178) : l'accueil, « Mes fichiers »,
/// la fiche d'un aperçu, son éditeur et la carte sans tracé.
class GpxToolsKeys {
  /// Le segment « Outils GPX » du sélecteur d'Explorer (MOB-192).
  final entryButton = const _GpxToolsKey('entryButton');

  /// Le segment « Parcours » du même sélecteur.
  final routesTab = const _GpxToolsKey('routesTab');

  // ── Accueil ──────────────────────────────────────────────────────────
  final hub = const _GpxToolsKey('hub');
  final viewFileButton = const _GpxToolsKey('viewFileButton');
  final mergeButton = const _GpxToolsKey('mergeButton');
  final drawButton = const _GpxToolsKey('drawButton');
  final blankMapButton = const _GpxToolsKey('blankMapButton');
  final listButton = const _GpxToolsKey('listButton');
  final hubError = const _GpxToolsKey('hubError');

  /// Un des derniers fichiers que l'accueil liste avant « Tout voir ».
  ValueKey<String> recent(String previewId) =>
      _GpxToolsKey('recent_$previewId');

  /// Le mot du quota personnel épuisé, sous « Tracer un fichier GPX ».
  final quotaMessage = const _GpxToolsKey('quotaMessage');

  // ── Fichier reçu d'une autre app (MOB-191) ───────────────────────────
  final received = const _GpxToolsKey('received');
  final receivedClose = const _GpxToolsKey('receivedClose');
  final receivedName = const _GpxToolsKey('receivedName');
  final receivedRefused = const _GpxToolsKey('receivedRefused');
  final receivedError = const _GpxToolsKey('receivedError');
  final receivedView = const _GpxToolsKey('receivedView');
  final receivedSaveToTeam = const _GpxToolsKey('receivedSaveToTeam');

  // ── Mes fichiers ─────────────────────────────────────────────────────
  final list = const _GpxToolsKey('list');
  final listEmpty = const _GpxToolsKey('listEmpty');
  ValueKey<String> row(String previewId) => _GpxToolsKey('row_$previewId');
  ValueKey<String> rowDelete(String previewId) =>
      _GpxToolsKey('rowDelete_$previewId');

  // ── Fiche d'un aperçu ────────────────────────────────────────────────
  final preview = const _GpxToolsKey('preview');
  final previewTitle = const _GpxToolsKey('previewTitle');
  final previewStats = const _GpxToolsKey('previewStats');
  final previewRouteSection = const _GpxToolsKey('previewRouteSection');
  final previewDeparture = const _GpxToolsKey('previewDeparture');
  final previewAddDeparture = const _GpxToolsKey('previewAddDeparture');
  final previewWeather = const _GpxToolsKey('previewWeather');
  final previewWeatherPending = const _GpxToolsKey('previewWeatherPending');
  final previewWaypoints = const _GpxToolsKey('previewWaypoints');
  final previewColorBy = const _GpxToolsKey('previewColorBy');
  final previewRetention = const _GpxToolsKey('previewRetention');
  final shareButton = const _GpxToolsKey('shareButton');
  final editButton = const _GpxToolsKey('editButton');
  final moreButton = const _GpxToolsKey('moreButton');
  final deleteAction = const _GpxToolsKey('deleteAction');
  final duplicateAction = const _GpxToolsKey('duplicateAction');
  final saveAsRouteAction = const _GpxToolsKey('saveAsRouteAction');
  final actionError = const _GpxToolsKey('actionError');

  /// La feuille « Dupliquer le fichier ».
  final duplicateSheet = const _GpxToolsKey('duplicateSheet');
  final duplicateName = const _GpxToolsKey('duplicateName');
  final duplicateSubmit = const _GpxToolsKey('duplicateSubmit');

  /// La feuille « Enregistrer comme parcours ».
  final saveAsRouteSheet = const _GpxToolsKey('saveAsRouteSheet');
  ValueKey<String> saveAsRouteTeam(String teamSlug) =>
      _GpxToolsKey('saveAsRouteTeam_$teamSlug');
  final saveAsRouteSubmit = const _GpxToolsKey('saveAsRouteSubmit');

  /// La carte plein écran d'un aperçu (`gpxToolsMap`).
  final previewMap = const _GpxToolsKey('previewMap');

  // ── Éditeur ──────────────────────────────────────────────────────────
  final editor = const _GpxToolsKey('editor');
  final editorName = const _GpxToolsKey('editorName');
  final editorDraw = const _GpxToolsKey('editorDraw');
  final editorPickFile = const _GpxToolsKey('editorPickFile');
  final editorDeparture = const _GpxToolsKey('editorDeparture');
  final editorClearDeparture = const _GpxToolsKey('editorClearDeparture');
  final editorSpeed = const _GpxToolsKey('editorSpeed');
  final editorSave = const _GpxToolsKey('editorSave');
  final editorError = const _GpxToolsKey('editorError');

  // ── Carte sans tracé ─────────────────────────────────────────────────
  final blankMap = const _GpxToolsKey('blankMap');
}
