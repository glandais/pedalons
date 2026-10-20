import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/pdl_tokens.dart';
import '../map/pdl_waypoint_mark.dart';
import 'elevation_samples.dart';

/// Un repère posé sur le profil : un point de parcours **sur le tracé**
/// (`core/pdl` ne connaît pas son DTO). Les points hors tracé n'ont pas de
/// distance et n'y figurent jamais.
@immutable
class PdlProfileMarker {
  const PdlProfileMarker({
    required this.key,
    required this.distance,
    required this.mark,
    required this.priority,
  });

  final String key;

  /// Mètres depuis le départ.
  final double distance;
  final PdlWaypointMark mark;
  final int priority;

  @override
  bool operator ==(Object other) =>
      other is PdlProfileMarker &&
      other.key == key &&
      other.distance == distance &&
      other.mark == mark &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(key, distance, mark, priority);
}

/// Le painter des repères, entre l'aire et le réticule : un trait vertical en
/// pointillés et le pictogramme du point en haut. Il ne dépend que des données
/// et ne repeint pas pendant un glissement.
///
/// Public pour que les tests appellent `paint` et [markerAt] sans arbre.
class ElevationMarkersPainter extends CustomPainter {
  ElevationMarkersPainter({
    required this.samples,
    required this.markers,
    required this.ring,
    this.selectedKey,
  });

  final ElevationSamples samples;
  final List<PdlProfileMarker> markers;
  final Color ring;
  final String? selectedKey;

  /// Ordonnée du centre des pictogrammes.
  static const double discY = 11;
  static const double discSize = 16;
  static const double discSizeSelected = 20;

  /// Écart horizontal maximal d'un toucher à un repère.
  static const double hitSlop = 22;

  /// Les repères triés du moins au plus important : le danger est peint en
  /// dernier, donc au-dessus.
  static List<PdlProfileMarker> _byPriority(List<PdlProfileMarker> markers) =>
      List<PdlProfileMarker>.of(markers)..sort(
        (PdlProfileMarker a, PdlProfileMarker b) =>
            a.priority.compareTo(b.priority),
      );

  /// Instrumentation de test uniquement : le glissement ne repeint pas les
  /// repères.
  @visibleForTesting
  static int debugPaintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    debugPaintCount++;
    final double total = samples.totalDistance;
    if (total <= 0 || size.isEmpty) return;
    for (final PdlProfileMarker m in _byPriority(markers)) {
      if (m.distance < 0 || m.distance > total) continue;
      final double x = m.distance / total * size.width;
      final bool selected = m.key == selectedKey;
      final Paint line = Paint()
        ..color = selected ? m.mark.disc : m.mark.disc.withValues(alpha: 0.5)
        ..strokeWidth = selected ? 2 : 1
        ..style = PaintingStyle.stroke;
      for (double y = discY; y < size.height; y += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, (y + 3).clamp(0, size.height)),
          line,
        );
      }
      paintPdlWaypointDisc(
        canvas,
        Offset(x, discY),
        selected ? discSizeSelected : discSize,
        m.mark,
        ring: ring,
        selected: selected,
      );
    }
  }

  @override
  bool shouldRepaint(ElevationMarkersPainter old) =>
      !identical(old.samples, samples) ||
      !listEquals(old.markers, markers) ||
      old.selectedKey != selectedKey ||
      old.ring != ring;

  /// Le repère touché en [local], ou `null`. Ne répond que dans la **bande
  /// haute** (44 px) : ailleurs, le toucher garde le réticule. Au plus 22 px
  /// d'écart ; à égalité, le type le plus important gagne.
  static String? markerAt(
    List<PdlProfileMarker> markers,
    double totalDistance,
    double width,
    Offset local,
  ) {
    if (totalDistance <= 0 || width <= 0) return null;
    if (local.dy < 0 || local.dy > PdlMetrics.tapTarget) return null;
    PdlProfileMarker? best;
    double bestGap = double.infinity;
    for (final PdlProfileMarker m in markers) {
      if (m.distance < 0 || m.distance > totalDistance) continue;
      final double gap = (m.distance / totalDistance * width - local.dx).abs();
      if (gap > hitSlop) continue;
      if (best == null ||
          gap < bestGap ||
          (gap == bestGap && m.priority > best.priority)) {
        best = m;
        bestGap = gap;
      }
    }
    return best?.key;
  }
}
