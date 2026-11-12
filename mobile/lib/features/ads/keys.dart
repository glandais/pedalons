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

  /// La puce « Prix » et sa feuille (règle RL3).
  final priceChip = const _AdsListKey('priceChip');
  final minPriceField = const _AdsListKey('minPriceField');
  final maxPriceField = const _AdsListKey('maxPriceField');
  final priceApplyButton = const _AdsListKey('priceApplyButton');

  /// La puce d'un type d'annonce (`AdType.json`) ; `null` pour « Tous ».
  ValueKey<String> typeChip(String? adType) =>
      _AdsListKey('typeChip_${adType ?? 'all'}');
}
