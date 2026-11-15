import 'package:flutter/foundation.dart';

/// Ce qui identifie un jeu de résultats de la liste des lieux d'une équipe :
/// l'équipe et la recherche (par nom ou adresse). Les champs entrent dans la
/// clé de famille du notifier : changer la recherche construit une liste
/// neuve au lieu d'entrelacer deux jeux de résultats.
@immutable
class PlaceFilters {
  const PlaceFilters({required this.teamSlug, this.search});

  final String teamSlug;
  final String? search;

  bool get isFiltered => search?.trim().isNotEmpty ?? false;

  PlaceFilters get cleared => PlaceFilters(teamSlug: teamSlug);

  PlaceFilters withSearch(String? search) =>
      PlaceFilters(teamSlug: teamSlug, search: search);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceFilters &&
          other.teamSlug == teamSlug &&
          other.search == search;

  @override
  int get hashCode => Object.hash(teamSlug, search);
}
