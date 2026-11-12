import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// Ce qui identifie un jeu de résultats d'annonces.
///
/// Recherche, type, prix, tags, colonne et sens de tri : tous participent à la clé
/// de famille de `adListProvider`, donc **changer l'un d'eux construit un
/// notifier neuf** plutôt que de muter celui en place. C'est le contrat que le
/// lot 3 a posé pour les parcours et qu'un test protège — deux jeux de
/// résultats ne peuvent pas se mélanger.
///
/// Le tri en fait partie bien qu'il ne filtre rien : il change l'ordre, donc
/// la page 0 n'est plus la même, donc reprendre la pagination en cours
/// entrelacerait deux ordres.
@immutable
class AdFilters {
  const AdFilters({
    required this.teamSlug,
    this.search,
    this.adType,
    this.sortBy = AdSortBy.dateTime,
    this.sortDir = SortDirection.desc,
    this.tagIds = const <String>[],
    this.minPrice,
    this.maxPrice,
  });

  /// Portée **imposée** par l'écran : la rubrique Annonces appartient à une
  /// équipe, et il n'existe pas de liste d'annonces inter-équipes au contrat.
  final String teamSlug;

  final String? search;
  final AdType? adType;

  /// Défauts du serveur, répétés ici pour que la chip de tri sache quoi
  /// afficher avant le premier appel.
  final AdSortBy sortBy;
  final SortDirection sortDir;

  /// Tags `AD` choisis, triés (`normalizeTagSelection`) ; une annonce sort si
  /// elle en porte **au moins un** (plan des tags, D6). Vide : pas de filtre.
  final List<String> tagIds;

  /// Les bornes de prix, en euros (règle RL3, comme au site) ; nulles :
  /// « Indifférent ». **L'une ou l'autre écarte les annonces sans prix** (« à
  /// négocier ») — c'est le serveur qui le décide, et la feuille le dit.
  final int? minPrice;
  final int? maxPrice;

  /// Vrai quand une borne de prix est posée.
  bool get hasPrice => minPrice != null || maxPrice != null;

  /// Vrai dès qu'un critère **restreint** le jeu de résultats. Le tri n'en est
  /// pas : il ne peut pas rendre une liste vide, donc il n'a rien à faire dans
  /// le diagnostic d'un cul-de-sac.
  bool get isFiltered =>
      (search?.trim().isNotEmpty ?? false) ||
      adType != null ||
      hasPrice ||
      tagIds.isNotEmpty;

  /// Les filtres levés — recherche, type, prix, tags —, le tri conservé :
  /// « Effacer les filtres » remet la liste en vue, il ne réordonne pas ce que
  /// l'utilisateur a choisi de lire (règle RL4).
  AdFilters get cleared =>
      AdFilters(teamSlug: teamSlug, sortBy: sortBy, sortDir: sortDir);

  AdFilters copyWith({
    String? search,
    bool clearSearch = false,
    AdType? adType,
    bool clearAdType = false,
    AdSortBy? sortBy,
    SortDirection? sortDir,
    List<String>? tagIds,
    ({int? min, int? max})? price,
  }) {
    return AdFilters(
      teamSlug: teamSlug,
      search: clearSearch ? null : (search ?? this.search),
      adType: clearAdType ? null : (adType ?? this.adType),
      sortBy: sortBy ?? this.sortBy,
      sortDir: sortDir ?? this.sortDir,
      tagIds: tagIds ?? this.tagIds,
      minPrice: price == null ? minPrice : price.min,
      maxPrice: price == null ? maxPrice : price.max,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdFilters &&
          other.teamSlug == teamSlug &&
          other.search == search &&
          other.adType == adType &&
          other.sortBy == sortBy &&
          other.sortDir == sortDir &&
          other.minPrice == minPrice &&
          other.maxPrice == maxPrice &&
          listEquals(other.tagIds, tagIds);

  @override
  int get hashCode => Object.hash(
    teamSlug,
    search,
    adType,
    sortBy,
    sortDir,
    minPrice,
    maxPrice,
    Object.hashAll(tagIds),
  );

  @override
  String toString() =>
      'AdFilters($teamSlug, search: $search, type: $adType, '
      'sort: ${sortBy.json} ${sortDir.json}, tags: $tagIds, '
      'price: $minPrice–$maxPrice)';
}
