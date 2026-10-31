import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/geo/polyline_index.dart';
import '../../../core/pdl/elevation/elevation_samples.dart';
import '../../../core/theme/pdl_tokens.dart';
import 'track_surfaces.dart';

/// La couleur de la **pente** le long d'un parcours, sur la carte comme sur le
/// profil : la règle du site (`getPointClimbGradient` et
/// `createGradientLineFeatures`, `frontend/src/components/map/mapUtils.ts`),
/// en Dart — ledger `MOB-105`.
///
/// **Seules les montées se colorent.** La source est `TrackDto.climbs`, partie
/// par partie (`ClimbDto.parts`) quand le serveur les donne, sinon la pente
/// moyenne de la montée ; tout le reste — plats, descentes, faux plats que le
/// détecteur ne retient pas — prend [slopeNeutral], le bleu neutre. La
/// géométrie seule colorait chaque segment, descentes comprises, et ne disait
/// donc pas la même chose que le site.
///
/// Les distances des montées sont en **mètres le long de la piste**, comme la
/// mesure `M` des coordonnées G3DM, qui repart de zéro sur chaque piste : un
/// segment se lit sur `M`, sans passer par le [PolylineIndex], et chaque piste
/// avec ses propres montées. Un sommet sans `M` est hors montée.

/// La pente de la montée qui couvre [meters] : celle de sa partie quand elle en
/// a, sinon sa pente moyenne ; 0 hors montée. Bornes incluses, comme au site.
double climbGradeAt(List<ClimbDto> climbs, double meters) {
  for (final ClimbDto climb in climbs) {
    if (meters < climb.startDistance || meters > climb.endDistance) continue;
    for (final ClimbPartDto part in climb.parts) {
      if (meters >= part.startDistance && meters <= part.endDistance) {
        return part.grade.toDouble();
      }
    }
    return climb.averageGradient.toDouble();
  }
  return 0;
}

/// La pente de chaque segment d'une piste (une de moins que de sommets), lue
/// sur le sommet **de départ** du segment : au site, un tronçon garde la
/// couleur du point qui l'ouvre.
List<double> _segmentGrades(List<ClimbDto> climbs, List<List<double>> coords) =>
    <double>[
      for (int i = 1; i < coords.length; i++)
        coords[i - 1].length < 4 ? 0 : climbGradeAt(climbs, coords[i - 1][3]),
    ];

/// Les traits de la carte en mode « Pente » : un par segment des lignes
/// aplaties (autant que [segmentCount]), **mémorisés par liste de pistes** —
/// `PdlMapTrack.==` compare la liste élément par élément, et le DTO ne change
/// pas d'un `build` à l'autre.
List<Color> climbSegmentColors(List<TrackDto> tracks) {
  final List<Color>? memo = _segmentMemo[tracks];
  if (memo != null) return memo;
  final List<Color> colors = List<Color>.unmodifiable(<Color>[
    for (final TrackDto t in tracks)
      ..._segmentGrades(t.climbs, t.line.coordinates).map(slopeColor),
  ]);
  _segmentMemo[tracks] = colors;
  return colors;
}

final Expando<List<Color>> _segmentMemo = Expando<List<Color>>(
  'climbSegmentColors',
);

/// La pente et la couleur de chaque barre du profil en mode « Pente » —
/// mémorisées avec le profil : `ElevationAreaPainter` compare ses couleurs par
/// identité.
@immutable
class ClimbBars {
  const ClimbBars({required this.grades, required this.colors});

  /// La pente de la montée sous chaque barre, 0 hors montée, `null` d'une
  /// barre sans segment couvert (le pont entre deux pistes).
  final List<double?> grades;

  /// `slopeColor` de chaque pente, `null` (neutre) d'une barre sans segment.
  final List<Color?> colors;
}

/// Les barres de [samples] colorées par les montées de [tracks] : chaque barre
/// prend la pente qui en couvre la plus grande longueur, sur les mêmes sommets
/// que `elevationPointsFromLines` (la règle de `barSurfaces`).
ClimbBars climbBars(ElevationSamples samples, List<TrackDto> tracks) {
  final List<double?> grades = barDominant<double>(
    samples,
    tracks,
    (TrackDto t, List<List<double>> coords) => _segmentGrades(t.climbs, coords),
  );
  return ClimbBars(
    grades: List<double?>.unmodifiable(grades),
    colors: List<Color?>.unmodifiable(<Color?>[
      for (final double? g in grades) g == null ? null : slopeColor(g),
    ]),
  );
}

/// La pente de la montée sous le réticule, pour l'infobulle du profil en mode
/// « Pente » : `null` hors montée, comme au site, qui ne la dit qu'en montée.
double? climbGradeTip(ElevationSamples samples, ClimbBars bars, double at) {
  final ElevationBar? bar = samples.barAt(at);
  if (bar == null) return null;
  final int index = samples.bars.indexOf(bar);
  if (index < 0 || index >= bars.grades.length) return null;
  final double? grade = bars.grades[index];
  return grade == null || grade == 0 ? null : grade;
}

/// La longueur d'un segment : le cumul `M` quand il est là, la haversine
/// sinon. C'est la même règle que [PolylineIndex], et il faut qu'elle le reste.
double _runMeters(List<double> from, List<double> to) {
  if (from.length >= 4 && to.length >= 4) {
    final double delta = to[3] - from[3];
    if (delta.isFinite && delta > 0) return delta;
  }
  return haversineMeters(LngLat(from[0], from[1]), LngLat(to[0], to[1]));
}

/// La pente moyenne d'un intervalle, en pourcent — utilitaire de test et de
/// libellé, pas de rendu.
double averageGradePercent(double riseMeters, double runMeters) =>
    runMeters <= 0 ? 0 : riseMeters / runMeters * 100;

/// L'altitude interpolée à une distance cumulée, pour l'info-bulle du réticule
/// quand elle est alimentée par la géométrie plutôt que par le profil.
double? elevationAt(Iterable<List<List<double>>> lines, double meters) {
  double cumulative = 0;
  for (final List<List<double>> line in lines) {
    for (int i = 1; i < line.length; i++) {
      final List<double> a = line[i - 1];
      final List<double> b = line[i];
      final double run = _runMeters(a, b);
      if (meters <= cumulative + run) {
        if (a.length < 3 || b.length < 3) return null;
        final double t = run <= 0
            ? 0
            : ((meters - cumulative) / run).clamp(0.0, 1.0);
        return a[2] + (b[2] - a[2]) * t;
      }
      cumulative += run;
    }
  }
  return null;
}

/// Le nombre de segments d'un ensemble de lignes — le contrat que
/// `PdlMapTrack.segmentColors` doit respecter.
int segmentCount(Iterable<List<List<double>>> lines) => lines.fold(
  0,
  (int sum, List<List<double>> l) => sum + math.max(0, l.length - 1),
);
