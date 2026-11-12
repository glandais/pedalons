import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_header.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// Constat C1 des captures des listes (ledger `MOB-143`) : l'en-tête d'équipe
/// affichait « Membre » à une organisatrice, que « Mes équipes » disait
/// « Organisateur ». Ce n'était pas la donnée de la galerie : l'en-tête
/// écrivait « Membre » pour tout rôle. Il porte désormais le rôle réel, comme
/// les cartes et l'en-tête du site.
void main() {
  setUpAll(loadTestTranslations);

  Future<void> open(WidgetTester tester, TeamDetailDto team) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamDetailProvider(team.slug).overrideWith((_) => team),
          myTeamsProvider.overrideWith((_) async => const <TeamDetailDto>[]),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                TeamHeaderSliver(
                  team: team,
                  section: TeamSectionKind.dashboard,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final (String role, String label) in <(String, String)>[
    ('ORGANIZER', 'Organisateur'),
    ('ADMIN', 'Administrateur'),
    ('MEMBER', 'Membre'),
  ]) {
    testWidgets('le badge dit « $label » pour $role', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureTeam(role: role));

      final PdlBadge badge = tester.widget<PdlBadge>(
        find.byKey(keys.team.headerRole),
      );
      expect(badge.label, label);
    });
  }

  testWidgets('pas de badge de rôle pour qui n\'est pas membre', (
    WidgetTester tester,
  ) async {
    await open(tester, fixtureTeam());

    expect(find.byKey(keys.team.headerRole), findsNothing);
  });
}
