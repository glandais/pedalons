import 'package:flutter/widgets.dart';

class _TripKey extends ValueKey<String> {
  const _TripKey(String value) : super('trip_$value');
}

class TripDetailKeys {
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

  /// Le bloc de départ du détail d'un voyage, sous le titre (BRANDING §7.8,
  /// ledger `BRAND-8`).
  final departureBlock = const _TripKey('departureBlock');

  /// Le bloc de départ du détail d'une étape (ledger `MOB-114`).
  final stageDepartureBlock = const _TripKey('stageDepartureBlock');

  /// Le nom de l'étape, en tête de l'écran 25.
  final stageTitle = const _TripKey('stageTitle');

  /// Le badge « Étape n sur N » de l'écran 25.
  final stagePosition = const _TripKey('stagePosition');

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
