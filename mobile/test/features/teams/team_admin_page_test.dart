import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/link_launcher.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/presentation/pages/team_admin_page.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// Le hub « Gestion de l'équipe » (ledger `MOB-165`) : qui y entre, quelles
/// lignes chacun voit, et où elles mènent.
class _Teams implements TeamRepository {
  _Teams({this.role, this.fail = false, this.refusedWith});

  final String? role;
  bool fail;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  final int? refusedWith;
  int myTeamsReads = 0;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    final int? status = refusedWith;
    if (status != null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/teams/$slug'),
        type: DioExceptionType.badResponse,
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(path: '/api/teams/$slug'),
          statusCode: status,
          data: <String, Object?>{'code': 'NOT_FOUND'},
        ),
      );
    }
    if (fail) throw StateError('indisponible');
    return fixtureTeam(slug: slug, role: role);
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async {
    myTeamsReads++;
    return const <TeamDetailDto>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));
  tearDown(() => debugLinkOpener = null);

  // Les lignes, dans l'ordre des onglets du site.
  final List<Key> organizerRows = <Key>[
    keys.teamAdmin.rideTemplates,
    keys.teamAdmin.places,
    keys.teamAdmin.reports,
  ];
  final List<Key> adminOnlyRows = <Key>[
    keys.teamAdmin.tags,
    keys.teamAdmin.pages,
    keys.teamAdmin.members,
    keys.teamAdmin.settings,
  ];

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<_Teams> open(
    WidgetTester tester, {
    String? role,
    bool platformAdmin = false,
    bool fail = false,
    int? refusedWith,
  }) async {
    final _Teams teams = _Teams(
      role: role,
      fail: fail,
      refusedWith: refusedWith,
    );
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('équipe'),
        ),
        GoRoute(
          path: '/hub',
          builder: (BuildContext _, GoRouterState _) =>
              const TeamAdminPage(teamSlug: 'n-peloton'),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/modeles-sortie',
          builder: (BuildContext _, GoRouterState state) =>
              Text('modèles de ${state.pathParameters['teamSlug']}'),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/parametres',
          builder: (BuildContext _, GoRouterState state) =>
              Text('paramètres de ${state.pathParameters['teamSlug']}'),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/membres',
          builder: (BuildContext _, GoRouterState state) =>
              Text('membres de ${state.pathParameters['teamSlug']}'),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/signalements',
          builder: (BuildContext _, GoRouterState state) =>
              Text('signalements de ${state.pathParameters['teamSlug']}'),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/lieux',
          builder: (BuildContext _, GoRouterState state) =>
              Text('lieux de ${state.pathParameters['teamSlug']}'),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/tags',
          builder: (BuildContext _, GoRouterState state) =>
              Text('tags de ${state.pathParameters['teamSlug']}'),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/pages',
          builder: (BuildContext _, GoRouterState state) =>
              Text('pages de ${state.pathParameters['teamSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/hub');
    await settle(tester);
    return teams;
  }

  /// Les clés des lignes rendues, de haut en bas.
  List<Key> shownRows(WidgetTester tester) {
    final List<Key> all = <Key>[
      keys.teamAdmin.rideTemplates,
      keys.teamAdmin.places,
      keys.teamAdmin.tags,
      keys.teamAdmin.pages,
      keys.teamAdmin.members,
      keys.teamAdmin.reports,
      keys.teamAdmin.settings,
    ];
    final List<Key> shown = <Key>[
      for (final Key key in all)
        if (find.byKey(key).evaluate().isNotEmpty) key,
    ];
    shown.sort(
      (Key a, Key b) => tester
          .getTopLeft(find.byKey(a))
          .dy
          .compareTo(tester.getTopLeft(find.byKey(b)).dy),
    );
    return shown;
  }

  testWidgets('un simple membre lit un refus, avec un retour', (
    WidgetTester tester,
  ) async {
    await open(tester, role: 'MEMBER');

    expect(find.byKey(keys.teamAdmin.forbidden), findsOneWidget);
    expect(find.text('Réservé au rôle Organisateur'), findsOneWidget);
    for (final Key row in <Key>[...organizerRows, ...adminOnlyRows]) {
      expect(find.byKey(row), findsNothing);
    }

    await tester.tap(find.byKey(keys.teamAdmin.forbiddenBack));
    await settle(tester);
    expect(find.text('équipe'), findsOneWidget);
    expect(find.byKey(keys.teamAdmin.forbidden), findsNothing);
  });

  testWidgets('hors de l\'équipe : le même refus', (WidgetTester tester) async {
    await open(tester);

    expect(find.byKey(keys.teamAdmin.forbidden), findsOneWidget);
  });

  for (final int status in <int>[403, 404]) {
    testWidgets('une équipe que le serveur refuse ($status) : le refus, pas '
        'une erreur à réessayer', (WidgetTester tester) async {
      await open(tester, refusedWith: status);

      expect(find.byKey(keys.teamAdmin.forbidden), findsOneWidget);
      expect(find.byKey(keys.teamAdmin.loadError), findsNothing);
      expect(find.text('Réessayer'), findsNothing);

      await tester.tap(find.byKey(keys.teamAdmin.forbiddenBack));
      await settle(tester);
      expect(find.text('équipe'), findsOneWidget);
    });
  }

  testWidgets('organisateur : les modèles, les lieux et les signalements — '
      'aucune ligne d\'administration', (WidgetTester tester) async {
    await open(tester, role: 'ORGANIZER');

    expect(find.text('Gestion de l\'équipe'), findsOneWidget);
    expect(find.byKey(keys.teamAdmin.forbidden), findsNothing);
    expect(shownRows(tester), organizerRows);
  });

  testWidgets('administrateur : les sept lignes, dans l\'ordre du site', (
    WidgetTester tester,
  ) async {
    await open(tester, role: 'ADMIN');

    expect(shownRows(tester), <Key>[
      keys.teamAdmin.rideTemplates,
      keys.teamAdmin.places,
      keys.teamAdmin.tags,
      keys.teamAdmin.pages,
      keys.teamAdmin.members,
      keys.teamAdmin.reports,
      keys.teamAdmin.settings,
    ]);
    expect(find.text('Modèles de sortie'), findsOneWidget);
    expect(find.text('Lieux'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Pages'), findsOneWidget);
    expect(find.text('Gestion des membres'), findsOneWidget);
    expect(find.text('Signalements'), findsOneWidget);
    expect(find.text('Paramètres'), findsOneWidget);
  });

  testWidgets('admin de plateforme non membre : les sept lignes, sans lire '
      '« Mes équipes »', (WidgetTester tester) async {
    final _Teams teams = await open(tester, platformAdmin: true);

    expect(find.byKey(keys.teamAdmin.forbidden), findsNothing);
    expect(shownRows(tester), hasLength(7));
    expect(teams.myTeamsReads, 0);
  });

  testWidgets('« Modèles de sortie » ouvre l\'écran de l\'app', (
    WidgetTester tester,
  ) async {
    final List<Uri> launched = <Uri>[];
    debugLinkOpener = (Uri url) async {
      launched.add(url);
      return true;
    };
    await open(tester, role: 'ORGANIZER');

    await tester.tap(find.byKey(keys.teamAdmin.rideTemplates));
    await settle(tester);

    expect(find.text('modèles de n-peloton'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('« Paramètres » ouvre l\'écran de l\'app (MOB-166)', (
    WidgetTester tester,
  ) async {
    final List<Uri> launched = <Uri>[];
    debugLinkOpener = (Uri url) async {
      launched.add(url);
      return true;
    };
    await open(tester, role: 'ADMIN');

    await tester.tap(find.byKey(keys.teamAdmin.settings));
    await settle(tester);

    expect(find.text('paramètres de n-peloton'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('« Gestion des membres » ouvre l\'écran de l\'app (MOB-167)', (
    WidgetTester tester,
  ) async {
    final List<Uri> launched = <Uri>[];
    debugLinkOpener = (Uri url) async {
      launched.add(url);
      return true;
    };
    await open(tester, role: 'ADMIN');

    await tester.tap(find.byKey(keys.teamAdmin.members));
    await settle(tester);

    expect(find.text('membres de n-peloton'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('« Lieux » ouvre l\'écran de l\'app, pour qui organise '
      '(MOB-168)', (WidgetTester tester) async {
    final List<Uri> launched = <Uri>[];
    debugLinkOpener = (Uri url) async {
      launched.add(url);
      return true;
    };
    await open(tester, role: 'ORGANIZER');

    await tester.tap(find.byKey(keys.teamAdmin.places));
    await settle(tester);

    expect(find.text('lieux de n-peloton'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('« Signalements » ouvre l\'écran de l\'app, pour qui '
      'organise (MOB-168)', (WidgetTester tester) async {
    final List<Uri> launched = <Uri>[];
    debugLinkOpener = (Uri url) async {
      launched.add(url);
      return true;
    };
    await open(tester, role: 'ORGANIZER');

    await tester.tap(find.byKey(keys.teamAdmin.reports));
    await settle(tester);

    expect(find.text('signalements de n-peloton'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('« Tags » ouvre l\'écran de l\'app (MOB-169)', (
    WidgetTester tester,
  ) async {
    final List<Uri> launched = <Uri>[];
    debugLinkOpener = (Uri url) async {
      launched.add(url);
      return true;
    };
    await open(tester, role: 'ADMIN');

    await tester.tap(find.byKey(keys.teamAdmin.tags));
    await settle(tester);

    expect(find.text('tags de n-peloton'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('un rôle Organisateur ne quitte plus l\'app : aucune de ses '
      'lignes n\'ouvre le site', (WidgetTester tester) async {
    await open(tester, role: 'ORGANIZER');

    expect(find.text('S\'ouvre sur le site'), findsNothing);
  });

  testWidgets('« Pages » ouvre l\'écran de l\'app (MOB-169)', (
    WidgetTester tester,
  ) async {
    final List<Uri> launched = <Uri>[];
    debugLinkOpener = (Uri url) async {
      launched.add(url);
      return true;
    };
    await open(tester, role: 'ADMIN');

    await tester.tap(find.byKey(keys.teamAdmin.pages));
    await settle(tester);

    expect(find.text('pages de n-peloton'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('plus aucune ligne ne quitte l\'app, pour qui administre '
      'comme pour qui organise (MOB-169)', (WidgetTester tester) async {
    await open(tester, role: 'ADMIN');

    expect(shownRows(tester), hasLength(7));
    expect(find.text('S\'ouvre sur le site'), findsNothing);
  });

  testWidgets('la fiche en échec : une erreur, et « Réessayer » la relit', (
    WidgetTester tester,
  ) async {
    final _Teams teams = await open(tester, role: 'ADMIN', fail: true);

    expect(find.byKey(keys.teamAdmin.loadError), findsOneWidget);
    expect(find.byKey(keys.teamAdmin.forbidden), findsNothing);

    teams.fail = false;
    await tester.tap(find.text('Réessayer'));
    await settle(tester);

    expect(find.byKey(keys.teamAdmin.loadError), findsNothing);
    expect(shownRows(tester), hasLength(7));
  });
}
