import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/ads/data/ad_repository.dart';
import 'package:pedalons/features/ads/data/place_search_repository.dart';
import 'package:pedalons/features/ads/presentation/pages/ad_editor_page.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../routes/route_fixtures.dart';
import 'ad_fixtures.dart';

/// L'éditeur d'annonce (ledger `MOB-158`) : qui y entre, et surtout **ce qui
/// part** — la requête que le serveur recevra, position comprise.
class _StubAds implements AdRepository {
  _StubAds({AdDto? ad, AdEditDto? edit})
    : ad = ad ?? fixtureAd(permissions: kAdOwnerPermissions),
      edit = edit ?? fixtureAdEdit();

  final AdDto ad;
  final AdEditDto edit;
  int editReads = 0;

  /// Si posé, `createAd` / `updateAd` lèvent cette erreur.
  Object? failWith;

  final List<({String team, AdRequest request})> created = [];
  final List<({String slug, AdRequest request})> updated = [];

  @override
  Future<AdDto> getAd(String teamSlug, String adSlug) async => ad;

  @override
  Future<AdEditDto> getAdEdit(String teamSlug, String adSlug) async {
    editReads++;
    return edit;
  }

  @override
  Future<AdDto> createAd(String teamSlug, AdRequest request) async {
    final Object? error = failWith;
    if (error != null) throw error;
    created.add((team: teamSlug, request: request));
    return fixtureAd(slug: 'nouvelle-annonce', name: request.name);
  }

  @override
  Future<AdDto> updateAd(
    String teamSlug,
    String adSlug,
    AdRequest request,
  ) async {
    final Object? error = failWith;
    if (error != null) throw error;
    updated.add((slug: adSlug, request: request));
    return fixtureAd(slug: adSlug, name: request.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Des suggestions sans position, comme le fournisseur les rend : la
/// position ne vient qu'à la résolution.
class _StubPlaces implements PlaceSearchRepository {
  final List<String> searches = <String>[];
  final List<String> resolved = <String>[];
  Object? resolveError;

  @override
  Future<List<GeocodeResultDto>> search(String query) async {
    if (query.trim().length < PlaceSearchRepository.minQueryLength) {
      return const <GeocodeResultDto>[];
    }
    searches.add(query);
    return const <GeocodeResultDto>[
      GeocodeResultDto(id: 'place:1', displayName: 'Gare de Lyon-Perrache'),
    ];
  }

  @override
  Future<GeocodeResultDto> resolve(String id) async {
    resolved.add(id);
    final Object? error = resolveError;
    if (error != null) throw error;
    return const GeocodeResultDto(
      id: 'place:1',
      displayName: 'Lyon',
      lat: 45.7485,
      lon: 4.8262,
    );
  }
}

class _StubTeams implements TeamRepository {
  _StubTeams(this.team);

  final TeamDetailDto team;

  @override
  Future<TeamDetailDto> getTeam(String slug) async => team;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      team.role == null ? <TeamDetailDto>[] : <TeamDetailDto>[team];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  late _StubPlaces places;
  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    places = _StubPlaces();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    required _StubAds ads,
    String? role = 'MEMBER',
    bool enableAds = true,
    String? adSlug,
  }) async {
    // Un écran haut : le formulaire est long, et seul ce qui est construit
    // se trouve.
    tester.view.physicalSize = const Size(1200, 4400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('accueil'),
        ),
        GoRoute(
          path: '/editor',
          builder: (BuildContext _, GoRouterState _) =>
              AdEditorPage(teamSlug: 'n-peloton', adSlug: adSlug),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/annonces/:adSlug',
          builder: (BuildContext _, GoRouterState state) =>
              Text('annonce ${state.pathParameters['adSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          adRepositoryProvider.overrideWithValue(ads),
          placeSearchRepositoryProvider.overrideWithValue(places),
          teamRepositoryProvider.overrideWithValue(
            _StubTeams(
              fixtureRouteTeam(role: role).copyWith(enableAds: enableAds),
            ),
          ),
          teamTagsProvider.overrideWith(
            (Ref ref, ({String teamSlug, TagTarget type}) key) async =>
                <TagWithUsageDto>[],
          ),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/editor');
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.adEditor.saveButton));
    await settle(tester);
  }

  /// Ouvre la recherche d'adresse, cherche, et choisit la seule suggestion.
  Future<void> pickPlace(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.adEditor.positionRow));
    await settle(tester);
    await tester.enterText(
      find.byKey(keys.rideEditor.pickerSearch),
      'Perrache',
    );
    await settle(tester);
    await tester.tap(find.byKey(keys.rideEditor.pickerOption('place:1')));
    await settle(tester);
  }

  group('qui entre', () {
    testWidgets('un simple membre publie : le formulaire, pas un refus', (
      WidgetTester tester,
    ) async {
      await open(tester, ads: _StubAds());

      expect(find.byKey(keys.adEditor.forbidden), findsNothing);
      expect(find.text('Nouvelle annonce'), findsOneWidget);
      expect(find.byKey(keys.adEditor.saveButton), findsOneWidget);
    });

    testWidgets('hors de l\'équipe : un refus', (WidgetTester tester) async {
      await open(tester, ads: _StubAds(), role: null);

      expect(find.byKey(keys.adEditor.forbidden), findsOneWidget);
      expect(
        find.text(
          'Seuls les membres de l\'équipe peuvent publier une annonce.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(keys.adEditor.saveButton), findsNothing);
    });

    testWidgets('module annonces coupé : un autre message', (
      WidgetTester tester,
    ) async {
      await open(tester, ads: _StubAds(), enableAds: false);

      expect(find.byKey(keys.adEditor.forbidden), findsOneWidget);
      expect(
        find.text('Les annonces sont désactivées pour cette équipe.'),
        findsOneWidget,
      );
    });

    testWidgets('l\'annonce d\'une autre personne : refus, et sa position '
        'n\'est pas lue', (WidgetTester tester) async {
      final _StubAds ads = _StubAds(ad: fixtureAd());
      await open(tester, ads: ads, adSlug: 'velo-a-vendre');

      expect(find.byKey(keys.adEditor.forbidden), findsOneWidget);
      expect(ads.editReads, 0);
    });
  });

  group('création', () {
    testWidgets('une vente en brouillon, prix à virgule', (
      WidgetTester tester,
    ) async {
      final _StubAds ads = _StubAds();
      await open(tester, ads: ads);

      expect(find.byKey(keys.adEditor.slugRow), findsNothing);
      expect(find.byKey(keys.adEditor.rentalPeriod), findsNothing);

      await tester.enterText(find.byKey(keys.adEditor.nameField), 'Roues');
      await tester.enterText(find.byKey(keys.adEditor.priceField), '12,5');
      await tester.enterText(find.byKey(keys.adEditor.placeField), 'Lyon 7e');
      await tester.pump();
      await save(tester);

      final ({String team, AdRequest request}) sent = ads.created.single;
      expect(sent.team, 'n-peloton');
      expect(sent.request.name, 'Roues');
      expect(sent.request.adType, 'SALE');
      expect(sent.request.status, 'DRAFT');
      expect(sent.request.price, 12.5);
      expect(sent.request.rentalPeriod, isNull);
      expect(sent.request.locationDescription, 'Lyon 7e');
      expect(sent.request.locationGeometry, isNull);
      // La création laisse place à l'écran de l'annonce.
      expect(find.text('annonce nouvelle-annonce'), findsOneWidget);
    });

    testWidgets('une location demande sa période', (WidgetTester tester) async {
      final _StubAds ads = _StubAds();
      await open(tester, ads: ads);

      await tester.enterText(find.byKey(keys.adEditor.nameField), 'Remorque');
      await tester.tap(find.byKey(keys.adEditor.adTypeOption('RENTAL')));
      await tester.pump();
      expect(find.byKey(keys.adEditor.rentalPeriod), findsOneWidget);

      await save(tester);
      expect(ads.created, isEmpty);
      expect(find.byKey(keys.adEditor.errorBanner), findsOneWidget);
      expect(
        find.text('Choisissez une période : jour, semaine ou mois.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(keys.adEditor.rentalPeriodOption('WEEK')));
      await tester.pump();
      await save(tester);

      final AdRequest request = ads.created.single.request;
      expect(request.adType, 'RENTAL');
      expect(request.rentalPeriod, 'WEEK');
    });

    testWidgets('un prix illisible ne devient pas « à négocier »', (
      WidgetTester tester,
    ) async {
      final _StubAds ads = _StubAds();
      await open(tester, ads: ads);

      await tester.enterText(find.byKey(keys.adEditor.nameField), 'Roues');
      await tester.enterText(find.byKey(keys.adEditor.priceField), '1.2.3');
      await tester.pump();
      expect(find.text('Un montant, par exemple 450 ou 12,50'), findsOneWidget);

      await save(tester);
      expect(ads.created, isEmpty);
    });

    testWidgets('une adresse choisie : sa position est lue une fois, et part '
        'en [longitude, latitude]', (WidgetTester tester) async {
      final _StubAds ads = _StubAds();
      await open(tester, ads: ads);

      await tester.enterText(find.byKey(keys.adEditor.nameField), 'Roues');
      expect(find.text('Aucune position sur la carte'), findsOneWidget);
      await pickPlace(tester);

      expect(places.searches, <String>['Perrache']);
      expect(places.resolved, <String>['place:1']);
      // Le nom que la personne a lu et choisi, pas celui de la résolution.
      expect(find.text('Gare de Lyon-Perrache'), findsOneWidget);

      await save(tester);
      expect(ads.created.single.request.locationGeometry!.coordinates, <double>[
        4.8262,
        45.7485,
      ]);
    });

    testWidgets('la position introuvable se dit, et rien ne change', (
      WidgetTester tester,
    ) async {
      final _StubAds ads = _StubAds();
      places.resolveError = DioException(
        requestOptions: RequestOptions(path: '/api/geocode/place'),
        type: DioExceptionType.badResponse,
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(path: '/api/geocode/place'),
          statusCode: 503,
          data: const <String, Object?>{'code': 'GEOCODING_UNAVAILABLE'},
        ),
      );
      await open(tester, ads: ads);

      await tester.enterText(find.byKey(keys.adEditor.nameField), 'Roues');
      await pickPlace(tester);

      expect(find.byKey(keys.adEditor.errorBanner), findsOneWidget);
      expect(
        find.textContaining('recherche d\'adresse est indisponible'),
        findsOneWidget,
      );
      expect(find.text('Aucune position sur la carte'), findsOneWidget);

      await save(tester);
      expect(ads.created.single.request.locationGeometry, isNull);
    });

    testWidgets('un échec du serveur garde le formulaire', (
      WidgetTester tester,
    ) async {
      final _StubAds ads = _StubAds()
        ..failWith = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, Object?>>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 403,
            data: const <String, Object?>{'code': 'FORBIDDEN'},
          ),
        );
      await open(tester, ads: ads);

      await tester.enterText(find.byKey(keys.adEditor.nameField), 'Roues');
      await save(tester);

      expect(find.byKey(keys.adEditor.errorBanner), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.adEditor.nameField))
            .controller!
            .text,
        'Roues',
      );
    });
  });

  group('modification', () {
    testWidgets('le formulaire reprend l\'annonce ; la position reçue repart '
        'inchangée', (WidgetTester tester) async {
      // Pour qui n'est pas l'auteur, ce point est flouté : le renvoyer tel
      // quel garde le point exact enregistré.
      final _StubAds ads = _StubAds(
        edit: fixtureAdEdit(coordinates: const <double>[4.835, 45.755]),
      );
      await open(tester, ads: ads, adSlug: 'velo-a-vendre');

      expect(find.text('Modifier l\'annonce'), findsOneWidget);
      expect(find.text('Position enregistrée'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.adEditor.priceField))
            .controller!
            .text,
        '1200',
      );
      // Un membre, même auteur, ne change pas l'adresse de l'annonce.
      expect(find.byKey(keys.adEditor.slugRow), findsNothing);

      await tester.enterText(find.byKey(keys.adEditor.nameField), 'Vélo vendu');
      await save(tester);

      final ({String slug, AdRequest request}) sent = ads.updated.single;
      expect(sent.slug, 'velo-a-vendre');
      expect(sent.request.name, 'Vélo vendu');
      expect(sent.request.price, 1200);
      expect(sent.request.status, 'PUBLISHED');
      expect(sent.request.media.markdown, 'Très bon état.');
      expect(sent.request.locationDescription, 'Lyon 7e');
      expect(sent.request.locationGeometry!.coordinates, <double>[
        4.835,
        45.755,
      ]);
      expect(sent.request.tagIds, isEmpty);
      // Revenu à ce qui était dessous.
      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets('retirer la position l\'efface', (WidgetTester tester) async {
      final _StubAds ads = _StubAds(
        edit: fixtureAdEdit(coordinates: const <double>[4.835, 45.755]),
      );
      await open(tester, ads: ads, adSlug: 'velo-a-vendre');

      await tester.tap(
        find.descendant(
          of: find.byKey(keys.adEditor.positionRow),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pump();
      expect(find.text('Aucune position sur la carte'), findsOneWidget);

      await save(tester);
      expect(ads.updated.single.request.locationGeometry, isNull);
    });

    testWidgets('le rôle Administrateur change l\'adresse de l\'annonce', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        ads: _StubAds(),
        role: 'ADMIN',
        adSlug: 'velo-a-vendre',
      );

      expect(find.byKey(keys.adEditor.slugRow), findsOneWidget);
    });
  });
}
