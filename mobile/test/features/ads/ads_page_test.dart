import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/ads/data/ad_repository.dart';
import 'package:pedalons/features/ads/domain/ad_filters.dart';
import 'package:pedalons/features/ads/presentation/pages/ads_page.dart';
import 'package:pedalons/features/ads/presentation/widgets/ad_card.dart';
import 'package:pedalons/features/ads/providers/ad_list_provider.dart';

import '../../support/localization.dart';
import 'ad_fixtures.dart';
import '../../support/content_permissions.dart';

/// S32-2 — la rubrique Annonces montée en entier.
///
/// Ce qui se vérifie ici est ce que la v1 ne disait pas : **combien d'annonces
/// la liste cache**. Le pied « 20 sur 57 » est le seul endroit qui le porte, et
/// il n'existe aucun endpoint `count` pour le produire.
class _StubAdRepository implements AdRepository {
  _StubAdRepository({this.total = 57, this.emptyWhenFiltered = false});

  final int total;

  /// Rend zéro résultat dès qu'un filtre est posé — le cul-de-sac.
  final bool emptyWhenFiltered;

  @override
  Future<PageResult<AdDto>> fetchAds({
    required AdFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
    ListViewMode? view,
  }) async {
    if (emptyWhenFiltered && filters.isFiltered) {
      return const PageResult<AdDto>(items: <AdDto>[], total: 0);
    }
    final int offset = page * size;
    final int remaining = (total - offset).clamp(0, size);
    return PageResult<AdDto>(
      items: fixtureAds(remaining, from: offset),
      total: total,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const TeamDetailDto _team = TeamDetailDto(
  allowedContentVisibilities: kAllContentVisibilities,
  defaultContentVisibility: 'PUBLIC',
  publicContentAllowed: false,
  timezone: 'Europe/Paris',
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  about: kEmptyMedia,
  visibility: 'PUBLIC',
  enableTrips: true,
  enableAds: true,
  enablePosts: true,
  enableRides: true,
  enableRoutes: true,
  visibilityEditable: true,
  joinable: true,
  addMemberAllowed: true,
  enableMemberDirectory: false,
  postsAsTeamByDefault: true,
  enableRoutePlanner: false,
  memberCount: 40,
  upcomingRideCount: 3,
  routeCount: 12,
  upcomingTripCount: 0,
  recentPostCount: 0,
  createdAt: '2024-01-01T00:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> openAds(
    WidgetTester tester, {
    required _StubAdRepository repository,
    AdFilters? filters,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adRepositoryProvider.overrideWithValue(repository),
          if (filters != null)
            adFiltersProvider(_team.slug).overrideWith((ref) => filters),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: Scaffold(
            body: AdsPage(teamSlug: _team.slug, team: _team),
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('le compteur dit le total, pas la page chargée', (
    WidgetTester tester,
  ) async {
    await openAds(tester, repository: _StubAdRepository());

    // La page 0 rend 20 annonces ; l'en-tête en annonce 57. C'est exactement
    // ce que la v1 taisait.
    expect(find.text('57 annonces'), findsOneWidget);
    expect(find.byType(AdCard), findsWidgets);
  });

  testWidgets('le pied compte les annonces chargées sur le total', (
    WidgetTester tester,
  ) async {
    // Un écran assez haut pour que le pied de liste soit construit : un sliver
    // hors du viewport ne l'est pas, et le pied vit après vingt cartes.
    tester.view.physicalSize = const Size(1200, 24000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openAds(tester, repository: _StubAdRepository());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('sur 57'), findsWidgets);
  });

  testWidgets('la barre d\'outils porte le tri en premier, puis les types', (
    WidgetTester tester,
  ) async {
    await openAds(tester, repository: _StubAdRepository());

    expect(find.text('Plus récentes d\'abord'), findsOneWidget);
    for (final String label in <String>[
      'Tous',
      'Vente',
      'Location',
      'Recherche',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('un vide filtré est un cul-de-sac, sans filtre suggéré', (
    WidgetTester tester,
  ) async {
    await openAds(
      tester,
      repository: _StubAdRepository(emptyWhenFiltered: true),
      filters: const AdFilters(teamSlug: 'n-peloton', search: 'gravel'),
    );

    expect(find.textContaining('gravel'), findsWidgets);
    expect(find.text('Tout réinitialiser'), findsOneWidget);
    // La suggestion « Retirer le filtre X » exigerait un compte par filtre
    // levé, que l'API des annonces ne sait pas rendre : elle est absente.
    expect(find.textContaining('Retirer le filtre'), findsNothing);
  });

  testWidgets('un vide absolu explique la rubrique au lieu de la nier', (
    WidgetTester tester,
  ) async {
    await openAds(tester, repository: _StubAdRepository(total: 0));

    expect(find.text('Aucune annonce'), findsOneWidget);
    expect(find.text('Tout réinitialiser'), findsNothing);
  });

  testWidgets('le mode sombre rend le même écran', (WidgetTester tester) async {
    await openAds(
      tester,
      repository: _StubAdRepository(),
      brightness: Brightness.dark,
    );

    expect(find.byType(AdCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
