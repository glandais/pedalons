import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/dev/card_gallery/gallery_images.dart';
import 'package:pedalons/dev/card_gallery/gallery_sections.dart';
import 'package:pedalons/dev/card_gallery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localization.dart';
import 'support/gallery_fonts.dart';

/// Ledger `MOB-139` — capture de chaque section de la galerie des cartes en
/// PNG, **sans simulateur** : 390 points de large, mode clair, français, toute
/// la hauteur du contenu, ratio de pixels 2.
///
/// Ignoré tant que `CARD_GALLERY_CAPTURE_DIR` n'est pas posée : le test
/// n'écrit jamais dans le dépôt de lui-même.
///
/// ```bash
/// CARD_GALLERY_CAPTURE_DIR=$PWD/../docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/captures/app \
///   flutter test test/dev/card_gallery_capture_test.dart
/// # puis, pour une capture de plus de ~1 Mo (le fil) :
/// magick fil.png -strip -dither None -colors 256 PNG8:fil.png
/// ```
///
/// Le rendu de `flutter test` n'est pas celui d'un appareil : pas de barre
/// d'état ni de zone sûre, rasterisation logicielle, plateforme Android (donc
/// défilement et typographie Material d'Android). Les polices sont les vraies
/// (Inter, Material Icons), chargées ci-dessous ; un glyphe qu'aucune ne
/// porte sort en carré.
final String? _captureDir = Platform.environment['CARD_GALLERY_CAPTURE_DIR'];

const double _width = 390;
const double _pixelRatio = 2;

/// La marge du bas de la section (`_SectionBody` de la galerie).
const double _bottomPadding = 48;

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

  for (final GallerySection section in kGallerySections) {
    testWidgets('capture de la section « ${section.id} »', (
      WidgetTester tester,
    ) async {
      // Les images de substitution, décodées une fois, puis posées dans le
      // cache d'images en mémoire sous la clé que `CachedNetworkImage`
      // calcule (l'adresse) : la carte les y trouve sans cache disque.
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

      // Les ombres sont aplaties par défaut sous `flutter test` ; une capture
      // les veut telles qu'à l'écran.
      debugDisableShadows = false;

      // Un débordement de carte est un constat, pas un échec de la capture :
      // on le relève et on capture quand même.
      final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = errors.add;

      final GlobalKey boundary = GlobalKey();
      tester.view.devicePixelRatio = _pixelRatio;
      tester.view.physicalSize = const Size(_width, 2000) * _pixelRatio;

      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ProviderScope(
              overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: PedalonsTheme.build(Brightness.light),
                home: CardGalleryPage(
                  sectionId: section.id,
                  prepareImages: () async {},
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        // Les images d'assets (logos des compteurs…) se décodent hors de
        // l'horloge factice du test : sans cela elles restent vides.
        await _precacheImages(tester);

        // La hauteur : le haut de la zone qui défile (sous la barre), plus la
        // colonne des cas et la marge du bas, jusqu'à ce qu'elle ne bouge
        // plus (une mise en page peut en changer une autre). Le corps d'un
        // `Scaffold` est contraint sans minimum : la zone qui défile se
        // resserre sur un contenu plus court que l'écran, d'où le haut et non
        // la hauteur de l'écran moins la sienne.
        final Finder scroll = find.byKey(
          ValueKey<String>('gallery-scroll-${section.id}'),
        );
        for (int i = 0; i < 5; i++) {
          final double view = tester.view.physicalSize.height / _pixelRatio;
          final double content =
              tester
                  .getSize(
                    find
                        .descendant(of: scroll, matching: find.byType(Column))
                        .first,
                  )
                  .height +
              _bottomPadding;
          final double height = (tester.getTopLeft(scroll).dy + content)
              .ceilToDouble();
          if (height == view) break;
          tester.view.physicalSize = Size(_width, height) * _pixelRatio;
          await _settle(tester);
        }
        expect(
          tester
              .state<ScrollableState>(
                find
                    .descendant(of: scroll, matching: find.byType(Scrollable))
                    .first,
              )
              .position
              .maxScrollExtent,
          0,
          reason: 'la capture doit montrer toute la section',
        );

        final RenderRepaintBoundary render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final File file = File('${_captureDir!}/${section.id}.png');
        await tester.runAsync(() async {
          final ui.Image image = await render.toImage(pixelRatio: _pixelRatio);
          final ByteData? bytes = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          image.dispose();
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print(
          '${section.id}.png : '
          '${(tester.view.physicalSize.height / _pixelRatio).round()} pt de '
          'haut, ${errors.length} erreur(s) de rendu',
        );
      } finally {
        FlutterError.onError = previous;
        debugDisableShadows = true;
        tester.view.reset();
      }

      for (final FlutterErrorDetails e in errors) {
        // ignore: avoid_print
        print('--- ${section.id} : ${e.exceptionAsString()}\n${e.context}');
        final DiagnosticsNode? info = e.informationCollector
            ?.call()
            .whereType<DiagnosticsNode>()
            .firstOrNull;
        // ignore: avoid_print
        if (info != null) print(info.toStringDeep());
      }
      // Seuls les débordements sont tolérés (constats sur les cartes) ;
      // toute autre erreur rend la capture suspecte.
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
  await _settle(tester);
}

/// Laisse passer les futurs des fournisseurs remplacés et les animations
/// d'entrée ; pas de `pumpAndSettle`, qu'un squelette animé ferait tourner
/// sans fin.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
