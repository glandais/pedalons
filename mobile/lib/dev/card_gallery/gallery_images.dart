// Les images de substitution de la galerie de cartes — page de DEBUG.
//
// Les cartes ne prennent que des adresses (`imageUrl`), qu'elles chargent par
// `CachedNetworkImage`. Plutôt que de les modifier ou d'appeler un serveur, la
// galerie dessine ses images en mémoire et les dépose dans le cache d'images
// sous les adresses de `GalleryImageUrls` : la carte les y trouve et ne
// demande rien au réseau.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';

import '../../core/material.dart';

import '../../core/theme/pdl_colors.dart';
import '../../core/theme/pedalons_theme.dart';
import 'gallery_data.dart';

Future<void>? _ready;

/// Dessine et dépose les images une fois par lancement.
Future<void> prepareGalleryImages() => _ready ??= _prepare();

Future<void> _prepare() async {
  final Map<String, Uint8List> drawings = await drawGalleryImages();
  for (final MapEntry<String, Uint8List> e in drawings.entries) {
    await CachedNetworkImageProvider.defaultCacheManager.putFile(
      e.key,
      e.value,
      fileExtension: 'png',
    );
  }
}

/// Les images de substitution en PNG, par adresse ([GalleryImageUrls]).
///
/// Séparé du dépôt dans le cache disque : un test, qui n'a ni système de
/// fichiers ni base du gestionnaire de cache, les décode lui-même et les
/// pose dans le cache d'images en mémoire
/// (`test/dev/card_gallery_capture_test.dart`).
Future<Map<String, Uint8List>> drawGalleryImages() async {
  final PdlColors light = PedalonsTheme.build(Brightness.light)
      .extension<PdlColors>()!;
  final PdlColors dark = PedalonsTheme.build(Brightness.dark)
      .extension<PdlColors>()!;
  return <String, Uint8List>{
    GalleryImageUrls.mapLight: await _map(light),
    GalleryImageUrls.mapDark: await _map(dark),
    GalleryImageUrls.photo: await _photo(light.accentTeal, light.primary),
    GalleryImageUrls.adPhoto: await _photo(
      light.accentOrange,
      light.accentGrape,
    ),
  };
}

const double _w = 800;
const double _h = 450;

/// Une vignette de parcours : un fond de carte, une boucle, départ et arrivée.
Future<Uint8List> _map(PdlColors c) {
  return _render((Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = c.surfaceAlt,
    );
    final Paint road = Paint()
      ..color = c.border
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(0, 60.0 + i * 70),
        Offset(_w, 20.0 + i * 85),
        road,
      );
    }
    final Path loop = Path()
      ..moveTo(180, 330)
      ..cubicTo(120, 180, 300, 70, 430, 120)
      ..cubicTo(560, 170, 690, 120, 650, 260)
      ..cubicTo(610, 380, 330, 400, 180, 330);
    canvas.drawPath(
      loop,
      Paint()
        ..color = c.primary
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(180, 330), 16, Paint()..color = c.success);
  });
}

/// Une « photo » : un dégradé, un relief et un soleil.
Future<Uint8List> _photo(Color top, Color bottom) {
  return _render((Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, _h), <Color>[
          top,
          bottom,
        ]),
    );
    canvas.drawCircle(
      const Offset(620, 120),
      60,
      Paint()..color = top.withValues(alpha: 0.6),
    );
    final Path hills = Path()
      ..moveTo(0, _h)
      ..lineTo(0, 300)
      ..quadraticBezierTo(200, 180, 400, 290)
      ..quadraticBezierTo(600, 380, _w, 260)
      ..lineTo(_w, _h)
      ..close();
    canvas.drawPath(hills, Paint()..color = bottom.withValues(alpha: 0.85));
  });
}

Future<Uint8List> _render(void Function(Canvas canvas) paint) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final ui.Image image = await recorder.endRecording().toImage(
    _w.toInt(),
    _h.toInt(),
  );
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  return bytes!.buffer.asUint8List();
}
