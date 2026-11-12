import 'package:flutter/widgets.dart';

import '../../api/generated/export.dart';

class _FeedKey extends ValueKey<String> {
  const _FeedKey(String value) : super('feed_$value');
}

/// Le fil de publications, sur l'accueil comme dans une équipe.
class FeedKeys {
  /// La carte d'une publication du fil, par son slug.
  ValueKey<String> card(String slug) => _FeedKey('card_$slug');

  /// L'état vide d'une recherche qui ne trouve rien.
  final filteredEmptyState = const _FeedKey('filteredEmptyState');

  final searchField = const _FeedKey('searchField');

  /// Le badge « En cours » d'une sortie ou d'un voyage, par son slug.
  ValueKey<String> underWayBadge(String slug) => _FeedKey('underWay_$slug');

  /// Le badge « Terminée » d'un voyage, par son slug.
  ValueKey<String> finishedBadge(String slug) => _FeedKey('finished_$slug');

  /// Le badge de visibilité d'une carte, par son slug — posé seulement quand
  /// la visibilité diffère de celle de l'équipe (règle R1).
  ValueKey<String> visibilityBadge(String slug) => _FeedKey('visibility_$slug');

  /// Le compte de personnes d'une carte de voyage, par son slug (règle R4).
  ValueKey<String> tripParticipantCount(String slug) =>
      _FeedKey('tripParticipants_$slug');

  /// L'état vide absolu (« Rien à l'agenda pour le moment »).
  final emptyState = const _FeedKey('emptyState');

  /// La ligne du nombre de résultats (« 5 sorties et voyages à venir »).
  final resultCount = const _FeedKey('resultCount');

  /// La puce d'un type de publication ; `null` pour « Tout ».
  ValueKey<String> typeChip(PublicationType? type) =>
      _FeedKey('typeChip_${type?.json ?? 'all'}');
}
