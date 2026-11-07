import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/rides/domain/group_start.dart';

import 'ride_fixtures.dart';

/// `docs/LEDGER_*.md MOB-111` : l'heure qui concerne la personne a une source
/// unique — son groupe s'il est connu, sinon la sortie.
void main() {
  const String rideAt = '2026-10-11T06:00:00Z';

  test('un groupe qui part avec la sortie rend l’instant de la sortie', () {
    expect(myStartAt(rideAt, fixtureGroup(startAt: rideAt)), rideAt);
  });

  test('un groupe à l’heure propre rend son propre départ', () {
    expect(
      myStartAt(rideAt, fixtureGroup(startAt: '2026-10-11T06:30:00Z')),
      '2026-10-11T06:30:00Z',
    );
  });

  test('sans groupe rejoint, le départ de la sortie', () {
    expect(myStartAt(rideAt, null), rideAt);
  });
}
