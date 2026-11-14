import 'package:flutter/widgets.dart';

class _AdDetailKey extends ValueKey<String> {
  const _AdDetailKey(String value) : super('adDetail_$value');
}

class AdDetailKeys {
  final title = const _AdDetailKey('title');
  final contactButton = const _AdDetailKey('contactButton');
  final moreButton = const _AdDetailKey('moreButton');
  final contactOptedOut = const _AdDetailKey('contactOptedOut');
  final contactSent = const _AdDetailKey('contactSent');
  final location = const _AdDetailKey('location');
  final locationCaption = const _AdDetailKey('locationCaption');
  final locationDescription = const _AdDetailKey('locationDescription');
  final locationMap = const _AdDetailKey('locationMap');
  final locationSector = const _AdDetailKey('locationSector');
  final seller = const _AdDetailKey('seller');
}

class _AdEditorKey extends ValueKey<String> {
  const _AdEditorKey(String value) : super('adEditor_$value');
}

/// L'éditeur d'annonce, création et modification (ledger `MOB-158`). Les
/// boutons de médias gardent les clés de `keys.rideEditor`, et la recherche
/// d'adresse celles de son sélecteur (`pickerSearch`, `pickerOption`) : ce
/// sont les mêmes widgets.
class AdEditorKeys {
  final forbidden = const _AdEditorKey('forbidden');
  final loadError = const _AdEditorKey('loadError');
  final errorBanner = const _AdEditorKey('errorBanner');
  final nameField = const _AdEditorKey('nameField');
  final slugRow = const _AdEditorKey('slugRow');
  final slugField = const _AdEditorKey('slugField');
  final slugSave = const _AdEditorKey('slugSave');
  final adType = const _AdEditorKey('adType');

  /// Un segment du type d'annonce (`AdType.json`).
  ValueKey<String> adTypeOption(String adType) =>
      _AdEditorKey('adType_$adType');
  final priceField = const _AdEditorKey('priceField');
  final rentalPeriod = const _AdEditorKey('rentalPeriod');

  /// Un segment de la période de location (`RentalPeriod.json`).
  ValueKey<String> rentalPeriodOption(String period) =>
      _AdEditorKey('rentalPeriod_$period');
  final markdownField = const _AdEditorKey('markdownField');
  final placeField = const _AdEditorKey('placeField');
  final positionRow = const _AdEditorKey('positionRow');
  final tagsRow = const _AdEditorKey('tagsRow');
  final status = const _AdEditorKey('status');

  /// Un segment du choix de statut (`DRAFT`, `PUBLISHED`).
  ValueKey<String> statusOption(String status) =>
      _AdEditorKey('status_$status');
  final saveButton = const _AdEditorKey('saveButton');
}

class _AdManageKey extends ValueKey<String> {
  const _AdManageKey(String value) : super('adManage_$value');
}

/// Les gestes de l'auteur sur l'écran d'une annonce (ledger `MOB-158`).
class AdManageKeys {
  /// Le crayon de la barre : modifier l'annonce.
  final editButton = const _AdManageKey('editButton');

  // Les lignes du menu « Gérer l'annonce ».
  final publish = const _AdManageKey('publish');
  final unpublish = const _AdManageKey('unpublish');
  final delete = const _AdManageKey('delete');
  final restore = const _AdManageKey('restore');
  final report = const _AdManageKey('report');

  /// Le bandeau d'une annonce supprimée.
  final deletedBanner = const _AdManageKey('deletedBanner');
}

class _AdContactKey extends ValueKey<String> {
  const _AdContactKey(String value) : super('adContact_$value');
}

class AdContactKeys {
  final error = const _AdContactKey('error');
  final messageField = const _AdContactKey('messageField');
  final sendButton = const _AdContactKey('sendButton');
}

class _AdsListKey extends ValueKey<String> {
  const _AdsListKey(String value) : super('adsList_$value');
}

/// La liste des annonces d'une équipe.
class AdsListKeys {
  /// La carte d'une annonce, par son slug.
  ValueKey<String> card(String adSlug) => _AdsListKey('card_$adSlug');

  /// L'état vide d'une liste filtrée, « cul-de-sac ».
  final filteredEmptyState = const _AdsListKey('filteredEmptyState');

  /// « Réservées aux membres » : le serveur a refusé la liste (403).
  final membersOnlyState = const _AdsListKey('membersOnlyState');

  final searchField = const _AdsListKey('searchField');

  /// « Créer » à droite de la recherche, et le bouton de la liste vide
  /// (ledger `MOB-158`).
  final createButton = const _AdsListKey('createButton');
  final emptyCreateButton = const _AdsListKey('emptyCreateButton');

  /// La puce « Prix » et sa feuille (règle RL3).
  final priceChip = const _AdsListKey('priceChip');
  final minPriceField = const _AdsListKey('minPriceField');
  final maxPriceField = const _AdsListKey('maxPriceField');
  final priceApplyButton = const _AdsListKey('priceApplyButton');

  /// La puce d'un type d'annonce (`AdType.json`) ; `null` pour « Tous ».
  ValueKey<String> typeChip(String? adType) =>
      _AdsListKey('typeChip_${adType ?? 'all'}');
}
