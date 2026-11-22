import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/gpxtools/data/gpx_preview_repository.dart';
import 'package:pedalons/features/gpxtools/presentation/pages/gpx_preview_editor_page.dart';
import 'package:pedalons/features/routes/data/gpx_file_source.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// docs/LEDGER_*.md MOB-178 : l'éditeur d'un aperçu — ce qui part à la
/// modification (le nom, le départ changé et lui seul), le refus à qui n'a
/// pas déposé l'aperçu, la création depuis un fichier puis son renommage.

const ConfigDto _config = ConfigDto(
  webAuthnRpId: 'localhost',
  appName: 'Pédalons',
  singleTeam: false,
  enableGpxPlanner: false,
  mapStyles: <MapStyleDto>[],
  tileServerBaseUrl: 'https://tiles.test',
  defaultCenter: MapCenterDto(lat: 46.6, lon: 2.5, zoom: 5),
  gpsAutoSyncEnabled: false,
);

GpxPreviewDto _preview({
  bool owned = true,
  String? departureTime = '2026-11-28T08:30:00Z',
  double? averageSpeed = 24,
}) => GpxPreviewDto(
  id: 'p1',
  name: 'Boucle du dimanche',
  distance: 30000,
  elevationGain: 420,
  elevationLoss: 410,
  hilliness: 14,
  elevationState: 'HD',
  owned: owned,
  createdAt: '2026-11-20T08:00:00Z',
  gpxUrl: '/api/gpx-previews/p1/gpx',
  fitUrl: '/api/gpx-previews/p1/fit',
  drawn: false,
  tracks: const <TrackDto>[],
  waypoints: const <WaypointDto>[],
  departureTime: departureTime,
  departureTimezone: departureTime == null ? null : 'Europe/Paris',
  averageSpeed: averageSpeed,
);

class _FakeRepository implements GpxPreviewRepository {
  _FakeRepository(this.preview);

  final GpxPreviewDto preview;
  final List<(String, GpxPreviewUpdateRequest, String?)> updates =
      <(String, GpxPreviewUpdateRequest, String?)>[];
  final List<(String, String?, double?)> uploads =
      <(String, String?, double?)>[];

  @override
  Future<GpxPreviewDto> get(String previewId) async => preview;

  @override
  Future<GpxPreviewDto> update(
    String previewId,
    GpxPreviewUpdateRequest request, {
    GpxFile? gpx,
  }) async {
    updates.add((previewId, request, gpx?.name));
    return preview.copyWith(name: request.name);
  }

  @override
  Future<GpxPreviewDto> createFromFile(
    GpxFile file, {
    String? departure,
    double? averageSpeed,
  }) async {
    uploads.add((file.name, departure, averageSpeed));
    return preview.copyWith(id: 'new1', name: 'boucle');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker implements GpxFilePicker {
  _Picker(this.file);
  final GpxFile? file;
  @override
  Future<GpxFile?> pick() async => file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('gpxeditor'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<_FakeRepository> open(
    WidgetTester tester, {
    String? previewId = 'p1',
    GpxPreviewDto? preview,
    GpxFile? file,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _FakeRepository repository = _FakeRepository(preview ?? _preview());
    final GoRouter router = GoRouter(
      initialLocation: '/e',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('fiche'),
          routes: <RouteBase>[
            GoRoute(
              path: 'e',
              builder: (_, _) => GpxPreviewEditorPage(previewId: previewId),
            ),
            GoRoute(
              path: 'outils-gpx/:id',
              builder: (_, GoRouterState s) =>
                  Text('fiche ${s.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gpxPreviewRepositoryProvider.overrideWithValue(repository),
          appConfigProvider.overrideWith((Ref ref) async => _config),
          gpxFilePickerProvider.overrideWith((Ref ref) => _Picker(file)),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    return repository;
  }

  testWidgets('renommer seulement : le nom part, ni tracé ni départ', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = await open(tester);
    expect(find.text('Boucle du dimanche'), findsWidgets);

    await tester.enterText(
      find.byKey(keys.gpxTools.editorName),
      'Boucle du lundi',
    );
    await tester.tap(find.byKey(keys.gpxTools.editorSave));
    await settle(tester);

    expect(repo.updates, hasLength(1));
    final (String id, GpxPreviewUpdateRequest request, String? gpx) =
        repo.updates.single;
    expect(id, 'p1');
    expect(gpx, isNull);
    expect(request.name, 'Boucle du lundi');
    expect(request.points, isNull);
    expect(request.plannerState, isNull);
    expect(request.departure, isNull);
    expect(request.clearDeparture, isNull);
    expect(request.averageSpeed, isNull);
    expect(request.clearAverageSpeed, isNull);
    expect(find.text('fiche'), findsOneWidget);
  });

  testWidgets('retirer la date : clearDeparture, la vitesse reste', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = await open(tester);
    await tester.tap(find.byKey(keys.gpxTools.editorClearDeparture));
    await settle(tester);
    await tester.tap(find.byKey(keys.gpxTools.editorSave));
    await settle(tester);

    final GpxPreviewUpdateRequest request = repo.updates.single.$2;
    expect(request.clearDeparture, isTrue);
    expect(request.departure, isNull);
    expect(request.averageSpeed, isNull);
    expect(request.clearAverageSpeed, isNull);
  });

  testWidgets('une vitesse hors des bornes ne part pas', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = await open(tester);
    await tester.enterText(find.byKey(keys.gpxTools.editorSpeed), '5');
    await tester.tap(find.byKey(keys.gpxTools.editorSave));
    await settle(tester);

    expect(repo.updates, isEmpty);
    expect(find.text('Saisissez une vitesse entre 10 et 60.'), findsOneWidget);
  });

  testWidgets('qui n’a pas déposé l’aperçu ne le modifie pas', (
    WidgetTester tester,
  ) async {
    await open(tester, preview: _preview(owned: false));
    expect(
      find.text('Seule la personne qui a déposé ce fichier peut le modifier.'),
      findsOneWidget,
    );
    expect(find.byKey(keys.gpxTools.editorSave), findsNothing);
  });

  testWidgets('créer sans tracé : le mot, rien ne part', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = await open(tester, previewId: null);
    await tester.enterText(find.byKey(keys.gpxTools.editorName), 'Ma boucle');
    await tester.tap(find.byKey(keys.gpxTools.editorSave));
    await settle(tester);

    expect(repo.uploads, isEmpty);
    expect(find.text('Tracez au moins deux points sur la carte.'), findsOne);
  });

  testWidgets('créer depuis un fichier : l’envoi, puis le nom saisi, puis la '
      'fiche', (WidgetTester tester) async {
    final File f = File('${dir.path}/boucle.gpx')
      ..writeAsStringSync('<gpx version="1.1"></gpx>');
    final _FakeRepository repo = await open(
      tester,
      previewId: null,
      preview: _preview(departureTime: null, averageSpeed: null),
      file: GpxFile(path: f.path, name: 'boucle.gpx', size: f.lengthSync()),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(keys.routeEditor.trackChangeButton));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    await tester.enterText(find.byKey(keys.gpxTools.editorName), 'Ma boucle');
    await tester.tap(find.byKey(keys.gpxTools.editorSave));
    await settle(tester);

    expect(repo.uploads, <(String, String?, double?)>[
      ('boucle.gpx', null, null),
    ]);
    expect(repo.updates.single.$1, 'new1');
    expect(repo.updates.single.$2.name, 'Ma boucle');
    expect(find.text('fiche new1'), findsOneWidget);
  });
}
