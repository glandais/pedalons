import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/material.dart' hide Visibility;
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/data/gpx_file_source.dart';
import 'package:pedalons/features/routes/data/planner_web_view.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';
import 'package:pedalons/features/routes/presentation/pages/route_editor_page.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import 'route_fixtures.dart';

/// L'éditeur de parcours (ledger `MOB-79`) : le refus pour qui n'organise pas,
/// le contrôle du fichier, et surtout **ce qui part** — la requête et le
/// fichier que le serveur recevra.
class _StubRoutes implements RouteRepository {
  _StubRoutes({RouteDetailDto? detail})
    : detail =
          detail ??
          // Le droit que le serveur calcule pour un organisateur
          // (docs/LEDGER_*.md MOB-137).
          fixtureRouteDetail(
            permissions: permissionsFor(member: true, role: 'ORGANIZER'),
          );

  final RouteDetailDto detail;

  /// Si posé, `createRoute` / `updateRoute` lèvent cette erreur.
  Object? failWith;

  final List<({String team, RouteRequest request, GpxFile? gpx})> created = [];

  /// L'état d'édition servi ; [plannerStateFails] fait échouer sa lecture.
  PlannerState? plannerState;
  bool plannerStateFails = false;
  int plannerStateReads = 0;

  @override
  Future<PlannerState?> getPlannerState(
    String teamSlug,
    String routeSlug,
  ) async {
    plannerStateReads++;
    if (plannerStateFails) throw StateError('planner-state');
    return plannerState;
  }

  final List<({String slug, RouteRequest request, GpxFile? gpx})> updated = [];

  @override
  Future<RouteDetailDto> getRouteDetail(
    String teamSlug,
    String routeSlug,
  ) async => detail;

  RouteDto _dto(String slug, String name) => RouteDto(
    permissions: kNoPermissions,
    id: 'r1',
    slug: slug,
    elevationState: 'HD',
    team: detail.team,
    name: name,
    media: detail.media,
    distance: 1000,
    elevationGain: 10,
    elevationLoss: 10,
    surfaceType: 'ROAD',
    visibility: 'PUBLIC',
    createdAt: '2026-01-01T10:00:00Z',
    deleted: false,
    tags: const <TagDto>[],
  );

  @override
  Future<RouteDto> createRoute(
    String teamSlug,
    RouteRequest request, {
    GpxFile? gpx,
  }) async {
    final Object? error = failWith;
    if (error != null) throw error;
    created.add((team: teamSlug, request: request, gpx: gpx));
    return _dto('nouveau-parcours', request.name);
  }

  @override
  Future<RouteDto> updateRoute(
    String teamSlug,
    String routeSlug,
    RouteRequest request, {
    GpxFile? gpx,
  }) async {
    final Object? error = failWith;
    if (error != null) throw error;
    updated.add((slug: routeSlug, request: request, gpx: gpx));
    return _dto(routeSlug, request.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTeams implements TeamRepository {
  _StubTeams(this.team);

  final TeamDetailDto team;

  /// Combien de fois l'équipe a été lue : une relecture après un refus de
  /// quota ou un enregistrement se compte ici.
  int reads = 0;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    reads++;
    return team;
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      team.role == null ? <TeamDetailDto>[] : <TeamDetailDto>[team];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// La page du planificateur d'un test de widget : **jamais une WebView**. Elle
/// note ce que l'app lui envoie ([calls]) et joue les messages de la page
/// ([emit]) — le pendant de `RouteMap.debugSkipNativeMap`.
class _FakePlannerWeb implements PlannerWebView {
  late void Function(String raw) _onMessage;

  /// Combien de pages ont été créées : une seule par formulaire.
  int created = 0;
  bool disposed = false;
  final List<({String method, Object? argument})> calls =
      <({String method, Object? argument})>[];

  PlannerWebView create({required void Function(String raw) onMessage}) {
    created++;
    _onMessage = onMessage;
    return this;
  }

  void emit(Map<String, dynamic> message) => _onMessage(jsonEncode(message));

  List<Object?> argumentsOf(String method) => <Object?>[
    for (final ({String method, Object? argument}) c in calls)
      if (c.method == method) c.argument,
  ];

  @override
  Future<void> call(String method, Object? argument) async {
    // Ce qui part doit passer `jsonEncode`, comme vers la vraie page.
    calls.add((method: method, argument: jsonDecode(jsonEncode(argument))));
  }

  @override
  void setBackgroundColor(Color color) {}

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  void dispose() => disposed = true;
}

const ConfigDto _config = ConfigDto(
  webAuthnRpId: 'localhost',
  appName: 'Pédalons',
  singleTeam: false,
  enableGpxPlanner: true,
  mapStyles: <MapStyleDto>[
    MapStyleDto(
      id: 'route',
      label: 'Route',
      group: 'Vectoriel',
      url: 'https://cdn.test/route.json',
    ),
  ],
  tileServerBaseUrl: 'https://tiles.test',
  defaultCenter: MapCenterDto(lat: 46.6, lon: 2.5, zoom: 5),
  gpsAutoSyncEnabled: false,
);

/// Un sélecteur qui rend, dans l'ordre, les fichiers qu'on lui a préparés.
class _FakePicker implements GpxFilePicker {
  _FakePicker(this.files);

  final List<GpxFile?> files;
  int calls = 0;

  @override
  Future<GpxFile?> pick() async {
    final int i = calls++;
    return i < files.length ? files[i] : null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  late Directory dir;
  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    dir = Directory.systemTemp.createTempSync('route_editor_');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  GpxFile write(String name, String content) {
    final File f = File('${dir.path}/$name')..writeAsStringSync(content);
    return GpxFile(path: f.path, name: name, size: f.lengthSync());
  }

  /// Le choix du fichier lit le disque pour de vrai : le temps du test doit
  /// laisser passer l'entrée-sortie, que `pump` seul ne fait pas avancer.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  late GoRouter router;
  late _StubTeams teams;

  Future<void> open(
    WidgetTester tester, {
    required _StubRoutes routes,
    required _FakePicker picker,
    String? role = 'ORGANIZER',
    String teamVisibility = 'PUBLIC',
    bool enableRoutes = true,
    String? routeSlug,
    bool replaceGpx = false,
    bool planner = false,
    PlannerQuotaDto? quota,
    _FakePlannerWeb? web,
  }) async {
    teams = _StubTeams(
      fixtureRouteTeam(
        role: role,
        visibility: teamVisibility,
        enableRoutes: enableRoutes,
        enableRoutePlanner: planner,
        plannerQuota: quota,
      ),
    );
    // Un écran haut : le formulaire est long, et seul ce qui est construit
    // se trouve.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          // Un `Scaffold` : c'est lui qui montre le bandeau d'après
          // l'enregistrement, une fois l'éditeur parti.
          builder: (BuildContext _, GoRouterState _) =>
              const Scaffold(body: Text('accueil')),
        ),
        GoRoute(
          path: '/editor',
          builder: (BuildContext _, GoRouterState _) => RouteEditorPage(
            teamSlug: 'n-peloton',
            routeSlug: routeSlug,
            replaceGpx: replaceGpx,
          ),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/parcours/:routeSlug',
          builder: (BuildContext _, GoRouterState state) =>
              Text('fiche ${state.pathParameters['routeSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routeRepositoryProvider.overrideWithValue(routes),
          teamRepositoryProvider.overrideWithValue(teams),
          gpxFilePickerProvider.overrideWith((Ref _) => picker),
          appConfigProvider.overrideWith((Ref _) async => _config),
          if (web != null)
            plannerWebViewFactoryProvider.overrideWithValue(web.create),
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
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pickFirst(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.routeEditor.pickButton));
    await settle(tester);
  }

  testWidgets('un simple membre lit un refus, pas un formulaire', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[]),
      role: 'MEMBER',
    );

    expect(find.byKey(keys.routeEditor.forbidden), findsOneWidget);
    expect(find.text('Réservé au rôle Organisateur'), findsOneWidget);
    expect(find.byKey(keys.routeEditor.saveButton), findsNothing);
    expect(find.byKey(keys.routeEditor.pickButton), findsNothing);
  });

  testWidgets('le refus précède la lecture du parcours', (
    WidgetTester tester,
  ) async {
    // Un membre sur le lien de modification d'un parcours d'équipe privé :
    // lire le parcours donnerait un 403, pas l'écran de refus.
    final _StubRoutes routes = _StubRoutes();
    await open(
      tester,
      routes: routes,
      picker: _FakePicker(<GpxFile?>[]),
      role: 'MEMBER',
      routeSlug: 'col-de-la-croix',
    );

    expect(find.byKey(keys.routeEditor.forbidden), findsOneWidget);
    expect(find.byKey(keys.routeEditor.loadError), findsNothing);
  });

  testWidgets('modules parcours coupés : le même écran, un autre message', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[]),
      enableRoutes: false,
    );

    expect(find.byKey(keys.routeEditor.forbidden), findsOneWidget);
    expect(
      find.text('Les parcours sont désactivés pour cette équipe.'),
      findsOneWidget,
    );
    expect(find.byKey(keys.routeEditor.pickButton), findsNothing);
  });

  testWidgets('étape 1 : le fichier d\'abord, pas de formulaire', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[]),
    );

    expect(find.byKey(keys.routeEditor.pickStep), findsOneWidget);
    expect(find.byKey(keys.routeEditor.pickButton), findsOneWidget);
    expect(find.text('Choisir un fichier GPX'), findsOneWidget);
    expect(
      find.textContaining('Le tracé ne se dessine pas dans l\'app'),
      findsOneWidget,
    );
    expect(find.byKey(keys.routeEditor.nameField), findsNothing);
    expect(find.byKey(keys.routeEditor.saveButton), findsNothing);
  });

  testWidgets('annuler le sélecteur ne change rien', (
    WidgetTester tester,
  ) async {
    final _FakePicker picker = _FakePicker(<GpxFile?>[null]);
    await open(tester, routes: _StubRoutes(), picker: picker);

    await pickFirst(tester);

    expect(picker.calls, 1);
    expect(find.byKey(keys.routeEditor.refusedBanner), findsNothing);
    expect(find.byKey(keys.routeEditor.pickStep), findsOneWidget);
  });

  testWidgets('un .txt est refusé, avec « Choisir un autre fichier »', (
    WidgetTester tester,
  ) async {
    final _FakePicker picker = _FakePicker(<GpxFile?>[
      write('notes.txt', 'pas un gpx'),
      write('col-test.gpx', fixtureGpx()),
    ]);
    await open(tester, routes: _StubRoutes(), picker: picker);

    await pickFirst(tester);

    expect(find.byKey(keys.routeEditor.refusedBanner), findsOneWidget);
    // Le titre est un fragment du texte du bandeau.
    expect(
      find.textContaining('Fichier refusé', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('« notes.txt » n\'est pas un GPX lisible'),
      findsOneWidget,
    );
    expect(find.byKey(keys.routeEditor.pickAnotherButton), findsOneWidget);
    expect(find.byKey(keys.routeEditor.saveButton), findsNothing);

    // « Choisir un autre fichier » rouvre le sélecteur ; un bon GPX ouvre le
    // formulaire et fait disparaître le bandeau.
    await tester.tap(find.byKey(keys.routeEditor.pickAnotherButton));
    await settle(tester);

    expect(picker.calls, 2);
    expect(find.byKey(keys.routeEditor.refusedBanner), findsNothing);
    expect(find.byKey(keys.routeEditor.nameField), findsOneWidget);
  });

  testWidgets('un .gpx qui contient du HTML est refusé aussi', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[
        write('page.gpx', '<!doctype html><html></html>'),
      ]),
    );

    await pickFirst(tester);

    expect(find.byKey(keys.routeEditor.refusedBanner), findsOneWidget);
    expect(find.byKey(keys.routeEditor.nameField), findsNothing);
  });

  testWidgets('un GPX accepté ouvre le formulaire, nom repris du fichier', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[
        write('col-test.gpx', fixtureGpx(trackName: 'Col de test')),
      ]),
    );

    await pickFirst(tester);

    expect(find.byKey(keys.routeEditor.pickStep), findsNothing);
    expect(find.byKey(keys.routeEditor.trackSection), findsOneWidget);
    expect(find.text('col-test.gpx'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(keys.routeEditor.nameField))
          .controller!
          .text,
      'Col de test',
    );
    expect(find.byKey(keys.routeEditor.nameFromGpxHint), findsOneWidget);
    expect(find.text('Repris du fichier GPX, modifiable.'), findsOneWidget);
    expect(find.byKey(keys.routeEditor.saveButton), findsOneWidget);
    expect(find.text('Créer le parcours'), findsOneWidget);
    // Création : pas d'avertissement de remplacement, pas d'adresse.
    expect(find.byKey(keys.routeEditor.trackWarning), findsNothing);
    expect(find.byKey(keys.routeEditor.slugRow), findsNothing);
  });

  testWidgets('sans nom dans le GPX, le nom du fichier sans extension', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[
        write('boucle-nord.gpx', '<gpx><trk><trkseg/></trk></gpx>'),
      ]),
    );

    await pickFirst(tester);

    expect(
      tester
          .widget<TextField>(find.byKey(keys.routeEditor.nameField))
          .controller!
          .text,
      'boucle-nord',
    );
  });

  testWidgets('« Changer » ne réécrit pas un nom tapé', (
    WidgetTester tester,
  ) async {
    final _FakePicker picker = _FakePicker(<GpxFile?>[
      write('a.gpx', fixtureGpx(trackName: 'Premier')),
      write('b.gpx', fixtureGpx(trackName: 'Second')),
    ]);
    await open(tester, routes: _StubRoutes(), picker: picker);
    await pickFirst(tester);

    await tester.enterText(find.byKey(keys.routeEditor.nameField), 'Mon nom');
    await tester.pump();
    await tester.tap(find.byKey(keys.routeEditor.trackChangeButton));
    await settle(tester);

    expect(picker.calls, 2);
    expect(find.text('b.gpx'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(keys.routeEditor.nameField))
          .controller!
          .text,
      'Mon nom',
    );
    expect(find.byKey(keys.routeEditor.nameFromGpxHint), findsNothing);
  });

  testWidgets('« Changer » remplace un nom encore repris du fichier', (
    WidgetTester tester,
  ) async {
    final _FakePicker picker = _FakePicker(<GpxFile?>[
      write('a.gpx', fixtureGpx(trackName: 'Premier')),
      write('b.gpx', fixtureGpx(trackName: 'Second')),
    ]);
    await open(tester, routes: _StubRoutes(), picker: picker);
    await pickFirst(tester);

    await tester.tap(find.byKey(keys.routeEditor.trackChangeButton));
    await settle(tester);

    expect(
      tester
          .widget<TextField>(find.byKey(keys.routeEditor.nameField))
          .controller!
          .text,
      'Second',
    );
  });

  testWidgets('visibilité et surface se choisissent pour une équipe publique', (
    WidgetTester tester,
  ) async {
    final GpxFile gpx = write('col.gpx', fixtureGpx());
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[gpx]),
    );
    await pickFirst(tester);
    expect(find.byKey(keys.routeEditor.visibility), findsOneWidget);
    expect(find.byKey(keys.routeEditor.surface), findsOneWidget);
  });

  testWidgets('visibilité masquée pour une équipe TEAM', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      routes: _StubRoutes(),
      picker: _FakePicker(<GpxFile?>[write('col.gpx', fixtureGpx())]),
      teamVisibility: 'TEAM',
    );
    await pickFirst(tester);

    expect(find.byKey(keys.routeEditor.nameField), findsOneWidget);
    expect(find.byKey(keys.routeEditor.visibility), findsNothing);
    expect(find.byKey(keys.routeEditor.surface), findsOneWidget);
  });

  testWidgets('un nom trop court bloque l\'envoi et le dit', (
    WidgetTester tester,
  ) async {
    final _StubRoutes routes = _StubRoutes();
    await open(
      tester,
      routes: routes,
      picker: _FakePicker(<GpxFile?>[write('col.gpx', fixtureGpx())]),
    );
    await pickFirst(tester);

    await tester.enterText(find.byKey(keys.routeEditor.nameField), 'ab');
    await tester.tap(find.byKey(keys.routeEditor.saveButton));
    await tester.pump();

    expect(routes.created, isEmpty);
    expect(find.byKey(keys.routeEditor.errorBanner), findsOneWidget);
    expect(find.text('Entre 3 et 200 caractères'), findsOneWidget);
  });

  testWidgets('créer envoie la requête et le fichier, puis ouvre la fiche', (
    WidgetTester tester,
  ) async {
    final _StubRoutes routes = _StubRoutes();
    final GpxFile gpx = write('col-test.gpx', fixtureGpx());
    await open(tester, routes: routes, picker: _FakePicker(<GpxFile?>[gpx]));
    await pickFirst(tester);

    await tester.tap(
      find.byKey(keys.routeEditor.surfaceOption(SurfaceType.gravel)),
    );
    await tester.pump();
    await tester.tap(find.byKey(keys.routeEditor.saveButton));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final created = routes.created.single;
    expect(created.team, 'n-peloton');
    expect(created.gpx, gpx);
    expect(created.request.name, 'Col de test');
    expect(created.request.surfaceType, 'GRAVEL');
    expect(created.request.visibility, 'PUBLIC');
    expect(created.request.points, isNull);
    expect(created.request.tagIds, isEmpty);
    expect(find.text('fiche nouveau-parcours'), findsOneWidget);
  });

  testWidgets(
    'le serveur refuse le fichier : retour à l\'étape 1 avec le bandeau, '
    'formulaire gardé, fichier refusé oublié',
    (WidgetTester tester) async {
      final _StubRoutes routes = _StubRoutes();
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[
          write('col-test.gpx', fixtureGpx()),
          write('col-bon.gpx', fixtureGpx()),
        ]),
      );
      await pickFirst(tester);

      await tester.enterText(find.byKey(keys.routeEditor.nameField), 'Mon col');
      await tester.pump();
      routes.failWith = DioException(
        requestOptions: RequestOptions(path: '/api/teams/n-peloton/routes'),
        type: DioExceptionType.badResponse,
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(path: '/api/teams/n-peloton/routes'),
          statusCode: 400,
          data: const <String, Object?>{'code': 'GPX_FAILURE'},
        ),
      );
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Le fichier refusé est oublié : on est revenu au choix du fichier, avec
      // le bandeau. Créer ne peut plus renvoyer le même fichier.
      expect(find.byKey(keys.routeEditor.pickStep), findsOneWidget);
      expect(find.byKey(keys.routeEditor.refusedBanner), findsOneWidget);
      expect(
        find.textContaining('« col-test.gpx » n\'est pas un GPX lisible'),
        findsOneWidget,
      );
      expect(find.byKey(keys.routeEditor.saveButton), findsNothing);
      expect(find.byKey(keys.routeEditor.errorBanner), findsNothing);
      expect(find.text('accueil'), findsNothing);

      // Un autre fichier ramène le formulaire, avec ce qui était tapé.
      routes.failWith = null;
      await tester.tap(find.byKey(keys.routeEditor.pickAnotherButton));
      await settle(tester);
      expect(find.byKey(keys.routeEditor.refusedBanner), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.routeEditor.nameField))
            .controller!
            .text,
        'Mon col',
      );
      expect(find.byKey(keys.routeEditor.saveButton), findsOneWidget);
    },
  );

  testWidgets('un autre échec reste une erreur de l\'écran', (
    WidgetTester tester,
  ) async {
    final _StubRoutes routes = _StubRoutes()
      ..failWith = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 403,
          data: const <String, Object?>{'code': 'FORBIDDEN'},
        ),
      );
    await open(
      tester,
      routes: routes,
      picker: _FakePicker(<GpxFile?>[write('col.gpx', fixtureGpx())]),
    );
    await pickFirst(tester);

    await tester.tap(find.byKey(keys.routeEditor.saveButton));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byKey(keys.routeEditor.errorBanner), findsOneWidget);
    expect(find.byKey(keys.routeEditor.refusedBanner), findsNothing);
  });

  group('modification', () {
    testWidgets('chiffres, avertissement, adresse ; enregistrer sans GPX', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        routeSlug: 'col-de-la-croix',
      );

      expect(find.byKey(keys.routeEditor.pickStep), findsNothing);
      expect(find.byKey(keys.routeEditor.trackSection), findsOneWidget);
      expect(find.byKey(keys.routeEditor.trackWarning), findsOneWidget);
      expect(
        find.textContaining('Un nouveau fichier remplace tout le tracé'),
        findsOneWidget,
      );
      expect(find.byKey(keys.routeEditor.trackReplaceButton), findsOneWidget);
      expect(find.byKey(keys.routeEditor.slugRow), findsOneWidget);
      expect(find.text('col-de-la-croix'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.routeEditor.nameField))
            .controller!
            .text,
        'Col de la Croix',
      );

      await tester.enterText(
        find.byKey(keys.routeEditor.nameField),
        'Col renommé',
      );
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final update = routes.updated.single;
      expect(update.slug, 'col-de-la-croix');
      expect(update.gpx, isNull);
      expect(update.request.name, 'Col renommé');
      expect(update.request.surfaceType, 'GRAVEL');
      expect(update.request.media.markdown, 'Un beau col.');
      expect(update.request.tagIds, isEmpty);
      // Revenu à ce qui était dessous.
      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets('« Remplacer le GPX » envoie le nouveau fichier', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      final GpxFile gpx = write('nouveau.gpx', fixtureGpx());
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[gpx]),
        routeSlug: 'col-de-la-croix',
      );

      await tester.tap(find.byKey(keys.routeEditor.trackReplaceButton));
      await settle(tester);

      expect(find.text('nouveau.gpx'), findsOneWidget);
      expect(find.byKey(keys.routeEditor.trackReplaceCancel), findsOneWidget);
      // Le nom du parcours existant n'est pas réécrit par celui du fichier.
      expect(
        tester
            .widget<TextField>(find.byKey(keys.routeEditor.nameField))
            .controller!
            .text,
        'Col de la Croix',
      );

      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(routes.updated.single.gpx, gpx);
    });

    testWidgets('« Garder le tracé actuel » renonce au fichier choisi', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[write('nouveau.gpx', fixtureGpx())]),
        routeSlug: 'col-de-la-croix',
      );
      await tester.tap(find.byKey(keys.routeEditor.trackReplaceButton));
      await settle(tester);

      await tester.tap(find.byKey(keys.routeEditor.trackReplaceCancel));
      await tester.pump();
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(routes.updated.single.gpx, isNull);
    });

    testWidgets('replaceGpx: true ouvre le sélecteur, une seule fois', (
      WidgetTester tester,
    ) async {
      final _FakePicker picker = _FakePicker(<GpxFile?>[
        write('nouveau.gpx', fixtureGpx()),
      ]);
      await open(
        tester,
        routes: _StubRoutes(),
        picker: picker,
        routeSlug: 'col-de-la-croix',
        replaceGpx: true,
      );
      await settle(tester);

      expect(picker.calls, 1);
      expect(find.text('nouveau.gpx'), findsOneWidget);
      // Rien n'est parti : l'organisateur relit l'avertissement et enregistre.
      expect(find.byKey(keys.routeEditor.trackWarning), findsOneWidget);
      expect(find.byKey(keys.routeEditor.saveButton), findsOneWidget);
    });

    testWidgets('un fichier refusé au remplacement garde le tracé actuel', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[write('notes.txt', 'rien')]),
        routeSlug: 'col-de-la-croix',
      );

      await tester.tap(find.byKey(keys.routeEditor.trackReplaceButton));
      await settle(tester);

      expect(
        find.descendant(
          of: find.byKey(keys.routeEditor.trackSection),
          matching: find.byKey(keys.routeEditor.refusedBanner),
        ),
        findsOneWidget,
      );
      expect(find.byKey(keys.routeEditor.trackReplaceCancel), findsNothing);
    });

    testWidgets(
      'un refus du serveur au remplacement oublie le fichier : tracé actuel',
      (WidgetTester tester) async {
        final _StubRoutes routes = _StubRoutes();
        await open(
          tester,
          routes: routes,
          picker: _FakePicker(<GpxFile?>[write('col.gpx', fixtureGpx())]),
          routeSlug: 'col-de-la-croix',
        );
        await tester.tap(find.byKey(keys.routeEditor.trackReplaceButton));
        await settle(tester);
        expect(find.byKey(keys.routeEditor.trackReplaceCancel), findsOneWidget);

        routes.failWith = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, Object?>>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 400,
            data: const <String, Object?>{'code': 'GPX_FAILURE'},
          ),
        );
        await tester.ensureVisible(find.byKey(keys.routeEditor.saveButton));
        await tester.tap(find.byKey(keys.routeEditor.saveButton));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          find.descendant(
            of: find.byKey(keys.routeEditor.trackSection),
            matching: find.byKey(keys.routeEditor.refusedBanner),
          ),
          findsOneWidget,
        );
        // Plus de « Remplacera le tracé » : le fichier refusé est oublié.
        expect(find.byKey(keys.routeEditor.trackReplaceCancel), findsNothing);
        expect(find.byKey(keys.routeEditor.trackReplaceButton), findsOneWidget);
      },
    );

    testWidgets('retour avec des modifications : confirmation d\'abandon', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[]),
        routeSlug: 'col-de-la-croix',
      );

      await tester.enterText(
        find.byKey(keys.routeEditor.nameField),
        'Autre nom',
      );
      await tester.pump();
      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      await navigator.maybePop();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      expect(find.byKey(keys.routeEditor.nameField), findsOneWidget);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets('retour sans modification : aucune question', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[]),
        routeSlug: 'col-de-la-croix',
      );

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      await navigator.maybePop();
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Abandonner les modifications ?'), findsNothing);
      expect(find.text('accueil'), findsOneWidget);
    });
  });

  /// docs/LEDGER_*.md MOB-137 : le sélecteur lit ce que le backend permet à
  /// **ce** parcours, et la baisse d'un parcours qui sert publiquement est
  /// refusée avec ses usages (décision D6) — sans alignement.
  group('visibilité calculée', () {
    testWidgets('un parcours qui sert publiquement ne propose pas « Équipe »', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes(
        detail: fixtureRouteDetail(
          permissions: permissionsFor(member: true, role: 'ORGANIZER').copyWith(
            allowedVisibilities: const <Visibility>[
              Visibility.publicUnlisted,
              Visibility.public,
            ],
          ),
        ),
      );
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        routeSlug: 'col-de-la-croix',
      );

      expect(find.byKey(keys.routeEditor.visibility), findsOneWidget);
      expect(find.byKey(keys.visibility.option('TEAM')), findsNothing);
      expect(find.byKey(keys.visibility.option('PUBLIC')), findsOneWidget);
    });

    testWidgets('aucune visibilité permise : l\'explication', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes(
        detail: fixtureRouteDetail(
          permissions: permissionsFor(
            member: true,
            role: 'ORGANIZER',
          ).copyWith(allowedVisibilities: const <Visibility>[]),
        ),
      );
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        routeSlug: 'col-de-la-croix',
      );

      expect(find.byKey(keys.visibility.noneAllowed), findsOneWidget);
      expect(find.byKey(keys.routeEditor.visibility), findsNothing);
    });

    testWidgets('le refus liste les usages, sans le message générique', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes()
        ..failWith = DioException(
          requestOptions: RequestOptions(path: '/routes'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/routes'),
            statusCode: 400,
            data: <String, dynamic>{
              'code': 'INCOMPATIBLE_VISIBILITY',
              'errorDetails': <String, dynamic>{
                'type': 'INCOMPATIBLE_VISIBILITY',
                'routes': <Map<String, dynamic>>[],
                'usages': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'type': 'RIDE',
                    'slug': 'sortie',
                    'name': 'Sortie du samedi',
                    'visibility': 'PUBLIC',
                  },
                  <String, dynamic>{
                    'type': 'TRIP',
                    'slug': 'voyage',
                    'name': 'Grand tour',
                    'visibility': 'PUBLIC_UNLISTED',
                  },
                ],
              },
            },
          ),
        );
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        routeSlug: 'col-de-la-croix',
      );
      await tester.tap(find.byKey(keys.visibility.option('TEAM')));
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byKey(keys.visibility.routeInUseSheet), findsOneWidget);
      expect(find.text('Sortie « Sortie du samedi » (Public)'), findsOneWidget);
      expect(
        find.text('Voyage « Grand tour » (Non répertorié)'),
        findsOneWidget,
      );
      expect(
        find.byKey(keys.visibility.usage('RIDE', 'sortie')),
        findsOneWidget,
      );
      expect(find.byKey(keys.routeEditor.errorBanner), findsNothing);
    });
  });

  group('planificateur (MOB-170)', () {
    // Large : la transition d'un écran plein dure plus qu'un demi-tour de
    // formulaire, et un écran en train de partir est encore trouvé.
    Future<void> pumps(WidgetTester tester, [int n = 24]) async {
      for (int i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Map<String, dynamic> done({
      Map<String, dynamic> payload = const <String, dynamic>{
        'plannerState': fixturePlannerStateJson,
      },
      int pointCount = 2,
      bool dirty = true,
      String? nameSuggestion,
      String? notice,
    }) => <String, dynamic>{
      'type': 'done',
      'payload': payload,
      'stats': <String, dynamic>{
        'distance': 18000,
        'ascend': 240,
        'pointCount': pointCount,
        // (45, 5) puis (45.01, 5.01), précision 6, latitude d'abord.
        'line': '_sqytA_sdpH_pR_pR',
      },
      'dirty': dirty,
      'nameSuggestion': ?nameSuggestion,
      'notice': ?notice,
    };

    RouteDetailDto singleTrack({bool? excludedFromGenerator}) =>
        fixtureRouteDetail(
          permissions: permissionsFor(member: true, role: 'ORGANIZER'),
          tracks: const <TrackDto>[fixtureTrack],
          excludedFromGenerator: excludedFromGenerator,
        );

    /// Ouvre le planificateur depuis l'étape 1 et laisse la page dire `ready`.
    Future<void> draw(WidgetTester tester, _FakePlannerWeb web) async {
      await tester.tap(find.byKey(keys.routeEditor.drawButton));
      await pumps(tester);
      web.emit(<String, dynamic>{'type': 'ready'});
      await pumps(tester);
    }

    testWidgets('fermé à l\'équipe : ni « Tracer sur la carte », ni case', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes(detail: singleTrack());
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        routeSlug: 'col-de-la-croix',
      );

      expect(find.byKey(keys.routeEditor.trackReplaceButton), findsOneWidget);
      expect(find.byKey(keys.routeEditor.trackEditButton), findsNothing);
      expect(find.byKey(keys.routeEditor.drawButton), findsNothing);
      expect(find.byKey(keys.routeEditor.excludedFromGenerator), findsNothing);

      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      await pumps(tester);
      // La requête de MOB-79, telle quelle : rien du planificateur.
      final RouteRequest request = routes.updated.single.request;
      expect(request.excludedFromGenerator, isNull);
      expect(request.plannerState, isNull);
      expect(request.points, isNull);
      expect(request.waypoints, isNull);
    });

    testWidgets('création : les deux entrées, puis tracer, aperçu, envoi', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        web: web,
      );

      expect(find.text('Importer un fichier GPX'), findsOneWidget);
      expect(find.text('Tracer sur la carte'), findsOneWidget);
      expect(
        find.textContaining('Le tracé ne se dessine pas dans l\'app'),
        findsNothing,
      );
      // La page n'est créée qu'à la première ouverture.
      expect(web.created, 0);

      await draw(tester, web);
      expect(find.byKey(keys.routeEditor.plannerScreen), findsOneWidget);
      final Map<String, dynamic> load =
          web.argumentsOf('load').single! as Map<String, dynamic>;
      expect(load['create'], isTrue);
      expect(load['teamSlug'], 'n-peloton');
      expect(load['theme'], 'light');
      expect(load['locale'], 'fr');
      expect(load['units'], 'METRIC');
      expect(load['defaultCenter'], <String, dynamic>{
        'lat': 46.6,
        'lon': 2.5,
        'zoom': 5.0,
      });
      // Un style d'un CDN tiers reste une adresse.
      expect((load['styles'] as List<dynamic>).single, <String, dynamic>{
        'id': 'route',
        'label': 'Route',
        'group': 'Vectoriel',
        'url': 'https://cdn.test/route.json',
      });
      expect(load.containsKey('state'), isFalse);
      expect(load.containsKey('track'), isFalse);
      expect(load.containsKey('testCommands'), isFalse);
      expect(routes.plannerStateReads, 0);

      web.emit(done(nameSuggestion: 'Tour du lac'));
      await pumps(tester);

      // De retour dans le formulaire : l'aperçu, le nom proposé.
      expect(find.byKey(keys.routeEditor.plannerScreen), findsNothing);
      expect(find.byKey(keys.routeEditor.plannerPreview), findsOneWidget);
      expect(find.textContaining('18,0'), findsOneWidget);
      expect(find.textContaining('240'), findsOneWidget);
      expect(find.text('Tracé de 2 points'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.routeEditor.nameField))
            .controller!
            .text,
        'Tour du lac',
      );
      expect(find.byKey(keys.routeEditor.trackEditButton), findsOneWidget);

      final int readsBefore = teams.reads;
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      await pumps(tester);

      final created = routes.created.single;
      expect(created.gpx, isNull);
      expect(created.request.name, 'Tour du lac');
      expect(
        created.request.plannerState,
        PlannerState.fromJson(fixturePlannerStateJson),
      );
      expect(created.request.points, isNull);
      expect(created.request.waypoints, isNull);
      expect(created.request.excludedFromGenerator, isFalse);
      // L'équipe est relue après l'enregistrement : son quota a bougé.
      expect(teams.reads, greaterThan(readsBefore));
      expect(find.text('fiche nouveau-parcours'), findsOneWidget);
      expect(web.disposed, isTrue);
    });

    testWidgets('rouvrir : la même page, `load` une seule fois', (
      WidgetTester tester,
    ) async {
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        web: web,
      );
      await draw(tester, web);
      web.emit(done());
      await pumps(tester);

      await tester.tap(find.byKey(keys.routeEditor.trackEditButton));
      await pumps(tester);

      expect(find.byKey(keys.routeEditor.plannerScreen), findsOneWidget);
      expect(web.created, 1);
      expect(web.argumentsOf('load'), hasLength(1));
      expect(web.disposed, isFalse);
    });

    testWidgets('un nom déjà tapé n\'est pas remplacé par celui du fichier', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        web: web,
      );
      await draw(tester, web);
      web.emit(done());
      await pumps(tester);
      await tester.enterText(
        find.byKey(keys.routeEditor.nameField),
        'Ma boucle',
      );

      await tester.tap(find.byKey(keys.routeEditor.trackEditButton));
      await pumps(tester);
      web.emit(done(nameSuggestion: 'Tour du lac'));
      await pumps(tester);

      expect(
        tester
            .widget<TextField>(find.byKey(keys.routeEditor.nameField))
            .controller!
            .text,
        'Ma boucle',
      );
    });

    testWidgets('moins de deux points à la création : toujours l\'étape 1', (
      WidgetTester tester,
    ) async {
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        web: web,
      );
      await draw(tester, web);
      // Un seul point posé : la page ne rend aucun fragment.
      web.emit(done(payload: const <String, dynamic>{}, pointCount: 1));
      await pumps(tester);

      expect(find.byKey(keys.routeEditor.pickStep), findsOneWidget);
      expect(find.byKey(keys.routeEditor.saveButton), findsNothing);
    });

    testWidgets('quota épuisé : le bouton reste, désactivé, avec sa raison', (
      WidgetTester tester,
    ) async {
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        quota: const PlannerQuotaDto(
          used: 20,
          limit: 20,
          resetsOn: '2026-12-01',
        ),
        web: web,
      );

      expect(find.byKey(keys.routeEditor.drawButton), findsOneWidget);
      expect(find.byKey(keys.routeEditor.quotaMessage), findsOneWidget);
      expect(
        find.textContaining(
          'N-Peloton utilise l\'offre gratuite, qui permet 20 enregistrements',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('le compteur repart le 1er décembre'),
        findsOneWidget,
      );
      // L'import reste.
      expect(find.byKey(keys.routeEditor.pickButton), findsOneWidget);

      await tester.tap(find.byKey(keys.routeEditor.drawButton));
      await pumps(tester);
      expect(web.created, 0);
      expect(find.byKey(keys.routeEditor.plannerScreen), findsNothing);
    });

    testWidgets('quota sans limite ou non atteint : le bouton est ouvert', (
      WidgetTester tester,
    ) async {
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        quota: const PlannerQuotaDto(
          used: 19,
          limit: 20,
          resetsOn: '2026-12-01',
        ),
        web: web,
      );

      expect(find.byKey(keys.routeEditor.quotaMessage), findsNothing);
      await tester.tap(find.byKey(keys.routeEditor.drawButton));
      await pumps(tester);
      expect(web.created, 1);
    });

    testWidgets('un calcul en vol bloque l\'enregistrement', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        web: web,
      );
      await draw(tester, web);
      web.emit(done(nameSuggestion: 'Tour du lac'));
      await pumps(tester);

      web.emit(<String, dynamic>{'type': 'busy', 'busy': true});
      await pumps(tester, 2);
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      await pumps(tester);
      expect(routes.created, isEmpty);

      web.emit(<String, dynamic>{'type': 'busy', 'busy': false});
      await pumps(tester, 2);
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      await pumps(tester);
      expect(routes.created, hasLength(1));
    });

    testWidgets('`quotaRefused` de la page : la feuille, l\'équipe relue', (
      WidgetTester tester,
    ) async {
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: _StubRoutes(),
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        web: web,
      );
      await draw(tester, web);
      final int readsBefore = teams.reads;

      web.emit(<String, dynamic>{
        'type': 'quotaRefused',
        'scope': 'TEAM',
        'limit': 20,
        'current': 20,
        'resetsOn': '2026-12-01',
        'teamName': 'N-Peloton',
      });
      await pumps(tester);

      expect(find.byKey(keys.routeEditor.quotaSheet), findsOneWidget);
      expect(
        find.text('Enregistrements du mois tous utilisés'),
        findsOneWidget,
      );

      // Fermer la feuille ne ferme pas le planificateur.
      await tester.tap(find.byKey(keys.routeEditor.quotaClose));
      await pumps(tester);
      expect(find.byKey(keys.routeEditor.quotaSheet), findsNothing);
      expect(find.byKey(keys.routeEditor.plannerScreen), findsOneWidget);

      // L'équipe est relue dès que le formulaire, dessous, revient à
      // l'écran (un écran couvert n'écoute pas).
      web.emit(<String, dynamic>{'type': 'close', 'dirty': false});
      await pumps(tester);
      expect(teams.reads, greaterThan(readsBefore));
    });

    testWidgets('PLANNER_QUOTA_REACHED à l\'enregistrement : la feuille', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      final _FakePlannerWeb web = _FakePlannerWeb();
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[]),
        planner: true,
        web: web,
      );
      await draw(tester, web);
      web.emit(done(nameSuggestion: 'Tour du lac'));
      await pumps(tester);

      final RequestOptions options = RequestOptions(
        path: '/api/teams/x/routes',
      );
      routes.failWith = DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 403,
          data: <String, dynamic>{
            'code': 'PLANNER_QUOTA_REACHED',
            'errorDetails': <String, dynamic>{
              'type': 'PLANNER_QUOTA_REACHED',
              'scope': 'TEAM',
              'limit': 20,
              'current': 20,
              'resetsOn': '2026-12-01',
              'teamName': 'N-Peloton',
            },
          },
        ),
      );
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      await pumps(tester);

      expect(find.byKey(keys.routeEditor.quotaSheet), findsOneWidget);
      // Ni message générique, ni tracé perdu.
      expect(find.byKey(keys.routeEditor.errorBanner), findsNothing);
      await tester.tap(find.byKey(keys.routeEditor.quotaClose));
      await pumps(tester);
      expect(find.byKey(keys.routeEditor.plannerPreview), findsOneWidget);
    });

    testWidgets('un fichier importé intact part en fichier (`file: true`)', (
      WidgetTester tester,
    ) async {
      final _StubRoutes routes = _StubRoutes();
      final _FakePlannerWeb web = _FakePlannerWeb();
      final GpxFile first = write('premier.gpx', fixtureGpx());
      final GpxFile second = write('second.gpx', fixtureGpx());
      await open(
        tester,
        routes: routes,
        picker: _FakePicker(<GpxFile?>[first, second]),
        planner: true,
        web: web,
      );
      await draw(tester, web);

      // Deux fichiers choisis dans la page ; le parcours reste le premier.
      web.emit(<String, dynamic>{'type': 'pickGpx'});
      await settle(tester);
      await settle(tester);
      web.emit(<String, dynamic>{'type': 'pickGpx'});
      await settle(tester);
      await settle(tester);
      final List<Object?> sent = web.argumentsOf('gpx');
      expect(sent, hasLength(2));
      final Map<String, dynamic> one = sent.first! as Map<String, dynamic>;
      expect(one['name'], 'premier.gpx');
      expect(utf8.decode(base64Decode(one['base64'] as String)), fixtureGpx());

      web.emit(
        done(
          payload: <String, dynamic>{'file': true, 'fileId': one['id']},
          nameSuggestion: 'Col de test',
        ),
      );
      await pumps(tester);
      await tester.tap(find.byKey(keys.routeEditor.saveButton));
      await pumps(tester);

      final created = routes.created.single;
      expect(created.gpx, first);
      expect(created.request.plannerState, isNull);
      expect(created.request.points, isNull);
    });

    testWidgets(
      'quitter le formulaire avec un tracé non repris : la question',
      (WidgetTester tester) async {
        final _FakePlannerWeb web = _FakePlannerWeb();
        await open(
          tester,
          routes: _StubRoutes(detail: singleTrack()),
          picker: _FakePicker(<GpxFile?>[]),
          planner: true,
          web: web,
          routeSlug: 'col-de-la-croix',
        );
        await tester.tap(find.byKey(keys.routeEditor.trackEditButton));
        await pumps(tester);
        web.emit(<String, dynamic>{'type': 'ready'});
        await pumps(tester);

        // Des retouches, puis la flèche de la page : l'écran part sans
        // question, la page reste.
        web.emit(<String, dynamic>{'type': 'dirty', 'dirty': true});
        web.emit(<String, dynamic>{'type': 'close', 'dirty': true});
        await pumps(tester);
        expect(find.byKey(keys.routeEditor.plannerScreen), findsNothing);
        expect(web.disposed, isFalse);
        expect(find.byKey(keys.routeEditor.plannerUnvalidated), findsOneWidget);

        // Le formulaire, lui, demande avant de partir.
        final NavigatorState navigator = tester.state<NavigatorState>(
          find.byType(Navigator).last,
        );
        await navigator.maybePop();
        await pumps(tester);
        expect(find.text('Abandonner les modifications ?'), findsOneWidget);
        expect(find.byKey(keys.routeEditor.nameField), findsOneWidget);
      },
    );

    group('modification', () {
      Future<_FakePlannerWeb> openEdit(
        WidgetTester tester,
        _StubRoutes routes,
      ) async {
        final _FakePlannerWeb web = _FakePlannerWeb();
        await open(
          tester,
          routes: routes,
          picker: _FakePicker(<GpxFile?>[]),
          planner: true,
          web: web,
          routeSlug: 'col-de-la-croix',
        );
        return web;
      }

      Future<void> edit(WidgetTester tester, _FakePlannerWeb web) async {
        await tester.tap(find.byKey(keys.routeEditor.trackEditButton));
        await pumps(tester);
        web.emit(<String, dynamic>{'type': 'ready'});
        await pumps(tester);
      }

      testWidgets('« Modifier le tracé » à côté de « Remplacer le GPX »', (
        WidgetTester tester,
      ) async {
        final _StubRoutes routes = _StubRoutes(detail: singleTrack())
          ..plannerState = PlannerState.fromJson(fixturePlannerStateJson);
        final _FakePlannerWeb web = await openEdit(tester, routes);

        expect(find.text('Modifier le tracé'), findsOneWidget);
        expect(find.byKey(keys.routeEditor.trackReplaceButton), findsOneWidget);
        // L'état n'est lu qu'à l'ouverture du planificateur.
        expect(routes.plannerStateReads, 0);

        await edit(tester, web);
        expect(routes.plannerStateReads, 1);
        final Map<String, dynamic> load =
            web.argumentsOf('load').single! as Map<String, dynamic>;
        expect(load['create'], isFalse);
        expect(load['routeName'], 'Col de la Croix');
        expect(load['ascend'], 800);
        expect(load['waypointsTotal'], 50000);
        expect(load['waypoints'], isEmpty);
        expect(load['track'], <dynamic>[
          <dynamic>[5.0, 45.0, 200.0, 0.0],
          <dynamic>[5.01, 45.01, 230.0, 1400.0],
        ]);
        // L'état, sans les `null` que les DTO écrivent pour un champ absent.
        expect(load['state'], fixturePlannerStateJson);
      });

      testWidgets('tracé retouché : l\'état part, sans fichier', (
        WidgetTester tester,
      ) async {
        final _StubRoutes routes = _StubRoutes(detail: singleTrack());
        final _FakePlannerWeb web = await openEdit(tester, routes);
        await edit(tester, web);
        web.emit(
          done(
            payload: <String, dynamic>{
              'plannerState': fixturePlannerStateJson,
              'waypoints': <dynamic>[
                <String, dynamic>{
                  'position': <String, dynamic>{'lng': 5.0, 'lat': 45.0},
                  'type': 'WATER',
                  'name': 'Fontaine',
                },
              ],
            },
          ),
        );
        await pumps(tester);

        expect(find.byKey(keys.routeEditor.plannerPreview), findsOneWidget);
        expect(
          find.text('Remplacera le tracé à l\'enregistrement'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(keys.routeEditor.saveButton));
        await pumps(tester);

        final update = routes.updated.single;
        expect(update.gpx, isNull);
        expect(update.request.plannerState, isNotNull);
        expect(update.request.points, isNull);
        expect(update.request.waypoints!.single.name, 'Fontaine');
      });

      testWidgets('tracé laissé tel quel : rien ne part du tracé', (
        WidgetTester tester,
      ) async {
        final _StubRoutes routes = _StubRoutes(detail: singleTrack());
        final _FakePlannerWeb web = await openEdit(tester, routes);
        await edit(tester, web);
        web.emit(done(payload: const <String, dynamic>{}, dirty: false));
        await pumps(tester);

        expect(find.byKey(keys.routeEditor.plannerPreview), findsNothing);
        await tester.tap(find.byKey(keys.routeEditor.saveButton));
        await pumps(tester);

        final update = routes.updated.single;
        expect(update.gpx, isNull);
        expect(update.request.plannerState, isNull);
        expect(update.request.points, isNull);
        expect(update.request.waypoints, isNull);
      });

      testWidgets('état trop grand : les points, puis l\'avertissement', (
        WidgetTester tester,
      ) async {
        final _StubRoutes routes = _StubRoutes(detail: singleTrack());
        final _FakePlannerWeb web = await openEdit(tester, routes);
        await edit(tester, web);
        web.emit(
          done(
            payload: <String, dynamic>{
              'points': <dynamic>[
                <String, dynamic>{'lng': 5.0, 'lat': 45.0},
                <String, dynamic>{'lng': 5.01, 'lat': 45.01},
              ],
            },
            notice: 'tooLarge',
          ),
        );
        await pumps(tester);
        await tester.tap(find.byKey(keys.routeEditor.saveButton));
        await pumps(tester);

        final update = routes.updated.single;
        expect(update.request.plannerState, isNull);
        expect(update.request.points, hasLength(2));
        expect(
          find.textContaining('Tracé enregistré sans ses points de contrôle'),
          findsOneWidget,
        );
      });

      testWidgets('état illisible : le tracé s\'ouvre en import, et le dit', (
        WidgetTester tester,
      ) async {
        final _StubRoutes routes = _StubRoutes(detail: singleTrack())
          ..plannerStateFails = true;
        final _FakePlannerWeb web = await openEdit(tester, routes);
        await edit(tester, web);

        final Map<String, dynamic> load =
            web.argumentsOf('load').single! as Map<String, dynamic>;
        expect(load.containsKey('state'), isFalse);
        expect(load['track'], isNotEmpty);
        expect(load['create'], isFalse);

        web.emit(<String, dynamic>{'type': 'close', 'dirty': false});
        await pumps(tester);
        expect(find.byKey(keys.routeEditor.plannerWarning), findsOneWidget);
        expect(
          find.textContaining(
            'Les points de contrôle enregistrés n\'ont pas pu être relus',
          ),
          findsWidgets,
        );
        expect(find.byKey(keys.routeEditor.plannerUnvalidated), findsNothing);
      });

      testWidgets('plusieurs traces : le GPX seulement', (
        WidgetTester tester,
      ) async {
        final _StubRoutes routes = _StubRoutes(
          detail: fixtureRouteDetail(
            permissions: permissionsFor(member: true, role: 'ORGANIZER'),
            tracks: const <TrackDto>[fixtureTrack, fixtureTrack],
          ),
        );
        await openEdit(tester, routes);

        expect(find.byKey(keys.routeEditor.trackReplaceButton), findsOneWidget);
        expect(find.byKey(keys.routeEditor.trackEditButton), findsNothing);
        // La case, elle, ne dépend que de l'équipe.
        expect(
          find.byKey(keys.routeEditor.excludedFromGenerator),
          findsOneWidget,
        );
      });

      testWidgets('quota épuisé : « Modifier le tracé » désactivé', (
        WidgetTester tester,
      ) async {
        final _FakePlannerWeb web = _FakePlannerWeb();
        await open(
          tester,
          routes: _StubRoutes(detail: singleTrack()),
          picker: _FakePicker(<GpxFile?>[]),
          planner: true,
          quota: const PlannerQuotaDto(
            used: 21,
            limit: 20,
            resetsOn: '2026-12-01',
          ),
          web: web,
          routeSlug: 'col-de-la-croix',
        );

        expect(find.byKey(keys.routeEditor.quotaMessage), findsOneWidget);
        await tester.tap(find.byKey(keys.routeEditor.trackEditButton));
        await pumps(tester);
        expect(web.created, 0);
      });

      testWidgets('« Ne pas utiliser pour générer des parcours »', (
        WidgetTester tester,
      ) async {
        final _StubRoutes routes = _StubRoutes(
          detail: singleTrack(excludedFromGenerator: true),
        );
        await openEdit(tester, routes);

        expect(
          find.text('Ne pas utiliser pour générer des parcours'),
          findsOneWidget,
        );
        final Finder box = find.byKey(keys.routeEditor.excludedFromGenerator);
        expect(tester.widget<PdlSwitch>(box).value, isTrue);

        await tester.tap(box);
        await pumps(tester, 2);
        expect(tester.widget<PdlSwitch>(box).value, isFalse);
        await tester.tap(find.byKey(keys.routeEditor.saveButton));
        await pumps(tester);

        expect(routes.updated.single.request.excludedFromGenerator, isFalse);
      });
    });
  });
}
