import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/pdl/elevation/elevation_samples.dart';
import '../../../core/theme/enum_colors.dart';
import '../../../core/theme/pdl_colors.dart';

/// Le revêtement le long d'un parcours (`MOB-81`) : la logique du site
/// (`frontend/src/lib/trackSurface.ts`), en Dart.
///
/// Les plages (`TrackDto.surfaces`) sont en **mètres le long de la piste**, la
/// mesure `M` des coordonnées G3DM repart de zéro sur chaque piste : un
/// segment se lit à son milieu sur `M`, sans passer par le [PolylineIndex].

/// Ce que la pente / le revêtement colorent sur la fiche.
enum RouteColorBy { grade, surface }

/// L'ordre de la légende, celui du site (`TRACK_SURFACES`).
const List<TrackSurface> kTrackSurfaceOrder = <TrackSurface>[
  TrackSurface.paved,
  TrackSurface.pavedRough,
  TrackSurface.gravel,
  TrackSurface.dirt,
  TrackSurface.path,
  TrackSurface.unknown,
  TrackSurface.offNetwork,
];

/// Longueur et part d'une classe de revêtement.
@immutable
class TrackSurfaceShare {
  const TrackSurfaceShare({
    required this.surface,
    required this.length,
    required this.share,
  });

  final TrackSurface surface;

  /// En mètres.
  final double length;

  /// Dans `[0, 1]`.
  final double share;

  @override
  bool operator ==(Object other) =>
      other is TrackSurfaceShare &&
      other.surface == surface &&
      other.length == length &&
      other.share == share;

  @override
  int get hashCode => Object.hash(surface, length, share);

  @override
  String toString() => 'TrackSurfaceShare($surface, $length m, $share)';
}

List<SurfaceSpanDto>? _readySpans(TrackDto track) {
  final List<SurfaceSpanDto>? spans = track.surfaces;
  if (track.surfaceState == TrackSurfaceState.ready.json &&
      spans != null &&
      spans.isNotEmpty) {
    return spans;
  }
  return null;
}

/// Au moins une piste a son revêtement.
bool hasTrackSurfaces(List<TrackDto> tracks) =>
    tracks.any((TrackDto t) => _readySpans(t) != null);

/// Aucune piste n'a son revêtement, et au moins une est en cours de calcul.
bool trackSurfacesPending(List<TrackDto> tracks) =>
    !hasTrackSurfaces(tracks) &&
    tracks.any(
      (TrackDto t) => t.surfaceState == TrackSurfaceState.pending.json,
    );

/// La classe à [m] mètres (dichotomie : les plages sont contiguës et triées),
/// `unknown` hors plages. Une borne appartient à la plage qui y commence.
TrackSurface surfaceAtDistance(List<SurfaceSpanDto>? spans, double m) {
  if (spans == null || spans.isEmpty) return TrackSurface.unknown;
  int lo = 0;
  int hi = spans.length - 1;
  while (lo <= hi) {
    final int mid = (lo + hi) >> 1;
    final SurfaceSpanDto span = spans[mid];
    if (m < span.from) {
      hi = mid - 1;
    } else if (m > span.to || (m == span.to && mid < spans.length - 1)) {
      lo = mid + 1;
    } else {
      return span.surface;
    }
  }
  return TrackSurface.unknown;
}

/// La classe de chaque segment de [coords] (une de moins que de sommets),
/// lue au milieu du segment sur la mesure `M` ; `unknown` sans plages ou sans
/// `M`.
List<TrackSurface> _lineSegments(
  List<SurfaceSpanDto>? spans,
  List<List<double>> coords,
) => <TrackSurface>[
  for (int i = 1; i < coords.length; i++)
    spans == null || coords[i - 1].length < 4 || coords[i].length < 4
        ? TrackSurface.unknown
        : _known(
            surfaceAtDistance(spans, (coords[i - 1][3] + coords[i][3]) / 2),
          ),
];

/// Une classe que ce client ne connaît pas se lit « inconnu ».
TrackSurface _known(TrackSurface s) =>
    s == TrackSurface.$unknown ? TrackSurface.unknown : s;

/// Une classe par segment des lignes aplaties, dans l'ordre (autant que
/// `segmentCount`). `null` quand aucune piste n'a son revêtement.
List<TrackSurface>? segmentSurfaces(List<TrackDto> tracks) {
  if (!hasTrackSurfaces(tracks)) return null;
  return <TrackSurface>[
    for (final TrackDto t in tracks)
      ..._lineSegments(_readySpans(t), t.line.coordinates),
  ];
}

/// Les traits de la carte : un par segment ([segmentSurfaces]).
List<Color>? surfaceSegmentColors(List<TrackDto> tracks, PdlColors c) =>
    segmentSurfaces(tracks)?.map((TrackSurface s) => s.stroke(c)).toList();

/// Longueur et part de chaque classe sur les pistes prêtes, dans l'ordre de la
/// légende, classes vides retirées.
List<TrackSurfaceShare> surfaceShares(List<TrackDto> tracks) {
  final Map<TrackSurface, double> lengths = <TrackSurface, double>{};
  double total = 0;
  for (final TrackDto t in tracks) {
    for (final SurfaceSpanDto span
        in _readySpans(t) ?? const <SurfaceSpanDto>[]) {
      final double length = span.to - span.from;
      if (length <= 0) continue;
      final TrackSurface key = _known(span.surface);
      lengths[key] = (lengths[key] ?? 0) + length;
      total += length;
    }
  }
  if (total <= 0) return const <TrackSurfaceShare>[];
  return <TrackSurfaceShare>[
    for (final TrackSurface s in kTrackSurfaceOrder)
      if (lengths.containsKey(s))
        TrackSurfaceShare(
          surface: s,
          length: lengths[s]!,
          share: lengths[s]! / total,
        ),
  ];
}

/// La classe de chaque barre du profil : la plus longue des segments qu'elle
/// couvre (égalité : ordre de la légende), sur les mêmes sommets que
/// `elevationPointsFromLines` ; le pont entre deux pistes ne compte pas.
/// `null` d'une barre sans segment couvert.
List<TrackSurface?> barSurfaces(
  ElevationSamples samples,
  List<TrackDto> tracks,
) {
  // La classe du segment `j → j+1` de l'index, `null` pour un pont. Les lignes
  // vides et les coordonnées sans longitude/latitude sont écartées comme le
  // fait `PolylineIndex.fromLineStrings`.
  final List<TrackSurface?> segments = <TrackSurface?>[];
  bool first = true;
  for (final TrackDto t in tracks) {
    final List<List<double>> coords = <List<double>>[
      for (final List<double> c in t.line.coordinates)
        if (c.length >= 2) c,
    ];
    if (coords.isEmpty) continue;
    if (!first) segments.add(null);
    first = false;
    segments.addAll(_lineSegments(_readySpans(t), coords));
  }

  final List<ElevationPoint> points = samples.points;
  final List<TrackSurface?> result = <TrackSurface?>[];
  int cursor = 0;
  for (final ElevationBar bar in samples.bars) {
    final Map<TrackSurface, double> weights = <TrackSurface, double>{};
    int j = cursor;
    while (j < points.length - 1 && j < segments.length) {
      final double segStart = points[j].distance;
      final double segEnd = points[j + 1].distance;
      if (segStart >= bar.end) break;
      final double overlap =
          (segEnd < bar.end ? segEnd : bar.end) -
          (segStart > bar.start ? segStart : bar.start);
      final TrackSurface? s = segments[j];
      if (overlap > 0 && s != null) {
        weights[s] = (weights[s] ?? 0) + overlap;
      }
      if (segEnd <= bar.end) {
        j++;
        cursor = j;
      } else {
        break;
      }
    }

    TrackSurface? best;
    double bestWeight = 0;
    for (final TrackSurface s in kTrackSurfaceOrder) {
      final double w = weights[s] ?? 0;
      if (w > bestWeight) {
        best = s;
        bestWeight = w;
      }
    }
    result.add(best);
  }
  return result;
}
