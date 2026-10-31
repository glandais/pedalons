import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'elevation_samples.dart';

/// Une bande fine sous le profil, une couleur par tranche de
/// [ElevationSamples.bars] : le vent relatif en mode Météo (ledger `MOB-106`,
/// le pendant de `windBand.ts` au site).
///
/// Les tranches se placent **comme celles de l'aire** (`ElevationAreaPainter`),
/// sur le même axe des distances : une tranche de la bande est exactement sous
/// la tranche du profil qu'elle décrit. Le painter ne sait pas ce qu'il
/// peint : il reçoit des couleurs, l'écran les a tirées de son domaine.
///
/// Ne dépend que des données, comme l'aire : le réticule qui la traverse est
/// peint à part ([ElevationBandCursorPainter]), et un glissement ne la
/// repeint pas.
class ElevationBandPainter extends CustomPainter {
  ElevationBandPainter({required this.samples, required this.colors});

  final ElevationSamples samples;

  /// Une couleur par tranche de [samples]. Une tranche sans couleur (liste plus
  /// courte) n'est pas peinte. **Comparée par identité** : mémorisez-la.
  final List<Color> colors;

  /// Nombre d'appels à [paint] — la preuve, en test, que le glissement ne
  /// repeint pas la bande.
  @visibleForTesting
  static int debugPaintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    debugPaintCount++;
    final List<ElevationBar> bars = samples.bars;
    final int n = bars.length < colors.length ? bars.length : colors.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;

    final double left = bars.first.start;
    final double span = bars.last.end - left;
    double xAt(double distance) =>
        span <= 0 ? 0 : ((distance - left) / span).clamp(0.0, 1.0) * size.width;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    int i = 0;
    while (i < n) {
      // Les tranches voisines d'une même couleur ne font qu'un rectangle.
      int j = i + 1;
      while (j < n && colors[j] == colors[i]) {
        j++;
      }
      final double from = xAt(bars[i].start);
      final double to = xAt(bars[j - 1].end);
      // Un demi-pixel de chaque côté : deux aplats jointifs ne laissent pas
      // de couture entre eux.
      paint.color = colors[i];
      canvas.drawRect(
        Rect.fromLTRB(from - 0.5, 0, to + 0.5, size.height),
        paint,
      );
      i = j;
    }
  }

  @override
  bool shouldRepaint(covariant ElevationBandPainter old) =>
      !identical(old.samples, samples) || !identical(old.colors, colors);
}

/// Le réticule à travers la bande : à la même abscisse que celui du profil,
/// mais de 2 px comme au site (`windBand.ts`, ledger `WEB-129`), qui se repeint seul quand la distance change.
class ElevationBandCursorPainter extends CustomPainter {
  ElevationBandCursorPainter({
    required this.samples,
    required this.distance,
    required this.lineColor,
    super.repaint,
  });

  final ElevationSamples samples;
  final ValueListenable<double?> distance;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double? d = distance.value;
    if (d == null || samples.isEmpty || size.width <= 0) return;
    final double total = samples.totalDistance;
    final double x =
        (total <= 0 ? 0.0 : (d / total).clamp(0.0, 1.0)) * size.width;
    canvas.drawRect(
      Rect.fromLTWH(x - 1, 0, 2, size.height),
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant ElevationBandCursorPainter old) =>
      !identical(old.samples, samples) || old.lineColor != lineColor;
}
