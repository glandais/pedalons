import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections_bar.dart';

import 'team_fixtures.dart';

/// La rangée des sections d'une équipe déborde de l'écran : la puce de la
/// section ouverte est amenée à l'écran, sinon « Parcours » ou « À propos »
/// restent au-delà du bord et rien ne dit où l'on est.
void main() {
  setUp(() => setCurrentLocale('fr'));

  final TeamDetailDto team = fixtureTeam(role: 'ADMIN');
  final List<TeamSection> sections = buildTeamSections(team);

  // Sans traductions, une puce porte sa clé (« team.sections… ») et mesure
  // ~300 px : l'écran de 400 px n'en montre qu'une.
  Future<void> open(WidgetTester tester, TeamSectionKind current) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: TeamSectionChips(sections: sections, current: current),
        ),
      ),
    );
    await tester.pump();
  }

  Rect chipRect(WidgetTester tester, TeamSectionKind kind) =>
      tester.getRect(find.byType(PdlChip).at(indexOfSection(kind, sections)));

  test('la rangée a de quoi déborder', () {
    expect(sections.length, greaterThanOrEqualTo(6));
  });

  testWidgets('la dernière section ouverte, sa puce est à l\'écran', (
    WidgetTester tester,
  ) async {
    await open(tester, sections.last.kind);
    final Rect rect = chipRect(tester, sections.last.kind);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(400));
  });

  testWidgets('le tableau de bord ouvert, la rangée part du début', (
    WidgetTester tester,
  ) async {
    await open(tester, TeamSectionKind.dashboard);
    expect(
      tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!
          .offset,
      0,
    );
  });
}
