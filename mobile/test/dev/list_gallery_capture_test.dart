import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/dev/card_gallery/gallery_images.dart';
import 'package:pedalons/dev/list_gallery/list_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localization.dart';
import 'support/gallery_fonts.dart';
import 'support/list_gallery_harness.dart';

/// Capture de chaque cas de la galerie des listes en PNG, **sans
/// simulateur** : la page entière dans un écran de 390 × 844 points, ratio de
/// pixels 2, mode clair, français, une image par cas, dans
/// `<dossier>/<section>/<cas>.png` (cahier `audit-listes/galerie.md`,
/// § Capture).
///
/// Ignoré tant que `LIST_GALLERY_CAPTURE_DIR` n'est pas posée : le test
/// n'écrit jamais dans le dépôt de lui-même.
///
/// ```bash
/// LIST_GALLERY_CAPTURE_DIR=$PWD/../docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/captures/app \
///   flutter test test/dev/list_gallery_capture_test.dart
/// ```
///
/// Les gestes d'un cas (ouvrir une feuille, taper une recherche) sont joués
/// par de vrais appuis avant la capture. Le rendu est celui de `flutter test`
/// (voir `card_gallery_capture_test.dart`) : pas de barre d'état — la légende
/// du cas en tient la place —, rasterisation logicielle, plateforme Android,
/// vraies polices (Inter, Material Icons). La carte native n'existe pas : la
/// vue Carte des parcours montre sa barre au-dessus d'un fond neutre.
final String? _captureDir = Platform.environment['LIST_GALLERY_CAPTURE_DIR'];

const Size _screen = Size(390, 844);
const double _pixelRatio = 2;

void main() {
  final bool skip = _captureDir == null || _captureDir!.isEmpty;

  late SharedPreferences prefs;
  final Map<String, ui.Image> images = <String, ui.Image>{};

  setUpAll(() async {
    if (skip) return;
    await loadTestTranslations();
    await loadGalleryFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  for (final ListSection section in kListSections) {
    for (final ListCase item in section.cases) {
      testWidgets('capture de « ${item.id} »', (WidgetTester tester) async {
        // Les images de substitution, posées dans le cache d'images en
        // mémoire sous la clé que `CachedNetworkImage` calcule.
        if (images.isEmpty) {
          await tester.runAsync(() async {
            final Map<String, Uint8List> png = await drawGalleryImages();
            for (final MapEntry<String, Uint8List> e in png.entries) {
              final ui.Codec codec = await ui.instantiateImageCodec(e.value);
              images[e.key] = (await codec.getNextFrame()).image;
            }
          });
        }
        for (final MapEntry<String, ui.Image> e in images.entries) {
          imageCache.putIfAbsent(
            CachedNetworkImageProvider(e.key),
            () => OneFrameImageStreamCompleter(
              SynchronousFuture<ImageInfo>(ImageInfo(image: e.value.clone())),
            ),
          );
        }
        debugDisableShadows = false;

        // Un débordement est un constat, pas un échec de la capture.
        final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
        final FlutterExceptionHandler? previous = FlutterError.onError;
        FlutterError.onError = errors.add;

        final GlobalKey boundary = GlobalKey();
        tester.view.devicePixelRatio = _pixelRatio;
        tester.view.physicalSize = _screen * _pixelRatio;

        try {
          await pumpListCase(
            tester,
            section: section,
            item: item,
            prefs: prefs,
            images: true,
            wrap: (Widget app) => RepaintBoundary(key: boundary, child: app),
          );
          await _precacheImages(tester);

          final RenderRepaintBoundary render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final File file = File(
            '${_captureDir!}/${section.id}/${item.id}.png',
          );
          await tester.runAsync(() async {
            final ui.Image image = await render.toImage(
              pixelRatio: _pixelRatio,
            );
            final ByteData? bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
          // ignore: avoid_print
          print('${section.id}/${item.id}.png : ${errors.length} erreur(s)');
        } finally {
          FlutterError.onError = previous;
          debugDisableShadows = true;
          tester.view.reset();
        }

        for (final FlutterErrorDetails e in errors) {
          // ignore: avoid_print
          print('--- ${item.id} : ${e.exceptionAsString()}\n${e.context}');
        }
        expect(
          errors.where(
            (FlutterErrorDetails e) =>
                !e.exceptionAsString().contains('overflowed'),
          ),
          isEmpty,
        );
      }, skip: skip);
    }
  }
}

/// Décode, en vrai temps, toutes les images montées puis repompe.
Future<void> _precacheImages(WidgetTester tester) async {
  final List<Element> elements = find
      .byType(Image, skipOffstage: false)
      .evaluate()
      .toList();
  if (elements.isEmpty) return;
  await tester.runAsync(() async {
    for (final Element e in elements) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await settleList(tester);
}
