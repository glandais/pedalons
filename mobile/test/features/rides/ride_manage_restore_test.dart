import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_manage_menu.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// Restaurer une sortie visible hors de l'équipe dont des parcours sont passés
/// en « Équipe » : le refus liste ces parcours dans sa feuille, pas dans le
/// message générique (docs/LEDGER_*.md MOB-137, plan §4.4).
class _StubRides implements RideRepository {
  _StubRides(this.failure);

  final Object failure;

  @override
  Future<RideDto> undeleteRide(String teamSlug, String rideSlug) async =>
      throw failure;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _refusal(List<Map<String, dynamic>> routes) => DioException(
  requestOptions: RequestOptions(path: '/rides/x/undelete'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/rides/x/undelete'),
    statusCode: 400,
    data: <String, dynamic>{
      'code': 'INCOMPATIBLE_VISIBILITY',
      'errorDetails': <String, dynamic>{
        'type': 'INCOMPATIBLE_VISIBILITY',
        'routes': routes,
        'usages': <Map<String, dynamic>>[],
      },
    },
  ),
);

const Map<String, dynamic> _colDuCoq = <String, dynamic>{
  'slug': 'col-du-coq',
  'name': 'Col du Coq',
  'visibility': 'TEAM',
  'proposedVisibility': 'PUBLIC_UNLISTED',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> restore(WidgetTester tester, Object failure) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final RideDto ride = fixtureRide().copyWith(deleted: true);
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                Scaffold(
                  body: TextButton(
                    onPressed: () => runRideManageAction(
                      context,
                      ref,
                      ride,
                      RideManageAction.restore,
                    ),
                    child: const Text('restaurer'),
                  ),
                ),
          ),
        ),
        GoRoute(
          path: PathVariants.route(':teamSlug', ':routeSlug')['fr']!,
          builder: (BuildContext _, GoRouterState state) =>
              Text('fiche ${state.pathParameters['routeSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rideRepositoryProvider.overrideWithValue(_StubRides(failure)),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.text('restaurer'));
    await settle(tester);
  }

  testWidgets('le refus liste les parcours, sans message générique', (
    WidgetTester tester,
  ) async {
    await restore(tester, _refusal(<Map<String, dynamic>>[_colDuCoq]));

    expect(find.byKey(keys.visibility.restoreBlockedSheet), findsOneWidget);
    expect(
      find.byKey(keys.visibility.restoreRoute('col-du-coq')),
      findsOneWidget,
    );
    expect(find.text('Col du Coq'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // Chaque parcours ouvre sa fiche.
    await tester.tap(find.byKey(keys.visibility.restoreRoute('col-du-coq')));
    await settle(tester);
    expect(find.byKey(keys.visibility.restoreBlockedSheet), findsNothing);
    expect(find.text('fiche col-du-coq'), findsOneWidget);
  });

  testWidgets('« Fermer » referme la feuille sans rien ouvrir', (
    WidgetTester tester,
  ) async {
    await restore(tester, _refusal(<Map<String, dynamic>>[_colDuCoq]));

    await tester.tap(find.byKey(keys.visibility.refusalClose));
    await settle(tester);
    expect(find.byKey(keys.visibility.restoreBlockedSheet), findsNothing);
    expect(find.text('restaurer'), findsOneWidget);
  });

  testWidgets('un refus sans liste garde le message, sans feuille', (
    WidgetTester tester,
  ) async {
    await restore(tester, _refusal(<Map<String, dynamic>>[]));

    expect(find.byKey(keys.visibility.restoreBlockedSheet), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
