import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../domain/place_filters.dart';

final placesRepositoryProvider = Provider<PlacesRepository>((Ref ref) {
  return PlacesRepository(ref.watch(placesClientProvider));
});

/// Les lieux d'une équipe — ses points de départ et d'arrivée —, tels que
/// l'écran « Lieux » les administre (docs/LEDGER_*.md MOB-168). Réservé aux
/// organisateurs côté serveur, lecture comprise.
///
/// La recherche de lieux des éditeurs de sortie et de voyage reste dans
/// `RideEditorRepository` : elle filtre par usage (départ ou arrivée), cet
/// écran non.
class PlacesRepository {
  PlacesRepository(this._client);

  final PlacesClient _client;

  /// Une page de la liste, tous usages confondus, cherchée par nom ou
  /// adresse.
  Future<PageResult<PlaceDetailDto>> fetchPlaces({
    required PlaceFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    final String? search = filters.search?.trim();
    final PlaceListResponse response = await _client.listPlaces(
      teamSlug: filters.teamSlug,
      search: search == null || search.isEmpty ? null : search,
      page: page,
      size: size,
    );
    return PageResult<PlaceDetailDto>(
      items: response.places,
      total: response.total,
    );
  }

  Future<PlaceDetailDto> create(String teamSlug, PlaceRequest request) {
    return _client.createPlace(teamSlug: teamSlug, body: request);
  }

  /// Réécrit le lieu **en entier** : ce que [request] ne porte pas est effacé.
  Future<PlaceDetailDto> update(
    String teamSlug,
    String placeId,
    PlaceRequest request,
  ) {
    return _client.updatePlace(
      teamSlug: teamSlug,
      placeId: placeId,
      body: request,
    );
  }

  Future<void> delete(String teamSlug, String placeId) {
    return _client.deletePlace(teamSlug: teamSlug, placeId: placeId);
  }
}
