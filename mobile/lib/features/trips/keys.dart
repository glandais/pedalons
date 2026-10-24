import 'package:flutter/widgets.dart';

class _TripKey extends ValueKey<String> {
  const _TripKey(String value) : super('trip_$value');
}

class TripDetailKeys {
  /// Le nom du voyage, en tête de l'écran 24.
  final title = const _TripKey('title');

  /// Le badge « Terminé » d'un voyage passé.
  final finishedBadge = const _TripKey('finishedBadge');

  /// Le bandeau « Voyage annulé ».
  final cancelledBanner = const _TripKey('cancelledBanner');

  /// « Rejoindre » dans la barre d'action.
  final joinButton = const _TripKey('join');

  /// « Se désinscrire » dans la barre d'action.
  final leaveButton = const _TripKey('leave');

  /// Le `⋯` de l'app bar : signaler le voyage.
  final moreButton = const _TripKey('moreButton');

  /// La section des participants, nommés en pastilles.
  final participants = const _TripKey('participants');

  /// La carte d'une étape dans la liste du voyage.
  ValueKey<String> stageCard(String stageSlug) =>
      _TripKey('stageCard_$stageSlug');

  /// Le nom de l'étape, en tête de l'écran 25.
  final stageTitle = const _TripKey('stageTitle');

  /// Le badge « Étape n sur N » de l'écran 25.
  final stagePosition = const _TripKey('stagePosition');

  /// Le rail d'étapes épinglé de l'écran 25. Ses pastilles portent leur rang
  /// (`ValueKey<int>`, 0 pour « Aperçu ») : c'est `PdlStageRail` qui les pose.
  final stageRail = const _TripKey('stageRail');

  /// La puce « Météo » sous la carte d'ensemble du voyage : chaque étape
  /// colorée par son vent (ledger `MOB-94`).
  final windMapChip = const _TripKey('windMapChip');

  /// La légende du vent de la carte d'ensemble, parts des étapes additionnées.
  final windMapLegend = const _TripKey('windMapLegend');

  /// La puce « Météo » sous la carte du détail d'une étape.
  final stageWindMapChip = const _TripKey('stageWindMapChip');
}
