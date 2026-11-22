import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/gpxtools/data/gpx_files_picker.dart';
import 'package:pedalons/features/gpxtools/data/gpx_preview_repository.dart';
import 'package:pedalons/features/gpxtools/presentation/pages/gpx_tools_page.dart';
import 'package:pedalons/features/gpxtools/presentation/pages/my_gpx_previews_page.dart';
import 'package:pedalons/features/routes/data/gpx_file_source.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// docs/LEDGER_*.md MOB-178 : l'accueil des outils GPX (voir un fichier, en
/// fusionner plusieurs) et « Mes fichiers ».

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

GpxPreviewSummaryDto _summary(String id, {String? departureTime}) =>
    GpxPreviewSummaryDto(
      id: id,
      name: 'Fichier $id',
      distance: 42000,
      elevationGain: 600,
      elevationLoss: 590,
      hilliness: 14,
      createdAt: '2026-11-20T08:00:00Z',
      departureTime: departureTime,
      departureTimezone: departureTime == null ? null : 'Europe/Paris',
    );

class _FakeRepository implements GpxPreviewRepository {
  final List<String> uploaded = <String>[];
  final List<List<String>> merged = <List<String>>[];
  final List<String> deleted = <String>[];
  List<GpxPreviewSummaryDto> mine = <GpxPreviewSummaryDto>[];

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
  Future<GpxPreviewDto> merge(List<GpxFile> files) async {
    merged.add(<String>[for (final GpxFile f in files) f.name]);
    return _created('merged1');
  }

  @override
  Future<PageResult<GpxPreviewSummaryDto>> listMine({
    required int page,
    required int size,
  }) async => PageResult<GpxPreviewSummaryDto>(items: mine, total: mine.length);

  @override
  Future<void> delete(String previewId) async {
    deleted.add(previewId);
    mine = <GpxPreviewSummaryDto>[
      for (final GpxPreviewSummaryDto p in mine)
        if (p.id != previewId) p,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ConfigDto _config({required bool planner}) => ConfigDto(
  webAuthnRpId: 'localhost',
  appName: 'Pédalons',
  singleTeam: false,
  enableGpxPlanner: planner,
  mapStyles: const <MapStyleDto>[],
  tileServerBaseUrl: 'https://tiles.test',
  defaultCenter: const MapCenterDto(lat: 46.6, lon: 2.5, zoom: 5),
  gpsAutoSyncEnabled: false,
);

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Une session dont le quota personnel des outils GPX vaut [quota].
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref, PlannerQuotaDto quota)
    : super(_FakeAuthRepository(), _FakeSecureStorage(), ref) {
    state = AuthState(
      isInitialized: true,
      accessToken: 'token',
      user: UserDto(
        plannerQuota: quota,
        id: 'u-me',
        email: 'moi@example.org',
        displayName: 'Moi',
        contactableByMembers: true,
        emailVerified: true,
        connectedServices: const <GpsServiceConnectionDto>[],
      ),
    );
  }
}

class _Picker implements GpxFilePicker {
  _Picker(this.file);
  final GpxFile? file;
  @override
  Future<GpxFile?> pick() async => file;
}

class _ManyPicker implements GpxFilesPicker {
  _ManyPicker(this.files);
  final List<GpxFile> files;
  @override
  Future<List<GpxFile>> pickMany() async => files;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('gpxtools'));
  tearDown(() => dir.deleteSync(recursive: true));

  GpxFile gpx(String name, {String body = '<gpx version="1.1"></gpx>'}) {
    final File f = File('${dir.path}/$name')..writeAsStringSync(body);
    return GpxFile(path: f.path, name: name, size: f.lengthSync());
  }

  /// Des images bornées : le squelette d'une liste qui se recharge anime
  /// sans fin, `pumpAndSettle` n'en verrait pas le bout.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_FakeRepository> open(
    WidgetTester tester, {
    GpxFile? single,
    List<GpxFile> many = const <GpxFile>[],
    List<GpxPreviewSummaryDto> mine = const <GpxPreviewSummaryDto>[],
    String initial = '/',
    bool planner = false,
    PlannerQuotaDto quota = const PlannerQuotaDto(
      used: 0,
      limit: 10,
      resetsOn: '2026-12-01',
    ),
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _FakeRepository repository = _FakeRepository()..mine = mine;
    final GoRouter router = GoRouter(
      initialLocation: initial,
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const GpxToolsPage(),
          routes: <RouteBase>[
            GoRoute(
              path: 'outils-gpx/mes-fichiers',
              builder: (_, _) => const MyGpxPreviewsPage(),
            ),
            GoRoute(
              path: 'outils-gpx/carte',
              builder: (_, _) => const Text('carte sans tracé'),
            ),
            GoRoute(
              path: 'outils-gpx/nouveau',
              builder: (_, _) => const Text('créer un parcours'),
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
          gpxFilePickerProvider.overrideWith((Ref ref) => _Picker(single)),
          gpxFilesPickerProvider.overrideWith((Ref ref) => _ManyPicker(many)),
          appConfigProvider.overrideWith(
            (Ref ref) async => _config(planner: planner),
          ),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref, quota)),
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

  group('accueil', () {
    testWidgets('visualiser : le fichier part dès le choix, la fiche s’ouvre', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repo = await open(
        tester,
        single: gpx('boucle.gpx'),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(keys.gpxTools.viewFileButton));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);

      expect(repo.uploaded, <String>['boucle.gpx']);
      expect(find.text('fiche new1'), findsOneWidget);
    });

    testWidgets('un fichier qui n’est pas un GPX est refusé, rien ne part', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repo = await open(
        tester,
        single: gpx('notes.txt', body: 'bonjour'),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(keys.gpxTools.viewFileButton));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);

      expect(repo.uploaded, isEmpty);
      expect(find.byKey(keys.routeEditor.refusedBanner), findsOneWidget);
    });

    testWidgets('fusionner : hors de 2..10 fichiers, le mot, et rien ne part', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repo = await open(
        tester,
        many: <GpxFile>[gpx('a.gpx')],
      );
      await tester.tap(find.byKey(keys.gpxTools.mergeButton));
      await settle(tester);

      expect(repo.merged, isEmpty);
      expect(
        find.text(
          'Choisissez entre 2 et 10 fichiers GPX à fusionner (sélection : 1).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('fusionner : deux fichiers partent ensemble', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repo = await open(
        tester,
        many: <GpxFile>[gpx('a.gpx'), gpx('b.gpx')],
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(keys.gpxTools.mergeButton));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);

      expect(repo.merged, <List<String>>[
        <String>['a.gpx', 'b.gpx'],
      ]);
      expect(find.text('fiche merged1'), findsOneWidget);
    });
  });

  testWidgets('« Ouvrir la carte » ouvre la carte sans tracé', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(keys.gpxTools.blankMapButton));
    await settle(tester);
    expect(find.text('carte sans tracé'), findsOneWidget);
  });

  group('créer un parcours', () {
    testWidgets('fermé par le domaine : pas de carte', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.byKey(keys.gpxTools.drawButton), findsNothing);
    });

    testWidgets('ouvert : la carte, son bouton actif, pas de compteur', (
      WidgetTester tester,
    ) async {
      await open(tester, planner: true);
      expect(find.byKey(keys.gpxTools.drawButton), findsOneWidget);
      expect(find.byKey(keys.gpxTools.quotaMessage), findsNothing);
      await tester.tap(find.byKey(keys.gpxTools.drawButton));
      await settle(tester);
      expect(find.text('créer un parcours'), findsOneWidget);
    });

    testWidgets('quota du mois épuisé : le bouton inactif et sa raison', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        planner: true,
        quota: const PlannerQuotaDto(
          used: 10,
          limit: 10,
          resetsOn: '2026-12-01',
        ),
      );
      expect(find.byKey(keys.gpxTools.quotaMessage), findsOneWidget);
      final PdlButton draw = tester.widget<PdlButton>(
        find.byKey(keys.gpxTools.drawButton),
      );
      expect(draw.enabled, isFalse);
    });
  });

  group('mes fichiers', () {
    testWidgets('vide : le mot du site', (WidgetTester tester) async {
      await open(tester, initial: '/outils-gpx/mes-fichiers');
      expect(find.byKey(keys.gpxTools.listEmpty), findsOneWidget);
    });

    testWidgets('une ligne par fichier ; supprimer après confirmation', (
      WidgetTester tester,
    ) async {
      final _FakeRepository repo = await open(
        tester,
        initial: '/outils-gpx/mes-fichiers',
        mine: <GpxPreviewSummaryDto>[
          _summary('a', departureTime: '2026-12-01T08:00:00Z'),
          _summary('b'),
        ],
      );
      expect(find.byKey(keys.gpxTools.row('a')), findsOneWidget);
      expect(find.byKey(keys.gpxTools.row('b')), findsOneWidget);
      expect(find.text('Fichier a'), findsOneWidget);

      await tester.tap(find.byKey(keys.gpxTools.rowDelete('b')));
      await settle(tester);
      await tester.tap(find.text('Supprimer').last);
      await settle(tester);

      expect(repo.deleted, <String>['b']);
      expect(find.byKey(keys.gpxTools.row('b')), findsNothing);
      expect(find.byKey(keys.gpxTools.row('a')), findsOneWidget);
    });

    testWidgets('toucher une ligne ouvre sa fiche', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        initial: '/outils-gpx/mes-fichiers',
        mine: <GpxPreviewSummaryDto>[_summary('a')],
      );
      await tester.tap(find.text('Fichier a'));
      await settle(tester);
      expect(find.text('fiche a'), findsOneWidget);
    });
  });
}
