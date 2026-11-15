import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_header.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// « Gérer l'équipe » dans l'en-tête (ledger `MOB-165`) : l'entrée du hub
/// « Gestion de l'équipe », pour qui organise l'équipe et personne d'autre.
void main() {
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));

  Future<void> open(
    WidgetTester tester,
    TeamDetailDto team, {
    bool platformAdmin = false,
  }) async {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => Scaffold(
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
        GoRoute(
          path: '/equipes/:teamSlug/admin',
          builder: (BuildContext _, GoRouterState state) =>
              Text('gestion de ${state.pathParameters['teamSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamDetailProvider(team.slug).overrideWith((_) => team),
          myTeamsProvider.overrideWith((_) async => const <TeamDetailDto>[]),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  for (final String role in <String>['ORGANIZER', 'ADMIN']) {
    testWidgets('$role : le bouton ouvre « Gestion de l\'équipe »', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureTeam(role: role));

      expect(find.byKey(keys.team.manageButton), findsOneWidget);
      expect(find.bySemanticsLabel('Gérer l\'équipe'), findsOneWidget);

      await tester.tap(find.byKey(keys.team.manageButton));
      await tester.pumpAndSettle();
      expect(find.text('gestion de n-peloton'), findsOneWidget);
    });
  }

  testWidgets('un simple membre n\'a pas le bouton', (
    WidgetTester tester,
  ) async {
    await open(tester, fixtureTeam(role: 'MEMBER'));

    expect(find.byKey(keys.team.manageButton), findsNothing);
  });

  testWidgets('hors de l\'équipe : pas de bouton', (WidgetTester tester) async {
    await open(tester, fixtureTeam());

    expect(find.byKey(keys.team.manageButton), findsNothing);
  });

  testWidgets('admin de plateforme non membre : le bouton', (
    WidgetTester tester,
  ) async {
    await open(tester, fixtureTeam(), platformAdmin: true);

    expect(find.byKey(keys.team.manageButton), findsOneWidget);
  });

  testWidgets('la barre tient sur un petit écran, bouton compris', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await open(
      tester,
      fixtureTeam(name: 'Vélo Club des Hauts de Garonne', role: 'ADMIN'),
    );

    expect(find.byKey(keys.team.manageButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
