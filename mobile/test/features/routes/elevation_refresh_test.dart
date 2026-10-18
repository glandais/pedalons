import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/routes/domain/elevation_refresh.dart';

/// Le rafraîchissement de la fiche tant que l'altitude est provisoire (ledger
/// `MOB-76`) : toutes les 30 s en `PENDING`, jamais en `FAST` ni en `HD`, et
/// plus du tout au bout de 15 minutes — la règle du site (`WEB-102`).
///
/// `testWidgets` pour son temps simulé : `pump(d)` fait avancer les minuteurs,
/// et l'horloge du poller suit la même durée, par pas de 30 s.
void main() {
  test('seul PENDING est provisoire', () {
    expect(isElevationPending('PENDING'), isTrue);
    expect(isElevationPending('FAST'), isFalse);
    expect(isElevationPending('HD'), isFalse);
    expect(isElevationPending(null), isFalse);
  });

  late DateTime clock;
  late int calls;

  ElevationRefreshPoller poller() {
    clock = DateTime(2026, 10, 18, 9);
    calls = 0;
    return ElevationRefreshPoller(refresh: () => calls++, now: () => clock);
  }

  /// Avance l'horloge et les minuteurs de [d], par pas d'au plus 30 s.
  Future<void> elapse(WidgetTester tester, Duration d) async {
    Duration left = d;
    while (left > Duration.zero) {
      final Duration step = left > kElevationPollInterval
          ? kElevationPollInterval
          : left;
      clock = clock.add(step);
      await tester.pump(step);
      left -= step;
    }
  }

  testWidgets('PENDING redemande toutes les 30 s, HD arrête', (
    WidgetTester tester,
  ) async {
    final ElevationRefreshPoller p = poller()..update('PENDING');

    await elapse(tester, const Duration(seconds: 29));
    expect(calls, 0);
    await elapse(tester, const Duration(seconds: 1));
    expect(calls, 1);
    await elapse(tester, const Duration(seconds: 60));
    expect(calls, 3);

    // La réponse rechargée est encore PENDING : un seul minuteur.
    p.update('PENDING');
    await elapse(tester, kElevationPollInterval);
    expect(calls, 4);

    p.update('HD');
    expect(p.isPolling, isFalse);
    await elapse(tester, const Duration(minutes: 5));
    expect(calls, 4);
    p.dispose();
  });

  testWidgets('FAST et HD ne déclenchent rien', (WidgetTester tester) async {
    final ElevationRefreshPoller p = poller()..update('FAST');
    await elapse(tester, const Duration(minutes: 2));
    p.update('HD');
    await elapse(tester, const Duration(minutes: 2));
    expect(calls, 0);
    expect(p.isPolling, isFalse);
  });

  testWidgets('renonce au bout de 15 minutes, sans repartir sur un PENDING', (
    WidgetTester tester,
  ) async {
    final ElevationRefreshPoller p = poller()..update('PENDING');

    await elapse(tester, const Duration(minutes: 20));
    expect(p.isPolling, isFalse);
    // 30 relances au plus dans la fenêtre de 15 minutes.
    final int made = calls;
    expect(made, inInclusiveRange(29, 30));

    p.update('PENDING');
    await elapse(tester, const Duration(minutes: 2));
    expect(calls, made);

    // Un HD puis un nouvel enregistrement rouvrent une fenêtre.
    p.update('HD');
    p.update('PENDING');
    await elapse(tester, kElevationPollInterval);
    expect(calls, made + 1);
    p.dispose();
  });
}
