import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/utils/push_location.dart';

/// docs/LEDGER_*.md MOB-44, MOB-46 — depuis une page plein écran, ouvrir une
/// page d'onglet (l'équipe, une de ses sections) laissait un écran vide.
///
/// Le routeur reprend la forme de `config/router.dart`, avec ses vrais
/// chemins : un shell à onglets, l'arbre d'équipe dans la branche Équipes, et
/// une sortie imbriquée sous l'équipe mais affichée sur le navigateur racine.
void main() {
  setUpAll(() => setCurrentLocale('fr'));

  late GlobalKey<NavigatorState> rootKey;

  GoRouter buildRouter() {
    rootKey = GlobalKey<NavigatorState>();
    Page<void> tab(String label) => NoTransitionPage<void>(child: Text(label));
    return GoRouter(
      navigatorKey: rootKey,
      initialLocation: Paths.home(),
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: Paths.home(),
                  pageBuilder: (c, s) => tab('accueil'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: PathVariants.teams()['fr']!,
                  pageBuilder: (c, s) => tab('liste des équipes'),
                ),
                GoRoute(
                  path: PathVariants.team(':teamSlug')['fr']!,
                  pageBuilder: (c, s) =>
                      tab('équipe ${s.pathParameters['teamSlug']}'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'annonces',
                      pageBuilder: (c, s) =>
                          tab('annonces ${s.pathParameters['teamSlug']}'),
                    ),
                    GoRoute(
                      path: 'sorties/:rideSlug',
                      parentNavigatorKey: rootKey,
                      builder: (c, s) => Scaffold(
                        body: Text('sortie ${s.pathParameters['rideSlug']}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: Paths.profile(),
                  pageBuilder: (c, s) => tab('profil'),
                ),
                GoRoute(
                  path: Paths.profileAccount(),
                  pageBuilder: (c, s) => tab('mon compte'),
                ),
                GoRoute(
                  path: Paths.profilePrivacy(),
                  pageBuilder: (c, s) => tab('confidentialité'),
                  routes: <RouteBase>[
                    GoRoute(
                      path: Paths.blockedUsers().substring(
                        Paths.profilePrivacy().length + 1,
                      ),
                      pageBuilder: (c, s) => tab('bloqués'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<GoRouter> pump(WidgetTester tester) async {
    final GoRouter router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> open(WidgetTester tester, String location) async {
    pushLocation(rootKey.currentContext!, location);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester, GoRouter router) async {
    router.pop();
    await tester.pumpAndSettle();
  }

  Finder shown(String text) => find.text(text).hitTestable();

  testWidgets('d\'une sortie à son équipe : l\'équipe, dans son onglet', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester);
    await open(tester, Paths.ride('vc', 'rando'));
    expect(shown('sortie rando'), findsOneWidget);

    await open(tester, Paths.team('vc'));
    expect(tester.takeException(), isNull);
    expect(shown('équipe vc'), findsOneWidget);

    await back(tester, router);
    expect(shown('liste des équipes'), findsOneWidget);
  });

  testWidgets('d\'une sortie à une autre équipe, même chose', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await open(tester, Paths.ride('vc', 'rando'));
    await open(tester, Paths.team('autre'));
    expect(tester.takeException(), isNull);
    expect(shown('équipe autre'), findsOneWidget);
  });

  testWidgets('d\'une sortie à une section d\'équipe : retour sur l\'équipe', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester);
    await open(tester, Paths.ride('vc', 'rando'));
    await open(tester, Paths.teamAds('vc'));
    expect(tester.takeException(), isNull);
    expect(shown('annonces vc'), findsOneWidget);

    await back(tester, router);
    expect(shown('équipe vc'), findsOneWidget);
  });

  testWidgets('depuis un onglet, un push ordinaire qui garde le retour', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester);
    await open(tester, Paths.team('vc'));
    expect(shown('équipe vc'), findsOneWidget);

    await back(tester, router);
    expect(shown('accueil'), findsOneWidget);
  });

  testWidgets('vers une page plein écran, un push ordinaire', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester);
    await open(tester, Paths.team('vc'));
    await open(tester, Paths.ride('vc', 'rando'));
    expect(shown('sortie rando'), findsOneWidget);

    await back(tester, router);
    expect(shown('équipe vc'), findsOneWidget);
  });

  // MOB-48 : les sous-pages du profil sont des pages d'onglet ; ouvertes
  // depuis une page plein écran, elles prennent la pile de leur lien profond.
  testWidgets(
    'd\'une sortie aux utilisateurs bloqués : Profil › Confidentialité',
    (WidgetTester tester) async {
      final GoRouter router = await pump(tester);
      await open(tester, Paths.ride('vc', 'rando'));
      await open(tester, Paths.blockedUsers());
      expect(tester.takeException(), isNull);
      expect(shown('bloqués'), findsOneWidget);

      await back(tester, router);
      expect(shown('confidentialité'), findsOneWidget);
      await back(tester, router);
      expect(shown('profil'), findsOneWidget);
    },
  );

  testWidgets('depuis l\'onglet Profil, une sous-page par push ordinaire', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pump(tester);
    router.go(Paths.profile());
    await tester.pumpAndSettle();
    await open(tester, Paths.profileAccount());
    expect(shown('mon compte'), findsOneWidget);

    await back(tester, router);
    expect(shown('profil'), findsOneWidget);
  });
}
