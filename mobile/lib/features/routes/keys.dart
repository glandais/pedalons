import 'package:flutter/widgets.dart';

import '../../api/generated/export.dart' show SurfaceType;

class _RoutesKey extends ValueKey<String> {
  const _RoutesKey(String value) : super('routes_$value');
}

/// La parcothèque : l'onglet Parcours et la section Parcours d'une équipe.
class RoutesKeys {
  /// La carte (ou la ligne compacte) d'un parcours de la liste.
  ValueKey<String> card(String routeSlug) => _RoutesKey('card_$routeSlug');

  /// Les tags d'une carte (ou d'une ligne compacte) de la liste.
  ValueKey<String> cardTags(String routeSlug) =>
      _RoutesKey('cardTags_$routeSlug');

  /// L'état vide filtré, « cul-de-sac ».
  final emptyState = const _RoutesKey('emptyState');

  final filterApplyButton = const _RoutesKey('filterApplyButton');
  final filterButton = const _RoutesKey('filterButton');

  /// Une valeur d'un choix de la feuille de filtres (revêtement, relief…).
  ValueKey<String> filterChoice(Object value) =>
      _RoutesKey('filterChoice_$value');

  final listViewSegment = const _RoutesKey('listViewSegment');
  final mapView = const _RoutesKey('mapView');
  final mapViewSegment = const _RoutesKey('mapViewSegment');
  final searchField = const _RoutesKey('searchField');

  /// « Ajouter » : créer un parcours, à droite de la recherche de l'équipe
  /// (ledger `MOB-79`).
  final addButton = const _RoutesKey('addButton');
}

class _RouteDetailKey extends ValueKey<String> {
  const _RouteDetailKey(String value) : super('routeDetail_$value');
}

class RouteDetailKeys {
  /// « Profil d'altitude provisoire » au-dessus du profil (ledger `MOB-76`).
  final elevationRefining = const _RouteDetailKey('elevationRefining');

  /// Le profil altimétrique, tiré du tracé.
  final elevationProfile = const _RouteDetailKey('elevationProfile');

  /// Le `⋯` de l'overlay : signaler le parcours.
  final moreButton = const _RouteDetailKey('moreButton');

  /// Le partage de l'overlay (organisateur : la maquette l'y place).
  final shareButton = const _RouteDetailKey('shareButton');

  final title = const _RouteDetailKey('title');

  /// Le revêtement le long du parcours (ledger `MOB-81`) : la section, la
  /// bascule Pente / Revêtement, la ligne « en cours », la barre de répartition
  /// et l'attribution OpenStreetMap.
  final surfaceSection = const _RouteDetailKey('surfaceSection');
  final surfaceColorBy = const _RouteDetailKey('surfaceColorBy');
  final surfacePending = const _RouteDetailKey('surfacePending');
  final surfaceBar = const _RouteDetailKey('surfaceBar');
  final surfaceAttribution = const _RouteDetailKey('surfaceAttribution');

  /// Une carte de « Utilisée dans », par le slug de la sortie ou du voyage.
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
