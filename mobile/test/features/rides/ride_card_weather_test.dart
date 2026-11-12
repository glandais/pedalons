import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/home/providers/next_ride_provider.dart';
import 'package:pedalons/features/teams/presentation/widgets/publication_card.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';

/// La ligne météo d'une carte de fil, et son transport jusqu'à « Ma prochaine
/// sortie » (`rideFromListRow`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  const RideWeatherSummaryDto summary = RideWeatherSummaryDto(
    status: 'OK',
    condition: 'RAIN',
    daylight: true,
    temperatureMin: 9,
    temperatureMax: 13,
    wind: WindDto(speed: 22, direction: 250, compass: 'SW'),
  );

  PublicationDtoRide row({
    bool finished = false,
    String status = 'PUBLISHED',
  }) => PublicationDtoRide(
    permissions: kNoPermissions,
    timezone: 'Europe/Paris',
    tags: const <TagDto>[],
    groupSummaries: const [],
    team: const TeamPublicationDto(
      accessible: true,
      id: 't1',
      slug: 'n-peloton',
      name: 'N-Peloton',
      visibility: 'PUBLIC',
    ),
    id: 'r1',
    slug: 'np-665',
    name: 'N-Peloton #665',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    dateTime: '2099-07-29T19:30:00Z',
    endDateTime: '2099-07-29T22:30:00Z',
    status: status,
    visibility: 'PUBLIC',
    participantCount: 4,
    groupCount: 1,
    groups: const <RideGroupDto>[],
    topParticipants: const <PublicUserDto>[],
    deleted: false,
    registered: false,
    full: false,
    finished: finished,
    weather: summary,
  );

  PublicationDtoTrip trip({
    bool finished = false,
    String status = 'PUBLISHED',
  }) => PublicationDtoTrip(
    permissions: kNoPermissions,
    timezone: 'Europe/Paris',
    tags: const <TagDto>[],
    team: const TeamPublicationDto(
      accessible: true,
      id: 't1',
      slug: 'n-peloton',
      name: 'N-Peloton',
      visibility: 'PUBLIC',
    ),
    id: 'v1',
    slug: 'tour-des-alpes',
    name: 'Tour des Alpes',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    dateTime: '2099-07-29T07:30:00Z',
    endDateTime: '2099-07-29T10:30:00Z',
    status: status,
    finished: finished,
    visibility: 'PUBLIC',
    participantCount: 4,
    stageCount: 3,
    stages: const <TripStageDto>[],
    participants: const <PublicUserDto>[],
    deleted: false,
    registered: false,
    weather: summary,
  );

  Future<void> pump(WidgetTester tester, PublicationDto publication) async {
    final SharedPreferences prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PublicationCard(publication: publication),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('la carte de fil d\'une sortie porte sa ligne météo', (
    WidgetTester tester,
  ) async {
    await pump(tester, row());

    expect(find.byKey(keys.ride.weatherSummary), findsOneWidget);
    expect(find.text('9–13 °C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ni terminée, ni annulée', (WidgetTester tester) async {
    await pump(tester, row(finished: true));
    expect(find.byKey(keys.ride.weatherSummary), findsNothing);

    await pump(tester, row(status: 'CANCELLED'));
    expect(find.byKey(keys.ride.weatherSummary), findsNothing);
  });

  // Ledger API-82 : la carte d'un voyage porte la ligne de sa prochaine étape,
  // avec le même widget.
  testWidgets('la carte de fil d\'un voyage porte sa ligne météo', (
    WidgetTester tester,
  ) async {
    await pump(tester, trip());

    expect(find.byKey(keys.ride.weatherSummary), findsOneWidget);
    expect(find.text('9–13 °C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ni voyage terminé, ni annulé', (WidgetTester tester) async {
    await pump(tester, trip(finished: true));
    expect(find.byKey(keys.ride.weatherSummary), findsNothing);

    await pump(tester, trip(status: 'CANCELLED'));
    expect(find.byKey(keys.ride.weatherSummary), findsNothing);
  });

  test('« Ma prochaine sortie » garde la météo de la ligne de liste', () {
    expect(rideFromListRow(row()).weather, summary);
  });

  test('« Ma prochaine sortie » garde la distance d’affichage de la ligne '
      '(règle R3, docs/LEDGER_*.md API-178)', () {
    final RideDto ride = rideFromListRow(
      row().copyWith(displayDistance: 78000, displayElevationGain: 980),
    );
    expect(ride.displayDistance, 78000);
    expect(ride.displayElevationGain, 980);
  });
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}
