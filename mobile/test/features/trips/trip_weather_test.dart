import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/trips/data/trip_repository.dart';
import 'package:pedalons/features/trips/presentation/pages/stage_detail_page.dart';
import 'package:pedalons/features/trips/presentation/pages/stage_weather_page.dart';
import 'package:pedalons/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import 'trip_fixtures.dart';

/// La météo d'un voyage : la ligne de résumé des cartes d'étape (écran 24),
/// la carte météo de l'écran 25 dans ses états, et l'écran « Météo du
/// parcours » d'une étape.
class _Trips implements TripRepository {
  _Trips(this.trip, this.weather);

  final TripDto trip;
  TripWeatherDto weather;
  int weatherReads = 0;

  @override
  Future<TripDto> getTrip(String teamSlug, String tripSlug) async => trip;

  @override
  Future<TripWeatherDto> getTripWeather(String t, String s) async {
    weatherReads++;
    return weather;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Teams implements TeamRepository {
  _Teams({this.role});

  final String? role;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => <TeamDetailDto>[
    TeamDetailDto(
      timezone: 'Europe/Paris',
      id: 't1',
      slug: 'n-peloton',
      name: 'N-Peloton',
      about: kEmptyMedia,
      visibility: 'PUBLIC',
      enableTrips: true,
      enableAds: true,
      enablePosts: true,
      enableRides: true,
      enableRoutes: true,
      visibilityEditable: true,
      joinable: true,
      addMemberAllowed: true,
      enableMemberDirectory: false,
      postsAsTeamByDefault: true,
      enableRoutePlanner: false,
      memberCount: 40,
      upcomingRideCount: 3,
      routeCount: 12,
      upcomingTripCount: 0,
      recentPostCount: 0,
      createdAt: '2024-01-01T00:00:00Z',
      role: role,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Comments implements CommentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const WeatherAttributionDto _attribution = WeatherAttributionDto(
  name: 'Open-Meteo.com',
  url: 'https://open-meteo.com/',
);

const RideWeatherSummaryDto _okSummary = RideWeatherSummaryDto(
  status: 'OK',
  condition: 'CLEAR',
  daylight: true,
  temperature: 13,
  temperatureMin: 11.6,
  temperatureMax: 18.2,
  maxPrecipitationProbability: 20,
  wind: WindDto(speed: 18, direction: 315, compass: 'NW'),
);

TripStageWeatherDto _stage(
  String stageId, {
  String status = 'OK',
  RideWeatherSummaryDto? summary,
  String? availableFrom,
}) => TripStageWeatherDto(
  stageId: stageId,
  summary: summary,
  leg: fixtureLeg(
    groupId: null,
    status: status,
  ).copyWith(availableFrom: availableFrom),
);

TripWeatherDto _weather(
  List<TripStageWeatherDto> stages, {
  String status = 'OK',
}) => TripWeatherDto(
  status: status,
  stages: stages,
  attribution: _attribution,
  fetchedAt: '2099-08-10T17:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  // Trois étapes : J1 et J2 avec un parcours, J3 sans.
  final TripDto trip = fixtureTrip();

  Future<_Trips> pump(
    WidgetTester tester,
    TripWeatherDto weather, {
    required Widget home,
    String? role = 'MEMBER',
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final _Trips trips = _Trips(trip, weather);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          unitSystemProvider.overrideWithValue(UnitSystem.metric),
          tripRepositoryProvider.overrideWithValue(trips),
          teamRepositoryProvider.overrideWithValue(_Teams(role: role)),
          commentRepositoryProvider.overrideWithValue(_Comments()),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: home,
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return trips;
  }

  Widget stagePage(String slug) => StageDetailPage(
    teamSlug: trip.team.slug,
    tripSlug: trip.slug,
    stageSlug: slug,
  );

  group('écran 24 — la ligne de résumé des étapes', () {
    testWidgets('seule l\'étape qui a un résumé porte la ligne', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        _weather(<TripStageWeatherDto>[
          _stage('s1', summary: _okSummary),
          // Déjà partie : ni résumé, ni ligne.
          _stage('s2', status: 'OUT_OF_RANGE'),
          _stage('s3', status: 'NO_LOCATION'),
        ]),
        home: TripDetailPage(teamSlug: trip.team.slug, tripSlug: trip.slug),
      );

      expect(find.byKey(keys.ride.weatherSummary), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(keys.trip.stageCard('j1')),
          matching: find.byKey(keys.ride.weatherSummary),
        ),
        findsOneWidget,
      );
      expect(find.text('12–18 °C'), findsOneWidget);
    });

    testWidgets('un voyage hors fenêtre ne montre aucune ligne', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        _weather(<TripStageWeatherDto>[
          _stage('s1', summary: _okSummary),
        ], status: 'OUT_OF_RANGE'),
        home: TripDetailPage(teamSlug: trip.team.slug, tripSlug: trip.slug),
      );

      expect(find.byKey(keys.ride.weatherSummary), findsNothing);
    });

    testWidgets('NOT_YET_AVAILABLE : « Météo dès le … » sur la carte', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        _weather(<TripStageWeatherDto>[
          _stage(
            's1',
            status: 'NOT_YET_AVAILABLE',
            availableFrom: '2099-08-05T07:00:00Z',
            summary: const RideWeatherSummaryDto(
              status: 'NOT_YET_AVAILABLE',
              availableFrom: '2099-08-05T07:00:00Z',
            ),
          ),
        ], status: 'NOT_YET_AVAILABLE'),
        home: TripDetailPage(teamSlug: trip.team.slug, tripSlug: trip.slug),
      );

      expect(find.textContaining('Météo dès le'), findsOneWidget);
    });
  });

  group('écran 25 — la carte météo de l\'étape', () {
    testWidgets(
      'OK : la carte, et l\'écran « Météo du parcours » de l\'étape',
      (WidgetTester tester) async {
        await pump(
          tester,
          _weather(<TripStageWeatherDto>[
            _stage('s1', summary: _okSummary),
            _stage('s2'),
          ]),
          home: stagePage('j1'),
        );

        expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
        expect(find.text('Météo au départ'), findsOneWidget);

        await tester.tap(find.byKey(keys.ride.weatherOpenButton));
        await tester.pumpAndSettle();

        expect(find.byType(StageWeatherPage), findsOneWidget);
        expect(find.text('Météo du parcours'), findsOneWidget);
        // L'en-tête porte le nom de l'étape ; pas de sélecteur de groupe.
        expect(find.text('J1'), findsWidgets);
        expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
        // Sans carte, la ligne ne se touche pas : ni bouton ni état
        // « sélectionné / non sélectionné » annoncé.
        expect(
          tester.getSemantics(find.byKey(keys.ride.weatherCheckpoint(0))),
          isSemantics(
            isButton: false,
            hasSelectedState: false,
            hasTapAction: false,
          ),
        );
      },
    );

    testWidgets('NOT_YET_AVAILABLE : « Prévision disponible à partir du … »', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        _weather(<TripStageWeatherDto>[
          _stage(
            's1',
            status: 'NOT_YET_AVAILABLE',
            availableFrom: '2099-08-05T07:00:00Z',
            summary: const RideWeatherSummaryDto(
              status: 'NOT_YET_AVAILABLE',
              availableFrom: '2099-08-05T07:00:00Z',
            ),
          ),
        ], status: 'NOT_YET_AVAILABLE'),
        home: stagePage('j1'),
      );

      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
      expect(
        find.textContaining('Prévision disponible à partir du'),
        findsOneWidget,
      );
      expect(find.byKey(keys.ride.weatherCard), findsNothing);
    });

    testWidgets('UNAVAILABLE : « Réessayer » relit la météo', (
      WidgetTester tester,
    ) async {
      final _Trips trips = await pump(
        tester,
        _weather(<TripStageWeatherDto>[
          _stage('s1', status: 'UNAVAILABLE'),
        ], status: 'UNAVAILABLE'),
        home: stagePage('j1'),
      );
      expect(find.byKey(keys.ride.weatherUnavailable), findsOneWidget);
      final int before = trips.weatherReads;

      trips.weather = _weather(<TripStageWeatherDto>[_stage('s1')]);
      await tester.tap(find.byKey(keys.ride.weatherRetryButton));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(trips.weatherReads, before + 1);
      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
    });

    testWidgets('une étape déjà partie ne montre rien', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        _weather(<TripStageWeatherDto>[
          _stage('s1', status: 'OUT_OF_RANGE'),
          _stage('s2'),
        ]),
        home: stagePage('j1'),
      );

      expect(find.byKey(keys.ride.weatherCard), findsNothing);
      expect(find.byKey(keys.ride.weatherUnavailable), findsNothing);
      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsNothing);
    });

    testWidgets('NO_LOCATION : dit à l\'organisateur, tu au membre', (
      WidgetTester tester,
    ) async {
      final TripWeatherDto weather = _weather(<TripStageWeatherDto>[
        _stage('s1'),
        _stage('s2'),
        _stage('s3', status: 'NO_LOCATION'),
      ]);

      await pump(tester, weather, home: stagePage('j3'));
      expect(find.byKey(keys.ride.weatherNoLocation), findsNothing);

      await pump(tester, weather, home: stagePage('j3'), role: 'ORGANIZER');
      expect(find.byKey(keys.ride.weatherNoLocation), findsOneWidget);
    });
  });
}
