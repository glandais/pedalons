import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../data/trip_repository.dart';
import 'trip_detail_provider.dart';

/// La météo d'un voyage, étape par étape
/// (`GET …/trips/{tripSlug}/weather`).
///
/// Une seule lecture pour tout le voyage, partagée par les lignes de résumé
/// des cartes d'étape (écran 24), la carte de l'étape et sa section Météo
/// (écran 25) : passer d'une étape à l'autre ne recharge rien.
///
/// `autoDispose`, comme `rideWeatherProvider` : une prévision vieillit, et la
/// garder après ces écrans ne servirait qu'à en montrer une périmée au
/// retour. Les tirer-pour-rafraîchir des écrans 24 et 25 et de l'écran météo
/// l'invalident explicitement.
///
/// Aucun calcul côté app : le serveur fait tout, l'app traduit et convertit
/// les unités.
final tripWeatherProvider = FutureProvider.autoDispose
    .family<TripWeatherDto, TripKey>(
      (Ref ref, TripKey key) => ref
          .watch(tripRepositoryProvider)
          .getTripWeather(key.teamSlug, key.tripSlug),
    );

/// La météo de l'étape [stageId] (`TripStageDto.id`), ou `null` si la réponse
/// ne la porte pas (voyage non publié, étape supprimée entre deux lectures).
TripStageWeatherDto? stageWeatherFor(TripWeatherDto weather, String stageId) {
  for (final TripStageWeatherDto s in weather.stages) {
    if (s.stageId == stageId) return s;
  }
  return null;
}

/// Le statut global montre-t-il quelque chose ? Non pour `OUT_OF_RANGE`
/// (voyage terminé, annulé, brouillon) ni pour un statut que cette build ne
/// connaît pas ; sinon chaque étape se rend selon son propre `leg.status`.
bool tripWeatherShowsAnything(TripWeatherDto weather) =>
    switch (WeatherStatus.fromJson(weather.status)) {
      WeatherStatus.outOfRange || WeatherStatus.$unknown => false,
      _ => true,
    };
