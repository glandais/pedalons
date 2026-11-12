import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/presentation/pages/teams_page.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_discovery_card.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// Ledger `MOB-139` — la carte de l'onglet Équipes : D3 (« 1 membre », jamais
/// « 1 membres »), D4 (« Administrateur »), D9 (logo lu dans `team.logoUrl`)
/// et règle R12 (la carte de la découverte, seule carte d'équipe de l'app).
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
    await tester.pumpAndSettle();
  }

  testWidgets('le compte de membres s\'accorde, le rôle garde son nom', (
    WidgetTester tester,
  ) async {
    await open(tester, <TeamDetailDto>[
      fixtureTeam(slug: 'solo', name: 'Solo', memberCount: 1, role: 'ADMIN'),
      fixtureTeam(slug: 'club', name: 'Club', memberCount: 40),
    ]);

    expect(find.text('1\u00a0membre'), findsOneWidget);
    expect(find.text('40\u00a0membres'), findsOneWidget);
    expect(find.textContaining('1\u00a0membres'), findsNothing);
    final PdlBadge role = tester.widget<PdlBadge>(
      find.byKey(keys.teams.teamCardRole('solo')),
    );
    expect(role.label, 'Administrateur');
  });

  testWidgets('règle R12 : la carte de la découverte, avec le logo de '
      '`team.logoUrl`, l’extrait sur deux lignes et aucun bouton', (
    WidgetTester tester,
  ) async {
    await open(tester, <TeamDetailDto>[
      fixtureTeam(
        slug: 'club',
        name: 'Club',
        logoUrl: 'https://x/logo.png',
        role: 'MEMBER',
      ).copyWith(excerpt: 'Sorties route et gravel au départ de Huelgoat.'),
    ]);

    final Finder card = find.byKey(keys.teams.teamCard('club'));
    expect(tester.widget(card), isA<TeamDiscoveryCard>());
    expect(
      find.descendant(of: card, matching: find.byType(PdlCardMedia)),
      findsOneWidget,
    );
    final Text excerpt = tester.widget<Text>(
      find.text('Sorties route et gravel au départ de Huelgoat.'),
    );
    expect(excerpt.maxLines, 2);
    expect(
      tester
          .widget<PdlBadge>(find.byKey(keys.teams.teamCardRole('club')))
          .label,
      'Membre',
    );
    expect(
      find.descendant(of: card, matching: find.byType(PdlButton)),
      findsNothing,
    );
    final PdlAvatar avatar = tester.widget<PdlAvatar>(
      find.descendant(of: card, matching: find.byType(PdlAvatar)),
    );
    expect(avatar.imageUrl, 'https://x/logo.png');
  });
}
