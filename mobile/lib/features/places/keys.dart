import 'package:flutter/widgets.dart';

class _TeamPlacesKey extends ValueKey<String> {
  const _TeamPlacesKey(String value) : super('teamPlaces_$value');
}

/// « Lieux » : la liste des lieux d'une équipe et la feuille de son
/// formulaire (ledger `MOB-168`).
class TeamPlacesKeys {
  final loadError = const _TeamPlacesKey('loadError');

  /// Le refus rendu à qui n'organise pas l'équipe, et son « Retour ».
  final forbidden = const _TeamPlacesKey('forbidden');
  final forbiddenBack = const _TeamPlacesKey('forbiddenBack');

  /// « Créer un lieu », dans la barre épinglée.
  final addButton = const _TeamPlacesKey('addButton');

  /// Ce que le serveur a refusé à une suppression.
  final errorBanner = const _TeamPlacesKey('errorBanner');

  final searchField = const _TeamPlacesKey('searchField');
  final resultCount = const _TeamPlacesKey('resultCount');
  final empty = const _TeamPlacesKey('empty');
  final searchEmpty = const _TeamPlacesKey('searchEmpty');

  /// La ligne d'un lieu, ses badges d'usage, son lien et ses deux gestes.
  ValueKey<String> row(String placeId) => _TeamPlacesKey('row_$placeId');
  ValueKey<String> rowStart(String placeId) =>
      _TeamPlacesKey('rowStart_$placeId');
  ValueKey<String> rowEnd(String placeId) => _TeamPlacesKey('rowEnd_$placeId');
  ValueKey<String> rowLink(String placeId) =>
      _TeamPlacesKey('rowLink_$placeId');
  ValueKey<String> rowEdit(String placeId) =>
      _TeamPlacesKey('rowEdit_$placeId');
  ValueKey<String> rowDelete(String placeId) =>
      _TeamPlacesKey('rowDelete_$placeId');

  // ── Feuille du formulaire ──
  final formSheet = const _TeamPlacesKey('formSheet');
  final formClose = const _TeamPlacesKey('formClose');
  final formErrorBanner = const _TeamPlacesKey('formErrorBanner');
  final formName = const _TeamPlacesKey('formName');
  final formAddress = const _TeamPlacesKey('formAddress');
  final formLink = const _TeamPlacesKey('formLink');

  /// La ligne « Localisation », et la croix qui efface la position.
  final formLocation = const _TeamPlacesKey('formLocation');
  final formLocationClear = const _TeamPlacesKey('formLocationClear');
  final formStartSwitch = const _TeamPlacesKey('formStartSwitch');
  final formEndSwitch = const _TeamPlacesKey('formEndSwitch');
  final formSubmit = const _TeamPlacesKey('formSubmit');
}
