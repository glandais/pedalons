import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/gpxtools/domain/weather_arrival.dart';

/// docs/LEDGER_*.md MOB-178 : la météo d'un aperçu se relit toutes les 15 s
/// tant qu'elle arrive, 3 minutes au plus, comme au site ; « Réessayer »
/// rouvre la fenêtre. `testWidgets` pour son temps simulé : les minuteurs
/// avancent avec `pump`, l'horloge avec [now].
void main() {
  testWidgets('relit toutes les 15 s tant que le cache est vide, puis '
      'renonce', (WidgetTester tester) async {
    DateTime clock = DateTime(2026);
    Future<void> elapse(Duration d) async {
      for (int s = 0; s < d.inSeconds; s++) {
        clock = clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    int refreshes = 0;
    int gaveUp = 0;
    final WeatherArrivalPoller poller = WeatherArrivalPoller(
      refresh: () => refreshes++,
      onGaveUp: () => gaveUp++,
      now: () => clock,
    );
    poller.update('UNAVAILABLE');
    await elapse(const Duration(seconds: 46));
    expect(refreshes, 3);
    expect(poller.waiting, isTrue);

    await elapse(const Duration(minutes: 3));
    expect(poller.waiting, isFalse);
    expect(poller.isPolling, isFalse);
    expect(gaveUp, 1);
    final int before = refreshes;

    poller.retry();
    expect(refreshes, before + 1);
    expect(poller.waiting, isTrue);
    poller.dispose();
  });

  testWidgets('une prévision arrivée arrête la relecture', (
    WidgetTester tester,
  ) async {
    int refreshes = 0;
    final WeatherArrivalPoller poller = WeatherArrivalPoller(
      refresh: () => refreshes++,
    );
    poller.update('STALE');
    expect(poller.isPolling, isTrue);
    poller.update('OK');
    expect(poller.isPolling, isFalse);
    await tester.pump(const Duration(minutes: 1));
    expect(refreshes, 0);
  });
}
