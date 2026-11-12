import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/dev/card_gallery/gallery_sections.dart';
import 'package:pedalons/dev/card_gallery_page.dart';
import 'package:pedalons/dev/dev_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localization.dart';

/// Ledger `MOB-139` — la galerie des cartes rend chaque cas du cahier commun
/// (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/galerie.md`,
/// § Sections et cas), dans l'ordre, sans exception de rendu.
///
/// La liste ci-dessous est recopiée du cahier, pas de la galerie : un cas qui
/// disparaîtrait de la galerie ferait échouer le test au lieu de passer
/// inaperçu.
const Map<String, List<String>> _cahier = <String, List<String>>{
  'fil': <String>[
    'fil-sortie',
    'fil-sortie-inscrite',
    'fil-sortie-demain',
    'fil-sortie-en-cours',
    'fil-sortie-terminee',
    'fil-sortie-annulee',
    'fil-sortie-brouillon',
    'fil-sortie-sans-groupe',
    'fil-sortie-alerte-pluie',
    'fil-sortie-meteo-a-venir',
    'fil-sortie-photo',
    'fil-sortie-lien',
    'fil-voyage',
    'fil-voyage-termine',
    'fil-voyage-non-membre',
    'fil-voyage-inscrit-en-cours',
    'fil-voyage-annule',
    'fil-publication',
    'fil-publication-brouillon',
    'fil-supprime',
  ],
  'accueil': <String>[
    'prochaine-sortie',
    'prochaine-sortie-sans-maximum',
    'prochaine-sortie-vide',
    'semaine',
    'semaine-vide',
    'mes-equipes',
    'mes-equipes-vide',
  ],
  'agenda': <String>[
    'agenda-sortie',
    'agenda-inscrite',
    'agenda-annulee',
    'agenda-etape',
    'agenda-passee',
  ],
  'groupes': <String>[
    'groupes-inscrite-b',
    'groupes-non-inscrite',
    'groupe-erreur',
    'groupe-non-membre',
    'groupe-sans-parcours',
    'groupe-sans-meteo',
  ],
  'etapes': <String>[
    'etapes',
    'etape-inscrite',
    'etape-lieux',
    'etape-sans-parcours',
    'etape-alerte-pluie',
  ],
  'parcours': <String>[
    'parcours',
    'parcours-sans-vignette',
    'parcours-supprime',
    'parcours-ligne',
    'usages',
  ],
  'annonces': <String>[
    'annonce-vente',
    'annonce-location',
    'annonce-recherche',
    'annonce-brouillon',
  ],
  'equipes': <String>[
    'equipe',
    'equipe-admin',
    'equipe-decouverte',
    'equipe-decouverte-membre',
    'equipe-photo',
    'invitations',
    'membre',
    'membre-admin',
    'inscrits',
  ],
  'tableau': <String>[
    'a-traiter',
    'mes-sorties',
    'sortie-a-venir',
    'sortie-a-venir-inscrite',
    'sortie-a-venir-complet',
    'sortie-a-venir-sans-parcours',
    'dernieres-publications',
    'nouveaux-parcours',
    'annonces-tableau',
  ],
  'divers': <String>[
    'notification-non-lue',
    'notification-lue',
    'notification-modification',
    'modele',
    'modele-brouillon',
    'appareils',
    'commentaires',
    'commentaire-markdown',
  ],
};

/// Les cas dont la carte lit un fournisseur remplacé : un texte de leurs
/// données doit apparaître, preuve qu'ils ne sont restés ni en chargement ni en
/// erreur.
const Map<String, String> _loaded = <String, String>{
  'groupes-inscrite-b': 'Changer pour Groupe A',
  'semaine': 'Sortie récupération',
  'mes-equipes': 'Gravel Bretagne',
  'usages': 'Traversée du Morvan',
  'equipe': 'Vélo Club des Monts',
  'invitations': 'Gravel Bretagne',
  'membre': 'Noé Perrin',
  'membre-admin': 'Léa Martin',
  'inscrits': 'Malo Guérin',
  'appareils': 'Karoo',
  'commentaires': 'café avant le départ',
  'commentaire-markdown': '**avant le départ**',
};

void main() {
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  Future<void> pumpGallery(WidgetTester tester, {String? section}) async {
    // La largeur d'un grand iPhone ; la hauteur ne compte pas, la section
    // construit tous ses cas.
    tester.view.physicalSize = const Size(430, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: CardGalleryPage(sectionId: section, images: false),
        ),
      ),
    );
    // Les fournisseurs remplacés répondent tout de suite ; quelques images
    // laissent passer leurs futurs et les animations d'entrée.
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test('les sections de la galerie sont celles du cahier, dans son ordre', () {
    expect(
      kGallerySections.map((GallerySection s) => s.id).toList(),
      _cahier.keys.toList(),
    );
  });

  for (final MapEntry<String, List<String>> entry in _cahier.entries) {
    testWidgets('section « ${entry.key} » : chaque cas du cahier est rendu', (
      WidgetTester tester,
    ) async {
      await pumpGallery(tester, section: entry.key);

      expect(tester.takeException(), isNull);
      final GallerySection section = gallerySection(entry.key)!;
      // Les cas montés, dans l'ordre du cahier, puis les omis, chacun avec
      // sa raison : rien d'autre, rien de moins.
      final List<String> expected = entry.value
          .where((String id) => !section.omitted.containsKey(id))
          .toList();
      expect(section.cases.map((GalleryCase c) => c.id).toList(), expected);
      expect(
        section.omitted.keys.every(entry.value.contains),
        isTrue,
        reason: 'un cas omis doit être un cas du cahier',
      );
      for (final String id in expected) {
        expect(
          find.byKey(ValueKey<String>('gallery-$id'), skipOffstage: false),
          findsOneWidget,
          reason: id,
        );
      }
      for (final String id in section.omitted.keys) {
        expect(
          find.byKey(
            ValueKey<String>('gallery-omitted-$id'),
            skipOffstage: false,
          ),
          findsOneWidget,
          reason: id,
        );
      }
      for (final String id in expected.where(_loaded.containsKey)) {
        expect(
          find.descendant(
            of: find.byKey(
              ValueKey<String>('gallery-$id'),
              skipOffstage: false,
            ),
            matching: find.textContaining(_loaded[id]!, skipOffstage: false),
          ),
          findsWidgets,
          reason: id,
        );
      }
      // Un cas ne monte pas qu'une légende : sa carte a une hauteur.
      for (final String id in expected) {
        final Size size = tester.getSize(
          find.byKey(ValueKey<String>('gallery-$id'), skipOffstage: false),
        );
        expect(size.height, greaterThan(40), reason: id);
      }
    });
  }

  testWidgets('le sommaire liste les dix sections', (
    WidgetTester tester,
  ) async {
    await pumpGallery(tester);

    expect(tester.takeException(), isNull);
    for (final String id in _cahier.keys) {
      expect(
        find.byKey(
          ValueKey<String>('gallery-section-$id'),
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: id,
      );
    }
  });

  test('les adresses de debug ne se confondent pas avec celles de l’app', () {
    expect(isDevLocation('/dev/cartes/fil'), isTrue);
    expect(isDevLocation('/dev/composants'), isTrue);
    expect(isDevLocation('/devices'), isFalse);
    expect(isDevLocation('/equipes/dev'), isFalse);
    expect(kCardGalleryPath, '/dev/cartes');
  });
}
