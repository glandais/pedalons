import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/presentation/pages/teams_page.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// Ledger `MOB-139` — la carte de l'onglet Équipes : D3 (« 1 membre », jamais
/// « 1 membres »), D4 (« Administrateur ») et D9 (composants Pdl, logo lu dans
/// `team.logoUrl`).
void main() {
  setUpAll(loadTestTranslations);

  Future<void> open(WidgetTester tester, List<TeamDetailDto> teams) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myTeamsProvider.overrideWith((Ref ref) async => teams),
          myInvitationsProvider.overrideWith(
            (Ref ref) async => const <MyInvitationDto>[],
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const TeamsPage(),
        ),
      ),
    );
    // La grille anime l'entrée de ses cartes.
    await tester.pumpAndSettle();
  }

  testWidgets('le compte de membres s\'accorde, le rôle garde son nom', (
    WidgetTester tester,
  ) async {
    await open(tester, <TeamDetailDto>[
      fixtureTeam(slug: 'solo', name: 'Solo', memberCount: 1, role: 'ADMIN'),
      fixtureTeam(slug: 'club', name: 'Club', memberCount: 40),
    ]);

    expect(find.text('1 membre'), findsOneWidget);
    expect(find.text('40 membres'), findsOneWidget);
    expect(find.textContaining('1 membres'), findsNothing);
    final PdlBadge role = tester.widget<PdlBadge>(
      find.descendant(
        of: find.byKey(keys.teams.teamCard('solo')),
        matching: find.byType(PdlBadge),
      ),
    );
    expect(role.label, 'Administrateur');
  });

  testWidgets('la carte est une PdlCard, avec le logo de `team.logoUrl`', (
    WidgetTester tester,
  ) async {
    await open(tester, <TeamDetailDto>[
      fixtureTeam(slug: 'club', name: 'Club', logoUrl: 'https://x/logo.png'),
    ]);

    final Finder card = find.byKey(keys.teams.teamCard('club'));
    expect(tester.widget(card), isA<PdlCard>());
    final PdlAvatar avatar = tester.widget<PdlAvatar>(
      find.descendant(of: card, matching: find.byType(PdlAvatar)),
    );
    expect(avatar.imageUrl, 'https://x/logo.png');
  });
}
