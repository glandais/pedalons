import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/calendar/data/calendar_repository.dart';
import 'package:pedalons/features/calendar/presentation/widgets/calendar_subscription_card.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

CalendarTokenDto _token(String token) => CalendarTokenDto(
  token: token,
  globalFeedUrl: 'https://pedalons.test/api/calendar/ics?token=$token',
  teamFeedUrlTemplate:
      'https://pedalons.test/api/teams/{teamSlug}/calendar/ics?token=$token',
);

/// Le serveur d'un jeton : `getToken` rend le courant, sauf quand un test
/// retient la relecture ([nextRead]) pour observer la carte entre les deux.
class _FakeCalendarRepository implements CalendarRepository {
  CalendarTokenDto current = _token('ancien');
  Completer<void>? nextRead;

  @override
  Future<CalendarTokenDto> getToken() async {
    final Completer<void>? gate = nextRead;
    if (gate != null) await gate.future;
    return current;
  }

  @override
  Future<CalendarTokenDto> regenerateToken() async {
    current = _token('neuf');
    return current;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Après « Régénérer le lien », la carte ne donne jamais l'URL de l'ancien
/// jeton, qui ne marche plus : tant que le neuf n'est pas relu, ni copie ni
/// abonnement, et l'issue ne s'annonce qu'une fois relu.
void main() {
  setUpAll(loadTestTranslations);

  final List<String> clipboard = <String>[];
  setUp(() {
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  testWidgets('la copie après régénération donne le nouveau jeton', (
    WidgetTester tester,
  ) async {
    final _FakeCalendarRepository repository = _FakeCalendarRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [calendarRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: CalendarSubscriptionCard(teamSlug: 'mon-equipe'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(keys.calendar.subscriptionCopyButton));
    await tester.pumpAndSettle();
    expect(clipboard.last, contains('mon-equipe/calendar/ics?token=ancien'));

    repository.nextRead = Completer<void>();
    await tester.tap(find.byKey(keys.calendar.subscriptionRegenerateButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(keys.calendar.subscriptionRegenerateConfirmButton),
    );
    await tester.pump();
    await tester.pump();

    // Relecture en cours : l'ancien jeton est encore là, mais rien ne le donne.
    expect(find.textContaining('Lien régénéré'), findsNothing);
    await tester.tap(find.byKey(keys.calendar.subscriptionCopyButton));
    await tester.pump();
    expect(clipboard, hasLength(1));

    repository.nextRead!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Lien régénéré'), findsOneWidget);

    await tester.tap(find.byKey(keys.calendar.subscriptionCopyButton));
    await tester.pumpAndSettle();
    expect(clipboard.last, contains('mon-equipe/calendar/ics?token=neuf'));
  });
}
