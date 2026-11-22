import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/gpxtools/data/gpx_preview_repository.dart';
import 'package:pedalons/features/gpxtools/presentation/pages/gpx_preview_page.dart';
import 'package:pedalons/features/gpxtools/providers/gpx_preview_provider.dart';
import 'package:pedalons/features/routes/presentation/widgets/gps_button.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import '../../support/content_permissions.dart';
import '../routes/route_fixtures.dart';

/// docs/LEDGER_*.md MOB-178 : la fiche d'un aperçu GPX, l'ossature commune
/// des fiches — titre, tuiles, départ, section Parcours (sur l'aperçu, son
/// « GPS » compris), Météo, points, conservation —, et la suppression
/// réservée à qui l'a déposé.

TrackDto _track() => TrackDto(
  line: GeoJsonLineString(
    type: GeoJsonLineStringTypeType.lineString,
    coordinates: <List<double>>[
      for (int i = 0; i <= 30; i++)
        <double>[5, 45 + i * 1000 / 111195, 100.0 + (i % 6) * 15, i * 1000.0],
    ],
  ),
  climbs: const <ClimbDto>[],
);

GpxPreviewDto _preview({
  bool owned = true,
  String? departureTime,
  double? averageSpeed,
  List<WaypointDto> waypoints = const <WaypointDto>[],
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
  tracks: <TrackDto>[_track()],
  waypoints: waypoints,
  departureTime: departureTime,
  departureTimezone: departureTime == null ? null : 'Europe/Paris',
  averageSpeed: averageSpeed,
);

class _FakeRepository implements GpxPreviewRepository {
  final List<String> deleted = <String>[];
  final List<(String, String)> copied = <(String, String)>[];
  final List<(String, String, RouteRequest)> routes =
      <(String, String, RouteRequest)>[];

  @override
  Future<void> delete(String previewId) async => deleted.add(previewId);

  @override
  Future<GpxPreviewDto> copy(String previewId, {required String name}) async {
    copied.add((previewId, name));
    return _preview().copyWith(id: 'copy1', name: name);
  }

  @override
  Future<RouteDto> createRoute(
    String previewId, {
    required String teamSlug,
    required RouteRequest request,
  }) async {
    routes.add((previewId, teamSlug, request));
    return RouteDto(
      permissions: kNoPermissions,
      id: 'r1',
      slug: 'boucle-du-dimanche',
      elevationState: 'HD',
      team: const TeamPublicationDto(
        accessible: true,
        id: 't1',
        slug: 'n-peloton',
        name: 'N-Peloton',
        visibility: 'PUBLIC',
      ),
      name: request.name,
      media: request.media,
      distance: 30000,
      elevationGain: 420,
      elevationLoss: 410,
      surfaceType: request.surfaceType,
      visibility: request.visibility,
      createdAt: '2026-11-22T10:00:00Z',
      deleted: false,
      tags: const <TagDto>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  Future<_FakeRepository> open(
    WidgetTester tester,
    GpxPreviewDto preview, {
    RideWeatherDto? weather,
    List<TeamDetailDto> teams = const <TeamDetailDto>[],
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _FakeRepository repository = _FakeRepository();
    final GoRouter router = GoRouter(
      initialLocation: '/p',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('accueil des outils'),
          routes: <RouteBase>[
            GoRoute(
              path: 'p',
              builder: (_, _) => const GpxPreviewPage(previewId: 'p1'),
            ),
            GoRoute(
              path: 'outils-gpx/:id',
              builder: (_, GoRouterState s) =>
                  Text('fiche ${s.pathParameters['id']}'),
            ),
            GoRoute(
              path: 'equipes/:team/parcours/:route',
              builder: (_, GoRouterState s) =>
                  Text('parcours ${s.pathParameters['route']}'),
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
          gpxPreviewProvider('p1').overrideWith((Ref ref) async => preview),
          gpxPreviewWeatherProvider('p1')
              .overrideWith((Ref ref) async => weather ?? fixtureWeather()),
          myTeamsProvider.overrideWith((Ref ref) async => teams),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return repository;
  }

  void expectOrder(WidgetTester tester, List<Key> order) {
    final List<double> tops = <double>[
      for (final Key k in order) tester.getTopLeft(find.byKey(k)).dy,
    ];
    for (int i = 1; i < tops.length; i++) {
      expect(
        tops[i],
        greaterThan(tops[i - 1]),
        reason: '${order[i]} doit suivre ${order[i - 1]}',
      );
    }
  }

  testWidgets('sans date : titre, tuiles, section Parcours et « GPS », '
      'conservation ; ni départ ni météo', (WidgetTester tester) async {
    await open(tester, _preview());

    expectOrder(tester, <Key>[
      keys.gpxTools.previewTitle,
      keys.gpxTools.previewStats,
      keys.gpxTools.previewRouteSection,
      keys.gpxTools.previewRetention,
    ]);
    expect(find.text('Boucle du dimanche'), findsOneWidget);
    expect(find.byType(GpsButton), findsOneWidget);
    expect(find.byKey(keys.gpxTools.previewDeparture), findsNothing);
    expect(find.byKey(keys.gpxTools.previewWeather), findsNothing);
    expect(find.byKey(keys.gpxTools.shareButton), findsOneWidget);
  });

  testWidgets('daté : le bloc de départ avec la vitesse, puis la météo ; un '
      'départ passé le dit', (WidgetTester tester) async {
    await open(
      tester,
      _preview(departureTime: '2026-11-01T08:00:00Z', averageSpeed: 24),
      weather: fixtureWeather(),
    );

    expectOrder(tester, <Key>[
      keys.gpxTools.previewDeparture,
      keys.gpxTools.previewRouteSection,
      keys.gpxTools.previewWeather,
    ]);
    expect(find.textContaining('Vitesse moyenne'), findsOneWidget);
    expect(
      find.text('Ce départ est passé : plus de prévisions à afficher.'),
      findsOneWidget,
    );
  });

  testWidgets('la météo qui arrive se dit « en cours », pas « indisponible »', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _preview(departureTime: '2099-07-29T06:00:00Z'),
      weather: fixtureWeather(status: 'UNAVAILABLE'),
    );

    expect(find.byKey(keys.gpxTools.previewWeatherPending), findsOneWidget);
    expect(
      find.text(
        'Récupération des prévisions en cours, cela prend environ une minute.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('les points du parcours ont leur section', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _preview(
        waypoints: <WaypointDto>[
          fixtureWaypoint(id: 'w1', type: 'WATER', distance: 4000),
        ],
      ),
    );
    expect(find.byKey(keys.gpxTools.previewWaypoints), findsOneWidget);
  });

  testWidgets('« Supprimer » n’est offert qu’à qui a déposé le fichier', (
    WidgetTester tester,
  ) async {
    await open(tester, _preview(owned: false));
    await tester.tap(find.byKey(keys.gpxTools.moreButton));
    await tester.pumpAndSettle();
    expect(find.byKey(keys.gpxTools.saveAsRouteAction), findsOneWidget);
    expect(find.byKey(keys.gpxTools.duplicateAction), findsOneWidget);
    expect(find.byKey(keys.gpxTools.deleteAction), findsNothing);
  });

  testWidgets('dupliquer : « Copie de … » d’avance, puis la copie s’ouvre', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repository = await open(tester, _preview());
    await tester.tap(find.byKey(keys.gpxTools.moreButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.gpxTools.duplicateAction));
    await tester.pumpAndSettle();

    expect(find.text('Copie de Boucle du dimanche'), findsOneWidget);
    await tester.tap(find.byKey(keys.gpxTools.duplicateSubmit));
    await tester.pumpAndSettle();

    expect(repository.copied, <(String, String)>[
      ('p1', 'Copie de Boucle du dimanche'),
    ]);
    expect(find.text('fiche copy1'), findsOneWidget);
  });

  testWidgets('dupliquer : un nom trop court ne part pas', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repository = await open(tester, _preview());
    await tester.tap(find.byKey(keys.gpxTools.moreButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.gpxTools.duplicateAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(keys.gpxTools.duplicateName), ' a ');
    await tester.tap(find.byKey(keys.gpxTools.duplicateSubmit));
    await tester.pumpAndSettle();

    expect(repository.copied, isEmpty);
    expect(
      find.text('Le nom doit contenir au moins 3 caractères.'),
      findsOneWidget,
    );
  });

  testWidgets('enregistrer comme parcours : les équipes où l’on organise ; un '
      'tracé dessiné grise celles sans tracé d’itinéraire', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repository = await open(
      tester,
      _preview().copyWith(drawn: true),
      teams: <TeamDetailDto>[
        fixtureRouteTeam(role: 'ORGANIZER', enableRoutePlanner: true),
        fixtureRouteTeam(role: 'ADMIN').copyWith(slug: 'ferme', name: 'Fermée'),
        fixtureRouteTeam(role: 'MEMBER').copyWith(slug: 'membre'),
        fixtureRouteTeam(
          role: 'ADMIN',
          enableRoutes: false,
        ).copyWith(slug: 'sans-parcours'),
      ],
    );
    await tester.tap(find.byKey(keys.gpxTools.moreButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.gpxTools.saveAsRouteAction));
    await tester.pumpAndSettle();

    expect(
      find.byKey(keys.gpxTools.saveAsRouteTeam('n-peloton')),
      findsOneWidget,
    );
    expect(find.byKey(keys.gpxTools.saveAsRouteTeam('ferme')), findsOneWidget);
    expect(find.byKey(keys.gpxTools.saveAsRouteTeam('membre')), findsNothing);
    expect(
      find.byKey(keys.gpxTools.saveAsRouteTeam('sans-parcours')),
      findsNothing,
    );
    expect(find.text('Tracé d\'itinéraire non activé'), findsOneWidget);

    // L'équipe fermée ne se choisit pas.
    await tester.tap(find.byKey(keys.gpxTools.saveAsRouteTeam('ferme')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.gpxTools.saveAsRouteSubmit));
    await tester.pumpAndSettle();
    expect(repository.routes, isEmpty);

    await tester.tap(find.byKey(keys.gpxTools.saveAsRouteTeam('n-peloton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.gpxTools.saveAsRouteSubmit));
    await tester.pumpAndSettle();

    expect(repository.routes, hasLength(1));
    final (String id, String team, RouteRequest request) =
        repository.routes.single;
    expect((id, team), ('p1', 'n-peloton'));
    expect(request.name, 'Boucle du dimanche');
    expect(request.surfaceType, 'ROAD');
    expect(request.visibility, 'PUBLIC');
    expect(find.text('parcours boucle-du-dimanche'), findsOneWidget);
  });

  testWidgets('supprimer : confirmation, appel, puis retour', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repository = await open(tester, _preview());

    await tester.tap(find.byKey(keys.gpxTools.moreButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.gpxTools.deleteAction));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Voulez-vous vraiment supprimer ce fichier ? Le lien ne sera plus '
        'accessible.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();

    expect(repository.deleted, <String>['p1']);
    expect(find.text('accueil des outils'), findsOneWidget);
  });
}
