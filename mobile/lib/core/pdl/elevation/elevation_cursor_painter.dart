import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'elevation_samples.dart';

/// Le painter du **haut** de la pile : le réticule et son info-bulle.
///
/// Il reçoit `repaint: ValueListenable<double?>` — la distance survolée — et se
/// repeint seul quand elle change. Le `CustomPaint` du dessous n'est pas
/// invalidé : c'est la raison d'être des deux couches.
///
/// Publique pour la même raison que `ElevationAreaPainter` : les bornes de
/// l'info-bulle se vérifient en appelant `paint` sur un canvas d'essai.
class ElevationCursorPainter extends CustomPainter {
  ElevationCursorPainter({
    required this.samples,
    required this.distance,
    required this.lineColor,
    required this.tipBackground,
    required this.tipBorder,
    required this.tipTextStyle,
    required this.label,
    required this.textScaler,
    super.repaint,
  });

  final ElevationSamples samples;

  /// Distance survolée, en mètres. `null` = pas de réticule.
  ///
  /// Redondante avec le `ValueListenable` passé en `repaint` : celui-ci
  /// déclenche la peinture, celle-ci est lue **pendant** la peinture. Le widget
  /// passe la même source aux deux.
  final ValueListenable<double?> distance;

  final Color lineColor;
  final Color tipBackground;
  final Color tipBorder;
  final TextStyle tipTextStyle;

  /// Libellé de l'info-bulle. `core/pdl` ne formate ni ne traduit rien : c'est
  /// l'écran qui rend « 28,7 km · 74 m · 4,1 % » dans l'unité choisie.
  final String Function(ElevationReading) label;

  final TextScaler textScaler;

  /// Marge haute de l'info-bulle — `.elev-tip { top: 6px }`.
  static const double tipTop = 6;
  static const double _tipPadH = 6;
  static const double _tipPadV = 2;
  static const double _tipRadius = 4;

  /// Écart minimal entre l'info-bulle et le bord de la boîte.
  static const double tipEdgeInset = 2;

  TextPainter? _cachedText;
  String? _cachedLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final double? d = distance.value;
    if (d == null || samples.isEmpty || size.width <= 0) return;

    final double total = samples.totalDistance;
    final double t = total <= 0 ? 0.0 : (d / total).clamp(0.0, 1.0);
    final double x = t * size.width;

    // Le trait fait 1 px logique et va de haut en bas (`.elev-cur`).
    canvas.drawRect(
      Rect.fromLTWH(x - 0.5, 0, 1, size.height),
      Paint()..color = lineColor,
    );

    final ElevationReading? reading = samples.readingAt(d);
    if (reading == null) return;

    final String text = label(reading);
    final TextPainter painter = _paintedLabel(text);

    final double tipWidth = painter.width + _tipPadH * 2;
    final double tipHeight = painter.height + _tipPadV * 2;

    // `transform: translateX(-50%)`, puis **bornage aux bords** : une bulle
    // centrée sur un réticule à 0 % ou à 100 % sortirait de la boîte.
    final double maxLeft = size.width - tipWidth - tipEdgeInset;
    final double left = maxLeft <= tipEdgeInset
        ? (size.width - tipWidth) / 2
        : (x - tipWidth / 2).clamp(tipEdgeInset, maxLeft);

    final RRect box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, tipTop, tipWidth, tipHeight),
      const Radius.circular(_tipRadius),
    );
    canvas
      ..drawRRect(box, Paint()..color = tipBackground)
      ..drawRRect(
        box,
        Paint()
          ..color = tipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    painter.paint(canvas, Offset(left + _tipPadH, tipTop + _tipPadV));
  }

  /// Le `TextPainter` est mis en cache **par libellé** : à 60 fps, remesurer
  /// une chaîne inchangée est du travail pur.
  TextPainter _paintedLabel(String text) {
    if (_cachedLabel == text && _cachedText != null) return _cachedText!;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: tipTextStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    _cachedLabel = text;
    _cachedText = painter;
    return painter;
  }

  @override
  bool shouldRepaint(covariant ElevationCursorPainter old) =>
      !identical(old.samples, samples) ||
      old.lineColor != lineColor ||
      old.tipBackground != tipBackground ||
      old.tipBorder != tipBorder ||
      old.tipTextStyle != tipTextStyle ||
      old.textScaler != textScaler ||
      // Le libellé change sans que le réticule bouge (passage en Météo,
      // nouveau leg) : la bulle d'un réticule posé doit suivre.
      old.label != label;
}
