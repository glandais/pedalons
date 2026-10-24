import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../rides/domain/ride_weather_map.dart';
import '../providers/trip_detail_provider.dart';
import '../providers/trip_weather_provider.dart';

/// Le vent sur les cartes d'un voyage (palier 3 lot B de
/// `docs/plans/archive/2026-10-24-weather-on-map.md`, ledger `MOB-94`) : la carte
/// d'ensemble (`TripMap`), chaque étape colorée par son propre vent, et la
/// carte du détail d'une étape.
///
/// Le leg d'une étape (`TripStageWeatherDto.leg`) a la forme de celui d'un
/// groupe : la règle d'affichage est la même ([showsWindOnMap]). Une étape
/// déjà partie arrive en `OUT_OF_RANGE` et n'a donc pas de mode ; un voyage
/// terminé ou annulé ne demande même pas sa météo.

/// Le mode « Météo » des cartes d'un voyage — **une clé pour le voyage** :
/// la carte d'ensemble et celle du détail d'une étape partagent le choix,
/// comme la carte encastrée et le plein écran d'un groupe partagent
/// `rideMapWindModeProvider`.
///
/// En mémoire, **éteint par défaut** : on ne change pas le sens des couleurs
/// sans que la personne l'ait choisi. Chaque page qui l'offre l'écoute pour
/// le garder vivant tant qu'elle est montée, et l'éteint quand un refetch
/// perd la prévision de ce qu'elle montre.
final tripMapWindModeProvider = StateProvider.autoDispose.family<bool, TripKey>(
  (Ref ref, TripKey key) => false,
);

/// Le leg à poser sur la carte de chaque étape, par `TripStageDto.id` :
/// seulement les étapes dont la prévision se montre ([showsWindOnMap]).
/// Vide sans réponse, pour un statut global qui ne montre rien
/// (`OUT_OF_RANGE`), ou un voyage terminé ou annulé.
Map<String, WeatherLegDto> tripMapWindLegs(TripDto trip, TripWeatherDto? dto) {
  if (dto == null ||
      trip.isPast ||
      trip.isCancelled ||
      !tripWeatherShowsAnything(dto)) {
    return const <String, WeatherLegDto>{};
  }
  return <String, WeatherLegDto>{
    for (final TripStageWeatherDto s in dto.stages)
      if (s.stageId != null && showsWindOnMap(s.leg)) s.stageId!: s.leg,
  };
}

/// La météo d'un voyage que ses cartes lisent : `null` pour un voyage
/// terminé ou annulé, qui ne la demande pas.
TripWeatherDto? watchTripMapWeather(WidgetRef ref, TripKey key, TripDto trip) =>
    trip.isPast || trip.isCancelled
    ? null
    : ref.watch(tripWeatherProvider(key)).value;

/// Garde vivant le mode « Météo » des cartes de [trip] tant que la page qui
/// l'appelle dans son `build` est montée, et l'éteint quand un refetch perd
/// ce que la page colorait — [stillShows] vrai avant, faux après —,
/// pour qu'une prévision revenue ne recolore pas le tracé sans nouveau choix
/// (plan 2026-10-24-weather-on-map §4, la règle de `RideGroupPage`).
void listenTripMapWindMode(
  WidgetRef ref,
  TripKey key,
  TripDto trip, {
  required bool Function(Map<String, WeatherLegDto> legs) stillShows,
}) {
  ref.listen(tripMapWindModeProvider(key), (bool? _, bool _) {});
  // Un voyage terminé ou annulé ne demande même pas sa météo.
  if (trip.isPast || trip.isCancelled) return;
  // **Perdre**, pas « ne pas avoir » : le mode est partagé à l'échelle du
  // voyage, si bien qu'une étape déjà partie (sans prévision) qu'on
  // rafraîchit ne doit pas l'éteindre pour les autres étapes.
  ref.listen(tripWeatherProvider(key), (
    AsyncValue<TripWeatherDto>? previous,
    AsyncValue<TripWeatherDto> next,
  ) {
    final bool showed = stillShows(tripMapWindLegs(trip, previous?.value));
    if (showed && !stillShows(tripMapWindLegs(trip, next.value))) {
      ref.read(tripMapWindModeProvider(key).notifier).state = false;
    }
  });
}
