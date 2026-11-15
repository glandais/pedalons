import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/trips/data/trip_repository.dart';
import 'package:pedalons/features/trips/presentation/widgets/trip_manage_menu.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import 'trip_fixtures.dart';

/// Le menu « Gérer le voyage » (ledger `MOB-162`).
TripDto _trip({
  String status = 'PUBLISHED',
  bool deleted = false,
  ContentPermissionsDto? permissions,
}) => fixtureTrip(status: status).copyWith(
  deleted: deleted,
  permissions: permissions ?? permissionsFor(member: true, role: 'ORGANIZER'),
);

class _StubTrips implements TripRepository {
  final List<String> statuses = <String>[];
  final List<String> deleted = <String>[];
  final List<String> restored = <String>[];

  @override
  Future<TripDto> changeStatus(
    String teamSlug,
    String tripSlug,
    Status status,
  ) async {
    statuses.add('$tripSlug ${status.json}');
    return _trip(status: status.json!);
  }

  @override
  Future<void> deleteTrip(String teamSlug, String tripSlug) async =>
      deleted.add('$teamSlug/$tripSlug');

  @override
  Future<TripDto> undeleteTrip(String teamSlug, String tripSlug) async {
    restored.add('$teamSlug/$tripSlug');
    return _trip();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  group('tripManageActions', () {
    test('selon le statut, comme le menu du site', () {
      expect(tripManageActions(_trip(status: 'DRAFT')), <TripManageAction>[
        TripManageAction.publish,
        TripManageAction.delete,
        TripManageAction.report,
      ]);
      expect(tripManageActions(_trip()), <TripManageAction>[
        TripManageAction.unpublish,
        TripManageAction.cancel,
        TripManageAction.delete,
        TripManageAction.report,
      ]);
      expect(tripManageActions(_trip(status: 'CANCELLED')), <TripManageAction>[
        TripManageAction.reinstate,
        TripManageAction.delete,
        TripManageAction.report,
      ]);
    });

    test("un voyage supprimé n'offre que sa restauration", () {
      expect(tripManageActions(_trip(deleted: true)), <TripManageAction>[
        TripManageAction.restore,
      ]);
    });

    // Les droits viennent du bloc `permissions` du voyage, pas du
    // rôle (docs/LEDGER_*.md MOB-137).
    test('sans aucun droit : le signalement seul, et pas de « Gérer »', () {
      final TripDto trip = _trip(permissions: kNoPermissions);
      expect(tripManageActions(trip), <TripManageAction>[
        TripManageAction.report,
      ]);
      expect(tripHasManageActions(trip), isFalse);
    });

    test('canEdit sans canDelete : le statut, pas la suppression', () {
      final TripDto trip = _trip(
        permissions: kNoPermissions.copyWith(canEdit: true),
      );
      expect(tripManageActions(trip), <TripManageAction>[
        TripManageAction.unpublish,
        TripManageAction.cancel,
        TripManageAction.report,
      ]);
      expect(tripHasManageActions(trip), isTrue);
    });
  });

  group('la feuille', () {
    late SharedPreferences prefs;
    late _StubTrips trips;

    setUp(() async {
      setCurrentLocale('fr');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      trips = _StubTrips();
    });

    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester, {required TripDto trip}) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext _, GoRouterState _) => Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  Scaffold(
                    body: TextButton(
                      onPressed: () => showTripManageMenu(context, ref, trip),
                      child: const Text('ouvrir'),
                    ),
                  ),
            ),
          ),
          GoRoute(
            path: PathVariants.teamAgenda(':teamSlug')['fr']!,
            builder: (BuildContext _, GoRouterState _) =>
                const Text('agenda de l\'équipe'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            tripRepositoryProvider.overrideWithValue(trips),
          ],
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await settle(tester);
    }

    testWidgets('un brouillon se publie sans confirmation', (
      WidgetTester tester,
    ) async {
      await pump(tester, trip: _trip(status: 'DRAFT'));

      expect(find.text('Gérer le voyage'), findsOneWidget);
      expect(find.byKey(keys.tripManage.unpublish), findsNothing);
      await tester.tap(find.byKey(keys.tripManage.publish));
      await settle(tester);

      expect(trips.statuses, <String>['gtmc-bromance PUBLISHED']);
      expect(find.text('Voyage publié'), findsOneWidget);
    });

    testWidgets('dépublier demande confirmation', (WidgetTester tester) async {
      await pump(tester, trip: _trip());

      await tester.tap(find.byKey(keys.tripManage.unpublish));
      await settle(tester);
      expect(find.text('Dépublier le voyage ?'), findsOneWidget);
      expect(trips.statuses, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);
      expect(trips.statuses, <String>['gtmc-bromance DRAFT']);
    });

    testWidgets('un voyage supprimé : « Restaurer » seulement', (
      WidgetTester tester,
    ) async {
      await pump(tester, trip: _trip(deleted: true));

      expect(find.byKey(keys.tripManage.delete), findsNothing);
      await tester.tap(find.byKey(keys.tripManage.restore));
      await settle(tester);

      expect(trips.restored, <String>['n-peloton/gtmc-bromance']);
      expect(find.text('Voyage restauré'), findsOneWidget);
    });

    testWidgets('la suppression demande confirmation, puis supprime', (
      WidgetTester tester,
    ) async {
      await pump(tester, trip: _trip());

      await tester.tap(find.byKey(keys.tripManage.delete));
      await settle(tester);
      expect(find.text('Supprimer le voyage ?'), findsOneWidget);
      expect(trips.deleted, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(trips.deleted, <String>['n-peloton/gtmc-bromance']);
      // Rien dessous : retour à l'Agenda de l'équipe.
      expect(find.text('agenda de l\'équipe'), findsOneWidget);
    });
  });
}
