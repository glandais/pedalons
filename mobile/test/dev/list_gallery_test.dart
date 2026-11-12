import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/dev/dev_routes.dart';
import 'package:pedalons/dev/list_gallery/gallery_api.dart';
import 'package:pedalons/dev/list_gallery/list_sections.dart';
import 'package:pedalons/dev/list_gallery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localization.dart';
import 'support/list_gallery_harness.dart';

/// La galerie des listes monte chaque cas du cahier commun
/// (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/galerie.md`,
/// § Cas, par liste), dans l'ordre, sans exception, sans requête que son
/// serveur factice ne connaisse.
///
/// La liste ci-dessous est recopiée du cahier, pas de la galerie : un cas qui
/// disparaîtrait de la galerie ferait échouer le test au lieu de passer
/// inaperçu. Un cas omis l'est dans la galerie (`ListSection.omitted`), avec
/// sa raison, et doit figurer ici.
const Map<String, List<String>> _cahier = <String, List<String>>{
  'accueil': <String>[
    'accueil-repos',
    'accueil-filtre',
    'accueil-criteres',
    'accueil-vide',
    'accueil-vide-filtre',
    'accueil-erreur',
    'accueil-chargement',
  ],
  'publications': <String>[
    'publications-repos',
    'publications-filtre',
    'publications-vide',
    'publications-vide-filtre',
    'publications-erreur',
    'publications-lecture',
  ],
  'agenda': <String>[
    'agenda-repos',
    'agenda-filtre',
    'agenda-criteres',
    'agenda-passees',
    'agenda-vide',
    'agenda-vide-filtre',
    'agenda-erreur',
    'agenda-lecture',
  ],
  'calendrier': <String>[
    'calendrier-repos',
    'calendrier-filtre',
    'calendrier-equipe',
    'calendrier-vide',
    'calendrier-vide-filtre',
    'calendrier-erreur',
    'calendrier-chargement',
  ],
  'parcours': <String>[
    'parcours-repos',
    'parcours-lignes',
    'parcours-carte',
    'parcours-filtre',
    'parcours-criteres',
    'parcours-tri',
    'parcours-vide',
    'parcours-vide-filtre',
    'parcours-erreur',
    'parcours-lecture',
  ],
  'explorer': <String>[
    'explorer-repos',
    'explorer-filtre',
    'explorer-criteres',
    'explorer-vide-filtre',
    'explorer-erreur',
  ],
  'annonces': <String>[
    'annonces-repos',
    'annonces-filtre',
    'annonces-criteres',
    'annonces-tri',
    'annonces-vide',
    'annonces-vide-filtre',
    'annonces-erreur',
  ],
  'equipes': <String>[
    'equipes-repos',
    'equipes-decouvrir',
    'equipes-filtre',
    'equipes-vide',
    'equipes-vide-filtre',
    'equipes-erreur',
  ],
  'membres': <String>[
    'membres-repos',
    'membres-filtre',
    'membres-vide-filtre',
    'membres-erreur',
  ],
  'inscrits': <String>[
    'inscrits-repos',
    'inscrits-filtre',
    'inscrits-vide',
    'inscrits-vide-filtre',
    'inscrits-erreur',
  ],
  'notifications': <String>[
    'notifications-repos',
    'notifications-filtre',
    'notifications-vide',
    'notifications-vide-filtre',
    'notifications-erreur',
  ],
  'modeles': <String>[
    'modeles-repos',
    'modeles-filtre',
    'modeles-vide',
    'modeles-vide-filtre',
    'modeles-erreur',
  ],
};

void main() {
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  test('les sections de la galerie sont celles du cahier, dans son ordre', () {
    expect(
      kListSections.map((ListSection s) => s.id).toList(),
      _cahier.keys.toList(),
    );
    for (final ListSection s in kListSections) {
      final List<String> expected = _cahier[s.id]!;
      expect(
        s.cases.map((ListCase c) => c.id).toList(),
        expected.where((String id) => !s.omitted.containsKey(id)).toList(),
        reason: s.id,
      );
      expect(
        s.omitted.keys.every(expected.contains),
        isTrue,
        reason: 'un cas omis doit être un cas du cahier',
      );
      for (final String reason in s.omitted.values) {
        expect(reason, isNotEmpty);
      }
    }
  });

  for (final MapEntry<String, List<String>> entry in _cahier.entries) {
    final ListSection section = listSection(entry.key)!;
    for (final ListCase item in section.cases) {
      testWidgets('cas « ${item.id} »', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final GalleryApi api = await pumpListCase(
          tester,
          section: section,
          item: item,
          prefs: prefs,
          // Les données se cherchent avant les gestes : une feuille ouverte
          // peut couvrir la liste.
          beforeSteps: (_) {
            if (item.loaded == null) return;
            expect(
              find.textContaining(item.loaded!, skipOffstage: false),
              findsWidgets,
              reason: 'la page montre ses données',
            );
          },
        );

        expect(tester.takeException(), isNull);
        expect(api.unknown, isEmpty, reason: 'requêtes sans réponse');
        expect(api.log, isNotEmpty, reason: 'la page a lu son serveur');
      });
    }
  }

  test('les adresses de la galerie des listes sont des adresses de debug', () {
    expect(kListGalleryPath, '/dev/listes');
    expect(isDevLocation('/dev/listes/parcours/parcours-repos'), isTrue);
  });
}
