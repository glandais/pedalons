import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/data/gpx_file_source.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';
import 'package:pedalons/features/routes/presentation/pages/route_editor_page.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'route_fixtures.dart';

/// L'éditeur de parcours (ledger `MOB-79`) : le refus pour qui n'organise pas,
/// le contrôle du fichier, et surtout **ce qui part** — la requête et le
/// fichier que le serveur recevra.
class _StubRoutes implements RouteRepository {
  _StubRoutes({RouteDetailDto? detail})
    : detail = detail ?? fixtureRouteDetail();

  final RouteDetailDto detail;

  /// Si posé, `createRoute` / `updateRoute` lèvent cette erreur.
  Object? failWith;

  final List<({String team, RouteRequest request, GpxFile gpx})> created = [];
  final List<({String slug, RouteRequest request, GpxFile? gpx})> updated = [];

  @override
  Future<RouteDetailDto> getRouteDetail(
    String teamSlug,
    String routeSlug,
  ) async => detail;

  RouteDto _dto(String slug, String name) => RouteDto(
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
    required GpxFile gpx,
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

  @override
  Future<TeamDetailDto> getTeam(String slug) async => team;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      team.role == null ? <TeamDetailDto>[] : <TeamDetailDto>[team];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  Future<void> open(
    WidgetTester tester, {
    required _StubRoutes routes,
    required _FakePicker picker,
    String? role = 'ORGANIZER',
    String teamVisibility = 'PUBLIC',
    bool enableRoutes = true,
    String? routeSlug,
    bool replaceGpx = false,
  }) async {
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
          builder: (BuildContext _, GoRouterState _) => const Text('accueil'),
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
          teamRepositoryProvider.overrideWithValue(
            _StubTeams(
              fixtureRouteTeam(
                role: role,
                visibility: teamVisibility,
                enableRoutes: enableRoutes,
              ),
            ),
          ),
          gpxFilePickerProvider.overrideWith((Ref _) => picker),
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
    expect(find.text('Réservé aux organisateurs'), findsOneWidget);
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
}
