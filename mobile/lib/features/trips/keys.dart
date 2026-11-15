import 'package:flutter/widgets.dart';

class _TripKey extends ValueKey<String> {
  const _TripKey(String value) : super('trip_$value');
}

class TripDetailKeys {
  /// Le bandeau du non-membre (« Rejoignez cette équipe… », ou l'équipe
  /// privée d'un voyage lu par lien, docs/LEDGER_*.md MOB-137).
  final notMemberBanner = const _TripKey('notMemberBanner');

  /// Le nom du voyage, en tête de l'écran 24.
  final title = const _TripKey('title');

  /// Le badge « Terminé » d'un voyage passé.
  final finishedBadge = const _TripKey('finishedBadge');

  /// Le badge « En cours », entre le premier départ et la dernière arrivée.
  final underWayBadge = const _TripKey('underWayBadge');

  /// Le bandeau « Voyage annulé ».
  final cancelledBanner = const _TripKey('cancelledBanner');

  /// « Rejoindre », à droite de l'heure du bloc de départ.
  final joinButton = const _TripKey('join');

  /// Le badge « J'y vais », à droite de l'heure du bloc de départ.
  final goingBadge = const _TripKey('goingBadge');

  /// Le lien « Se désinscrire », au pied de « Personnes inscrites ».
  final leaveButton = const _TripKey('leave');

  /// Le `⋯` de l'app bar : signaler le voyage.
  final moreButton = const _TripKey('moreButton');

  /// La section « Personnes inscrites ».
  final participants = const _TripKey('participants');

  /// La grappe d'avatars de « Personnes inscrites ».
  final participantsAvatars = const _TripKey('participantsAvatars');

  /// « Voir toutes les personnes inscrites » : la feuille des inscriptions.
  final viewAllParticipants = const _TripKey('viewAllParticipants');

  /// Les tuiles de chiffres, sous le bloc de départ.
  final statTiles = const _TripKey('statTiles');

  /// La section « Parcours » : carte, interrupteur, profil.
  final routeSection = const _TripKey('routeSection');

  /// L'ⓘ du profil : la source des altitudes.
  final profileSource = const _TripKey('profileSource');

  /// La section « Description ».
  final descriptionSection = const _TripKey('descriptionSection');

  /// La section « Étapes ».
  final stagesSection = const _TripKey('stagesSection');

  /// Le fil de commentaires du voyage.
  final commentsSection = const _TripKey('commentsSection');

  /// Le lieu de départ de la première étape, dans le bloc de départ : un lien
  /// d'itinéraire.
  final startPlaceLink = const _TripKey('startPlaceLink');

  /// La carte d'une étape dans la liste du voyage.
  ValueKey<String> stageCard(String stageSlug) =>
      _TripKey('stageCard_$stageSlug');

  /// La ligne de départ d'une carte d'étape : « sam. 12 avr. · 09:00 »
  /// (ledger `MOB-134`).
  ValueKey<String> stageDeparture(String stageSlug) =>
      _TripKey('stageDeparture_$stageSlug');

  /// « Départ → Arrivée » sur la carte d'une étape (règle R11).
  ValueKey<String> stagePlaces(String stageSlug) =>
      _TripKey('stagePlaces_$stageSlug');

  /// « GPS » sur la carte d'une étape d'un voyage où l'on est inscrit.
  ValueKey<String> stageGps(String stageSlug) =>
      _TripKey('stageGps_$stageSlug');

  /// Le bloc de départ du détail d'un voyage, sous le titre (BRANDING §7.8,
  /// ledger `BRAND-8`).
  final departureBlock = const _TripKey('departureBlock');

  /// Le bloc de départ du détail d'une étape (ledger `MOB-114`).
  final stageDepartureBlock = const _TripKey('stageDepartureBlock');

  /// Le nom de l'étape, en tête de l'écran 25.
  final stageTitle = const _TripKey('stageTitle');

  /// « Étape n sur N », le titre de la barre du haut de l'écran 25 (ledger
  /// `MOB-134`, lot 11).
  final stagePosition = const _TripKey('stagePosition');

  /// Les sections du détail d'une étape, dans l'ordre de la maquette
  /// `etape-mobile-cible` (ledger `MOB-134`, lot 11) : titre ([stageTitle]),
  /// bloc de départ ([stageDepartureBlock]), tuiles, « Parcours »,
  /// « Description », « Météo », « Commentaires ».
  final stageStatTiles = const _TripKey('stageStatTiles');
  final stageRouteSection = const _TripKey('stageRouteSection');
  final stageDescriptionSection = const _TripKey('stageDescriptionSection');
  final stageWeatherSection = const _TripKey('stageWeatherSection');
  final stageCommentsSection = const _TripKey('stageCommentsSection');

  /// « Points du parcours » et « Cols et montées », repliés sous la carte de
  /// l'étape.
  final stageWaypoints = const _TripKey('stageWaypoints');
  final stageClimbs = const _TripKey('stageClimbs');

  /// Les lieux de départ et d'arrivée du bloc de départ d'une étape, en liens
  /// d'itinéraire.
  final stageStartPlaceLink = const _TripKey('stageStartPlaceLink');
  final stageEndPlaceLink = const _TripKey('stageEndPlaceLink');

  /// Le rail d'étapes épinglé de l'écran 25. Ses pastilles portent leur rang
  /// (`ValueKey<int>`, 0 pour « Aperçu ») : c'est `PdlStageRail` qui les pose.
  final stageRail = const _TripKey('stageRail');

  /// L'interrupteur Étapes | Météo sous la carte d'ensemble du voyage : chaque
  /// étape à sa couleur, ou colorée par son vent (ledgers `MOB-94`, `MOB-105`).
  final mapColorBy = const _TripKey('mapColorBy');

  /// Le même interrupteur, posé en bas du plein écran de la carte d'ensemble.
  final fullscreenMapColorBy = const _TripKey('fullscreenMapColorBy');

  /// Un segment de l'interrupteur de la carte d'ensemble, par
  /// `TripMapColorBy.name` (`stages`, `wind`).
  ValueKey<String> mapColorByMode(String mode) => _TripKey('mapColorBy_$mode');

  /// La légende du vent de la carte d'ensemble, parts des étapes additionnées.
  final windMapLegend = const _TripKey('windMapLegend');

  /// L'interrupteur Pente | Revêtement | Météo sous la carte du détail d'une
  /// étape (ledger `MOB-105`).
  final stageMapColorBy = const _TripKey('stageMapColorBy');
}

class _TripEditorKey extends ValueKey<String> {
  const _TripEditorKey(String value) : super('tripEditor_$value');
}

/// L'éditeur de voyage, création et modification (ledger `MOB-162`).
class TripEditorKeys {
  final forbidden = const _TripEditorKey('forbidden');
  final loadError = const _TripEditorKey('loadError');
  final saveButton = const _TripEditorKey('saveButton');
  final errorBanner = const _TripEditorKey('errorBanner');
  final nameField = const _TripEditorKey('nameField');
  final slugRow = const _TripEditorKey('slugRow');
  final markdownField = const _TripEditorKey('markdownField');
  final dateRow = const _TripEditorKey('dateRow');
  final timeRow = const _TripEditorKey('timeRow');
  final tagsRow = const _TripEditorKey('tagsRow');
  final visibility = const _TripEditorKey('visibility');
  final status = const _TripEditorKey('status');
  final publishAtRow = const _TripEditorKey('publishAtRow');
  final routeRow = const _TripEditorKey('routeRow');
  final addStageButton = const _TripEditorKey('addStageButton');

  /// La carte de l'étape de rang [index] (à partir de zéro), et ses champs.
  ValueKey<String> stage(int index) => _TripEditorKey('stage_$index');
  ValueKey<String> stageName(int index) => _TripEditorKey('stageName_$index');
  ValueKey<String> stageDate(int index) => _TripEditorKey('stageDate_$index');
  ValueKey<String> stageTime(int index) => _TripEditorKey('stageTime_$index');
  ValueKey<String> stageSpeed(int index) => _TripEditorKey('stageSpeed_$index');
  ValueKey<String> stageStartPlace(int index) =>
      _TripEditorKey('stageStartPlace_$index');
  ValueKey<String> stageEndPlace(int index) =>
      _TripEditorKey('stageEndPlace_$index');
  ValueKey<String> stageRoute(int index) => _TripEditorKey('stageRoute_$index');
  ValueKey<String> stageMarkdown(int index) =>
      _TripEditorKey('stageMarkdown_$index');
  ValueKey<String> stageUp(int index) => _TripEditorKey('stageUp_$index');
  ValueKey<String> stageDown(int index) => _TripEditorKey('stageDown_$index');
  ValueKey<String> stageRemove(int index) =>
      _TripEditorKey('stageRemove_$index');
}

class _TripManageKey extends ValueKey<String> {
  const _TripManageKey(String value) : super('tripManage_$value');
}

/// Les gestes d'organisateur du détail d'un voyage (ledger `MOB-162`).
class TripManageKeys {
  final editButton = const _TripManageKey('editButton');
  final publish = const _TripManageKey('publish');
  final unpublish = const _TripManageKey('unpublish');
  final cancel = const _TripManageKey('cancel');
  final reinstate = const _TripManageKey('reinstate');
  final delete = const _TripManageKey('delete');
  final restore = const _TripManageKey('restore');
  final report = const _TripManageKey('report');
  final deletedBanner = const _TripManageKey('deletedBanner');
}
