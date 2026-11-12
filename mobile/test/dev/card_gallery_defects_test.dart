import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/dev/card_gallery/gallery_sections.dart';
import 'package:pedalons/dev/card_gallery_page.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localization.dart';

/// Ledger `MOB-139` — les défauts que les captures de la galerie des cartes
/// ont montrés (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/
/// constat-captures.md`, N1…N20, D26), vérifiés sur les vraies cartes de la
/// galerie : un test par défaut.
void main() {
  setUpAll(() async {
    await loadTestTranslations();
    // Les vraies polices : une largeur ne se juge pas sur la police carrée
    // de `flutter test`.
    final List<dynamic> manifest = json.decode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    for (final dynamic entry in manifest) {
      final Map<String, dynamic> family = entry as Map<String, dynamic>;
      final FontLoader loader = FontLoader(family['family'] as String);
      for (final dynamic font in family['fonts'] as List<dynamic>) {
        loader.addFont(
          rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
        );
      }
      await loader.load();
    }
  });

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  Future<void> pumpSection(
    WidgetTester tester,
    String section, {
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 3000);
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
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  }

  Finder inCase(String id, Finder matching) => find.descendant(
    of: find.byKey(ValueKey<String>('gallery-$id'), skipOffstage: false),
    matching: matching,
    skipOffstage: false,
  );

  List<String> texts(Finder scope) => <String>[
    for (final Element e
        in find
            .descendant(
              of: scope,
              matching: find.byType(RichText),
              skipOffstage: false,
            )
            .evaluate())
      (e.widget as RichText).text.toPlainText(),
  ];

  /// Le texte tient en entier : ni ellipse, ni ligne de trop, ni largeur
  /// rognée.
  void expectWhole(WidgetTester tester, Finder text) {
    final RenderParagraph p = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );
    expect(p.didExceedMaxLines, isFalse);
    final double natural = p.getMaxIntrinsicWidth(double.infinity);
    expect(p.size.width, greaterThanOrEqualTo(natural - 0.5));
  }

  testWidgets('N1 — tout nombre à quatre chiffres a son insécable, '
      'sur toutes les cartes', (WidgetTester tester) async {
    // Un dénivelé, une distance ou un prix sans séparateur : « 1240 m ».
    final RegExp bare = RegExp(r'\d{4}(\u00a0| )?(m|km|ft|mi|€)\b');
    for (final GallerySection section in kGallerySections) {
      await pumpSection(tester, section.id);
      for (final String s in texts(find.byType(CardGalleryPage))) {
        expect(bare.hasMatch(s), isFalse, reason: '${section.id} : « $s »');
      }
    }
  });

  testWidgets('D26 — la carte d’annonce et le tableau de bord écrivent le '
      'même prix', (WidgetTester tester) async {
    const String price = '1\u00a0200,00\u00a0€';
    await pumpSection(tester, 'annonces');
    expect(
      texts(inCase('annonce-vente', find.byType(Column))),
      contains(price),
    );
    await pumpSection(tester, 'tableau');
    expect(
      texts(inCase('annonces-tableau', find.byType(Column))).join('\n'),
      contains(price),
    );
  });

  for (final double width in <double>[390, 320]) {
    testWidgets('N2 — « 11/12 personnes » entier sur la carte sélectionnée, '
        'à $width pt', (WidgetTester tester) async {
      await pumpSection(tester, 'groupes', width: width);
      final Finder count = inCase(
        'groupes-inscrite-b',
        find.byKey(keys.ride.groupCount('g-b')),
      );
      expect(tester.widget<Text>(count).data, '11/12\u00a0personnes');
      expectWhole(tester, count);
      // « Voir tout » reste offert, sur chaque carte dont la grappe affiche
      // « +N » (règle R5) : les trois groupes en ont.
      for (final String g in <String>['g-a', 'g-b', 'g-c']) {
        expect(
          inCase('groupes-inscrite-b', find.byKey(keys.ride.groupViewAll(g))),
          findsOne,
          reason: g,
        );
      }
    });

    testWidgets('N3 — « départ 10:00 » jamais tronqué sur la carte de sortie '
        'à venir, à $width pt', (WidgetTester tester) async {
      await pumpSection(tester, 'tableau', width: width);
      for (final String id in <String>[
        'sortie-a-venir',
        'sortie-a-venir-complet',
      ]) {
        final Finder departures = inCase(
          id,
          find.byWidgetPredicate(
            (Widget w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.contains(
                  'groupFillDeparture_',
                ),
          ),
        );
        expect(departures, findsNWidgets(3), reason: id);
        for (int i = 0; i < 3; i++) {
          expectWhole(tester, departures.at(i));
          expect(
            tester.widget<Text>(departures.at(i)).data,
            matches(RegExp('^ · départ\u00a0\\d\\d:\\d\\d\$')),
          );
        }
      }
    });
  }

  testWidgets('N4 — « Complet » désactivé, pas « S’inscrire », quand tous les '
      'groupes sont pleins', (WidgetTester tester) async {
    await pumpSection(tester, 'tableau');
    final Finder full = inCase(
      'sortie-a-venir-complet',
      find.byKey(keys.teamDashboard.rideFullButton(kRideSlug)),
    );
    expect(full, findsOne);
    expect(tester.widget<PdlButton>(full).enabled, isFalse);
    expect(
      inCase('sortie-a-venir-complet', find.text("S'inscrire")),
      findsNothing,
    );
    // Une sortie qui a encore de la place garde « S'inscrire ».
    expect(inCase('sortie-a-venir', find.text("S'inscrire")), findsOne);
  });

  testWidgets('N6 — badge « Brouillon » sur la ligne en brouillon des 7 '
      'prochains jours', (WidgetTester tester) async {
    await pumpSection(tester, 'accueil');
    expect(
      inCase(
        'semaine',
        find.byKey(keys.home.weekDraftBadge('sortie-decouverte')),
      ),
      findsOne,
    );
    // Les autres lignes n'en ont pas.
    expect(
      inCase(
        'semaine',
        find.byWidgetPredicate(
          (Widget w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.contains('weekDraft_'),
        ),
      ),
      findsOne,
    );
  });

  testWidgets('N7 — « 1 membre sur 1 » en pied de la liste des membres', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'equipes');
    // Le pied unique : « 1 membre sur 1 · Vous avez tout vu » (règle RL12).
    expect(
      inCase('membre', find.text('1 membre sur 1 · Vous avez tout vu')),
      findsOne,
    );
    expect(inCase('membre', find.textContaining('membres sur')), findsNothing);
  });

  testWidgets('N8 — « via le groupe A » au singulier', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'parcours');
    expect(inCase('usages', find.text('via le groupe A')), findsOne);
    expect(
      inCase('usages', find.textContaining('via les groupes')),
      findsNothing,
    );
  });

  testWidgets('N10 — la capitaine n’est pas répétée dans la grappe ; le '
      'compteur la compte toujours', (WidgetTester tester) async {
    await pumpSection(tester, 'groupes');
    final Finder card = find.byKey(
      const ValueKey<String>('gallery-groupe-sans-meteo'),
      skipOffstage: false,
    );
    expect(
      find.descendant(of: card, matching: find.text('Capitaine : Léa Martin')),
      findsOne,
    );
    final PdlAvatarStack stack = tester.widget<PdlAvatarStack>(
      find.descendant(
        of: card,
        matching: find.byKey(keys.ride.groupAvatars('g-a')),
      ),
    );
    expect(
      stack.people.map((PdlAvatarEntry p) => p.name),
      isNot(contains(GalleryData.lea.displayName)),
    );
    final Text count = tester.widget<Text>(
      find.descendant(
        of: card,
        matching: find.byKey(keys.ride.groupCount('g-a')),
      ),
    );
    expect(count.data, startsWith('8/12'));
    expect(stack.total, 7);
  });

  testWidgets('N13 — « Ma prochaine sortie » sans maximum compte son groupe, '
      'pas la sortie', (WidgetTester tester) async {
    await pumpSection(tester, 'accueil');
    final List<String> shown = texts(
      inCase('prochaine-sortie-sans-maximum', find.byType(Column)),
    );
    // « 11 personnes », à côté de la grappe, sans barre (règle R5).
    expect(shown, contains('11\u00a0personnes'));
    expect(shown.where((String s) => s.contains('31')), isEmpty);
    expect(
      inCase(
        'prochaine-sortie-sans-maximum',
        find.byKey(keys.home.nextRideSeatsBar),
      ),
      findsNothing,
    );
  });

  testWidgets('N14 — aucune coupure entre un nombre et son nom', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'tableau');
    final String all = texts(
      inCase('dernieres-publications', find.byType(Column)),
    ).join('\n');
    expect(all, contains('4\u00a0commentaires'));
    expect(all, isNot(contains('4 commentaires')));
  });

  testWidgets('N15 — « Appairé le 13 octobre 2026 », sans jour de la semaine', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'divers');
    final List<String> paired = texts(inCase('appareils', find.byType(Column)))
        .where((String s) => s.startsWith('Appairé le'))
        .toList();
    expect(paired, hasLength(2));
    for (final String s in paired) {
      expect(s, matches(RegExp(r'^Appairé le \d{1,2} [a-zéû]+ \d{4}')));
    }
  });

  testWidgets('N20 — « GPS » sur la carte de mon groupe et sur « Ma prochaine '
      'sortie »', (WidgetTester tester) async {
    await pumpSection(tester, 'groupes');
    expect(
      inCase('groupes-inscrite-b', find.byKey(keys.ride.groupGps('g-b'))),
      findsOne,
    );
    // Jamais sur la carte d'un autre groupe.
    expect(
      inCase('groupes-inscrite-b', find.byKey(keys.ride.groupGps('g-a'))),
      findsNothing,
    );
    await pumpSection(tester, 'accueil');
    expect(
      inCase('prochaine-sortie', find.byKey(keys.home.nextRideGps)),
      findsOne,
    );
  });

  // ── Règles R5, R6, R7 (KIT §9, docs/LEDGER_*.md MOB-139) ──────────────

  testWidgets('R6 — l’échec d’inscription se dit dans la carte du groupe, '
      'plus en tête de section', (WidgetTester tester) async {
    await pumpSection(tester, 'groupes');
    final Finder inCard = find.descendant(
      of: inCase('groupe-erreur', find.byKey(keys.ride.group('g-b'))),
      matching: find.byKey(keys.ride.groupRegistrationFailure('g-b')),
      skipOffstage: false,
    );
    expect(inCard, findsOne);
    expect(
      inCase('groupe-erreur', find.byKey(keys.ride.registrationFailure)),
      findsNothing,
    );
    expect(
      texts(inCard).join(),
      contains('Ce groupe est complet. Choisissez un autre groupe.'),
    );
    // « Complet » désactivé à la place de « Rejoindre ».
    final PdlButton full = tester.widget(
      inCase('groupe-erreur', find.byKey(keys.ride.groupFullButton('g-b'))),
    );
    expect(full.enabled, isFalse);
  });

  testWidgets('R5 — hors de l’équipe : le compte et la barre, jamais de '
      'grappe ni de nom', (WidgetTester tester) async {
    await pumpSection(tester, 'groupes');
    expect(
      inCase('groupe-non-membre', find.byType(PdlAvatarStack)),
      findsNothing,
    );
    expect(
      inCase('groupe-non-membre', find.text('8/12\u00a0personnes')),
      findsOne,
    );
    expect(
      inCase('groupe-non-membre', find.textContaining('Léa')),
      findsNothing,
    );
    expect(
      inCase('groupe-non-membre', find.byKey(keys.ride.groupSeatsBar('g-a'))),
      findsOne,
    );
    expect(inCase('groupe-non-membre', find.text('Voir tout')), findsNothing);
  });

  testWidgets('R5 — la grappe reste sur un groupe plein, la barre est rouge', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'groupes');
    expect(
      inCase('groupes-non-inscrite', find.byKey(keys.ride.groupAvatars('g-c'))),
      findsOne,
    );
    final PdlProgressBar bar = tester.widget(
      inCase(
        'groupes-non-inscrite',
        find.byKey(keys.ride.groupSeatsBar('g-c')),
      ),
    );
    expect(bar.color, PdlColors.light.danger);
  });

  testWidgets('R7 — « GPS » sur l’étape d’un voyage où l’on est inscrite, '
      'pas ailleurs', (WidgetTester tester) async {
    await pumpSection(tester, 'etapes');
    expect(
      inCase('etape-inscrite', find.byKey(keys.trip.stageGps('etape-1'))),
      findsOne,
    );
    expect(
      inCase('etapes', find.byKey(keys.trip.stageGps('etape-1'))),
      findsNothing,
    );
  });

  // ── Règles R1, R2, R4 (KIT §9, docs/LEDGER_*.md MOB-139) ──────────────

  /// Les libellés des badges d'un cas, dans l'ordre de lecture.
  List<String> badges(WidgetTester tester, String id) => <String>[
    for (final PdlBadge b in tester.widgetList<PdlBadge>(
      inCase(id, find.byType(PdlBadge)),
    ))
      b.label,
  ];

  testWidgets('R1 — un seul état, après le type ; « J’y vais » en dernier ; '
      'jamais « Publié »', (WidgetTester tester) async {
    await pumpSection(tester, 'fil');
    expect(badges(tester, 'fil-sortie'), <String>['Sortie']);
    expect(badges(tester, 'fil-sortie-inscrite'), <String>[
      'Sortie',
      "J'y vais",
    ]);
    expect(badges(tester, 'fil-sortie-annulee'), <String>['Sortie', 'Annulé']);
    expect(badges(tester, 'fil-sortie-terminee'), <String>[
      'Sortie',
      'Terminée',
    ]);
    expect(badges(tester, 'fil-sortie-brouillon'), <String>[
      'Sortie',
      'Brouillon',
    ]);
    expect(badges(tester, 'fil-supprime').first, 'Supprimé');
    expect(badges(tester, 'fil-voyage-inscrit-en-cours'), <String>[
      'Voyage',
      'En cours',
      "J'y vais",
    ]);
    for (final GalleryCase c in gallerySection('fil')!.cases) {
      expect(badges(tester, c.id), isNot(contains('Publié')), reason: c.id);
    }
  });

  testWidgets('R1 — un voyage terminé porte « Terminé »', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'fil');
    expect(
      inCase(
        'fil-voyage-termine',
        find.byKey(keys.feed.finishedBadge(kTripSlug)),
      ),
      findsOne,
    );
    expect(badges(tester, 'fil-voyage-termine'), <String>['Voyage', 'Terminé']);
  });

  testWidgets('R1 — la visibilité ne se badge que si elle diffère de celle de '
      'l’équipe', (WidgetTester tester) async {
    await pumpSection(tester, 'fil');
    // « Équipe uniquement » dans l'équipe privée : rien.
    expect(
      inCase('fil-sortie', find.byKey(keys.feed.visibilityBadge(kRideSlug))),
      findsNothing,
    );
    // Lisible par lien dans l'équipe privée : « Public ».
    expect(
      inCase(
        'fil-sortie-lien',
        find.byKey(keys.feed.visibilityBadge('boucle-lien')),
      ),
      findsOne,
    );
    expect(badges(tester, 'fil-sortie-lien'), <String>['Sortie', 'Public']);
    // Public dans une équipe publique : rien.
    expect(
      inCase(
        'fil-voyage-non-membre',
        find.byKey(keys.feed.visibilityBadge(kTripSlug)),
      ),
      findsNothing,
    );
  });

  testWidgets('R1 — « Équipe uniquement » sur la carte d’une équipe privée, '
      'rien sur une équipe publique', (WidgetTester tester) async {
    await pumpSection(tester, 'equipes');
    expect(
      inCase(
        'equipe',
        find.byKey(keys.teams.teamCardVisibility(GalleryData.vcm.slug)),
      ),
      findsOne,
    );
    expect(badges(tester, 'equipe'), <String>['Équipe uniquement', 'Membre']);
    expect(
      inCase(
        'equipe-decouverte',
        find.byKey(keys.teamsDiscover.cardVisibility(GalleryData.gravel.slug)),
      ),
      findsNothing,
    );
    expect(badges(tester, 'equipe-decouverte'), isNot(contains('Public')));
  });

  testWidgets('R1 — un parcours public de l’équipe privée garde « Public »', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'parcours');
    expect(
      inCase('parcours', find.byKey(keys.routes.cardVisibility(kRouteSlug))),
      findsOne,
    );
  });

  testWidgets(
    'R2 — « Météo dès le {date} » avant l’ouverture de la prévision',
    (WidgetTester tester) async {
      await pumpSection(tester, 'fil');
      final Finder line = inCase(
        'fil-sortie-meteo-a-venir',
        find.byKey(keys.ride.weatherSummary),
      );
      expect(line, findsOne);
      // Le premier texte est le glyphe de l'icône.
      expect(_plain(texts(line).last), startsWith('Météo dès le '));
    },
  );

  testWidgets('R4 — voyage : étapes · distance · D+ · personnes ; hors de '
      'l’équipe le compte seul, sans grappe ni nom', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'fil');
    for (final String id in <String>['fil-voyage', 'fil-voyage-non-membre']) {
      final Finder count = inCase(
        id,
        find.byKey(keys.feed.tripParticipantCount(kTripSlug)),
      );
      expect(count, findsOne, reason: id);
      expect(_plain(texts(count).last), '12 personnes', reason: id);
    }
    expect(inCase('fil-voyage', find.byType(PdlAvatarStack)), findsOne);
    expect(
      inCase('fil-voyage-non-membre', find.byType(PdlAvatarStack)),
      findsNothing,
    );
    for (final PublicUserDto p in GalleryData.people) {
      expect(
        inCase('fil-voyage-non-membre', find.textContaining(p.displayName)),
        findsNothing,
      );
    }
    // Aucun commentaire : pas de « 0 commentaire ».
    expect(
      texts(inCase('fil-voyage', find.byType(PdlStatRow))).join(' '),
      isNot(contains('commentaire')),
    );
  });

  testWidgets('R4 — aucun compteur à zéro sur les cartes du fil', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, 'fil');
    for (final GalleryCase c in gallerySection('fil')!.cases) {
      final String all = texts(inCase(c.id, find.byType(PdlCard))).join(' | ');
      expect(all, isNot(contains('Aucun')), reason: c.id);
      expect(all, isNot(matches(RegExp(r'(^|\| )0\u00a0'))), reason: c.id);
    }
  });
}

/// Les espaces insécables (normale, fine) ramenées à l'espace ordinaire.
String _plain(String s) => s.replaceAll(RegExp('[\u00a0\u202f]'), ' ');
