import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/geocoding/data/place_search_repository.dart';
import 'package:pedalons/features/rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/presentation/pages/team_editor_page.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// L'écran de création d'équipe (ledger `MOB-165`) : **ce qui part** — la
/// requête que le serveur recevra —, ce qui ne part pas, et ce que l'écran
/// fait d'un refus du serveur.
class _StubTeams implements TeamRepository {
  /// Si posé, `createTeam` lève cette erreur.
  Object? failWith;

  final List<TeamRequest> created = <TeamRequest>[];
  int myTeamsReads = 0;

  @override
  Future<TeamDetailDto> createTeam(TeamRequest request) async {
    final Object? error = failWith;
    if (error != null) throw error;
    created.add(request);
    return fixtureTeam(
      slug: 'velo-club-du-lac',
      name: request.name,
      role: 'ADMIN',
    );
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async {
    myTeamsReads++;
    return const <TeamDetailDto>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubPlaces implements PlaceSearchRepository {
  final List<String> resolved = <String>[];
  Object? resolveError;

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
    final Object? error = resolveError;
    if (error != null) throw error;
    return const GeocodeResultDto(
      id: 'place:1',
      displayName: 'Annecy',
      lat: 45.8992,
      lon: 6.1294,
    );
  }
}

class _NoAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// La personne connectée, avec ou sans fuseau de profil.
class _Me extends AuthNotifier {
  _Me(Ref ref, String? timezone) : super(_NoAuth(), _NoStorage(), ref) {
    state = AuthState(
      isInitialized: true,
      accessToken: 'token',
      user: UserDto(
        plannerQuota: const PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
        id: 'u1',
        email: 'moi@example.org',
        displayName: 'Membre 1',
        contactableByMembers: true,
        emailVerified: true,
        timezone: timezone,
      ),
    );
  }
}

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  late _StubTeams teams;
  late _StubPlaces places;
  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    teams = _StubTeams();
    places = _StubPlaces();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> open(
    WidgetTester tester, {
    String? timezone,
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
          builder: (BuildContext _, GoRouterState _) => const TeamEditorPage(),
        ),
        GoRoute(
          path: '/equipes/:teamSlug',
          // Un `Scaffold`, comme la page d'une équipe : c'est lui qui montre
          // « Équipe créée » une fois l'éditeur parti.
          builder: (BuildContext _, GoRouterState state) => Scaffold(
            body: Text('équipe ${state.pathParameters['teamSlug']}'),
          ),
        ),
      ],
    );
    final ProviderContainer container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        teamRepositoryProvider.overrideWithValue(teams),
        placeSearchRepositoryProvider.overrideWithValue(places),
        authProvider.overrideWith((Ref ref) => _Me(ref, timezone)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/editor');
    await settle(tester);
    return container;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.teamEditor.saveButton));
    await settle(tester);
  }

  PdlSwitch switchOf(WidgetTester tester, Key key) =>
      tester.widget<PdlSwitch>(find.byKey(key));

  /// Ouvre la recherche d'adresse, cherche, et choisit la seule suggestion.
  Future<void> pickPlace(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.teamEditor.locationRow));
    await settle(tester);
    await tester.enterText(find.byKey(keys.rideEditor.pickerSearch), 'Annecy');
    await settle(tester);
    await tester.tap(find.byKey(keys.rideEditor.pickerOption('place:1')));
    await settle(tester);
  }

  testWidgets('une équipe par défaut : le nom et la description partent, '
      'avec les modules du site', (WidgetTester tester) async {
    final ProviderContainer container = await open(tester);
    // « Mes équipes » est écouté quelque part dans l'app : la création doit
    // le relire.
    container.listen(myTeamsProvider, (_, _) {});
    await settle(tester);
    expect(teams.myTeamsReads, 1);

    expect(find.text('Créer une équipe'), findsOneWidget);
    expect(find.text('Aucune localisation'), findsOneWidget);
    // Les interrupteurs de départ : tout, sauf le trombinoscope.
    expect(switchOf(tester, keys.teamEditor.enableRoutes).value, isTrue);
    expect(switchOf(tester, keys.teamEditor.enableRides).value, isTrue);
    expect(switchOf(tester, keys.teamEditor.enableTrips).value, isTrue);
    expect(switchOf(tester, keys.teamEditor.enablePosts).value, isTrue);
    expect(switchOf(tester, keys.teamEditor.enableAds).value, isTrue);
    expect(
      switchOf(tester, keys.teamEditor.enableMemberDirectory).value,
      isFalse,
    );
    expect(
      switchOf(tester, keys.teamEditor.postsAsTeamByDefault).value,
      isTrue,
    );

    await tester.enterText(
      find.byKey(keys.teamEditor.nameField),
      'Vélo Club du Lac',
    );
    // L'éditeur riche (une WebView, absente des tests de widget) écrit son
    // markdown dans le contrôleur du champ : on y écrit à sa place.
    final RichMarkdownEditorField editor = tester
        .widget<RichMarkdownEditorField>(find.byType(RichMarkdownEditorField));
    // Pas d'image à la création : l'upload exige une équipe.
    expect(editor.onInsertImage, isNull);
    editor.controller.text = 'On roule le dimanche.';
    await tester.pump();
    await save(tester);

    final TeamRequest sent = teams.created.single;
    expect(sent.name, 'Vélo Club du Lac');
    expect(sent.media.markdown, 'On roule le dimanche.');
    expect(sent.media.assets.logo, isNull);
    expect(sent.media.assets.images, isEmpty);
    expect(sent.media.assets.attachments, isEmpty);
    expect(sent.visibility, 'TEAM');
    expect(sent.geometry, isNull);
    expect(sent.timezone, 'Europe/Paris');
    expect(sent.enableRoutes, isTrue);
    expect(sent.enableRides, isTrue);
    expect(sent.enableTrips, isTrue);
    expect(sent.enablePosts, isTrue);
    expect(sent.enableAds, isTrue);
    expect(sent.enableMemberDirectory, isFalse);
    expect(sent.postsAsTeamByDefault, isTrue);

    // La création mène à la page de l'équipe créée, et « Mes équipes » est
    // relu.
    expect(find.text('équipe velo-club-du-lac'), findsOneWidget);
    expect(find.text('Équipe créée'), findsOneWidget);
    expect(teams.myTeamsReads, 2);
  });

  testWidgets('le fuseau de départ est la préférence du profil', (
    WidgetTester tester,
  ) async {
    await open(tester, timezone: 'Pacific/Auckland');

    expect(find.text('Pacific/Auckland'), findsOneWidget);
    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await save(tester);

    expect(teams.created.single.timezone, 'Pacific/Auckland');
  });

  testWidgets('sans préférence : Europe/Paris, visible, et le sélecteur en '
      'pose un autre', (WidgetTester tester) async {
    await open(tester);

    expect(find.text('Europe/Paris'), findsOneWidget);
    await tester.tap(find.byKey(keys.teamEditor.timezoneRow));
    await settle(tester);
    await tester.enterText(find.byKey(keys.profile.timezoneSearch), 'auckland');
    await settle(tester);
    await tester.tap(find.text('Pacific/Auckland'));
    await settle(tester);
    expect(find.text('Pacific/Auckland'), findsOneWidget);

    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await save(tester);
    expect(teams.created.single.timezone, 'Pacific/Auckland');
  });

  testWidgets('couper les parcours coupe et grise les sorties et les '
      'voyages', (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.byKey(keys.teamEditor.enableRoutes));
    await tester.pump();

    final PdlSwitch rides = switchOf(tester, keys.teamEditor.enableRides);
    final PdlSwitch trips = switchOf(tester, keys.teamEditor.enableTrips);
    expect(rides.value, isFalse);
    expect(rides.onChanged, isNull);
    expect(trips.value, isFalse);
    expect(trips.onChanged, isNull);

    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await save(tester);

    final TeamRequest sent = teams.created.single;
    expect(sent.enableRoutes, isFalse);
    expect(sent.enableRides, isFalse);
    expect(sent.enableTrips, isFalse);
  });

  testWidgets('sans publications, la signature par défaut est grisée, et '
      'les autres interrupteurs partent', (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.byKey(keys.teamEditor.enablePosts));
    await tester.tap(find.byKey(keys.teamEditor.enableAds));
    await tester.tap(find.byKey(keys.teamEditor.enableMemberDirectory));
    await tester.pump();
    expect(
      switchOf(tester, keys.teamEditor.postsAsTeamByDefault).onChanged,
      isNull,
    );

    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await save(tester);

    final TeamRequest sent = teams.created.single;
    expect(sent.enablePosts, isFalse);
    expect(sent.enableAds, isFalse);
    expect(sent.enableMemberDirectory, isTrue);
    // Gardé tel quel, comme au site.
    expect(sent.postsAsTeamByDefault, isTrue);
  });

  testWidgets('une adresse choisie : sa position est lue une fois, et part '
      'en [longitude, latitude]', (WidgetTester tester) async {
    await open(tester);

    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await pickPlace(tester);

    expect(places.resolved, <String>['place:1']);
    // Le nom que la personne a lu et choisi.
    expect(find.text('Annecy, Haute-Savoie'), findsOneWidget);
    expect(find.byKey(keys.teamEditor.locationClear), findsOneWidget);

    await save(tester);
    expect(teams.created.single.geometry!.coordinates, <double>[
      6.1294,
      45.8992,
    ]);
  });

  testWidgets('la localisation s\'efface', (WidgetTester tester) async {
    await open(tester);

    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await pickPlace(tester);
    await tester.tap(find.byKey(keys.teamEditor.locationClear));
    await tester.pump();
    expect(find.text('Aucune localisation'), findsOneWidget);

    await save(tester);
    expect(teams.created.single.geometry, isNull);
  });

  testWidgets('la position introuvable se dit, et rien ne change', (
    WidgetTester tester,
  ) async {
    places.resolveError = _apiError(503, 'GEOCODING_UNAVAILABLE');
    await open(tester);

    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await pickPlace(tester);

    expect(find.byKey(keys.teamEditor.errorBanner), findsOneWidget);
    expect(
      find.textContaining('recherche d\'adresse est indisponible'),
      findsOneWidget,
    );
    expect(find.text('Aucune localisation'), findsOneWidget);

    await save(tester);
    expect(teams.created.single.geometry, isNull);
  });

  testWidgets('sans nom : rien ne part, le champ le dit', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await save(tester);

    expect(teams.created, isEmpty);
    expect(find.byKey(keys.teamEditor.errorBanner), findsOneWidget);
    expect(find.text('Entre 1 et 200 caractères'), findsOneWidget);
    // Toujours sur le formulaire.
    expect(find.byKey(keys.teamEditor.saveButton), findsOneWidget);
  });

  testWidgets('un nom fait de blancs ne part pas non plus', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tester.enterText(find.byKey(keys.teamEditor.nameField), '   ');
    await save(tester);

    expect(teams.created, isEmpty);
    expect(find.text('Entre 1 et 200 caractères'), findsOneWidget);
  });

  for (final (String code, String message) in <(String, String)>[
    (
      'USER_TEAM_LIMIT_REACHED',
      'Vous administrez déjà une équipe : il n\'est pas possible d\'en créer '
          'une autre.',
    ),
    (
      'TEAM_CREATION_DISABLED',
      'La création d\'équipes est désactivée sur cette plateforme',
    ),
  ]) {
    testWidgets('$code : le bandeau le dit, la saisie reste', (
      WidgetTester tester,
    ) async {
      teams.failWith = _apiError(403, code);
      await open(tester);

      await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
      await save(tester);

      expect(find.byKey(keys.teamEditor.errorBanner), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.teamEditor.nameField))
            .controller!
            .text,
        'Club',
      );
      // Un second essai repart : le bouton n'est pas resté en attente.
      teams.failWith = null;
      await save(tester);
      expect(teams.created.single.name, 'Club');
    });
  }

  testWidgets('quitter un formulaire modifié demande confirmation', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Club');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    expect(teams.created, isEmpty);
  });

  testWidgets('quitter un formulaire intact ne demande rien', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Abandonner les modifications ?'), findsNothing);
    expect(find.text('accueil'), findsOneWidget);
  });
}
