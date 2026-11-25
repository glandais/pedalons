import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/gpxtools/data/gpx_preview_repository.dart';
import 'package:pedalons/features/gpxtools/data/received_gpx_file.dart';
import 'package:pedalons/features/gpxtools/presentation/pages/received_gpx_page.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// docs/LEDGER_*.md MOB-191 : « Ouvrir avec Pédalons », l'écran « Fichier
/// reçu ».

GpxPreviewDto _created(String id) => GpxPreviewDto(
  id: id,
  name: 'Boucle',
  distance: 1000,
  elevationGain: 10,
  elevationLoss: 10,
  hilliness: 10,
  elevationState: 'HD',
  owned: true,
  createdAt: '2026-11-22T08:00:00Z',
  gpxUrl: '/api/gpx-previews/$id/gpx',
  fitUrl: '/api/gpx-previews/$id/fit',
  drawn: false,
  tracks: const <TrackDto>[],
  waypoints: const <WaypointDto>[],
);

class _FakeRepository implements GpxPreviewRepository {
  final List<String> uploaded = <String>[];

  @override
  Future<GpxPreviewDto> createFromFile(
    GpxFile file, {
    String? departure,
    double? averageSpeed,
  }) async {
    uploaded.add(file.name);
    return _created('new1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('received'));
  tearDown(() => dir.deleteSync(recursive: true));

  GpxFile file(String name, String body) {
    final File f = File('${dir.path}/$name')..writeAsStringSync(body);
    return GpxFile(path: f.path, name: name, size: f.lengthSync());
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_FakeRepository> open(WidgetTester tester, GpxFile received) async {
    tester.view.physicalSize = const Size(402 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _FakeRepository repository = _FakeRepository();
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('accueil'),
          routes: <RouteBase>[
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
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      showReceivedGpxPage(
        router.routerDelegate.navigatorKey.currentState!,
        received,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    // Le contrôle local lit le fichier sur le disque : une vraie attente.
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    return repository;
  }

  test('seuls file:// et content:// sont des fichiers reçus', () {
    expect(
      isReceivedFileUri(Uri.parse('file:///private/var/Inbox/a.gpx')),
      isTrue,
    );
    expect(
      isReceivedFileUri(Uri.parse('content://com.android.providers/doc/12')),
      isTrue,
    );
    expect(
      isReceivedFileUri(Uri.parse('https://www.pedalons.fr/outils-gpx')),
      isFalse,
    );
  });

  testWidgets('un GPX : son nom, deux choix sans « Fusionner », Visualiser ouvre la fiche '
      'et efface la copie', (WidgetTester tester) async {
    final GpxFile received = file(
      'sortie.gpx',
      '<gpx version="1.1"><metadata><name>Sortie du dimanche</name>'
          '</metadata></gpx>',
    );
    final _FakeRepository repo = await open(tester, received);

    expect(find.text('Fichier reçu'), findsOneWidget);
    expect(find.text('Sortie du dimanche'), findsOneWidget);
    expect(find.text('sortie.gpx'), findsOneWidget);
    expect(find.byKey(keys.gpxTools.receivedView), findsOneWidget);
    expect(find.byKey(keys.gpxTools.receivedSaveToTeam), findsOneWidget);
    expect(find.textContaining('Fusionner'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(keys.gpxTools.receivedView));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);

    expect(repo.uploaded, <String>['sortie.gpx']);
    expect(find.text('fiche new1'), findsOneWidget);
    expect(find.byKey(keys.gpxTools.received), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(File(received.path).existsSync(), isFalse);
  });

  testWidgets('un fichier qui n’est pas un GPX : refusé, rien ne part', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repo = await open(
      tester,
      file('notes.txt', 'pas un gpx'),
    );

    expect(find.byKey(keys.gpxTools.receivedRefused), findsOneWidget);
    await tester.tap(find.byKey(keys.gpxTools.receivedView));
    await settle(tester);
    expect(repo.uploaded, isEmpty);
    expect(find.byKey(keys.gpxTools.received), findsOneWidget);
  });
}
