import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/rides/domain/ride_weather_display.dart';
import 'package:pedalons/features/rides/presentation/widgets/weather_section.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// La section Météo des écrans de détail (ledger `MOB-134`, KIT §8) : l'ordre
/// de ses blocs, l'heure de son départ, la frise repliée ou dépliée, la
/// légende du vent, le bas de section, la variante « départ seul » et ses
/// états.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  setUp(() => AppFormatters.setDisplayTimezone('Europe/Paris'));
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  const WeatherAttributionDto attribution = WeatherAttributionDto(
    name: 'Open-Meteo.com',
    url: 'https://open-meteo.com/',
  );
  final DateTime fetchedAt = DateTime.utc(2036, 7, 29, 17);
  // La sortie part à 21:30 à Paris ; le leg du fixture part à 21:30 et
  // arrive à 22:40.
  const String rideAt = '2036-07-29T19:30:00Z';
  final DepartureWeatherDto rideDeparture = DepartureWeatherDto(
    status: 'OK',
    conditions: fixtureConditions(),
    sunrise: '2036-07-29T04:12:00Z',
    sunset: '2036-07-29T19:31:00Z',
  );

  /// Les espaces insécables des unités (`AppFormatters.withUnit`).
  String nb(String text) => text.replaceAllMapped(
    RegExp(r' (°C|%|km/h|km)'),
    (Match m) => ' ${m[1]}',
  );

  Future<void> pump(WidgetTester tester, WeatherSection section) async {
    tester.view.physicalSize = const Size(402 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSystemProvider.overrideWithValue(UnitSystem.metric)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: section)),
        ),
      ),
    );
  }

  /// Le leg du fixture, ramené en 2036 : au-delà de 2037, la base des
  /// fuseaux ne connaît plus l'heure d'été.
  WeatherLegDto leg2036({
    String status = 'OK',
    bool speedIsDefault = false,
    DepartureWeatherDto? departure,
  }) =>
      fixtureLeg(
        status: status,
        speedIsDefault: speedIsDefault,
        departure: departure,
      ).copyWith(
        startTime: '2036-07-29T19:30:00Z',
        arrivalTime: '2036-07-29T20:40:00Z',
      );

  WeatherSection section({
    RideWeatherView view = RideWeatherView.forecast,
    WeatherLegDto? leg,
    bool noLeg = false,
    WeatherDepartureOf departureOf = WeatherDepartureOf.leg,
    String? groupStartAt,
    bool collapsed = false,
    bool departureOnly = false,
    VoidCallback? onRetry,
    ValueChanged<WeatherCheckpointDto>? onCheckpointTap,
  }) => WeatherSection(
    view: view,
    timezone: 'Europe/Paris',
    departure: rideDeparture,
    departureAt: rideAt,
    leg: noLeg ? null : (leg ?? leg2036()),
    departureOf: departureOf,
    groupStartAt: groupStartAt,
    attribution: attribution,
    fetchedAt: fetchedAt,
    availableFrom: DateTime.utc(2036, 7, 22, 12),
    collapsed: collapsed,
    departureOnly: departureOnly,
    noLocationMessage: 'Ajoutez un lieu.',
    onRetry: onRetry,
    onCheckpointTap: onCheckpointTap,
  );

  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('les blocs dans l\'ordre : titre, départ, exposition, frise, '
      'prévision', (WidgetTester tester) async {
    await pump(tester, section());

    final List<Finder> blocks = <Finder>[
      find.byKey(keys.ride.weatherSection),
      find.byKey(keys.rideGroup.departureWeatherTitle),
      find.byKey(keys.ride.weatherExposure),
      find.byKey(keys.ride.weatherAlongRoute),
      find.byKey(keys.ride.weatherCheckpoint(0)),
      find.byKey(keys.ride.weatherForecastOf),
    ];
    for (final Finder f in blocks) {
      expect(f, findsOneWidget);
    }
    for (int i = 1; i < blocks.length; i++) {
      expect(top(tester, blocks[i]), greaterThan(top(tester, blocks[i - 1])));
    }
    expect(find.text('Météo'), findsOneWidget);
    expect(find.text('Exposition au vent'), findsOneWidget);
    // Plus de sous-titre « Le vent le long du parcours » dans la carte.
    expect(find.text('Le vent le long du parcours'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('l\'heure du départ', () {
    testWidgets('un leg qui porte son départ : celui du groupe', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        section(
          leg: leg2036(
            departure: DepartureWeatherDto(
              status: 'OK',
              conditions: fixtureConditions(temperature: 9),
            ),
          ).copyWith(startTime: '2036-07-29T20:00:00Z'),
          groupStartAt: '2036-07-29T20:00:00Z',
        ),
      );

      expect(find.text('Météo au départ de 22:00'), findsOneWidget);
      expect(find.text(nb('9 °C')), findsOneWidget);
      expect(find.textContaining('de la sortie'), findsNothing);
    });

    testWidgets('departureOf: ride — celui de la sortie, même si le leg en '
        'porte un', (WidgetTester tester) async {
      await pump(
        tester,
        section(
          leg: leg2036(
            departure: DepartureWeatherDto(
              status: 'OK',
              conditions: fixtureConditions(temperature: 9),
            ),
          ).copyWith(startTime: '2036-07-29T20:00:00Z'),
          departureOf: WeatherDepartureOf.ride,
        ),
      );

      expect(find.text('Météo au départ de 21:30'), findsOneWidget);
      expect(find.text(nb('14 °C')), findsWidgets);
      expect(find.text(nb('9 °C')), findsNothing);
    });

    testWidgets('un groupe à son heure sans départ propre : « de la sortie »', (
      WidgetTester tester,
    ) async {
      await pump(tester, section(groupStartAt: '2036-07-29T20:00:00Z'));

      expect(find.text('Météo au départ de la sortie, 21:30'), findsOneWidget);
    });

    testWidgets('lever et coucher du soleil au fuseau de la sortie', (
      WidgetTester tester,
    ) async {
      await pump(tester, section());

      expect(find.text('Lever du soleil 06:12'), findsOneWidget);
      expect(find.text('Coucher du soleil 21:31'), findsOneWidget);
    });
  });

  group('« Météo le long du parcours »', () {
    testWidgets('dépliée, dernier bloc : sous-titre et vitesse, la frise', (
      WidgetTester tester,
    ) async {
      await pump(tester, section());

      expect(find.byType(PdlDisclosure), findsNothing);
      expect(find.text('Météo le long du parcours'), findsOneWidget);
      expect(find.text(nb('Passages estimés à 26 km/h')), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
    });

    testWidgets('repliée quand du contenu suit : nombre de points, heures, '
        'vitesse ; se déplie au toucher', (WidgetTester tester) async {
      await pump(tester, section(collapsed: true));

      expect(find.byType(PdlDisclosure), findsOneWidget);
      expect(find.text('Météo le long du parcours'), findsOneWidget);
      expect(find.text('3 points · de 21:30 à 22:40'), findsOneWidget);
      expect(find.text(nb('Passages estimés à 26 km/h')), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);

      await tester.tap(find.byKey(keys.ride.weatherAlongRoute));
      await tester.pumpAndSettle();

      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(2)), findsOneWidget);
    });

    testWidgets('la vitesse par défaut se dit', (WidgetTester tester) async {
      await pump(
        tester,
        section(leg: leg2036(speedIsDefault: true), collapsed: true),
      );

      expect(find.textContaining('vitesse par défaut'), findsOneWidget);
    });

    testWidgets('seuls « Départ » et « Arrivée » portent un libellé', (
      WidgetTester tester,
    ) async {
      await pump(tester, section());

      expect(
        find.descendant(
          of: find.byKey(keys.ride.weatherCheckpoint(0)),
          matching: find.text('Départ'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(keys.ride.weatherCheckpoint(2)),
          matching: find.text('Arrivée'),
        ),
        findsOneWidget,
      );
      expect(find.text('En route'), findsNothing);
      // Le point intermédiaire commence par sa météo.
      expect(
        find.descendant(
          of: find.byKey(keys.ride.weatherCheckpoint(1)),
          matching: find.text(nb('14 °C Pluie')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('toucher un point le remonte à l\'écran (le réticule)', (
      WidgetTester tester,
    ) async {
      final List<int> taps = <int>[];
      await pump(
        tester,
        section(
          onCheckpointTap: (WeatherCheckpointDto p) => taps.add(p.indexField),
        ),
      );

      await tester.tap(find.byKey(keys.ride.weatherCheckpoint(1)));
      expect(taps, <int>[1]);
    });
  });

  testWidgets('la légende du vent, à pastilles, au dixième', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      section(
        leg: leg2036().copyWith(
          windExposure: const WindExposureDto(
            head: 40100,
            cross: 18200,
            tail: 34100,
          ),
        ),
      ),
    );

    expect(find.text(nb('Face 40,1 km')), findsOneWidget);
    expect(find.text(nb('Travers 18,2 km')), findsOneWidget);
    expect(find.text(nb('Dos 34,1 km')), findsOneWidget);
    // La légende n'a pas de flèches ; la seule est celle du vent dominant.
    expect(
      find.descendant(
        of: find.byKey(keys.ride.weatherExposure),
        matching: find.byType(PdlWindArrow),
      ),
      findsOneWidget,
    );
    expect(find.text('Vent dominant :'), findsOneWidget);
  });

  testWidgets('« Prévision du … » et ⓘ, qui ouvre la source', (
    WidgetTester tester,
  ) async {
    await pump(tester, section());

    final String line = tester
        .widget<Text>(find.byKey(keys.ride.weatherForecastOf))
        .data!;
    expect(line, 'Prévision du ${AppFormatters.formatTimestamp(fetchedAt)}');
    expect(line, matches(RegExp(r'^Prévision du \S+ \d+ \S+.* · 19:00$')));
    expect(find.text('Prévisions : Open-Meteo.com'), findsNothing);

    await tester.tap(find.byKey(keys.ride.weatherSourceButton));
    await tester.pumpAndSettle();

    expect(find.byKey(keys.ride.weatherSourceSheet), findsOneWidget);
    expect(find.text('Source des prévisions météo'), findsOneWidget);
    expect(find.text('Prévisions : Open-Meteo.com'), findsOneWidget);
  });

  testWidgets('le bouton ⓘ fait 44 px et se nomme', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pump(tester, section());

    expect(
      tester.getSize(find.byKey(keys.ride.weatherSourceButton)),
      const Size(44, 44),
    );
    expect(
      find.bySemanticsLabel('Source des prévisions météo'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('départ seul (plusieurs groupes) : ni vent ni frise', (
    WidgetTester tester,
  ) async {
    await pump(tester, section(departureOnly: true));

    expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
    expect(find.byKey(keys.rideGroup.departureWeatherTitle), findsOneWidget);
    expect(find.byKey(keys.ride.weatherForecastOf), findsOneWidget);
    expect(find.byKey(keys.ride.weatherExposure), findsNothing);
    expect(find.byKey(keys.ride.weatherAlongRoute), findsNothing);
    expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
    expect(find.byType(PdlBanner), findsNothing);
  });

  testWidgets('sans leg : le départ et la prévision', (
    WidgetTester tester,
  ) async {
    await pump(tester, section(noLeg: true));

    expect(find.byKey(keys.rideGroup.departureWeatherTitle), findsOneWidget);
    expect(find.byKey(keys.ride.weatherExposure), findsNothing);
    expect(find.byKey(keys.ride.weatherForecastOf), findsOneWidget);
  });

  group('états', () {
    testWidgets('hidden : le titre reste, avec une ligne d\'explication', (
      WidgetTester tester,
    ) async {
      await pump(tester, section(view: RideWeatherView.hidden));

      // La section ne disparaît plus (décision du 2026-11-10, MOB-134).
      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.text('Météo'), findsOneWidget);
      expect(find.byKey(keys.ride.weatherEmpty), findsOneWidget);
      expect(
        find.text('Aucune prévision n\'est à afficher pour cette sortie.'),
        findsOneWidget,
      );
      // Ni départ, ni frise, ni pied de prévision.
      expect(find.byKey(keys.rideGroup.departureWeatherTitle), findsNothing);
      expect(find.byKey(keys.ride.weatherAlongRoute), findsNothing);
      expect(find.byKey(keys.ride.weatherForecastOf), findsNothing);
      // `shows` dit encore qu'il n'y a rien d'autre que cette ligne.
      expect(WeatherSection.shows(RideWeatherView.hidden), isFalse);
    });

    testWidgets('hidden : la ligne de l\'écran quand il en donne une', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const WeatherSection(
          view: RideWeatherView.hidden,
          timezone: 'Europe/Paris',
          emptyMessage: 'Rien pour cette étape.',
        ),
      );

      expect(find.text('Rien pour cette étape.'), findsOneWidget);
    });

    testWidgets('STALE : le bandeau « Prévision ancienne »', (
      WidgetTester tester,
    ) async {
      await pump(tester, section(view: RideWeatherView.stale));

      expect(
        find.textContaining('Prévision ancienne', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
    });

    testWidgets('unavailable : « Réessayer » rappelle l\'écran', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await pump(
        tester,
        section(view: RideWeatherView.unavailable, onRetry: () => retries++),
      );

      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.byKey(keys.ride.weatherUnavailable), findsOneWidget);
      await tester.tap(find.byKey(keys.ride.weatherRetryButton));
      expect(retries, 1);
    });

    testWidgets('notYetAvailable : la date d\'ouverture', (
      WidgetTester tester,
    ) async {
      await pump(tester, section(view: RideWeatherView.notYetAvailable));

      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
      expect(
        find.textContaining('Prévision disponible à partir du'),
        findsOneWidget,
      );
      expect(find.byKey(keys.rideGroup.departureWeatherTitle), findsNothing);
    });

    testWidgets('noLocation : le mot de l\'écran', (WidgetTester tester) async {
      await pump(tester, section(view: RideWeatherView.noLocation));

      expect(find.byKey(keys.ride.weatherNoLocation), findsOneWidget);
      expect(find.text('Ajoutez un lieu.'), findsOneWidget);
    });

    testWidgets('un leg sans parcours : le départ, puis le bandeau', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        section(
          leg: leg2036(status: 'NO_LOCATION').copyWith(
            checkpoints: const <WeatherCheckpointDto>[],
            segments: const <WindSegmentDto>[],
          ),
        ),
      );

      expect(find.byKey(keys.rideGroup.departureWeatherTitle), findsOneWidget);
      expect(find.textContaining('n\'a pas de parcours'), findsOneWidget);
      expect(find.byKey(keys.ride.weatherAlongRoute), findsNothing);
    });

    testWidgets('un leg sans prévision : un bandeau, pas de frise', (
      WidgetTester tester,
    ) async {
      await pump(tester, section(leg: leg2036(status: 'UNAVAILABLE')));

      expect(find.byKey(keys.ride.weatherLegUnavailable), findsOneWidget);
      expect(find.byKey(keys.ride.weatherExposure), findsNothing);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
      expect(find.byKey(keys.ride.weatherForecastOf), findsOneWidget);
    });
  });
}
