import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/link_launcher.dart';
import 'package:pedalons/features/geocoding/data/place_search_repository.dart';
import 'package:pedalons/features/places/data/places_repository.dart';
import 'package:pedalons/features/places/domain/place_filters.dart';
import 'package:pedalons/features/places/presentation/pages/team_places_page.dart';
import 'package:pedalons/features/rides/data/ride_editor_repository.dart';
import 'package:pedalons/features/rides/providers/ride_editor_providers.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// « Lieux » (ledger `MOB-168`) : qui y entre — et qu'aucune requête de lieux
/// ne part pour les autres —, la liste, sa recherche et sa pagination, le
/// formulaire (validation, requêtes exactes de création et de modification,
/// erreur du serveur), la suppression, et ce qui est relu après une écriture.
class _Teams implements TeamRepository {
  _Teams({this.role, this.refusedWith, this.gate});

  final String? role;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  final int? refusedWith;

  /// Si posé, `getTeam` attend qu'il soit complété.
  final Completer<void>? gate;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    await gate?.future;
    final int? status = refusedWith;
    if (status != null) throw _apiError(status, 'NOT_FOUND');
    return fixtureTeam(slug: slug, role: role);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Places implements PlacesRepository {
  _Places([List<PlaceDetailDto>? places])
    : places = places ?? <PlaceDetailDto>[_gare, _forclaz];

  List<PlaceDetailDto> places;
  Object? writeError;
  Object? deleteError;

  /// Si posé, `delete` attend qu'il soit complété.
  Completer<void>? deleteGate;

  final List<({String slug, String? search, int page, int size})> listCalls =
      <({String slug, String? search, int page, int size})>[];
  final List<({String slug, PlaceRequest request})> created =
      <({String slug, PlaceRequest request})>[];
  final List<({String slug, String id, PlaceRequest request})> updated =
      <({String slug, String id, PlaceRequest request})>[];
  final List<({String slug, String id})> deleted =
      <({String slug, String id})>[];

  @override
  Future<PageResult<PlaceDetailDto>> fetchPlaces({
    required PlaceFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    listCalls.add((
      slug: filters.teamSlug,
      search: filters.search,
      page: page,
      size: size,
    ));
    final String? search = filters.search?.toLowerCase();
    final List<PlaceDetailDto> found = <PlaceDetailDto>[
      for (final PlaceDetailDto p in places)
        if (search == null ||
            p.name.toLowerCase().contains(search) ||
            (p.address ?? '').toLowerCase().contains(search))
          p,
    ];
    return PageResult<PlaceDetailDto>(
      items: found.skip(page * size).take(size).toList(),
      total: found.length,
    );
  }

  PlaceDetailDto _saved(String id, PlaceRequest request) => PlaceDetailDto(
    id: id,
    name: request.name,
    address: request.address,
    link: request.link,
    startPlace: request.startPlace,
    endPlace: request.endPlace,
    geometry: request.geometry == null
        ? null
        : GeoJsonPoint(
            type: GeoJsonPointTypeType.point,
            coordinates: request.geometry!.coordinates,
          ),
  );

  @override
  Future<PlaceDetailDto> create(String teamSlug, PlaceRequest request) async {
    final Object? error = writeError;
    if (error != null) throw error;
    created.add((slug: teamSlug, request: request));
    final PlaceDetailDto place = _saved('new', request);
    places = <PlaceDetailDto>[...places, place];
    return place;
  }

  @override
  Future<PlaceDetailDto> update(
    String teamSlug,
    String placeId,
    PlaceRequest request,
  ) async {
    final Object? error = writeError;
    if (error != null) throw error;
    updated.add((slug: teamSlug, id: placeId, request: request));
    final PlaceDetailDto place = _saved(placeId, request);
    places = <PlaceDetailDto>[
      for (final PlaceDetailDto p in places) p.id == placeId ? place : p,
    ];
    return place;
  }

  @override
  Future<void> delete(String teamSlug, String placeId) async {
    await deleteGate?.future;
    final Object? error = deleteError;
    if (error != null) throw error;
    deleted.add((slug: teamSlug, id: placeId));
    places = <PlaceDetailDto>[
      for (final PlaceDetailDto p in places)
        if (p.id != placeId) p,
    ];
  }
}

class _Geocoder implements PlaceSearchRepository {
  final List<String> resolved = <String>[];

  /// Si posé, `resolve` attend qu'il soit complété.
  Completer<void>? resolveGate;

  @override
  Future<List<GeocodeResultDto>> search(String query) async {
    if (query.trim().length < PlaceSearchRepository.minQueryLength) {
      return const <GeocodeResultDto>[];
    }
    return const <GeocodeResultDto>[
      GeocodeResultDto(id: 'place:1', displayName: 'Annecy, Haute-Savoie'),
    ];
  }

  @override
  Future<GeocodeResultDto> resolve(String id) async {
    resolved.add(id);
    await resolveGate?.future;
    return const GeocodeResultDto(
      id: 'place:1',
      displayName: 'Annecy',
      lat: 45.8992,
      lon: 6.1294,
    );
  }
}

/// Le dépôt des éditeurs de sortie et de voyage : ce que leur lecture d'un
/// lieu demande au serveur.
class _Editors implements RideEditorRepository {
  final List<String> placeReads = <String>[];

  @override
  Future<PlaceDetailDto> getPlace(String teamSlug, String placeId) async {
    placeReads.add(placeId);
    return _gare;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const PlaceDetailDto _gare = PlaceDetailDto(
  id: 'p1',
  name: 'Parking de la gare',
  address: '1 place de la Gare, Annecy',
  link: 'https://maps.example.org/gare',
  startPlace: true,
  endPlace: false,
  geometry: GeoJsonPoint(
    type: GeoJsonPointTypeType.point,
    coordinates: <double>[6.12, 45.9],
  ),
);

const PlaceDetailDto _forclaz = PlaceDetailDto(
  id: 'p2',
  name: 'Col de la Forclaz',
  startPlace: false,
  endPlace: true,
);

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton/places'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton/places'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));
  tearDown(() => debugLinkOpener = null);

  final k = keys.teamPlaces;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  late _Geocoder geocoder;
  late _Editors editors;
  setUp(() {
    geocoder = _Geocoder();
    editors = _Editors();
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    required _Teams teams,
    _Places? places,
    bool platformAdmin = false,
  }) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('hub'),
        ),
        GoRoute(
          path: '/lieux',
          builder: (BuildContext _, GoRouterState _) =>
              const TeamPlacesPage(teamSlug: 'n-peloton'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams),
          placesRepositoryProvider.overrideWithValue(places ?? _Places()),
          placeSearchRepositoryProvider.overrideWithValue(geocoder),
          rideEditorRepositoryProvider.overrideWithValue(editors),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/lieux');
    await settle(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(TeamPlacesPage)),
      listen: false,
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(k.formSubmit));
    await settle(tester);
  }

  Future<void> pickLocation(WidgetTester tester) async {
    await tester.tap(find.byKey(k.formLocation));
    await settle(tester);
    await tester.enterText(find.byKey(keys.rideEditor.pickerSearch), 'Annecy');
    await settle(tester);
    await tester.tap(find.byKey(keys.rideEditor.pickerOption('place:1')));
    await settle(tester);
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<PdlButton>(find.byKey(key)).enabled;

  bool actionEnabled(WidgetTester tester, Key key) =>
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed !=
      null;

  group('accès', () {
    for (final String? role in <String?>['MEMBER', null]) {
      testWidgets('rôle $role : un refus, et aucune requête de lieux', (
        WidgetTester tester,
      ) async {
        final _Places places = _Places();
        await open(
          tester,
          teams: _Teams(role: role),
          places: places,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.text('Réservé au rôle Organisateur'), findsOneWidget);
        expect(places.listCalls, isEmpty);
        expect(find.byKey(k.searchField), findsNothing);
        expect(find.byKey(k.addButton), findsNothing);
        expect(find.text('Parking de la gare'), findsNothing);

        await tester.tap(find.byKey(k.forbiddenBack));
        await settle(tester);
        expect(find.text('hub'), findsOneWidget);
      });
    }

    for (final int status in <int>[403, 404]) {
      testWidgets('une équipe que le serveur refuse ($status) : le refus, '
          'aucune requête de lieux', (WidgetTester tester) async {
        final _Places places = _Places();
        await open(
          tester,
          teams: _Teams(refusedWith: status),
          places: places,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.byKey(k.loadError), findsNothing);
        expect(places.listCalls, isEmpty);
      });
    }

    testWidgets('tant que la fiche charge : ni liste, ni refus, ni requête', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER', gate: gate),
        places: places,
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(places.listCalls, isEmpty);

      gate.complete();
      await settle(tester);
      expect(places.listCalls, hasLength(1));
    });

    for (final String role in <String>['ORGANIZER', 'ADMIN']) {
      testWidgets('rôle $role : la liste, lue une fois, par pages de 20', (
        WidgetTester tester,
      ) async {
        final _Places places = _Places();
        await open(
          tester,
          teams: _Teams(role: role),
          places: places,
        );

        expect(find.byKey(k.forbidden), findsNothing);
        expect(
          places.listCalls,
          <({String slug, String? search, int page, int size})>[
            (slug: 'n-peloton', search: null, page: 0, size: 20),
          ],
        );
        expect(find.byKey(k.row('p1')), findsOneWidget);
        expect(find.byKey(k.row('p2')), findsOneWidget);
        expect(find.byKey(k.addButton), findsOneWidget);
      });
    }

    testWidgets('admin de plateforme non membre : la liste', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places();
      await open(tester, teams: _Teams(), places: places, platformAdmin: true);

      expect(find.byKey(k.forbidden), findsNothing);
      expect(find.byKey(k.row('p1')), findsOneWidget);
      expect(places.listCalls, hasLength(1));
    });
  });

  group('liste', () {
    testWidgets('une ligne : nom, adresse, badges d\'usage, et le lien qui '
        'quitte l\'app', (WidgetTester tester) async {
      final List<Uri> launched = <Uri>[];
      debugLinkOpener = (Uri url) async {
        launched.add(url);
        return true;
      };
      await open(tester, teams: _Teams(role: 'ORGANIZER'));

      expect(find.text('2 lieux'), findsOneWidget);
      expect(find.text('Parking de la gare'), findsOneWidget);
      expect(find.text('1 place de la Gare, Annecy'), findsOneWidget);
      // Départ seulement pour la gare, arrivée seulement pour le col.
      expect(
        tester.widget<PdlBadge>(find.byKey(k.rowStart('p1'))).label,
        'Départ',
      );
      expect(find.byKey(k.rowEnd('p1')), findsNothing);
      expect(find.byKey(k.rowStart('p2')), findsNothing);
      expect(
        tester.widget<PdlBadge>(find.byKey(k.rowEnd('p2'))).label,
        'Arrivée',
      );

      // Pas de lien : pas de « Voir sur la carte ».
      expect(find.byKey(k.rowLink('p2')), findsNothing);
      expect(find.text('Voir sur la carte'), findsOneWidget);
      await tester.tap(find.byKey(k.rowLink('p1')));
      await settle(tester);
      expect(launched.single.toString(), 'https://maps.example.org/gare');
    });

    testWidgets('aucun lieu : l\'état vide du site', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: _Places(<PlaceDetailDto>[]),
      );

      expect(find.byKey(k.empty), findsOneWidget);
      expect(find.text('Aucun lieu défini'), findsOneWidget);
      expect(
        find.text('Ajoutez des lieux pour les départs/arrivées de sorties.'),
        findsOneWidget,
      );
      expect(find.byKey(k.resultCount), findsNothing);
    });

    testWidgets('la recherche part au serveur, par nom ou adresse', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.enterText(find.byKey(k.searchField), 'annecy');
      await settle(tester);

      expect(places.listCalls.last, (
        slug: 'n-peloton',
        search: 'annecy',
        page: 0,
        size: 20,
      ));
      expect(find.byKey(k.row('p1')), findsOneWidget);
      expect(find.byKey(k.row('p2')), findsNothing);
    });

    testWidgets('une recherche sans résultat : « Aucun lieu trouvé », et '
        'l\'effacer rend la liste', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ORGANIZER'));

      await tester.enterText(find.byKey(k.searchField), 'zzz');
      await settle(tester);

      expect(find.byKey(k.searchEmpty), findsOneWidget);
      expect(find.text('Aucun lieu trouvé'), findsOneWidget);
      expect(find.byKey(k.empty), findsNothing);

      await tester.tap(find.text('Effacer les filtres'));
      await settle(tester);
      expect(find.byKey(k.row('p1')), findsOneWidget);
    });

    testWidgets('au-delà de 20 lieux, la page suivante est demandée', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places(<PlaceDetailDto>[
        for (int i = 0; i < 45; i++)
          PlaceDetailDto(
            id: 'p$i',
            name: 'Lieu $i',
            startPlace: true,
            endPlace: true,
          ),
      ]);
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      expect(find.text('45 lieux'), findsOneWidget);
      expect(places.listCalls.first.page, 0);

      await tester.scrollUntilVisible(
        find.byKey(k.row('p25')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);

      expect(
        places.listCalls.map((c) => (c.page, c.size)),
        containsAllInOrder(<(int, int)>[(0, 20), (1, 20)]),
      );
      expect(find.byKey(k.row('p25')), findsOneWidget);
    });
  });

  group('formulaire', () {
    testWidgets('un nom vide n\'envoie rien, et l\'erreur se lit sur le '
        'champ', (WidgetTester tester) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      expect(find.text('Ajouter un lieu'), findsWidgets);
      // Pas d'erreur avant une tentative.
      expect(find.text('Entre 1 et 200 caractères'), findsNothing);

      await submit(tester);

      expect(places.created, isEmpty);
      expect(find.byKey(k.formSheet), findsOneWidget);
      expect(find.text('Entre 1 et 200 caractères'), findsOneWidget);
      expect(find.byKey(k.formErrorBanner), findsOneWidget);
    });

    testWidgets('une adresse ou un lien de moins de 3 caractères n\'envoie '
        'rien', (WidgetTester tester) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      await tester.enterText(find.byKey(k.formName), 'Mairie');
      await tester.enterText(find.byKey(k.formAddress), 'ab');
      await tester.enterText(find.byKey(k.formLink), 'x');
      await submit(tester);

      expect(places.created, isEmpty);
      expect(
        find.text('Entre 3 et 200 caractères, ou laissez vide'),
        findsNWidgets(2),
      );
    });

    testWidgets('création : la requête exacte, adresse et lien vides '
        'absents, les deux usages vrais par défaut', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );
      final int listsBefore = places.listCalls.length;

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      expect(
        tester.widget<PdlSwitch>(find.byKey(k.formStartSwitch)).value,
        isTrue,
      );
      expect(
        tester.widget<PdlSwitch>(find.byKey(k.formEndSwitch)).value,
        isTrue,
      );
      expect(find.text('Aucune localisation'), findsOneWidget);

      await tester.enterText(find.byKey(k.formName), ' Mairie ');
      await tester.enterText(find.byKey(k.formAddress), '   ');
      await submit(tester);

      expect(places.created.single, (
        slug: 'n-peloton',
        request: const PlaceRequest(
          name: 'Mairie',
          startPlace: true,
          endPlace: true,
        ),
      ));
      // La feuille se ferme, l'écran confirme et relit la liste : le
      // nouveau lieu y est.
      expect(find.byKey(k.formSheet), findsNothing);
      expect(find.text('Lieu créé'), findsOneWidget);
      expect(places.listCalls.length, listsBefore + 1);
      expect(find.byKey(k.row('new')), findsOneWidget);
    });

    testWidgets('création complète : la position choisie part en '
        '[longitude, latitude]', (WidgetTester tester) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      await tester.enterText(find.byKey(k.formName), 'Pâquier');
      await tester.enterText(find.byKey(k.formAddress), 'Avenue d\'Albigny');
      await tester.enterText(
        find.byKey(k.formLink),
        'https://maps.example.org/paquier',
      );
      await pickLocation(tester);
      expect(geocoder.resolved, <String>['place:1']);
      expect(find.text('Annecy, Haute-Savoie'), findsOneWidget);
      await tester.tap(find.byKey(k.formEndSwitch));
      await settle(tester);
      await submit(tester);

      expect(
        places.created.single.request,
        const PlaceRequest(
          name: 'Pâquier',
          address: 'Avenue d\'Albigny',
          link: 'https://maps.example.org/paquier',
          startPlace: true,
          endPlace: false,
          geometry: PlaceRequestGeometry(
            type: PlaceRequestGeometryTypeType.point,
            coordinates: <double>[6.1294, 45.8992],
          ),
        ),
      );
    });

    testWidgets('pendant la lecture de la position, « Ajouter » attend', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places();
      geocoder.resolveGate = Completer<void>();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      await tester.enterText(find.byKey(k.formName), 'Pâquier');
      await pickLocation(tester);

      expect(enabled(tester, k.formSubmit), isFalse);
      expect(find.text('Localisation de l\'adresse…'), findsOneWidget);

      geocoder.resolveGate!.complete();
      await settle(tester);
      expect(enabled(tester, k.formSubmit), isTrue);
    });

    testWidgets('modification : un formulaire intact renvoie le lieu '
        'entier, position comprise — le PUT réécrit tout', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );
      final int listsBefore = places.listCalls.length;

      await tester.tap(find.byKey(k.rowEdit('p1')));
      await settle(tester);
      expect(find.text('Modifier le lieu'), findsOneWidget);
      expect(find.text('Localisation enregistrée'), findsOneWidget);

      await tester.enterText(find.byKey(k.formName), 'Gare d\'Annecy');
      await submit(tester);

      expect(places.updated.single, (
        slug: 'n-peloton',
        id: 'p1',
        request: const PlaceRequest(
          name: 'Gare d\'Annecy',
          address: '1 place de la Gare, Annecy',
          link: 'https://maps.example.org/gare',
          startPlace: true,
          endPlace: false,
          geometry: PlaceRequestGeometry(
            type: PlaceRequestGeometryTypeType.point,
            coordinates: <double>[6.12, 45.9],
          ),
        ),
      ));
      expect(places.created, isEmpty);
      expect(find.byKey(k.formSheet), findsNothing);
      expect(find.text('Lieu mis à jour'), findsOneWidget);
      // La ligne est remplacée à sa place : la liste n'est pas rechargée.
      expect(find.text('Gare d\'Annecy'), findsOneWidget);
      expect(find.text('Parking de la gare'), findsNothing);
      expect(places.listCalls.length, listsBefore);
    });

    testWidgets('modification : adresse, lien et position effacés partent '
        'absents', (WidgetTester tester) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.rowEdit('p1')));
      await settle(tester);
      await tester.enterText(find.byKey(k.formAddress), '');
      await tester.enterText(find.byKey(k.formLink), '');
      await tester.tap(find.byKey(k.formLocationClear));
      await settle(tester);
      expect(find.text('Aucune localisation'), findsOneWidget);
      await tester.tap(find.byKey(k.formStartSwitch));
      await settle(tester);
      await submit(tester);

      expect(
        places.updated.single.request,
        const PlaceRequest(
          name: 'Parking de la gare',
          startPlace: false,
          endPlace: false,
        ),
      );
    });

    testWidgets('une erreur du serveur garde la feuille et la saisie', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places()
        ..writeError = _apiError(400, 'VALIDATION_ERROR');
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );
      final int listsBefore = places.listCalls.length;

      await tester.tap(find.byKey(k.addButton));
      await settle(tester);
      await tester.enterText(find.byKey(k.formName), 'Mairie');
      await tester.enterText(find.byKey(k.formLink), 'pas une adresse');
      await submit(tester);

      expect(find.byKey(k.formSheet), findsOneWidget);
      expect(find.byKey(k.formErrorBanner), findsOneWidget);
      expect(find.text('Mairie'), findsOneWidget);
      expect(find.text('pas une adresse'), findsOneWidget);
      expect(find.text('Lieu créé'), findsNothing);
      expect(places.listCalls.length, listsBefore);

      // La saisie corrigée repart.
      places.writeError = null;
      await tester.enterText(find.byKey(k.formLink), 'https://exemple.org');
      await submit(tester);
      expect(places.created.single.request.link, 'https://exemple.org');
      expect(find.byKey(k.formSheet), findsNothing);
    });

    testWidgets('une écriture fait relire le lieu que les éditeurs de '
        'sortie et de voyage ont lu', (WidgetTester tester) async {
      final ProviderContainer container = await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
      );
      // Un éditeur resté ouvert sous l'écran.
      container.listen(
        editorPlaceProvider((teamSlug: 'n-peloton', id: 'p1')),
        (_, _) {},
      );
      await settle(tester);
      expect(editors.placeReads, <String>['p1']);

      await tester.tap(find.byKey(k.rowEdit('p1')));
      await settle(tester);
      await tester.enterText(find.byKey(k.formName), 'Gare d\'Annecy');
      await submit(tester);

      expect(editors.placeReads, <String>['p1', 'p1']);
    });
  });

  group('suppression', () {
    testWidgets('confirmée : la requête part, la ligne quitte la liste sans '
        'la recharger', (WidgetTester tester) async {
      final _Places places = _Places();
      final ProviderContainer container = await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );
      container.listen(
        editorPlaceProvider((teamSlug: 'n-peloton', id: 'p1')),
        (_, _) {},
      );
      await settle(tester);
      final int listsBefore = places.listCalls.length;

      await tester.tap(find.byKey(k.rowDelete('p1')));
      await settle(tester);
      expect(find.text('Supprimer le lieu'), findsOneWidget);
      expect(
        find.text(
          'Voulez-vous vraiment supprimer ce lieu ? Cette action est '
          'irréversible.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(places.deleted, <({String slug, String id})>[
        (slug: 'n-peloton', id: 'p1'),
      ]);
      expect(find.byKey(k.row('p1')), findsNothing);
      expect(find.byKey(k.row('p2')), findsOneWidget);
      expect(find.text('1 lieu'), findsOneWidget);
      expect(find.text('Lieu supprimé'), findsOneWidget);
      expect(places.listCalls.length, listsBefore);
      expect(editors.placeReads, hasLength(2));
    });

    testWidgets('annulée : rien ne part', (WidgetTester tester) async {
      final _Places places = _Places();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.rowDelete('p1')));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(places.deleted, isEmpty);
      expect(find.byKey(k.row('p1')), findsOneWidget);
    });

    testWidgets('refusée par le serveur : un bandeau, la ligne reste', (
      WidgetTester tester,
    ) async {
      final _Places places = _Places()
        ..deleteError = _apiError(409, 'CONFLICT');
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.rowDelete('p1')));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(find.byKey(k.row('p1')), findsOneWidget);
      expect(find.text('Lieu supprimé'), findsNothing);
    });

    testWidgets('pendant une suppression, les autres gestes sont inactifs — '
        'aucun n\'est perdu en silence', (WidgetTester tester) async {
      final _Places places = _Places()..deleteGate = Completer<void>();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        places: places,
      );

      await tester.tap(find.byKey(k.rowDelete('p1')));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(enabled(tester, k.addButton), isFalse);
      for (final String id in <String>['p1', 'p2']) {
        expect(actionEnabled(tester, k.rowEdit(id)), isFalse);
        expect(actionEnabled(tester, k.rowDelete(id)), isFalse);
      }

      places.deleteGate!.complete();
      await settle(tester);
      expect(enabled(tester, k.addButton), isTrue);
      expect(actionEnabled(tester, k.rowEdit('p2')), isTrue);
      expect(find.byKey(k.row('p1')), findsNothing);
    });
  });
}
