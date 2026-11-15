import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(tripsClientProvider));
});

class TripRepository {
  final TripsClient _tripsClient;

  TripRepository(this._tripsClient);

  Future<TripDto> getTrip(String teamSlug, String tripSlug) {
    return _tripsClient.getTrip(teamSlug: teamSlug, tripSlug: tripSlug);
  }

  /// La météo du voyage, étape par étape. Toujours 200 pour qui peut lire
  /// le voyage : l'état est dans `TripWeatherDto.status` et, pour chaque
  /// étape, dans `leg.status`. Le serveur ne lit que son cache : l'appel est
  /// bon marché, et le recharger ne « force » aucune prévision.
  Future<TripWeatherDto> getTripWeather(String teamSlug, String tripSlug) {
    return _tripsClient.getTripWeather(teamSlug: teamSlug, tripSlug: tripSlug);
  }

  Future<TripParticipationDto> joinTrip(String teamSlug, String tripSlug) {
    return _tripsClient.joinTrip(teamSlug: teamSlug, tripSlug: tripSlug);
  }

  Future<void> leaveTrip(String teamSlug, String tripSlug) {
    return _tripsClient.leaveTrip(teamSlug: teamSlug, tripSlug: tripSlug);
  }

  // ── Écriture (docs/LEDGER_*.md MOB-162) ──────────────────────────────────

  Future<TripDto> createTrip(String teamSlug, TripRequest request) {
    return _tripsClient.createTrip(teamSlug: teamSlug, body: request);
  }

  /// Réécrit un voyage. Le serveur applique **tous** les champs du PUT,
  /// absents compris : chaque étape doit y figurer avec son id, son parcours
  /// et ses lieux, sinon elle est supprimée ou vidée.
  Future<TripDto> updateTrip(
    String teamSlug,
    String tripSlug,
    TripRequest request,
  ) {
    return _tripsClient.updateTrip(
      teamSlug: teamSlug,
      tripSlug: tripSlug,
      body: request,
    );
  }

  /// Publier, dépublier, annuler ou rétablir : le `PATCH /status`, qui ne
  /// touche à rien d'autre — ni aux étapes ni aux tags, qu'un PUT recopié
  /// depuis un détail périmé pourrait abîmer.
  Future<TripDto> changeStatus(
    String teamSlug,
    String tripSlug,
    Status status,
  ) {
    return _tripsClient.changeTripStatus(
      teamSlug: teamSlug,
      tripSlug: tripSlug,
      body: StatusChangeRequest(status: status.toJson()),
    );
  }

  /// Change l'adresse (le slug) d'un voyage. Les liens vers l'ancienne ne
  /// fonctionnent plus.
  Future<TripDto> changeSlug(String teamSlug, String tripSlug, String slug) {
    return _tripsClient.changeTripSlug(
      teamSlug: teamSlug,
      tripSlug: tripSlug,
      body: SlugChangeRequest(slug: slug),
    );
  }

  /// Suppression **douce** : le voyage reste lisible par le rôle
  /// Administrateur de l'équipe, marqué `deleted`, et [undeleteTrip] le
  /// ramène.
  Future<void> deleteTrip(String teamSlug, String tripSlug) {
    return _tripsClient.deleteTrip(teamSlug: teamSlug, tripSlug: tripSlug);
  }

  Future<TripDto> undeleteTrip(String teamSlug, String tripSlug) {
    return _tripsClient.undeleteTrip(teamSlug: teamSlug, tripSlug: tripSlug);
  }
}
