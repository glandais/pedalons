import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/config/router.dart';

/// `/equipes?role=all` ouvre l'annuaire ; `/equipes` reste « Mes équipes ».
void main() {
  test('role=all ouvre l\'annuaire, en français comme en anglais', () {
    expect(
      redirectTeamsDirectory(Uri.parse('/equipes?role=all')),
      Paths.teamsDiscover(),
    );
    expect(
      redirectTeamsDirectory(Uri.parse('/teams?role=all')),
      Paths.teamsDiscover(),
    );
  });

  test('les autres adresses ne sont pas détournées', () {
    expect(redirectTeamsDirectory(Uri.parse('/equipes')), isNull);
    expect(redirectTeamsDirectory(Uri.parse('/equipes?role=member')), isNull);
    expect(redirectTeamsDirectory(Uri.parse('/sorties?role=all')), isNull);
  });
}
