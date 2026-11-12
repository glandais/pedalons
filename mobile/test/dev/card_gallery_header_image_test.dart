import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/dev/card_gallery/gallery_images.dart';
import 'package:pedalons/dev/card_gallery/gallery_scope.dart';
import 'package:pedalons/dev/card_gallery_page.dart';
import 'package:pedalons/features/home/presentation/widgets/next_ride_card.dart';
import 'package:pedalons/features/home/providers/next_ride_provider.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localization.dart';

/// Règle R10 des cartes (KIT §9, docs/LEDGER_*.md MOB-139), sur les vraies
/// cartes de la galerie **avec** leurs images : le bandeau est la photo du
/// contenu, sinon la carte du tracé, sinon le dégradé ; la vignette du tracé
/// n'apparaît que sous une photo.
void main() {
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  final Map<String, ui.Image> images = <String, ui.Image>{};

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  /// Les images de substitution, posées dans le cache d'images en mémoire
  /// sous leur adresse, comme la capture le fait : rien ne part sur le réseau.
  Future<void> seedImages(WidgetTester tester) async {
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
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await seedImages(tester);
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: home,
        ),
      ),
    );
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder inCase(String id, Finder matching) => find.descendant(
    of: find.byKey(ValueKey<String>('gallery-$id'), skipOffstage: false),
    matching: matching,
    skipOffstage: false,
  );

  String? banner(WidgetTester tester, String id) => tester
      .widget<PdlCardMedia>(inCase(id, find.byType(PdlCardMedia)).first)
      .imageUrl;

  Finder thumbs(String id) => inCase(id, find.byType(PdlThumb));

  testWidgets('fil : la photo en bandeau garde la vignette du tracé ; la '
      'carte du tracé en bandeau la perd', (WidgetTester tester) async {
    await pump(
      tester,
      CardGalleryPage(sectionId: 'fil', prepareImages: () async {}),
    );
    expect(tester.takeException(), isNull);

    expect(banner(tester, 'fil-sortie-photo'), GalleryImageUrls.photo);
    expect(thumbs('fil-sortie-photo'), findsOne);
    expect(
      tester.widget<PdlThumb>(thumbs('fil-sortie-photo')).imageUrl,
      GalleryImageUrls.mapLight,
    );

    for (final String id in <String>['fil-sortie', 'fil-voyage']) {
      expect(banner(tester, id), GalleryImageUrls.mapLight, reason: id);
      expect(thumbs(id), findsNothing, reason: id);
    }
    // Sans parcours ni photo : le dégradé, et pas de vignette.
    expect(banner(tester, 'fil-sortie-sans-groupe'), isNull);
    expect(thumbs('fil-sortie-sans-groupe'), findsNothing);
  });

  testWidgets(
    'découverte : la photo de l’équipe en bandeau, sinon le dégradé',
    (WidgetTester tester) async {
      await pump(
        tester,
        CardGalleryPage(sectionId: 'equipes', prepareImages: () async {}),
      );
      expect(tester.takeException(), isNull);
      expect(banner(tester, 'equipe-photo'), GalleryImageUrls.photo);
      expect(banner(tester, 'equipe-decouverte'), isNull);
    },
  );

  testWidgets('« Ma prochaine sortie » : la photo en bandeau, le tracé du '
      'groupe en vignette ; sans photo, pas de vignette', (
    WidgetTester tester,
  ) async {
    final GalleryData d = GalleryData();
    final RideDto plain = d.ride(registeredIn: 'B');
    final RideDto withPhoto = plain.copyWith(media: d.photoMedia('sortie'));

    Widget card(RideDto ride) => GalleryScope(
      data: d,
      child: NextRideCard(
        next: NextRide(ride: ride, group: ride.registeredGroup),
      ),
    );

    await pump(
      tester,
      Scaffold(body: SingleChildScrollView(child: card(withPhoto))),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<PdlCardMedia>(find.byType(PdlCardMedia)).imageUrl,
      GalleryImageUrls.photo,
    );
    expect(find.byKey(keys.home.nextRideTrackThumb), findsOne);

    await pump(
      tester,
      Scaffold(body: SingleChildScrollView(child: card(plain))),
    );
    expect(
      tester.widget<PdlCardMedia>(find.byType(PdlCardMedia)).imageUrl,
      GalleryImageUrls.mapLight,
    );
    expect(find.byKey(keys.home.nextRideTrackThumb), findsNothing);
  });
}
