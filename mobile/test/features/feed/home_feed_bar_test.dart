import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// La barre et les sections du fil d'accueil (règles RL2, RL3 et RL15 des
/// listes, KIT §10).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late List<PublicationFeedKey> requested;
  setUp(() => requested = <PublicationFeedKey>[]);

  Future<void> pumpHome(
    WidgetTester tester, {
    PageResult<PublicationDto>? page,
    int count = 47,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unitSystemProvider.overrideWithValue(UnitSystem.metric),
          publicationFeedProvider.overrideWith((ref, key) {
            requested.add(key);
            return _Feed(key, page);
          }),
          publicationFeedCountProvider.overrideWith((ref, key) async => count),
          myTeamsProvider.overrideWith(
            (ref) async => <TeamDetailDto>[fixtureTeam()],
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: PublicationFeedView(
              teamSlug: null,
              emptyMessage: 'vide',
              showSectionHeader: true,
              showPeriod: true,
              datedSections: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Les squelettes animent sans fin : pas de `pumpAndSettle`.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tearDownFeed(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  PdlChip scopeChip(WidgetTester tester) => tester.widget<PdlChip>(
    find.descendant(
      of: find.byKey(keys.feed.scopeChip),
      matching: find.byType(PdlChip),
    ),
  );

  group('RL2 — la puce « Portée »', () {
    testWidgets('neutre au défaut (« Membre »), teintée hors du défaut', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(scopeChip(tester).label, 'Membre');
      expect(scopeChip(tester).selected, isFalse);
      expect(scopeChip(tester).trailingIcon, PdlIcons.chevronDown);

      await tester.tap(find.byKey(keys.feed.scopeChip));
      await settle(tester);
      // Une feuille à coche, quatre valeurs, sans chevron.
      for (final String value in <String>[
        'Toutes les équipes',
        'Membre',
        'Organisateur',
        'Administrateur',
      ]) {
        expect(find.text(value), findsWidgets);
      }
      expect(find.byIcon(PdlIcons.check), findsOneWidget);
      expect(find.byIcon(PdlIcons.chevronRight), findsNothing);

      await tester.tap(find.text('Toutes les équipes').last);
      await settle(tester);
      expect(requested.last.minRole, isNull);
      expect(scopeChip(tester).label, 'Toutes les équipes');
      expect(scopeChip(tester).selected, isTrue);

      await tearDownFeed(tester);
    });
  });

  group('RL3 et RL15 — la période « Tout / Je participe »', () {
    testWidgets('« Tout » envoie when=UPCOMING_FIRST ; « Je participe » '
        'restreint les deux sections', (WidgetTester tester) async {
      await pumpHome(tester);

      expect(find.byKey(keys.feed.period(AgendaScope.all)), findsOneWidget);
      expect(requested.last.when, PublicationWhen.upcomingFirst);
      expect(requested.last.participating, isFalse);

      await tester.tap(find.byKey(keys.feed.period(AgendaScope.participating)));
      await tester.pump();
      await tester.pump();
      expect(requested.last.when, PublicationWhen.upcomingFirst);
      expect(requested.last.participating, isTrue);

      await tearDownFeed(tester);
    });

    testWidgets('« Sorties » et « Voyages » gardent les sections, '
        '« Publications » seules n\'en ont pas', (WidgetTester tester) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.ride)));
      await tester.pump();
      expect(requested.last.when, PublicationWhen.upcomingFirst);

      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.post)));
      await tester.pump();
      expect(requested.last.when, isNull);

      await tearDownFeed(tester);
    });

    testWidgets('deux en-têtes, chacun avec son compteur, à la place de '
        '« Dernières publications »', (WidgetTester tester) async {
      final GalleryData d = GalleryData(images: false);
      await pumpHome(
        tester,
        page: PageResult<PublicationDto>(
          items: <PublicationDto>[d.feedRide(), d.feedTrip(), d.feedPost()],
          total: 47,
          firstSectionTotal: 12,
        ),
      );
      await tester.pump();

      expect(find.text('Dernières publications'), findsNothing);
      expect(find.text('À venir'), findsOneWidget);
      expect(find.text('12 sorties et voyages'), findsOneWidget);
      // La première page n'a que 3 lignes, toutes de position < 12 : pas
      // d'en-tête « Plus tôt » avant qu'une ligne de la seconde section arrive.
      expect(find.byKey(keys.feed.earlierSection), findsNothing);

      await tearDownFeed(tester);
    });

    testWidgets('sous « Publications », l\'en-tête « Dernières publications » '
        'et son compteur', (WidgetTester tester) async {
      final GalleryData d = GalleryData(images: false);
      await pumpHome(
        tester,
        page: PageResult<PublicationDto>(
          items: <PublicationDto>[d.feedPost()],
          total: 47,
        ),
      );
      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.post)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Dernières publications'), findsOneWidget);
      expect(find.text('47\u00a0publications'), findsOneWidget);
      expect(find.byKey(keys.feed.upcomingSection), findsNothing);

      await tearDownFeed(tester);
    });

    testWidgets('« Je participe » sans résultat est un vide filtré', (
      WidgetTester tester,
    ) async {
      await pumpHome(
        tester,
        page: const PageResult<PublicationDto>(
          items: <PublicationDto>[],
          total: 0,
          firstSectionTotal: 0,
        ),
      );
      await tester.tap(find.byKey(keys.feed.period(AgendaScope.participating)));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(keys.feed.filteredEmptyState), findsOneWidget);
      expect(find.text('Rien ne correspond à : Je participe.'), findsOneWidget);

      await tester.tap(find.byKey(keys.feed.clearFiltersButton));
      await tester.pump();
      await tester.pump();
      expect(requested.last.participating, isFalse);

      await tearDownFeed(tester);
    });
  });

  // RL15, complément du 12 novembre 2026 : « Plus tôt », tout sauf l'à-venir,
  // en une liste simple.
  group('RL15 — « Plus tôt »', () {
    Future<void> tapEarlier(WidgetTester tester) async {
      await tester.tap(find.byKey(keys.feed.period(AgendaScope.earlier)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('trois choix ; « Plus tôt » envoie when=EARLIER, sans '
        'participation', (WidgetTester tester) async {
      await pumpHome(tester);

      expect(find.text('Tout'), findsWidgets);
      expect(find.text('Je participe'), findsOneWidget);
      expect(find.text('Plus tôt'), findsOneWidget);

      await tapEarlier(tester);
      expect(requested.last.when, PublicationWhen.earlier);
      expect(requested.last.participating, isFalse);
      expect(requested.last.datedOnly, isFalse);

      // « Je participe » l'exclut : un seul segmenté.
      await tester.tap(find.byKey(keys.feed.period(AgendaScope.participating)));
      await tester.pump();
      await tester.pump();
      expect(requested.last.when, PublicationWhen.upcomingFirst);
      expect(requested.last.participating, isTrue);

      await tearDownFeed(tester);
    });

    testWidgets('se combine avec le type : « Sorties » reste EARLIER', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await tapEarlier(tester);

      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.ride)));
      await tester.pump();
      expect(requested.last.when, PublicationWhen.earlier);
      expect(requested.last.type, PublicationType.ride);

      await tearDownFeed(tester);
    });

    testWidgets('une liste simple : ni section ni « Dernières publications », '
        'le compteur global sur sa ligne', (WidgetTester tester) async {
      final GalleryData d = GalleryData(images: false);
      await pumpHome(
        tester,
        page: PageResult<PublicationDto>(
          items: <PublicationDto>[d.feedPost(), d.feedRide(finished: true)],
          total: 47,
        ),
      );
      await tapEarlier(tester);
      await tester.pump();

      expect(find.byKey(keys.feed.upcomingSection), findsNothing);
      expect(find.byKey(keys.feed.earlierSection), findsNothing);
      expect(find.text('Dernières publications'), findsNothing);
      expect(find.byKey(keys.feed.resultCount), findsOneWidget);
      // Le même compteur que l'en-tête d'une section.
      expect(find.text('47 publications'), findsOneWidget);

      await tearDownFeed(tester);
    });

    testWidgets('masqué à zéro', (WidgetTester tester) async {
      final GalleryData d = GalleryData(images: false);
      await pumpHome(
        tester,
        count: 0,
        page: PageResult<PublicationDto>(
          items: <PublicationDto>[d.feedPost()],
          total: 1,
        ),
      );
      await tapEarlier(tester);
      await tester.pump();

      expect(find.byKey(keys.feed.resultCount), findsNothing);

      await tearDownFeed(tester);
    });

    testWidgets('compte comme un filtre : le vide filtré le nomme, « Effacer '
        'les filtres » ramène à « Tout »', (WidgetTester tester) async {
      await pumpHome(
        tester,
        page: const PageResult<PublicationDto>(
          items: <PublicationDto>[],
          total: 0,
        ),
      );
      await tapEarlier(tester);
      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.ride)));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(keys.feed.filteredEmptyState), findsOneWidget);
      expect(
        find.text('Rien ne correspond à : Plus tôt · Sorties.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(keys.feed.clearFiltersButton));
      await tester.pump();
      await tester.pump();
      expect(requested.last.when, PublicationWhen.upcomingFirst);
      expect(requested.last.type, isNull);

      await tearDownFeed(tester);
    });
  });
}

/// Rend [page] (une liste vide sans elle reste en chargement).
class _Feed extends PublicationFeedNotifier {
  _Feed(PublicationFeedKey key, this.page)
    : super(PublicationsClient(Dio()), key);

  final PageResult<PublicationDto>? page;

  @override
  Future<PageResult<PublicationDto>> fetchPage(int index) {
    final PageResult<PublicationDto>? p = page;
    if (p == null) return Completer<PageResult<PublicationDto>>().future;
    return Future<PageResult<PublicationDto>>.value(
      index == 0
          ? p
          : PageResult<PublicationDto>(
              items: const <PublicationDto>[],
              total: p.total,
              firstSectionTotal: p.firstSectionTotal,
            ),
    );
  }
}
