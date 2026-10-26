import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/trips/presentation/widgets/trip_summary_card.dart';

import '../../support/localization.dart';
import 'trip_fixtures.dart';

/// Un non-membre ne reçoit que le nombre (API-144) : la rangée des
/// participants n'a ni avatars ni chevron, et ne se touche pas — la liste lui
/// est refusée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  Future<void> pump(
    WidgetTester tester,
    TripDto trip,
    VoidCallback? onShowParticipants,
  ) => tester.pumpWidget(
    ProviderScope(
      overrides: [unitSystemProvider.overrideWithValue(UnitSystem.metric)],
      child: MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TripSummaryCard(
              trip: trip,
              onShowParticipants: onShowParticipants,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('non-membre : le nombre seul, sans avatars ni action', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      fixtureTrip(participantCount: 12, participants: const <PublicUserDto>[]),
      null,
    );
    await tester.pump();

    expect(find.byType(PdlAvatarStack), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.textContaining('12'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('membre : les avatars et l\'action restent', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pump(tester, fixtureTrip(participantCount: 3), () => taps++);
    await tester.pump();

    expect(find.byType(PdlAvatarStack), findsOneWidget);
    await tester.tap(find.byType(PdlAvatarStack));
    expect(taps, 1);
  });
}
