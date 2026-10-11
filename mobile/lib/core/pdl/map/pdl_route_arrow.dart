import 'dart:typed_data';
import 'dart:ui' as ui;

/// Le chevron répété le long d'un tracé pour en montrer le sens — le même que
/// celui du site (`frontend/src/components/map/RouteArrows.tsx`,
/// `routeArrowLayout.ts`).
const String pdlRouteArrowImageId = 'pdl-route-arrow';

/// Le chevron est dessiné à trois fois sa taille affichée, puis réduit par
/// `icon-size` : les deux greffons natifs posent l'image à **un pixel par
/// point logique** (iOS la lit à l'échelle 1, Android la met à la densité de
/// l'écran), et une image dessinée à la taille affichée serait floue sur un
/// écran 3×.
const int _supersample = 3;

/// Taille affichée, en points logiques — celle du site (32 px à `pixelRatio: 2`).
const int _displaySize = 16;

/// Mise en page d'une couche `symbol` qui répète le chevron le long d'une
/// source de lignes. Un placement `line` tourne l'axe x de l'icône dans le
/// sens des coordonnées : le chevron est donc dessiné pointant vers l'est.
///
/// `symbol-spacing` est plus serré que les 90 du site : MapLibre natif mesure
/// l'espacement sur la tuile, que le zoom fractionnaire agrandit, et au cadrage
/// d'une étape de 65 km il ne posait **qu'un** chevron sur la vignette — caché
/// d'office sous une borne kilométrique, qui est un widget posé par-dessus.
const Map<String, Object> pdlRouteArrowLayout = <String, Object>{
  'symbol-placement': 'line',
  'symbol-spacing': 50,
  'icon-image': pdlRouteArrowImageId,
  'icon-size': 1 / _supersample,
  'icon-allow-overlap': true,
  'icon-ignore-placement': true,
  'icon-rotation-alignment': 'map',
};

/// Le chevron en PNG : un trait [fill] sur un liseré [rim], lisible sur toutes
/// les couleurs de tracé et tous les fonds. `null` si l'encodage échoue.
Future<Uint8List?> pdlRouteArrowPng({
  required ui.Color fill,
  required ui.Color rim,
}) async {
  const int size = _displaySize * _supersample;
  // Le tracé du site, sur sa grille de 16 points.
  final double s = _supersample.toDouble();
  final ui.Path chevron = ui.Path()
    ..moveTo(6 * s, 4 * s)
    ..lineTo(10.5 * s, 8 * s)
    ..lineTo(6 * s, 12 * s);
  ui.Paint stroke(ui.Color color, double width) => ui.Paint()
    ..color = color
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeWidth = width * s
    ..isAntiAlias = true;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawPath(chevron, stroke(rim, 3.5))
    ..drawPath(chevron, stroke(fill, 2));
  final ui.Image image = await recorder.endRecording().toImage(size, size);
  try {
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return bytes?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
