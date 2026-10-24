import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_header.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import 'team_fixtures.dart';

/// L'en-tête épinglé d'une équipe, sur une page plus courte que l'écran.
///
/// Le rebond d'iOS fait passer le défilement par des positions fractionnaires,
/// au-delà de la fin du contenu. L'en-tête mesurait alors son enfant par une
/// somme de flottants (barre, bloc replié à `1 - t`) qui tombait parfois un
/// ulp sous `maxExtent - scrollOffset` : « SliverGeometry is not valid:
/// layoutExtent exceeds paintExtent » (173.4982777320797 contre
/// 173.49827773207974), vu sur la page « À propos » d'une équipe.
void main() {
  final TeamDetailDto team = fixtureTeam();

  Future<ScrollController> open(WidgetTester tester, double topPadding) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamDetailProvider(team.slug).overrideWith((_) => team),
          // L'en-tête lit « Mes équipes » pour décider de son menu.
          myTeamsProvider.overrideWith((_) async => const <TeamDetailDto>[]),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(440, 956),
              padding: EdgeInsets.only(top: topPadding),
            ),
            child: Scaffold(
              body: CustomScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: <Widget>[
                  TeamHeaderSliver(
                    team: team,
                    section: TeamSectionKind.dashboard,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  for (final double topPadding in <double>[0, 47, 59, 61.49827773207974, 62]) {
    testWidgets('aucune position du rebond ne rend une géométrie invalide '
        '(encoche de $topPadding px)', (WidgetTester tester) async {
      final ScrollController controller = await open(tester, topPadding);

      // Toutes les positions d'un rebond, par pas fractionnaires : de
      // l'étirement en haut jusqu'au-delà du repli complet du bloc.
      for (double offset = -40; offset <= 80; offset += 0.0973) {
        controller.jumpTo(offset);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'offset $offset');
      }
    });
  }

  testWidgets('un vrai geste de rebond, tiré puis relâché', (
    WidgetTester tester,
  ) async {
    await open(tester, 62);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -300),
      2000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      2000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'l\'en-tête mesure exactement son étendue, déployé comme replié',
    (WidgetTester tester) async {
      final ScrollController controller = await open(tester, 62);

      expect(tester.getSize(find.byType(TeamHeader)).height, 62 + 56 + 56);
      controller.jumpTo(20.3);
      await tester.pump();
      expect(tester.getSize(find.byType(TeamHeader)).height, 62 + 112 - 20.3);
      controller.jumpTo(200);
      await tester.pump();
      expect(tester.getSize(find.byType(TeamHeader)).height, 62 + 56);
    },
  );
}
