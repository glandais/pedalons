import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/trips/presentation/widgets/stage_card.dart';

import 'trip_fixtures.dart';

/// Règle R7 des cartes (KIT §9, docs/LEDGER_*.md MOB-139) : « GPS » sur la
/// carte d'une étape d'un voyage auquel la personne participe, jusqu'à
/// l'arrivée de l'étape ; ni hors du voyage, ni sur un voyage annulé, ni sans
/// parcours.
void main() {
  final RouteDto route = fixtureStageRoute();
  TripStageDto stage({RouteDto? r}) =>
      fixtureStage(index: 1, dateTime: '2099-08-12T07:00:00Z', route: r);
  // Sans arrivée estimée, l'étape dure 3 h.
  final DateTime before = DateTime.utc(2099, 8, 12, 6);
  final DateTime during = DateTime.utc(2099, 8, 12, 8);
  final DateTime after = DateTime.utc(2099, 8, 12, 11);

  test('inscrite : avant le départ et pendant l’étape', () {
    final TripDto trip = fixtureTrip(registered: true);
    expect(stageExportable(trip, stage(r: route), now: before), isTrue);
    expect(stageExportable(trip, stage(r: route), now: during), isTrue);
  });

  test('l’étape arrivée : plus de « GPS »', () {
    final TripDto trip = fixtureTrip(registered: true);
    expect(stageExportable(trip, stage(r: route), now: after), isFalse);
  });

  test('pas inscrite, voyage annulé, étape sans parcours : rien', () {
    expect(
      stageExportable(fixtureTrip(), stage(r: route), now: before),
      isFalse,
    );
    expect(
      stageExportable(
        fixtureTrip(registered: true, status: 'CANCELLED'),
        stage(r: route),
        now: before,
      ),
      isFalse,
    );
    expect(
      stageExportable(fixtureTrip(registered: true), stage(), now: before),
      isFalse,
    );
  });
}
