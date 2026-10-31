import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../rides/domain/ride_weather_map.dart';
import '../../routes/domain/track_surfaces.dart';
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

/// Ce qui colore les cartes d'un voyage — **une clé pour le voyage** : la
/// carte d'ensemble et celle du détail d'une étape partagent le choix, comme
/// la carte encastrée, le plein écran et le profil d'un groupe partagent
/// `rideMapColorModeProvider` (ledger `MOB-105`). La carte d'ensemble, à une
/// couleur par étape, ne lit que « Météo » ou non ; le détail d'une étape lit
/// aussi Pente | Revêtement.
///
/// En mémoire, **sur la pente par défaut** : on ne change pas le sens des
/// couleurs sans que la personne l'ait choisi. Chaque page qui l'offre l'écoute
/// pour le garder vivant tant qu'elle est montée, et ramène « Météo » sur la
/// pente quand un refetch perd la prévision de ce qu'elle montre.
final tripMapColorModeProvider = StateProvider.autoDispose
    .family<RouteColorBy, TripKey>(
      (Ref ref, TripKey key) => RouteColorBy.grade,
    );

/// Vrai quand les cartes de [key] sont en mode « Météo ».
bool watchTripMapWindMode(WidgetRef ref, TripKey key) =>
    ref.watch(tripMapColorModeProvider(key)) == RouteColorBy.wind;

/// Allume ([on]) ou éteint le mode « Météo » des cartes de [key] : la puce et
/// l'interrupteur de la carte d'ensemble. Éteindre ramène sur la pente
/// **seulement depuis Météo** : un Revêtement choisi sur une étape reste
/// (ledger `MOB-105`).
void setTripMapWindMode(WidgetRef ref, TripKey key, bool on) {
  final StateController<RouteColorBy> mode = ref.read(
    tripMapColorModeProvider(key).notifier,
  );
  if (on) {
    mode.state = RouteColorBy.wind;
  } else if (mode.state == RouteColorBy.wind) {
    mode.state = RouteColorBy.grade;
  }
}

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

/// Garde vivant le mode des cartes de [trip] tant que la page qui l'appelle
/// dans son `build` est montée, et ramène « Météo » sur la pente quand un
/// refetch perd
/// ce que la page colorait — [stillShows] vrai avant, faux après —,
/// pour qu'une prévision revenue ne recolore pas le tracé sans nouveau choix
/// (plan 2026-10-24-weather-on-map §4, la règle de `RideGroupPage`).
void listenTripMapWindMode(
  WidgetRef ref,
  TripKey key,
  TripDto trip, {
  required bool Function(Map<String, WeatherLegDto> legs) stillShows,
}) {
  ref.listen(
    tripMapColorModeProvider(key),
    (RouteColorBy? _, RouteColorBy _) {},
  );
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
      setTripMapWindMode(ref, key, false);
    }
  });
}
