import 'package:flutter/material.dart';

import 'elevation_samples.dart';

/// Le painter du **bas** de la pile : l'aire remplie, et rien d'autre.
///
/// C'est tout l'intérêt de la superposition (§1.3.1 du plan) : ce painter ne
/// dépend que des données, son [shouldRepaint] est faux tant que le profil ne
/// change pas, et le réticule qui se repeint à chaque frame de glissement ne
/// l'entraîne pas avec lui.
///
/// **Une aire, pas un histogramme.** Les tranches de [ElevationSamples.bars]
/// restent l'unité de découpe — c'est là que vit la pente moyenne — mais chacune
/// est peinte comme un trapèze dont les deux bords verticaux valent l'altitude
/// **aux bornes** de la tranche, jamais à son centre : les trapèzes voisins
/// partagent donc leur arête et la silhouette est continue. La couleur reste
/// celle de la pente, en aplat translucide sous une ligne opaque.
///
/// La classe est **publique** parce que la garantie « le glissement ne repeint
/// pas l'aire » se vérifie par un compteur d'appels à `paint`, et qu'un
/// compteur sur une classe privée d'un autre fichier ne se lit pas depuis un
/// test.
class ElevationAreaPainter extends CustomPainter {
  ElevationAreaPainter({
    required this.samples,
    required this.neutralColor,
    required this.slopeColorOf,
    this.barColors,
  });

  final ElevationSamples samples;

  /// Couleur d'une tranche dont la pente est inconnue — `slopeNeutral`.
  final Color neutralColor;

  /// Échelle de pente. Injectée plutôt qu'appelée en dur pour que le test de
  /// painter puisse observer la couleur exacte demandée à chaque tranche.
  final Color Function(double gradePercent) slopeColorOf;

  /// Une couleur par tranche de [samples], à la place de l'échelle de pente
  /// (le mode « revêtement » d'une fiche, `MOB-81`). Une entrée nulle prend
  /// [neutralColor]. Comparée par identité, comme [samples] : mémorisez-la.
  final List<Color?>? barColors;

  /// Opacité de l'aplat sous la ligne. La ligne, elle, reste opaque : c'est
  /// elle qui porte la lecture de la pente, le remplissage ne fait que donner
  /// du corps au relief.
  static const double _fillOpacity = 0.45;

  /// Épaisseur de la ligne de crête.
  static const double _strokeWidth = 2;

  /// Nombre d'appels à [paint] depuis le début du processus.
  ///
  /// Instrumentation de test uniquement : c'est la preuve que le glissement
  /// n'entraîne pas l'aire.
  @visibleForTesting
  static int debugPaintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    debugPaintCount++;

    final int n = samples.bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;

    final double span = samples.bars.last.end - samples.bars.first.start;
    final double left = samples.bars.first.start;

    // Abscisse d'une borne de tranche. Un profil dégénéré (toutes les bornes
    // confondues) se répartit régulièrement plutôt que de diviser par zéro.
    double xAt(double distance) =>
        span <= 0 ? 0 : ((distance - left) / span).clamp(0.0, 1.0) * size.width;

    double yAt(double distance) =>
        size.height -
        samples.normalizedElevation(samples.elevationAt(distance)) *
            size.height;

    // Les n + 1 sommets de la silhouette, calculés une fois : chaque arête est
    // partagée par les deux trapèzes qu'elle sépare.
    final List<Offset> vertices = <Offset>[
      for (int i = 0; i < n; i++)
        Offset(xAt(samples.bars[i].start), yAt(samples.bars[i].start)),
      Offset(xAt(samples.bars.last.end), yAt(samples.bars.last.end)),
    ];

    final Paint fill = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < n; i++) {
      final double? grade = samples.bars[i].grade;
      final List<Color?>? override = barColors;
      final Color color = override != null && i < override.length
          ? (override[i] ?? neutralColor)
          : (grade == null ? neutralColor : slopeColorOf(grade));
      final Offset a = vertices[i];
      final Offset b = vertices[i + 1];

      // Un demi-pixel de recouvrement à droite : deux aplats antialiasés
      // jointifs laissent sinon une couture claire entre eux.
      final double overlap = i == n - 1 ? 0 : 0.5;
      final double slope = b.dx == a.dx ? 0 : (b.dy - a.dy) / (b.dx - a.dx);

      fill.color = color.withValues(alpha: color.a * _fillOpacity);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, size.height)
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx + overlap, b.dy + slope * overlap)
          ..lineTo(b.dx + overlap, size.height)
          ..close(),
        fill,
      );

      stroke.color = color;
      canvas.drawLine(a, b, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant ElevationAreaPainter old) =>
      !identical(old.samples, samples) ||
      old.neutralColor != neutralColor ||
      !identical(old.barColors, barColors);
}
