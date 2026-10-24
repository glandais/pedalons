import 'dart:math' as math;

import '../../../api/generated/export.dart';
import '../../../core/geo/polyline_index.dart';
import 'ride_weather_display.dart';

/// Le vent posé sur le tracé d'un groupe (ledger `MOB-91`, palier 1 de
/// `docs/plans/2026-10-24-weather-on-map.md`). Aucun widget ici : des
/// fonctions pures, testées sans carte.
///
/// ## Le piège des distances
///
/// Les distances des DTO météo (`WeatherCheckpointDto.distance`,
/// `WindSegmentDto.fromDistance/toDistance`) mettent les traces du parcours
/// **bout à bout sans compter le saut** entre la fin de l'une et le début de
/// la suivante (`RouteSampleLookup.chain`, côté serveur). [PolylineIndex], lui,
/// compte ce saut à vol d'oiseau : le réutiliser décalerait les couleurs dès
/// la deuxième trace. D'où [chainedMeasures], qui recopie la règle du serveur.

/// Le vent se montre-t-il sur la carte du groupe ?
///
/// Seulement avec une prévision (`OK` ou `STALE`), au moins un point de
/// passage qui porte une météo et des tronçons de vent. Rien pour
/// `NOT_YET_AVAILABLE`, `NO_LOCATION`, `UNAVAILABLE`, ni `OUT_OF_RANGE` — la
/// sortie terminée ou annulée. Un refetch qui perd la prévision fait donc
/// retomber la carte sur son trait habituel.
bool showsWindOnMap(WeatherLegDto? leg) {
  if (leg == null) return false;
  final RideWeatherView view = rideWeatherViewOf(
    leg.status,
    canSeeNoLocation: false,
  );
  if (view != RideWeatherView.forecast && view != RideWeatherView.stale) {
    return false;
  }
  return leg.segments.isNotEmpty &&
      leg.checkpoints.any((WeatherCheckpointDto c) => c.weather != null);
}

/// La distance de chaque sommet de chaque ligne, en mètres depuis le départ,
/// **traces mises bout à bout, saut nul** — la convention des distances météo.
///
/// Une ligne par trace, dans l'ordre reçu (celui des id, comme le serveur).
/// La 4ᵉ composante d'une coordonnée est la distance depuis le début de
/// **sa** trace ; elle repart de 0 (ou d'ailleurs) à chaque trace, et seule
/// sa progression compte. Une coordonnée qui n'en porte pas prend la
/// haversine depuis le sommet précédent. Les distances ne reculent jamais,
/// comme au serveur. Une ligne vide donne une liste vide et n'avance rien.
List<List<double>> chainedMeasures(List<List<List<double>>> lines) {
  final List<List<double>> result = <List<double>>[];
  double offset = 0;
  for (final List<List<double>> line in lines) {
    final List<double> measures = <double>[];
    if (line.isEmpty) {
      result.add(measures);
      continue;
    }
    final double? first = line.first.length >= 4 ? line.first[3] : null;
    double last = offset;
    for (int i = 0; i < line.length; i++) {
      final List<double> c = line[i];
      final double value;
      if (i == 0) {
        value = offset;
      } else if (first != null && c.length >= 4) {
        value = offset + c[3] - first;
      } else {
        final List<double> p = line[i - 1];
        value = last + haversineMeters(LngLat(p[0], p[1]), LngLat(c[0], c[1]));
      }
      last = math.max(last, value);
      measures.add(last);
    }
    offset = last;
    result.add(measures);
  }
  return result;
}

/// Une couleur par intervalle entre deux sommets consécutifs, **lignes brutes
/// aplaties dans l'ordre** : le contrat de `PdlMapTrack.segmentColors`. Une
/// ligne de moins de deux sommets ne compte aucun intervalle.
///
/// Le vent d'un intervalle est celui du tronçon qui contient son milieu.
/// [colorOf] reçoit `null` pour un intervalle hors de tout tronçon ou dont le
/// vent est inconnu : à l'appelant de rendre la couleur par défaut du tracé,
/// **jamais le gris**, qui dit « travers ».
List<T> windSegmentColors<T>(
  List<List<List<double>>> lines,
  List<WindSegmentDto> segments,
  T Function(RelativeWind? wind) colorOf,
) {
  final List<WindSegmentDto> sorted = List<WindSegmentDto>.of(segments)
    ..sort(
      (WindSegmentDto a, WindSegmentDto b) =>
          a.fromDistance.compareTo(b.fromDistance),
    );
  final List<List<double>> measures = chainedMeasures(lines);
  final List<T> colors = <T>[];
  for (final List<double> m in measures) {
    for (int i = 1; i < m.length; i++) {
      final WindSegmentDto? segment = _segmentAt(sorted, (m[i - 1] + m[i]) / 2);
      colors.add(colorOf(relativeWindOf(segment?.relativeWind)));
    }
  }
  return colors;
}

/// Le tronçon qui contient [distance] : `from <= d < to`, le dernier fermé à
/// droite. Recherche dichotomique sur les tronçons triés.
WindSegmentDto? _segmentAt(List<WindSegmentDto> sorted, double distance) {
  int lo = 0;
  int hi = sorted.length - 1;
  while (lo <= hi) {
    final int mid = (lo + hi) >> 1;
    final WindSegmentDto s = sorted[mid];
    if (distance < s.fromDistance) {
      hi = mid - 1;
    } else if (distance >= s.toDistance &&
        !(mid == sorted.length - 1 && distance == s.toDistance)) {
      lo = mid + 1;
    } else {
      return s;
    }
  }
  return null;
}

/// La position de chaque distance de [distances] sur les [lines] d'un
/// parcours (palier 2 du plan, ledger `MOB-92`) : **le premier sommet dont la
/// distance chaînée ([chainedMeasures], saut nul) atteint `d − 0,5 m`**. Un
/// point de passage tombe sur un sommet du tracé (la géométrie n'est pas
/// simplifiée), d'où le demi-mètre de tolérance pour l'arrondi du serveur.
///
/// Une distance au-delà du dernier sommet prend le dernier ; `null` pour
/// toutes quand le parcours n'a aucun sommet. Les distances sont chaînées une
/// seule fois pour toute la liste.
List<LngLat?> pointsAtDistances(
  List<List<List<double>>> lines,
  List<double> distances,
) {
  final List<List<double>> measures = chainedMeasures(lines);
  // Les sommets aplatis, dans l'ordre, avec leur distance chaînée.
  final List<double> flat = <double>[];
  final List<List<double>> coords = <List<double>>[];
  for (int l = 0; l < lines.length; l++) {
    for (int i = 0; i < lines[l].length; i++) {
      flat.add(measures[l][i]);
      coords.add(lines[l][i]);
    }
  }
  if (flat.isEmpty) {
    return List<LngLat?>.filled(distances.length, null);
  }
  return <LngLat?>[
    for (final double d in distances) _vertexAt(flat, coords, d - 0.5),
  ];
}

/// Le premier sommet de distance `>= target` (dichotomie : [flat] ne recule
/// jamais), le dernier à défaut.
LngLat _vertexAt(List<double> flat, List<List<double>> coords, double target) {
  int lo = 0;
  int hi = flat.length - 1;
  if (flat[hi] < target) return LngLat(coords[hi][0], coords[hi][1]);
  while (lo < hi) {
    final int mid = (lo + hi) >> 1;
    if (flat[mid] >= target) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return LngLat(coords[lo][0], coords[lo][1]);
}
