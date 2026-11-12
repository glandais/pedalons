import 'package:flutter/widgets.dart';

import '../../api/generated/export.dart' show SurfaceType;

class _RoutesKey extends ValueKey<String> {
  const _RoutesKey(String value) : super('routes_$value');
}

/// La parcothèque : l'onglet Explorer et la section Parcours d'une équipe.
class RoutesKeys {
  /// La carte (ou la ligne compacte) d'un parcours de la liste.
  ValueKey<String> card(String routeSlug) => _RoutesKey('card_$routeSlug');

  /// Les tags d'une carte (ou d'une ligne compacte) de la liste.
  ValueKey<String> cardTags(String routeSlug) =>
      _RoutesKey('cardTags_$routeSlug');

  /// Le badge de visibilité d'une carte de parcours — posé seulement quand
  /// elle diffère de celle de l'équipe (règle R1).
  ValueKey<String> cardVisibility(String routeSlug) =>
      _RoutesKey('cardVisibility_$routeSlug');

  /// L'extrait d'une carte de parcours en densité « vignettes » (règle R12).
  ValueKey<String> cardExcerpt(String routeSlug) =>
      _RoutesKey('cardExcerpt_$routeSlug');

  /// L'état vide filtré, « cul-de-sac ».
  final emptyState = const _RoutesKey('emptyState');

  /// L'état vide sans filtre : « Aucun parcours ».
  final noneState = const _RoutesKey('noneState');

  /// Le compteur sous la barre (« 47 parcours », règle RL8).
  final resultCount = const _RoutesKey('resultCount');

  /// « Créer un parcours » de cet état vide, pour qui gère les parcours.
  final emptyAddButton = const _RoutesKey('emptyAddButton');

  final filterApplyButton = const _RoutesKey('filterApplyButton');
  final filterButton = const _RoutesKey('filterButton');

  /// « Effacer les filtres » dans la feuille de filtres (règle RL4).
  final filterClearButton = const _RoutesKey('filterClearButton');

  /// Une valeur d'un choix de la feuille de filtres (revêtement, relief…).
  ValueKey<String> filterChoice(Object value) =>
      _RoutesKey('filterChoice_$value');

  /// Les trois segments du contrôle de vue (règle RL9) : « Vignettes »,
  /// « Lignes », « Carte ».
  final listViewSegment = const _RoutesKey('listViewSegment');
  final rowsViewSegment = const _RoutesKey('rowsViewSegment');
  final mapViewSegment = const _RoutesKey('mapViewSegment');
  final mapView = const _RoutesKey('mapView');
  final searchField = const _RoutesKey('searchField');

  /// La puce « Portée » d'Explorer (règle RL2).
  final scopeChip = const _RoutesKey('scopeChip');

  /// La puce de tri, en tête des critères.
  final sortChip = const _RoutesKey('sortChip');

  /// « Créer » : créer un parcours, à droite de la recherche de l'équipe
  /// (ledger `MOB-79`, règle RL13).
  final createButton = const _RoutesKey('createButton');
}

class _RouteDetailKey extends ValueKey<String> {
  const _RouteDetailKey(String value) : super('routeDetail_$value');
}

class RouteDetailKeys {
  /// « Profil d'altitude provisoire » au-dessus du profil (ledger `MOB-76`).
  final elevationRefining = const _RouteDetailKey('elevationRefining');

  /// Le profil altimétrique, tiré du tracé.
  final elevationProfile = const _RouteDetailKey('elevationProfile');

  /// Le `⋯` de la barre du haut : le menu d'organisateur, ou signaler le
  /// parcours.
  final moreButton = const _RouteDetailKey('moreButton');

  /// Le partage de la barre du haut.
  final shareButton = const _RouteDetailKey('shareButton');

  /// Le titre du parcours, dans l'identité en tête de la fiche.
  final title = const _RouteDetailKey('title');

  // Les sections de la fiche, dans l'ordre de la maquette
  // `parcours-mobile-cible` (ledger `MOB-134`, lot 10).
  final statTiles = const _RouteDetailKey('statTiles');

  /// La section « Parcours » (`RouteSection`) : carte, interrupteur, profil,
  /// revêtement, « GPS ».
  final routeSection = const _RouteDetailKey('routeSection');
  final descriptionSection = const _RouteDetailKey('descriptionSection');
  final waypointsSection = const _RouteDetailKey('waypointsSection');
  final climbsSection = const _RouteDetailKey('climbsSection');
  final usagesSection = const _RouteDetailKey('usagesSection');
  final informationSection = const _RouteDetailKey('informationSection');
  final commentsSection = const _RouteDetailKey('commentsSection');

  /// La carte de `RouteSection`.
  final map = const _RouteDetailKey('map');

  /// Le bouton ⓘ de « Profil » et sa feuille (la source des altitudes).
  final profileSource = const _RouteDetailKey('profileSource');
  final profileSourceSheet = const _RouteDetailKey('profileSourceSheet');

  /// Le bouton ⓘ de la légende du revêtement (OpenStreetMap).
  final surfaceSource = const _RouteDetailKey('surfaceSource');

  /// « Détails » de `RouteSection`, qui pousse la fiche du parcours (une
  /// étape, lot 11).
  final details = const _RouteDetailKey('details');

  /// Le revêtement le long du parcours (ledger `MOB-81`) : la section, la
  /// bascule Pente / Revêtement de la fiche, la ligne « en cours », la barre de répartition
  /// et l'attribution OpenStreetMap.
  final surfaceSection = const _RouteDetailKey('surfaceSection');
  final surfaceColorBy = const _RouteDetailKey('surfaceColorBy');

  /// Un segment de l'interrupteur Pente | Revêtement | Météo d'une carte de
  /// parcours (ledger `MOB-105`), par le nom du mode : `grade`, `surface`,
  /// `wind`.
  ValueKey<String> colorByMode(String mode) => _RouteDetailKey('colorBy_$mode');

  /// Le même interrupteur, posé sur la carte d'un groupe, d'une sortie solo
  /// ou d'une étape **en plein écran** (ledger `MOB-105`) : il partage l'état
  /// de celui de la carte encastrée.
  final fullscreenColorBy = const _RouteDetailKey('fullscreenColorBy');
  final surfacePending = const _RouteDetailKey('surfacePending');
  final surfaceBar = const _RouteDetailKey('surfaceBar');
  final surfaceAttribution = const _RouteDetailKey('surfaceAttribution');

  /// Le bouton « GPS » de `RouteSection` (et de la feuille de parcours d'une
  /// étape).
  final gps = const _RouteDetailKey('gps');

  /// Une carte de « Utilisé dans », par le slug de la sortie ou du voyage.
  ValueKey<String> usage(String slug) => _RouteDetailKey('usage_$slug');
}

class _RouteEditorKey extends ValueKey<String> {
  const _RouteEditorKey(String value) : super('routeEditor_$value');
}

/// L'éditeur de parcours, création et modification (ledger `MOB-79`). Les
/// boutons de médias (logo, images, pièces jointes) gardent les clés de
/// `keys.rideEditor` : c'est le même widget.
class RouteEditorKeys {
  final forbidden = const _RouteEditorKey('forbidden');
  final loadError = const _RouteEditorKey('loadError');

  /// L'étape 1 de la création : la zone « Envoyer un fichier GPX ».
  final pickStep = const _RouteEditorKey('pickStep');
  final pickButton = const _RouteEditorKey('pickButton');

  /// Le bandeau « Fichier refusé », à l'étape 1 comme dans la section Tracé.
  final refusedBanner = const _RouteEditorKey('refusedBanner');
  final pickAnotherButton = const _RouteEditorKey('pickAnotherButton');

  final trackSection = const _RouteEditorKey('trackSection');
  final trackChangeButton = const _RouteEditorKey('trackChangeButton');
  final trackReplaceButton = const _RouteEditorKey('trackReplaceButton');
  final trackReplaceCancel = const _RouteEditorKey('trackReplaceCancel');
  final trackWarning = const _RouteEditorKey('trackWarning');

  final nameField = const _RouteEditorKey('nameField');

  /// L'aide « Repris du fichier GPX » sous le nom.
  final nameFromGpxHint = const _RouteEditorKey('nameFromGpxHint');
  final slugRow = const _RouteEditorKey('slugRow');
  final slugField = const _RouteEditorKey('slugField');
  final slugSave = const _RouteEditorKey('slugSave');
  final markdownField = const _RouteEditorKey('markdownField');
  final surface = const _RouteEditorKey('surface');

  /// Un segment du choix de surface.
  ValueKey<String> surfaceOption(SurfaceType surface) =>
      _RouteEditorKey('surface_${surface.json}');
  final visibility = const _RouteEditorKey('visibility');
  final tagsRow = const _RouteEditorKey('tagsRow');
  final saveButton = const _RouteEditorKey('saveButton');
  final errorBanner = const _RouteEditorKey('errorBanner');
}

class _RouteManageKey extends ValueKey<String> {
  const _RouteManageKey(String value) : super('routeManage_$value');
}

/// Les gestes d'organisateur de la fiche d'un parcours (ledger `MOB-79`).
class RouteManageKeys {
  /// Le crayon de l'overlay : modifier le parcours.
  final editButton = const _RouteManageKey('editButton');

  // Les lignes du menu « Gérer le parcours ».
  final edit = const _RouteManageKey('edit');
  final replaceGpx = const _RouteManageKey('replaceGpx');
  final delete = const _RouteManageKey('delete');
  final restore = const _RouteManageKey('restore');
  final report = const _RouteManageKey('report');

  /// Le bandeau d'une fiche supprimée.
  final deletedBanner = const _RouteManageKey('deletedBanner');
}

class _RouteWaypointsKey extends ValueKey<String> {
  const _RouteWaypointsKey(String value) : super('routeWaypoints_$value');
}

/// Les points de parcours d'une fiche (ledger `MOB-84`).
class RouteWaypointsKeys {
  /// La section « Points du parcours ».
  final section = const _RouteWaypointsKey('section');

  /// La feuille d'un point.
  final sheet = const _RouteWaypointsKey('sheet');

  /// Une ligne de la liste, par la clé du point.
  ValueKey<String> row(String key) => _RouteWaypointsKey('row_$key');
}

class _GpsSheetKey extends ValueKey<String> {
  const _GpsSheetKey(String value) : super('gpsSheet_$value');
}

/// La feuille « GPS » (`showGpsSheet`), le seul chemin par lequel un parcours
/// sort de l'app, et les bandeaux de son issue (`GpsExportRunner`). Les
/// boutons « GPS » qui l'ouvrent portent la clé de leur écran
/// (`keys.ride.groupGps`, `keys.rideGroup.gps`, `keys.routeDetail.gps`…).
class GpsSheetKeys {
  final sheet = const _GpsSheetKey('sheet');

  /// Ce qui part : « Groupe B · 78,0 km », le nom du parcours.
  final subtitle = const _GpsSheetKey('subtitle');

  /// Le libellé de la section « Vers un appareil » — absente sans service.
  final toDevice = const _GpsSheetKey('toDevice');

  /// La ligne d'un service connecté, par son `serviceType` (`GARMIN`…).
  ValueKey<String> service(String serviceType) =>
      _GpsSheetKey('service_$serviceType');

  /// « Enregistrer sur le téléphone » du GPX (Android seulement).
  final gpxSave = const _GpsSheetKey('gpxSave');

  /// « Envoyer vers une autre app » du GPX sur Android, « Partager » sur iOS.
  final gpxShare = const _GpsSheetKey('gpxShare');

  final fitSave = const _GpsSheetKey('fitSave');
  final fitShare = const _GpsSheetKey('fitShare');

  /// « Connecter un compteur », quand aucun service n'est connecté.
  final connectDevice = const _GpsSheetKey('connectDevice');

  /// Les bandeaux de l'issue de l'export, sur l'écran appelant.
  final successBanner = const _GpsSheetKey('successBanner');
  final errorBanner = const _GpsSheetKey('errorBanner');
}
