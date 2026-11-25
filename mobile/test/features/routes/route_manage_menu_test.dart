import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/route_retouch.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_manage_menu.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import '../trips/trip_fixtures.dart';
import 'route_fixtures.dart';

/// Le menu « Gérer le parcours » de la fiche (ledger `MOB-79`).
class _StubRoutes implements RouteRepository {
  final List<String> deleted = <String>[];
  final List<String> restored = <String>[];
  final List<String> duplicated = <String>[];

  @override
  Future<RouteDto> duplicateRoute(
    String teamSlug,
    String routeSlug, {
    required String name,
  }) async {
    duplicated.add('$teamSlug/$routeSlug:$name');
    return fixtureStageRoute(slug: 'copie', name: name);
  }

  @override
  Future<void> deleteRoute(String teamSlug, String routeSlug) async =>
      deleted.add('$teamSlug/$routeSlug');

  @override
  Future<RouteDetailDto> undeleteRoute(
    String teamSlug,
    String routeSlug,
  ) async {
    restored.add('$teamSlug/$routeSlug');
    return managedRoute(slug: routeSlug);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Un parcours que l'appelant peut modifier et supprimer : le bloc
/// `permissions` d'un organisateur (docs/LEDGER_*.md MOB-137).
RouteDetailDto managedRoute({String? slug, bool deleted = false}) =>
    fixtureRouteDetail(
      slug: slug ?? 'col-de-la-croix',
      deleted: deleted,
      permissions: permissionsFor(member: true, role: 'ORGANIZER'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  group('routeManageActions', () {
    test("selon l'état, comme le menu du site", () {
      expect(
        routeManageActions(managedRoute(), canReport: true),
        <RouteManageAction>[
          RouteManageAction.edit,
          RouteManageAction.replaceGpx,
          RouteManageAction.duplicate,
          RouteManageAction.delete,
          RouteManageAction.report,
        ],
      );
    });

    test("pas de signalement de son propre parcours", () {
      expect(
        routeManageActions(managedRoute(), canReport: false),
        <RouteManageAction>[
          RouteManageAction.edit,
          RouteManageAction.replaceGpx,
          RouteManageAction.duplicate,
          RouteManageAction.delete,
        ],
      );
    });

    test("un parcours supprimé n'offre que sa restauration", () {
      for (final bool canReport in <bool>[true, false]) {
        expect(
          routeManageActions(managedRoute(deleted: true), canReport: canReport),
          <RouteManageAction>[RouteManageAction.restore],
        );
      }
    });

    // Les droits viennent du bloc `permissions` du parcours, pas du rôle
    // (docs/LEDGER_*.md MOB-137).
    test('sans aucun droit : le signalement seul, et pas de « Gérer »', () {
      final RouteDetailDto route = fixtureRouteDetail(
        permissions: kNoPermissions,
      );
      expect(routeManageActions(route, canReport: true), <RouteManageAction>[
        RouteManageAction.report,
      ]);
      expect(routeHasManageActions(route), isFalse);
    });

    test('supprimé, sans canDelete : rien à restaurer', () {
      expect(
        routeManageActions(
          fixtureRouteDetail(
            deleted: true,
            permissions: kNoPermissions.copyWith(canEdit: true),
          ),
          canReport: true,
        ),
        isEmpty,
      );
    });

    // docs/LEDGER_*.md MOB-185 : la retouche juste après « Modifier », pour
    // qui peut modifier — une ligne par opération offerte, comme le site ;
    // la ligne grisée « Retoucher » tant que l'analyse n'est pas finie.
    test('la retouche offerte : après « Modifier »', () {
      expect(
        routeManageActions(
          managedRoute(),
          canReport: false,
          retouch: RetouchEntry.available,
          operations: const <RouteRetouchOperation>[
            RouteRetouchOperation.resize,
            RouteRetouchOperation.moveEnd,
          ],
        ),
        <RouteManageAction>[
          RouteManageAction.edit,
          RouteManageAction.resize,
          RouteManageAction.moveEnd,
          RouteManageAction.replaceGpx,
          RouteManageAction.duplicate,
          RouteManageAction.delete,
        ],
      );
      expect(
        routeManageActions(
          managedRoute(),
          canReport: false,
          retouch: RetouchEntry.notReady,
        ),
        <RouteManageAction>[
          RouteManageAction.edit,
          RouteManageAction.retouch,
          RouteManageAction.replaceGpx,
          RouteManageAction.duplicate,
          RouteManageAction.delete,
        ],
      );
      expect(
        routeManageActions(
          fixtureRouteDetail(permissions: kNoPermissions),
          canReport: true,
          retouch: RetouchEntry.available,
        ),
        <RouteManageAction>[RouteManageAction.report],
      );
    });

    test('canEdit sans canDelete : modifier et remplacer, pas supprimer', () {
      final RouteDetailDto route = fixtureRouteDetail(
        permissions: kNoPermissions.copyWith(canEdit: true),
      );
      expect(routeManageActions(route, canReport: true), <RouteManageAction>[
        RouteManageAction.edit,
        RouteManageAction.replaceGpx,
        RouteManageAction.duplicate,
        RouteManageAction.report,
      ]);
      expect(routeHasManageActions(route), isTrue);
    });
  });

  group('la feuille', () {
    late SharedPreferences prefs;
    late _StubRoutes routes;
    late GoRouter router;

    setUp(() async {
      setCurrentLocale('fr');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      routes = _StubRoutes();
    });

    Future<void> pump(
      WidgetTester tester, {
      required RouteDetailDto route,
      bool canReport = true,
      RouteRetouchOfferDto? retouchOffer,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext _, GoRouterState _) => Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  Scaffold(
                    body: TextButton(
                      onPressed: () => showRouteManageMenu(
                        context,
                        ref,
                        route,
                        canReport: canReport,
                        retouchOffer: retouchOffer,
                      ),
                      child: const Text('ouvrir'),
                    ),
                  ),
            ),
          ),
          GoRoute(
            path: PathVariants.routes(':teamSlug')['fr']!,
            builder: (BuildContext _, GoRouterState _) =>
                const Text('liste des parcours'),
          ),
          GoRoute(
            path: PathVariants.routeEdit(':teamSlug', ':routeSlug')['fr']!,
            builder: (BuildContext _, GoRouterState state) => Text(
              'éditeur ${state.pathParameters['routeSlug']} '
              '${state.uri.queryParameters['gpx'] ?? '-'}',
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            routeRepositoryProvider.overrideWithValue(routes),
          ],
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('retouche en cours d\'analyse : la ligne, sa raison, inerte', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        route: managedRoute(),
        retouchOffer: const RouteRetouchOfferDto(
          available: false,
          operations: <RouteRetouchOperation>[],
          unavailableReason: 'NOT_READY',
        ),
      );
      expect(find.byKey(keys.routeManage.retouch), findsOneWidget);
      expect(
        find.text(
          'Ce parcours est en cours d\'analyse : la retouche sera possible ensuite.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(keys.routeManage.retouch));
      await settle(tester);
      // La feuille reste ouverte : la ligne ne mène nulle part.
      expect(find.byKey(keys.routeManage.retouch), findsOneWidget);
    });

    testWidgets('sans offre : pas de ligne « Retoucher »', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        route: managedRoute(),
        retouchOffer: const RouteRetouchOfferDto(
          available: false,
          operations: <RouteRetouchOperation>[],
          unavailableReason: 'ENGINE_UNAVAILABLE',
        ),
      );
      expect(find.byKey(keys.routeManage.edit), findsOneWidget);
      expect(find.byKey(keys.routeManage.retouch), findsNothing);
    });

    testWidgets('liste les gestes, destructif avant « Signaler »', (
      WidgetTester tester,
    ) async {
      await pump(tester, route: managedRoute());

      expect(find.text('Gérer le parcours'), findsOneWidget);
      expect(find.byKey(keys.routeManage.edit), findsOneWidget);
      expect(find.byKey(keys.routeManage.replaceGpx), findsOneWidget);
      expect(find.byKey(keys.routeManage.delete), findsOneWidget);
      expect(find.byKey(keys.routeManage.report), findsOneWidget);
      expect(find.byKey(keys.routeManage.restore), findsNothing);
      // Les libellés et les groupes du « Modifier ▾ » du site.
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Tracé'), findsOneWidget);
      expect(find.text('Remplacer le fichier GPX'), findsOneWidget);
      expect(find.text('Dupliquer'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
      expect(find.text('Signaler'), findsOneWidget);
    });

    testWidgets('sans signalement pour son propre parcours', (
      WidgetTester tester,
    ) async {
      await pump(tester, route: managedRoute(), canReport: false);

      expect(find.byKey(keys.routeManage.delete), findsOneWidget);
      expect(find.byKey(keys.routeManage.report), findsNothing);
    });

    testWidgets('un parcours supprimé : « Restaurer » seulement', (
      WidgetTester tester,
    ) async {
      await pump(tester, route: managedRoute(deleted: true));

      expect(find.byKey(keys.routeManage.restore), findsOneWidget);
      expect(find.byKey(keys.routeManage.edit), findsNothing);
      expect(find.byKey(keys.routeManage.delete), findsNothing);

      await tester.tap(find.byKey(keys.routeManage.restore));
      await settle(tester);

      expect(routes.restored, <String>['n-peloton/col-de-la-croix']);
      expect(find.text('Parcours restauré'), findsOneWidget);
    });

    testWidgets('« Modifier » ouvre l\'éditeur', (WidgetTester tester) async {
      await pump(tester, route: managedRoute());

      await tester.tap(find.byKey(keys.routeManage.edit));
      await settle(tester);

      expect(find.text('éditeur col-de-la-croix -'), findsOneWidget);
    });

    testWidgets(
      '« Remplacer le fichier GPX » ouvre l\'éditeur sur le sélecteur',
      (WidgetTester tester) async {
        await pump(tester, route: managedRoute());

        await tester.tap(find.byKey(keys.routeManage.replaceGpx));
        await settle(tester);

        expect(find.text('éditeur col-de-la-croix replace'), findsOneWidget);
        // Rien n'a été supprimé ni envoyé.
        expect(routes.deleted, isEmpty);
      },
    );

    testWidgets(
      '« Dupliquer » demande le nom de la copie, puis ouvre son éditeur',
      (WidgetTester tester) async {
        await pump(tester, route: managedRoute());

        await tester.tap(find.byKey(keys.routeManage.duplicate));
        await settle(tester);
        final TextField field = tester.widget(
          find.byKey(keys.routeManage.duplicateName),
        );
        expect(field.controller!.text, startsWith('Copie de '));

        await tester.enterText(
          find.byKey(keys.routeManage.duplicateName),
          'Col, variante',
        );
        await tester.tap(find.byKey(keys.routeManage.duplicateSubmit));
        await settle(tester);

        expect(routes.duplicated, <String>[
          'n-peloton/col-de-la-croix:Col, variante',
        ]);
        expect(find.text('éditeur copie -'), findsOneWidget);
      },
    );

    testWidgets('la suppression demande confirmation, puis supprime', (
      WidgetTester tester,
    ) async {
      await pump(tester, route: managedRoute());

      await tester.tap(find.byKey(keys.routeManage.delete));
      await settle(tester);

      expect(find.text('Supprimer le parcours ?'), findsOneWidget);
      expect(
        find.textContaining('« Col de la Croix » disparaîtra des listes'),
        findsOneWidget,
      );
      expect(routes.deleted, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(routes.deleted, <String>['n-peloton/col-de-la-croix']);
      // Rien dessous : retour à la liste des parcours de l'équipe.
      expect(find.text('liste des parcours'), findsOneWidget);
    });

    testWidgets('annuler la confirmation ne supprime rien', (
      WidgetTester tester,
    ) async {
      await pump(tester, route: managedRoute());

      await tester.tap(find.byKey(keys.routeManage.delete));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(routes.deleted, isEmpty);
      expect(find.text('liste des parcours'), findsNothing);
    });
  });
}
