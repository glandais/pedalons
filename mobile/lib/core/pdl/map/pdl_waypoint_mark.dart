import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Un point de parcours, vu de `core/pdl` : **sans DTO ni traduction**. C'est
/// `features/routes` qui convertit un `WaypointDto` en [PdlMapWaypoint] et en
/// [PdlWaypointMark] (ledger `MOB-84`).

/// Ce qu'il faut pour dessiner le pictogramme d'un point : le glyphe, le
/// disque et l'encre posée dessus.
@immutable
class PdlWaypointMark {
  const PdlWaypointMark({
    required this.glyph,
    required this.disc,
    required this.onDisc,
  });

  final IconData glyph;
  final Color disc;
  final Color onDisc;

  @override
  bool operator ==(Object other) =>
      other is PdlWaypointMark &&
      other.glyph == glyph &&
      other.disc == disc &&
      other.onDisc == onDisc;

  @override
  int get hashCode => Object.hash(glyph, disc, onDisc);
}

/// Un point à poser sur la carte.
@immutable
class PdlMapWaypoint {
  const PdlMapWaypoint({
    required this.key,
    required this.lon,
    required this.lat,
    required this.iconId,
    required this.mark,
    required this.priority,
    this.label,
  });

  /// Identité stable : elle sert à la sélection, au halo et au toucher.
  final String key;
  final double lon;
  final double lat;

  /// Identifiant de l'image du pictogramme (un par type, 12 au plus).
  final String iconId;
  final PdlWaypointMark mark;

  /// Le nom, ou `null` / vide : pas d'étiquette.
  final String? label;

  /// Ordre d'empilement et de collision des étiquettes (le danger en dernier).
  final int priority;

  @override
  bool operator ==(Object other) =>
      other is PdlMapWaypoint &&
      other.key == key &&
      other.lon == lon &&
      other.lat == lat &&
      other.iconId == iconId &&
      other.mark == mark &&
      other.label == label &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(key, lon, lat, iconId, mark, label, priority);
}

/// Ce que la caméra fait quand un point est choisi ailleurs que sur la carte.
enum PdlWaypointMove {
  /// Rien : le point est allumé (halo), la caméra reste.
  none,

  /// Recentre seulement si le point est hors de la région visible.
  ifHidden,

  /// Recentre toujours (un toucher dans la liste).
  center,
}

/// Le point allumé. [serial] change à chaque choix, pour qu'un point choisi
/// deux fois recentre deux fois.
@immutable
class PdlWaypointFocus {
  const PdlWaypointFocus({
    required this.key,
    this.move = PdlWaypointMove.none,
    this.serial = 0,
  });

  final String key;
  final PdlWaypointMove move;
  final int serial;

  @override
  bool operator ==(Object other) =>
      other is PdlWaypointFocus &&
      other.key == key &&
      other.move == move &&
      other.serial == serial;

  @override
  int get hashCode => Object.hash(key, move, serial);
}

/// Les noms ne s'affichent qu'à partir de ce zoom (comme au site).
const double kPdlWaypointLabelMinZoom = 12;

String pdlWaypointIconImageId(String iconId) => 'pdl-waypoint:$iconId';
String pdlWaypointLabelImageId(String key) => 'pdl-waypoint-label:$key';

/// Les images sont dessinées à trois fois leur taille affichée, puis réduites
/// par `icon-size` : même procédé que les chevrons de sens (`pdl_route_arrow`).
const int _supersample = 3;

/// Côté de l'image d'un pictogramme, en points.
const double _iconSide = 26;

/// Diamètre du disque (anneau compris), en points.
const double _iconDisc = 24;

const double _labelHeight = 22;
const double _labelPadH = 8;
const int _labelMaxGraphemes = 28;

/// Le nom tel qu'il est écrit sur la carte : tronqué à 28 graphèmes.
String pdlWaypointLabelText(String text) {
  final Characters chars = text.characters;
  if (chars.length <= _labelMaxGraphemes) return text;
  return '${chars.take(_labelMaxGraphemes)}…';
}

/// Dessine le disque d'un point : ombre légère, disque, anneau, glyphe.
///
/// [diameter] est le diamètre **extérieur**, anneau compris.
void paintPdlWaypointDisc(
  Canvas canvas,
  Offset center,
  double diameter,
  PdlWaypointMark mark, {
  required Color ring,
  bool selected = false,
}) {
  final double ringWidth = diameter >= 20 ? 2 : 1.5;
  final double radius = diameter / 2;
  canvas.drawCircle(
    center.translate(0, 1),
    radius,
    Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
  );
  canvas.drawCircle(center, radius, Paint()..color = ring);
  canvas.drawCircle(center, radius - ringWidth, Paint()..color = mark.disc);
  if (selected) {
    canvas.drawCircle(
      center,
      radius + 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = mark.disc,
    );
  }
  final double fontSize = diameter * 0.62;
  final TextPainter glyph = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(mark.glyph.codePoint),
      style: TextStyle(
        fontFamily: mark.glyph.fontFamily,
        package: mark.glyph.fontPackage,
        fontSize: fontSize,
        height: 1,
        color: mark.onDisc,
      ),
    ),
  )..layout();
  glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
  glyph.dispose();
}

Future<Uint8List?> _png(ui.Picture picture, int w, int h) async {
  final ui.Image image = await picture.toImage(w, h);
  try {
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return bytes?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Le pictogramme d'un type en PNG : 26 pt × 3 = 78 px de côté.
Future<Uint8List?> pdlWaypointIconPng(
  PdlWaypointMark mark, {
  required Color ring,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..scale(_supersample.toDouble(), _supersample.toDouble());
  paintPdlWaypointDisc(
    canvas,
    const Offset(_iconSide / 2, _iconSide / 2),
    _iconDisc,
    mark,
    ring: ring,
  );
  const int side = 26 * _supersample;
  return _png(recorder.endRecording(), side, side);
}

/// Le nom d'un point en PNG : une pastille de 22 pt de haut × 3, à coins de
/// 4 pt, tronquée à 28 graphèmes.
Future<Uint8List?> pdlWaypointLabelPng(
  String text, {
  required TextStyle style,
  required Color background,
  required Color foreground,
}) async {
  final TextPainter painter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
    text: TextSpan(
      text: pdlWaypointLabelText(text),
      style: style.copyWith(color: foreground),
    ),
  )..layout();
  final double width = (painter.width + 2 * _labelPadH).ceilToDouble();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..scale(_supersample.toDouble(), _supersample.toDouble());
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, _labelHeight),
      const Radius.circular(4),
    ),
    Paint()..color = background,
  );
  painter.paint(
    canvas,
    Offset(_labelPadH, (_labelHeight - painter.height) / 2),
  );
  painter.dispose();
  return _png(
    recorder.endRecording(),
    (width * _supersample).toInt(),
    (_labelHeight * _supersample).toInt(),
  );
}

/// Mise en page de la couche des pictogrammes. L'image vient de la propriété
/// `icon` de l'entité ; la taille grandit du zoom 8 au zoom 12.
const Map<String, Object> pdlWaypointIconLayout = <String, Object>{
  'icon-image': <Object>['get', 'icon'],
  'icon-size': <Object>[
    'interpolate',
    <Object>['linear'],
    <Object>['zoom'],
    8,
    0.7 / 3,
    12,
    1 / 3,
  ],
  'icon-allow-overlap': true,
  'icon-ignore-placement': false,
  'symbol-sort-key': <Object>['get', 'priority'],
};

/// Mise en page de la couche des noms : à droite du pictogramme, sans
/// recouvrement (la collision donne la priorité au plus important).
const Map<String, Object> pdlWaypointLabelLayout = <String, Object>{
  'icon-image': <Object>['get', 'label'],
  'icon-size': 1 / 3,
  'icon-anchor': 'left',
  // En pixels d'image : 45 × 1/3 = 15 pt, le rayon du pictogramme plus 2 pt.
  'icon-offset': <Object>[45, 0],
  'icon-allow-overlap': false,
  'symbol-sort-key': <Object>[
    '-',
    0,
    <Object>['get', 'priority'],
  ],
};
