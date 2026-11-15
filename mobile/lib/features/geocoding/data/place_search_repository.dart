import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final placeSearchRepositoryProvider = Provider<PlaceSearchRepository>((ref) {
  return PlaceSearchRepository(ref.watch(apiClientProvider).geocode);
});

/// La recherche d'adresse des formulaires — annonce (ledger `MOB-158`),
/// équipe (ledger `MOB-165`) — par le relais du serveur (`/api/geocode/*`) :
/// c'est lui qui parle au fournisseur, jamais l'appareil.
class PlaceSearchRepository {
  PlaceSearchRepository(this._client);

  final GeocodeClient _client;

  /// Le serveur ne cherche rien en dessous.
  static const int minQueryLength = 3;

  /// Cinq suggestions au plus, le plus souvent **sans position**.
  Future<List<GeocodeResultDto>> search(String query) {
    final String q = query.trim();
    if (q.length < minQueryLength) {
      return Future<List<GeocodeResultDto>>.value(const <GeocodeResultDto>[]);
    }
    return _client.searchPlaces(q: q);
  }

  /// La position de la suggestion **choisie** — jamais de chaque suggestion :
  /// chaque appel est facturé par le fournisseur (ledger `API-129`).
  Future<GeocodeResultDto> resolve(String id) => _client.resolvePlace(id: id);
}
