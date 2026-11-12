import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/rides/presentation/widgets/templates/ride_template_summary.dart';

import '../../support/localization.dart';
import 'ride_template_fixtures.dart';

/// Règle R4 des cartes (KIT §9, docs/LEDGER_*.md MOB-139) : un modèle sans
/// groupe ne dit pas « Aucun groupe ».
void main() {
  setUpAll(loadTestTranslations);

  test('avec des groupes : « 3 groupes · prochaine sortie #42 »', () {
    expect(
      rideTemplateSummary(fixtureTemplate(), long: true),
      '3 groupes · prochaine sortie #42',
    );
  });

  test('sans groupe : pas de compteur à zéro', () {
    final String long = rideTemplateSummary(
      fixtureTemplate(groups: const []),
      long: true,
    );
    expect(long, isNot(contains('groupe')));
    expect(long, isNotEmpty);
    expect(
      rideTemplateSummary(fixtureTemplate(groups: const [], nextNumber: null)),
      isEmpty,
    );
  });
}
