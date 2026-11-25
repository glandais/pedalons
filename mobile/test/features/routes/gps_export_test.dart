import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/share_file.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/home/presentation/widgets/next_ride_card.dart';
import 'package:pedalons/features/home/providers/next_ride_provider.dart';
import 'package:pedalons/features/rides/domain/ride_group_action.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_route_actions.dart';
import 'package:pedalons/features/routes/presentation/gps_export_runner.dart';
import 'package:pedalons/features/routes/presentation/gps_sheet.dart';
import 'package:pedalons/features/routes/presentation/widgets/gps_button.dart';
import 'package:pedalons/features/routes/providers/route_detail_provider.dart';
import 'package:pedalons/features/teams/presentation/widgets/dashboard/dashboard_rides.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import 'route_fixtures.dart';

/// docs/plans/2026-11-10-refonte-ecrans-detail-mobile.md, lot 4 : un seul
/// bouton « GPS » et une seule feuille partout où un parcours s'exporte, et
/// un seul contrôleur d'export (`GpsExportRunner`).

const AssetDto _gpx = AssetDto(
  id: 'a-gpx',
  fileName: 'col.gpx',
  contentType: 'application/gpx+xml',
  url: '/api/download/public/col.gpx',
);
const AssetDto _fit = AssetDto(
  id: 'a-fit',
  fileName: 'col.fit',
  contentType: 'application/vnd.ant.fit',
  url: '/api/download/public/col.fit',
);

GpsServiceConnectionDto _service(String type, String name) =>
    GpsServiceConnectionDto(
      serviceType: type,
      displayName: name,
      connectedAt: '2026-09-01T10:00:00Z',
      autoSync: false,
      autoSyncState: 'OFF',
      autoSyncRouteCount: 0,
    );

final List<GpsServiceConnectionDto> _services = <GpsServiceConnectionDto>[
  _service('GARMIN', 'Garmin Connect'),
  _service('HAMMERHEAD', 'Hammerhead Karoo'),
];

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref, List<GpsServiceConnectionDto> services)
    : super(_FakeAuthRepository(), _FakeSecureStorage(), ref) {
    state = AuthState(
      isInitialized: true,
      accessToken: 'token',
      user: UserDto(
        plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
        id: 'u-me',
        email: 'moi@example.org',
        displayName: 'Moi',
        contactableByMembers: true,
        emailVerified: true,
        connectedServices: services,
      ),
    );
  }
}

/// Les gestes d'export, enregistrés au lieu d'atteindre le sélecteur de
/// fichier, la feuille de partage ou l'API.
class _Ops {
  final List<(AssetDto, AssetDestination, Rect)> delivered =
      <(AssetDto, AssetDestination, Rect)>[];
  final List<(String, String, String)> uploaded = <(String, String, String)>[];
  final List<(String, String)> previewUploaded = <(String, String)>[];
  Completer<bool>? pendingDelivery;
  Object? uploadError;

  RouteExportOperations get operations => RouteExportOperations(
    deliver:
        (
          WidgetRef ref,
          AssetDto asset,
          AssetDestination destination, {
          required Rect origin,
        }) {
          delivered.add((asset, destination, origin));
          return pendingDelivery?.future ??
              Future<bool>.value(destination == AssetDestination.device);
        },
    upload:
        (
          WidgetRef ref,
          GpsServiceConnectionDto service, {
          required String teamSlug,
          required String routeSlug,
        }) async {
          uploaded.add((service.serviceType, teamSlug, routeSlug));
          if (uploadError != null) throw uploadError!;
        },
    uploadPreview:
        (
          WidgetRef ref,
          GpsServiceConnectionDto service, {
          required String previewId,
        }) async {
          previewUploaded.add((service.serviceType, previewId));
          if (uploadError != null) throw uploadError!;
        },
  );
}

/// [body] sous [platform] : la variable de fondation doit être rendue avant
/// la fin du test, pas dans un `tearDown`.
Future<void> onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Un hôte minimal du contrôleur d'export : le bouton « GPS » d'un parcours
/// et ses bandeaux, comme `RouteSection` les pose — la rangée d'actions de la
/// fiche embarquée qui jouait ce rôle est partie avec le lot 11 de
/// `MOB-134`.
class _RouteGps extends ConsumerStatefulWidget {
  const _RouteGps({this.route, this.target});

  final RouteDetailDto? route;

  /// Une cible donnée telle quelle — l'aperçu GPX (docs/LEDGER_*.md MOB-178).
  final GpsExportTarget? target;

  @override
  ConsumerState<_RouteGps> createState() => _RouteGpsState();
}

class _RouteGpsState extends ConsumerState<_RouteGps>
    with GpsExportRunner<_RouteGps> {
  @override
  Widget build(BuildContext context) {
    final RouteDetailDto? route = widget.route;
    final GpsExportTarget target =
        widget.target ??
        GpsExportTarget(
          subtitle: route!.name,
          teamSlug: route.team.slug,
          routeSlug: route.slug,
          gpx: route.media.assets.gpx,
          fit: route.media.assets.fit,
          syncStatuses: route.gpsSyncStatuses,
        );
    if (!target.offered(watchGpsServices())) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...gpsExportBanners(gap: PdlSpacing.chipGap),
        GpsButton(
          key: keys.routeDetail.gps,
          loading: gpsExporting,
          onPressed: (BuildContext button) => openGpsSheet(target, button),
        ),
      ],
    );
  }
}

/// Un écran de détail réduit à sa barre : « GPS » en action de barre
/// (`GpsAppBarAction`), l'issue de l'export en bandeau dans le corps.
class _BarGps extends ConsumerStatefulWidget {
  const _BarGps({required this.target});

  final GpsExportTarget target;

  @override
  ConsumerState<_BarGps> createState() => _BarGpsState();
}

class _BarGpsState extends ConsumerState<_BarGps>
    with GpsExportRunner<_BarGps> {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          if (widget.target.offered(watchGpsServices()))
            GpsAppBarAction(
              key: keys.ride.gps,
              busy: gpsExporting,
              onPressed: (BuildContext button) =>
                  openGpsSheet(widget.target, button),
            ),
        ],
      ),
      ...gpsExportBanners(gapBefore: true),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_Ops> pump(
    WidgetTester tester,
    Widget child, {
    List<GpsServiceConnectionDto> services = const <GpsServiceConnectionDto>[],
    RouteDetailDto? nextRideRoute,
  }) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _Ops ops = _Ops();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          unitSystemProvider.overrideWithValue(UnitSystem.metric),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref, services)),
          routeExportOperationsProvider.overrideWithValue(ops.operations),
          // Les fichiers du parcours de « Ma prochaine sortie », que sa ligne
          // de liste ne porte pas.
          nextRideRouteFilesProvider.overrideWith(
            (Ref ref, RouteKey key) async => nextRideRoute,
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
    return ops;
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  RouteDetailDto route({AssetDto? gpx = _gpx, AssetDto? fit = _fit}) =>
      fixtureRouteDetail().copyWith(
        media: fixtureEmptyMedia.copyWith(
          assets: fixtureEmptyMedia.assets.copyWith(gpx: gpx, fit: fit),
        ),
      );

  Future<void> openFromRoute(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.routeDetail.gps));
    await settle(tester);
    expect(find.byKey(keys.gpsSheet.sheet), findsOneWidget);
  }

  /// Le libellé de section, dans la feuille.
  Finder inSheet(String text) => find.descendant(
    of: find.byKey(keys.gpsSheet.sheet),
    matching: find.text(text),
  );

  group('la feuille GPS', () {
    testWidgets('Android, services connectés : appareils, GPX, FIT, deux '
        'lignes par fichier, et pas de « Connecter un compteur »', (
      WidgetTester tester,
    ) async {
      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, _RouteGps(route: route()), services: _services);
        await openFromRoute(tester);

        expect(inSheet('GPS'), findsOneWidget);
        expect(inSheet('Col de la Croix'), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.toDevice), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.service('GARMIN')), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.service('HAMMERHEAD')), findsOneWidget);
        for (final Key key in <Key>[
          keys.gpsSheet.gpxSave,
          keys.gpsSheet.gpxShare,
          keys.gpsSheet.fitSave,
          keys.gpsSheet.fitShare,
        ]) {
          expect(find.byKey(key), findsOneWidget);
        }
        expect(inSheet('Enregistrer sur le téléphone'), findsNWidgets(2));
        expect(inSheet('Envoyer vers une autre app'), findsNWidgets(2));
        expect(find.byKey(keys.gpsSheet.connectDevice), findsNothing);

        // Dans l'ordre de la maquette.
        double top(Key k) => tester.getTopLeft(find.byKey(k)).dy;
        expect(
          top(keys.gpsSheet.toDevice),
          lessThan(top(keys.gpsSheet.gpxSave)),
        );
        expect(
          top(keys.gpsSheet.gpxShare),
          lessThan(top(keys.gpsSheet.fitSave)),
        );
      });
    });

    testWidgets('iOS : une seule ligne « Partager » par fichier', (
      WidgetTester tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, _RouteGps(route: route()), services: _services);
        await openFromRoute(tester);

        expect(find.byKey(keys.gpsSheet.service('GARMIN')), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.gpxSave), findsNothing);
        expect(find.byKey(keys.gpsSheet.fitSave), findsNothing);
        expect(find.byKey(keys.gpsSheet.gpxShare), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.fitShare), findsOneWidget);
        expect(inSheet('Partager'), findsNWidgets(2));
        expect(inSheet('Enregistrer sur le téléphone'), findsNothing);
      });
    });

    // docs/LEDGER_*.md MOB-133 : où en est déjà le parcours, service par
    // service.
    testWidgets('chaque service dit où en est déjà le parcours ; sans état, '
        'rien', (WidgetTester tester) async {
      await pump(
        tester,
        _RouteGps(
          route: route().copyWith(
            gpsSyncStatuses: const <RouteGpsSyncStatusDto>[
              RouteGpsSyncStatusDto(serviceType: 'GARMIN', state: 'OUTDATED'),
            ],
          ),
        ),
        services: _services,
      );
      await openFromRoute(tester);

      Finder under(String service, String text) => find.descendant(
        of: find.byKey(keys.gpsSheet.service(service)),
        matching: find.text(text),
      );
      expect(
        under('GARMIN', 'Une version précédente y est : renvoyez-le'),
        findsOneWidget,
      );
      // Hammerhead n'a pas d'état : sa ligne n'a que son nom.
      expect(
        find.descendant(
          of: find.byKey(keys.gpsSheet.service('HAMMERHEAD')),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });

    test('gpsRouteStatusLine : un libellé par état, rien sans état', () {
      RouteGpsSyncStatusDto st(String state, [String? at]) =>
          RouteGpsSyncStatusDto(
            serviceType: 'WAHOO',
            state: state,
            syncedAt: at,
          );
      expect(gpsRouteStatusLine(null), isNull);
      expect(gpsRouteStatusLine(st('SENT')), 'Déjà envoyé');
      expect(
        gpsRouteStatusLine(st('SENT', '2026-11-15T08:30:00Z')),
        startsWith('Déjà envoyé · '),
      );
      expect(gpsRouteStatusLine(st('PENDING')), 'Envoi en cours…');
      expect(gpsRouteStatusLine(st('FAILING')), 'Le dernier envoi a échoué');
      expect(
        gpsRouteStatusLine(st('RECONNECT_REQUIRED')),
        'Accès refusé : reconnectez le service',
      );
      // Une valeur ajoutée côté serveur plus tard : rien plutôt qu'un faux.
      expect(gpsRouteStatusLine(st('SOMETHING_NEW')), isNull);
    });

    test('gpsTargetOfGroup : les états du groupe passent devant ceux de la '
        'route', () {
      const List<RouteGpsSyncStatusDto> ofGroup = <RouteGpsSyncStatusDto>[
        RouteGpsSyncStatusDto(serviceType: 'GARMIN', state: 'PENDING'),
      ];
      final RouteDetailDto withOwn = route().copyWith(
        gpsSyncStatuses: const <RouteGpsSyncStatusDto>[
          RouteGpsSyncStatusDto(serviceType: 'GARMIN', state: 'SENT'),
        ],
      );
      expect(
        gpsTargetOfGroup(
          subtitle: 'B',
          teamSlug: 't',
          routeSlug: 'r',
          route: withOwn,
          syncStatuses: ofGroup,
        ).syncStatuses,
        ofGroup,
      );
      expect(
        gpsTargetOfGroup(
          subtitle: 'B',
          teamSlug: 't',
          routeSlug: 'r',
          route: withOwn,
        ).syncStatuses,
        withOwn.gpsSyncStatuses,
      );
    });

    testWidgets('sans service : pas de section appareil, « Connecter un '
        'compteur » tout en bas', (WidgetTester tester) async {
      await pump(tester, _RouteGps(route: route()));
      await openFromRoute(tester);

      expect(find.byKey(keys.gpsSheet.toDevice), findsNothing);
      expect(inSheet('Vers un appareil'), findsNothing);
      final Finder connect = find.byKey(keys.gpsSheet.connectDevice);
      expect(connect, findsOneWidget);
      expect(inSheet('Connecter un compteur'), findsOneWidget);
      expect(
        inSheet('Garmin, Karoo… pour envoyer le parcours sans fichier'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(connect).dy,
        greaterThan(tester.getTopLeft(find.byKey(keys.gpsSheet.fitShare)).dy),
      );
    });

    testWidgets('sans FIT : pas de section FIT', (WidgetTester tester) async {
      await pump(
        tester,
        _RouteGps(route: route(fit: null)),
        services: _services,
      );
      await openFromRoute(tester);

      expect(inSheet('Fichier GPX'), findsOneWidget);
      expect(inSheet('Fichier FIT, pour compteur'), findsNothing);
      expect(find.byKey(keys.gpsSheet.fitSave), findsNothing);
      expect(find.byKey(keys.gpsSheet.fitShare), findsNothing);
    });

    testWidgets('« Connecter un compteur » rend son choix et ferme la '
        'feuille', (WidgetTester tester) async {
      GpsChoice? choice;
      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async => choice = await showGpsSheet(
                context,
                subtitle: 'Groupe B · 78,0 km',
                services: const <GpsServiceConnectionDto>[],
                offerConnect: true,
                gpx: _gpx,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await settle(tester);
      expect(find.text('Groupe B · 78,0 km'), findsOneWidget);
      await tester.tap(find.byKey(keys.gpsSheet.connectDevice));
      await settle(tester);

      expect(choice, isA<GpsConnectDevice>());
      expect(find.byKey(keys.gpsSheet.sheet), findsNothing);
    });

    // docs/LEDGER_*.md MOB-138 : la fiche est plein écran (navigateur
    // racine), « Appareils » une page de l'onglet Profil. Un `push` ordinaire
    // y laissait un écran vide.
    testWidgets('« Connecter un compteur » depuis une fiche plein écran ouvre '
        'les appareils, dans l’onglet Profil', (WidgetTester tester) async {
      setCurrentLocale('fr');
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();
      Page<void> tab(String label) =>
          NoTransitionPage<void>(child: Text(label));
      final GoRouter router = GoRouter(
        navigatorKey: rootKey,
        initialLocation: Paths.home(),
        routes: <RouteBase>[
          StatefulShellRoute.indexedStack(
            builder: (_, _, StatefulNavigationShell shell) =>
                Scaffold(body: shell),
            branches: <StatefulShellBranch>[
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: Paths.home(),
                    pageBuilder: (_, _) => tab('accueil'),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'fiche',
                        parentNavigatorKey: rootKey,
                        builder: (_, _) =>
                            Scaffold(body: _RouteGps(route: route())),
                      ),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: Paths.profile(),
                    pageBuilder: (_, _) => tab('profil'),
                  ),
                  GoRoute(
                    path: Paths.profileDevices(),
                    pageBuilder: (_, _) => tab('appareils'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            unitSystemProvider.overrideWithValue(UnitSystem.metric),
            authProvider.overrideWith(
              (ref) =>
                  _StubAuthNotifier(ref, const <GpsServiceConnectionDto>[]),
            ),
          ],
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      unawaited(router.push('${Paths.home()}fiche'));
      await settle(tester);

      await openFromRoute(tester);
      await tester.tap(find.byKey(keys.gpsSheet.connectDevice));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('appareils').hitTestable(), findsOneWidget);

      router.pop();
      await settle(tester);
      expect(find.text('profil').hitTestable(), findsOneWidget);
    });

    test('le bouton n’a rien à proposer sans fichier ni envoi possible', () {
      expect(gpsExportOffered(gpx: null, fit: null, canSend: false), isFalse);
      expect(gpsExportOffered(gpx: _gpx, fit: null, canSend: false), isTrue);
      expect(gpsExportOffered(gpx: null, fit: null, canSend: true), isTrue);
    });
  });

  group('le contrôleur d’export', () {
    testWidgets('enregistrer le GPX : la feuille se ferme, puis le bandeau '
        '« Fichier enregistré » sur l’écran, ancré au bouton', (
      WidgetTester tester,
    ) async {
      final _Ops ops = await pump(tester, _RouteGps(route: route()));
      await openFromRoute(tester);
      await tester.tap(find.byKey(keys.gpsSheet.gpxSave));
      await settle(tester);

      expect(find.byKey(keys.gpsSheet.sheet), findsNothing);
      expect(ops.delivered, hasLength(1));
      expect(ops.delivered.single.$1, _gpx);
      expect(ops.delivered.single.$2, AssetDestination.device);
      // L'ancre du partage sur iPad : le bouton « GPS », pas la feuille.
      expect(ops.delivered.single.$3, isNot(Rect.zero));
      expect(find.byKey(keys.gpsSheet.successBanner), findsOneWidget);
      expect(find.text('Fichier enregistré'), findsOneWidget);
    });

    testWidgets('partager : pas de bandeau de succès', (
      WidgetTester tester,
    ) async {
      final _Ops ops = await pump(tester, _RouteGps(route: route()));
      await openFromRoute(tester);
      await tester.tap(find.byKey(keys.gpsSheet.fitShare));
      await settle(tester);

      expect(ops.delivered.single.$1, _fit);
      expect(ops.delivered.single.$2, AssetDestination.share);
      expect(find.byKey(keys.gpsSheet.successBanner), findsNothing);
    });

    testWidgets('un export à la fois : pendant le téléchargement, le bouton '
        'attend et n’ouvre pas de seconde feuille', (
      WidgetTester tester,
    ) async {
      final _Ops ops = await pump(tester, _RouteGps(route: route()));
      ops.pendingDelivery = Completer<bool>();
      await openFromRoute(tester);
      await tester.tap(find.byKey(keys.gpsSheet.gpxSave));
      await settle(tester);

      final GpsButton button = tester.widget<GpsButton>(
        find.byKey(keys.routeDetail.gps),
      );
      expect(button.loading, isTrue);
      await tester.tap(find.byKey(keys.routeDetail.gps));
      await settle(tester);
      expect(find.byKey(keys.gpsSheet.sheet), findsNothing);
      expect(ops.delivered, hasLength(1));

      ops.pendingDelivery!.complete(true);
      await settle(tester);
      expect(
        tester.widget<GpsButton>(find.byKey(keys.routeDetail.gps)).loading,
        isFalse,
      );
      expect(find.byKey(keys.gpsSheet.successBanner), findsOneWidget);
    });

    testWidgets('envoyer vers un appareil : le bon service, le bon parcours, '
        'puis le bandeau de succès', (WidgetTester tester) async {
      final _Ops ops = await pump(
        tester,
        _RouteGps(route: route()),
        services: _services,
      );
      await openFromRoute(tester);
      await tester.tap(find.byKey(keys.gpsSheet.service('HAMMERHEAD')));
      await settle(tester);

      expect(ops.uploaded, <(String, String, String)>[
        ('HAMMERHEAD', 'n-peloton', 'col-de-la-croix'),
      ]);
      expect(find.byKey(keys.gpsSheet.successBanner), findsOneWidget);
    });

    testWidgets('un aperçu GPX part vers un appareil par l’aperçu, sans '
        'équipe ni slug (MOB-178)', (WidgetTester tester) async {
      final _Ops ops = await pump(
        tester,
        const _RouteGps(
          target: GpsExportTarget.preview(
            subtitle: 'Sortie du dimanche',
            previewId: 'p1',
            gpx: _gpx,
            fit: _fit,
          ),
        ),
        services: _services,
      );
      await openFromRoute(tester);
      expect(inSheet('Sortie du dimanche'), findsOneWidget);
      await tester.tap(find.byKey(keys.gpsSheet.service('GARMIN')));
      await settle(tester);

      expect(ops.previewUploaded, <(String, String)>[('GARMIN', 'p1')]);
      expect(ops.uploaded, isEmpty);
      expect(find.byKey(keys.gpsSheet.successBanner), findsOneWidget);
    });

    testWidgets('un échec : le bandeau d’erreur, que l’on referme', (
      WidgetTester tester,
    ) async {
      final _Ops ops = await pump(
        tester,
        _RouteGps(route: route()),
        services: _services,
      );
      ops.uploadError = Exception('boom');
      await openFromRoute(tester);
      await tester.tap(find.byKey(keys.gpsSheet.service('GARMIN')));
      await settle(tester);

      expect(find.byKey(keys.gpsSheet.errorBanner), findsOneWidget);
      expect(find.byKey(keys.gpsSheet.successBanner), findsNothing);
      await tester.tap(find.byTooltip('Fermer').first);
      await settle(tester);
      expect(find.byKey(keys.gpsSheet.errorBanner), findsNothing);
    });
  });

  group('les points d’entrée', () {
    testWidgets('la fiche parcours : « GPS » et le partage du lien ; rien '
        'pour un parcours sans fichier ni service', (
      WidgetTester tester,
    ) async {
      await pump(tester, _RouteGps(route: route()));
      expect(find.byKey(keys.routeDetail.gps), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);

      await pump(tester, _RouteGps(route: route(gpx: null, fit: null)));
      expect(find.byKey(keys.routeDetail.gps), findsNothing);
    });

    testWidgets('le bouton se lit « Envoyer le parcours vers un GPS ou '
        'l’exporter »', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pump(tester, _RouteGps(route: route()));
      expect(
        find.bySemanticsLabel('Envoyer le parcours vers un GPS ou l\'exporter'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('la barre d’un écran : « GPS », et la feuille qui nomme le '
        'groupe ; rien sans fichier ni compteur (MOB-184)', (
      WidgetTester tester,
    ) async {
      const GpsExportTarget target = GpsExportTarget(
        subtitle: 'Groupe B · 82 km',
        teamSlug: 'n-peloton',
        routeSlug: 'court',
        gpx: _gpx,
        fit: _fit,
      );
      await pump(tester, const _BarGps(target: target));
      expect(find.byKey(keys.ride.gps), findsOneWidget);
      expect(
        find.bySemanticsLabel("Envoyer le parcours vers un GPS ou l'exporter"),
        findsOneWidget,
      );
      await tester.tap(find.byKey(keys.ride.gps));
      await settle(tester);
      expect(find.byKey(keys.gpsSheet.sheet), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(keys.gpsSheet.subtitle)).data,
        'Groupe B · 82 km',
      );

      // Ni fichier ni appareil connecté : rien à proposer, pas de bouton.
      await pump(
        tester,
        const _BarGps(
          target: GpsExportTarget(
            subtitle: 'Groupe B',
            teamSlug: 'n-peloton',
            routeSlug: null,
          ),
        ),
      );
      expect(find.byKey(keys.ride.gps), findsNothing);
    });

    testWidgets('la carte d’un groupe n’a plus de « GPS » : il est dans '
        'l’en-tête de la sortie (MOB-184)', (WidgetTester tester) async {
      await pump(
        tester,
        RideGroupCard(
          group: fixtureGroup(id: 'g1', registered: true),
          rideDateTime: '2026-10-11T06:00:00Z',
          timezone: 'Europe/Paris',
          showDeparture: false,
          action: RideGroupAction.leave,
          trackColor: multiTrackColor(0),
          units: UnitSystem.metric,
        ),
      );
      expect(find.byType(GpsButton), findsNothing);
    });

    testWidgets('« Ma prochaine sortie » : « GPS » avec un service, qui '
        'ouvre la feuille sur les seuls appareils', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide(
        dateTime: '2099-07-29T19:30:00Z',
        groups: <RideGroupDto>[fixtureGroup(id: 'g1', routeSlug: 'court')],
      );
      final RideGroupDto group = ride.groups.single;
      final _Ops ops = await pump(
        tester,
        NextRideCard(
          next: NextRide(ride: ride, group: group),
        ),
        services: _services,
      );
      final Finder gps = find.byKey(keys.home.nextRideGps);
      expect(gps, findsOneWidget);
      await tester.tap(gps);
      await settle(tester);

      expect(find.byKey(keys.gpsSheet.sheet), findsOneWidget);
      expect(find.byKey(keys.gpsSheet.toDevice), findsOneWidget);
      expect(find.byKey(keys.gpsSheet.gpxShare), findsNothing);
      await tester.tap(find.byKey(keys.gpsSheet.service('GARMIN')));
      await settle(tester);
      expect(ops.uploaded.single, ('GARMIN', ride.team.slug, 'court'));
      expect(find.byKey(keys.gpsSheet.successBanner), findsOneWidget);
    });

    testWidgets('« Ma prochaine sortie » sans service : « GPS » quand même, '
        'la feuille offre GPX, FIT et « Connecter un compteur » (règle R7)', (
      WidgetTester tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        final RideDto ride = fixtureRide(
          dateTime: '2099-07-29T19:30:00Z',
          groups: <RideGroupDto>[fixtureGroup(id: 'g1', routeSlug: 'court')],
        );
        await pump(
          tester,
          NextRideCard(
            next: NextRide(ride: ride, group: ride.groups.single),
          ),
          nextRideRoute: route(),
        );
        final Finder gps = find.byKey(keys.home.nextRideGps);
        expect(gps, findsOneWidget);
        await tester.tap(gps);
        await settle(tester);
        expect(find.byKey(keys.gpsSheet.sheet), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.toDevice), findsNothing);
        expect(find.byKey(keys.gpsSheet.gpxShare), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.fitShare), findsOneWidget);
        expect(find.byKey(keys.gpsSheet.connectDevice), findsOneWidget);
      });
    });

    testWidgets('« Ma prochaine sortie » sans parcours : pas de « GPS »', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide(
        dateTime: '2099-07-29T19:30:00Z',
        groups: <RideGroupDto>[fixtureGroup(id: 'g1')],
      ).copyWith(routeSlug: null);
      await pump(
        tester,
        NextRideCard(
          next: NextRide(ride: ride, group: ride.groups.single),
        ),
        services: _services,
      );
      expect(find.byKey(keys.home.nextRideGps), findsNothing);
    });

    testWidgets('« Vos prochaines sorties » : « GPS » ouvre la même feuille', (
      WidgetTester tester,
    ) async {
      const PublicationDtoRide row = PublicationDtoRide(
        permissions: kNoPermissions,
        timezone: 'Europe/Paris',
        tags: <TagDto>[],
        groupSummaries: <RideGroupSummaryDto>[],
        team: TeamPublicationDto(
          accessible: true,
          id: 't1',
          slug: 'n-peloton',
          name: 'N-Peloton',
          visibility: 'PUBLIC',
        ),
        id: 'r1',
        slug: 'np-665',
        name: 'N-Peloton #665',
        routeSlug: 'court',
        media: fixtureEmptyMedia,
        dateTime: '2099-07-29T19:30:00Z',
        endDateTime: '2099-07-29T22:30:00Z',
        status: 'PUBLISHED',
        visibility: 'TEAM',
        participantCount: 10,
        groupCount: 1,
        groups: <RideGroupDto>[],
        topParticipants: <PublicUserDto>[],
        deleted: false,
        registered: true,
        full: false,
        finished: false,
      );
      await pump(
        tester,
        DashboardMyUpcoming(
          list: const PublicationListResponse(
            publications: <PublicationDto>[row],
            total: 1,
            page: 0,
            size: 3,
          ),
          onViewAll: () {},
        ),
        services: _services,
      );
      final Finder gps = find.byKey(keys.teamDashboard.myUpcomingGps('np-665'));
      expect(gps, findsOneWidget);
      await tester.tap(gps);
      await settle(tester);
      expect(find.byKey(keys.gpsSheet.sheet), findsOneWidget);
      expect(inSheet('N-Peloton #665'), findsOneWidget);
      expect(find.byKey(keys.gpsSheet.service('GARMIN')), findsOneWidget);
    });

    testWidgets(
      '« Vos prochaines sorties » : pas de « GPS » sur une sortie annulée',
      (WidgetTester tester) async {
        const PublicationDtoRide row = PublicationDtoRide(
          permissions: kNoPermissions,
          timezone: 'Europe/Paris',
          tags: <TagDto>[],
          groupSummaries: <RideGroupSummaryDto>[],
          team: TeamPublicationDto(
            accessible: true,
            id: 't1',
            slug: 'n-peloton',
            name: 'N-Peloton',
            visibility: 'PUBLIC',
          ),
          id: 'r1',
          slug: 'np-665',
          name: 'N-Peloton #665',
          routeSlug: 'court',
          media: fixtureEmptyMedia,
          dateTime: '2099-07-29T19:30:00Z',
          endDateTime: '2099-07-29T22:30:00Z',
          status: 'CANCELLED',
          visibility: 'TEAM',
          participantCount: 10,
          groupCount: 1,
          groups: <RideGroupDto>[],
          topParticipants: <PublicUserDto>[],
          deleted: false,
          registered: true,
          full: false,
          finished: false,
        );
        await pump(
          tester,
          DashboardMyUpcoming(
            list: const PublicationListResponse(
              publications: <PublicationDto>[row],
              total: 1,
              page: 0,
              size: 3,
            ),
            onViewAll: () {},
          ),
          services: _services,
        );
        expect(
          find.byKey(keys.teamDashboard.myUpcomingGps('np-665')),
          findsNothing,
        );
      },
    );
  });
}
