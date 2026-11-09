import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/widgets/day_box.dart';

import '../../support/localization.dart';

/// BRANDING §7.8 (ledger `BRAND-9`) : sur une carte, la boîte du jour est la
/// seule date — l'année s'y ajoute hors de l'année en cours.
void main() {
  setUpAll(() => loadTestTranslations());

  final DateTime now = DateTime(2026, 11, 9);

  test('l\'année en cours garde trois lignes', () {
    expect(dayBoxFor(DateTime(2026, 12, 12), now: now).year, isNull);
  });

  test('une autre année ajoute « 2027 »', () {
    expect(dayBoxFor(DateTime(2027, 4, 10), now: now).year, '2027');
  });
}
