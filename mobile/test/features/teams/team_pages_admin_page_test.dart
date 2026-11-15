import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart' hide Visibility;
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/presentation/pages/team_pages_admin_page.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/features/visibility/presentation/visibility_badge.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// « Pages de l'équipe » (ledger `MOB-169`) : qui y entre — et qu'aucune
/// requête de pages ne part pour les autres —, les états de la liste (aucune
/// page, une, trois, une page supprimée), les requêtes exactes de monter et
/// descendre, la suppression, la restauration, et ce qui est relu ensuite.
class _Teams implements TeamRepository {
  _Teams({this.role, this.refusedWith, this.gate});

  final String? role;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  final int? refusedWith;

  /// Si posé, `getTeam` attend qu'il soit complété.
  final Completer<void>? gate;

  int teamReads = 0;
  int myTeamsReads = 0;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    teamReads++;
    await gate?.future;
    final int? status = refusedWith;
    if (status != null) throw _apiError(status, 'NOT_FOUND');
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

class _Pages implements TeamPagesClient {
  _Pages([List<TeamPageSummaryDto>? pages])
    : pages = pages ?? <TeamPageSummaryDto>[_faq, _rules, _gear];

  List<TeamPageSummaryDto> pages;
  Object? writeError;

  /// Si posé, les écritures attendent qu'il soit complété.
  Completer<void>? writeGate;

  int listCalls = 0;
  final List<List<String>> reorders = <List<String>>[];
  final List<String> deleted = <String>[];
  final List<String> restored = <String>[];

  Future<void> _write() async {
    await writeGate?.future;
    final Object? error = writeError;
    if (error != null) throw error;
  }

  @override
  Future<List<TeamPageSummaryDto>> listPages({required String teamSlug}) async {
    listCalls++;
    return pages;
  }

  @override
  Future<List<TeamPageSummaryDto>> reorderPages({
    required String teamSlug,
    required ReorderPagesRequest body,
  }) async {
    await _write();
    reorders.add(body.pageIds);
    pages = <TeamPageSummaryDto>[
      for (int i = 0; i < body.pageIds.length; i++)
        pages
            .firstWhere((TeamPageSummaryDto p) => p.id == body.pageIds[i])
            .copyWith(order: i),
    ];
    return pages;
  }

  @override
  Future<void> deletePage({
    required String pageSlug,
    required String teamSlug,
  }) async {
    await _write();
    deleted.add(pageSlug);
    pages = <TeamPageSummaryDto>[
      for (final TeamPageSummaryDto p in pages)
        p.slug == pageSlug ? p.copyWith(deleted: true) : p,
    ];
  }

  @override
  Future<TeamPageDto> undeletePage({
    required String pageSlug,
    required String teamSlug,
  }) async {
    await _write();
    restored.add(pageSlug);
    pages = <TeamPageSummaryDto>[
      for (final TeamPageSummaryDto p in pages)
        p.slug == pageSlug ? p.copyWith(deleted: false) : p,
    ];
    throw StateError('la réponse n\'est pas lue');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const TeamPageSummaryDto _faq = TeamPageSummaryDto(
  id: 'pg1',
  title: 'FAQ',
  slug: 'faq',
  visibility: 'PUBLIC',
  order: 0,
  deleted: false,
);

const TeamPageSummaryDto _rules = TeamPageSummaryDto(
  id: 'pg2',
  title: 'Règlement',
  slug: 'reglement',
  visibility: 'TEAM',
  order: 1,
  deleted: false,
);

const TeamPageSummaryDto _gear = TeamPageSummaryDto(
  id: 'pg3',
  title: 'Équipement',
  slug: 'equipement',
  visibility: 'PUBLIC_UNLISTED',
  order: 2,
  deleted: false,
);

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton/pages'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton/pages'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));

  final k = keys.teamPages;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    required _Teams teams,
    _Pages? pages,
    bool platformAdmin = false,
  }) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('hub'),
        ),
        GoRoute(
          path: '/pages',
          builder: (BuildContext _, GoRouterState _) =>
              const TeamPagesAdminPage(teamSlug: 'n-peloton'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams),
          teamPagesClientProvider.overrideWithValue(pages ?? _Pages()),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/pages');
    await settle(tester);
  }

  bool actionEnabled(WidgetTester tester, Key key) =>
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed !=
      null;

  String count(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(k.count)).data!;

  /// Les ids des lignes rendues, de haut en bas.
  List<String> shownOrder(WidgetTester tester, List<String> ids) {
    final List<String> shown = <String>[
      for (final String id in ids)
        if (find.byKey(k.row(id)).evaluate().isNotEmpty) id,
    ];
    shown.sort(
      (String a, String b) => tester
          .getTopLeft(find.byKey(k.row(a)))
          .dy
          .compareTo(tester.getTopLeft(find.byKey(k.row(b))).dy),
    );
    return shown;
  }

  group('accès', () {
    for (final String? role in <String?>['ORGANIZER', 'MEMBER', null]) {
      testWidgets('rôle $role : un refus, et aucune requête de pages', (
        WidgetTester tester,
      ) async {
        final _Pages pages = _Pages();
        await open(
          tester,
          teams: _Teams(role: role),
          pages: pages,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.text('Réservé au rôle Administrateur'), findsOneWidget);
        expect(pages.listCalls, 0);
        expect(find.text('FAQ'), findsNothing);

        await tester.tap(find.byKey(k.forbiddenBack));
        await settle(tester);
        expect(find.text('hub'), findsOneWidget);
      });
    }

    for (final int status in <int>[403, 404]) {
      testWidgets('une équipe que le serveur refuse ($status) : le refus, '
          'aucune requête de pages', (WidgetTester tester) async {
        final _Pages pages = _Pages();
        await open(
          tester,
          teams: _Teams(refusedWith: status),
          pages: pages,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.byKey(k.loadError), findsNothing);
        expect(pages.listCalls, 0);
      });
    }

    testWidgets('tant que la fiche charge : ni liste, ni refus, ni requête', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final _Pages pages = _Pages();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN', gate: gate),
        pages: pages,
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(pages.listCalls, 0);

      gate.complete();
      await settle(tester);
      expect(pages.listCalls, 1);
    });

    testWidgets('rôle ADMIN : la liste, lue une fois', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(pages.listCalls, 1);
      expect(find.byKey(k.row('pg1')), findsOneWidget);
    });

    testWidgets('admin de plateforme non membre : la liste', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      await open(tester, teams: _Teams(), pages: pages, platformAdmin: true);

      expect(find.byKey(k.forbidden), findsNothing);
      expect(find.byKey(k.row('pg1')), findsOneWidget);
      expect(pages.listCalls, 1);
    });
  });

  group('liste', () {
    testWidgets('aucune page : l\'état vide du site, « 0 page sur 3 '
        'maximum »', (WidgetTester tester) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: _Pages(<TeamPageSummaryDto>[]),
      );

      expect(find.byKey(k.empty), findsOneWidget);
      expect(find.text('Aucune page'), findsOneWidget);
      expect(
        find.text(
          'Créez des pages personnalisées pour la FAQ, les règles ou toute '
          'information sur l\'équipe.',
        ),
        findsOneWidget,
      );
      expect(count(tester), '0 page sur 3 maximum');
    });

    testWidgets('une page : son titre, sa visibilité, ni « monter » ni '
        '« descendre »', (WidgetTester tester) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: _Pages(<TeamPageSummaryDto>[_faq]),
      );

      expect(count(tester), '1 page sur 3 maximum');
      expect(tester.widget<Text>(find.byKey(k.rowTitle('pg1'))).data, 'FAQ');
      expect(
        tester
            .widget<VisibilityBadge>(find.byKey(k.rowVisibility('pg1')))
            .visibility,
        Visibility.public,
      );
      expect(find.byKey(k.rowMoveUp('pg1')), findsNothing);
      expect(find.byKey(k.rowMoveDown('pg1')), findsNothing);
      expect(find.byKey(k.rowDelete('pg1')), findsOneWidget);
      expect(find.byKey(k.rowRestore('pg1')), findsNothing);
      expect(find.byKey(k.rowDeleted('pg1')), findsNothing);
    });

    testWidgets('trois pages, dans l\'ordre de l\'équipe : la première ne '
        'monte pas, la dernière ne descend pas', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      expect(count(tester), '3 pages sur 3 maximum');
      expect(shownOrder(tester, <String>['pg1', 'pg2', 'pg3']), <String>[
        'pg1',
        'pg2',
        'pg3',
      ]);
      expect(find.byKey(k.rowMoveUp('pg1')), findsNothing);
      expect(find.byKey(k.rowMoveDown('pg1')), findsOneWidget);
      expect(find.byKey(k.rowMoveUp('pg2')), findsOneWidget);
      expect(find.byKey(k.rowMoveDown('pg2')), findsOneWidget);
      expect(find.byKey(k.rowMoveUp('pg3')), findsOneWidget);
      expect(find.byKey(k.rowMoveDown('pg3')), findsNothing);
      for (final (String id, Visibility visibility) in <(String, Visibility)>[
        ('pg1', Visibility.public),
        ('pg2', Visibility.team),
        ('pg3', Visibility.publicUnlisted),
      ]) {
        expect(
          tester
              .widget<VisibilityBadge>(find.byKey(k.rowVisibility(id)))
              .visibility,
          visibility,
        );
      }
    });

    testWidgets('une page supprimée : « Supprimé », à restaurer — elle ne '
        'compte pas dans les trois, et ne se supprime pas deux fois', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: _Pages(<TeamPageSummaryDto>[
          _faq,
          _rules.copyWith(deleted: true),
          _gear,
        ]),
      );

      expect(count(tester), '2 pages sur 3 maximum');
      expect(find.byKey(k.rowDeleted('pg2')), findsOneWidget);
      expect(find.byKey(k.rowRestore('pg2')), findsOneWidget);
      expect(find.byKey(k.rowDelete('pg2')), findsNothing);
      // Elle garde son rang, et se déplace comme les autres.
      expect(find.byKey(k.rowMoveUp('pg2')), findsOneWidget);
      expect(find.byKey(k.rowMoveDown('pg2')), findsOneWidget);
      // Les autres ne changent pas.
      expect(find.byKey(k.rowDeleted('pg1')), findsNothing);
      expect(find.byKey(k.rowDelete('pg1')), findsOneWidget);
    });

    testWidgets('la liste en échec : une erreur, et « Réessayer » la relit', (
      WidgetTester tester,
    ) async {
      final _FailingOnce pages = _FailingOnce();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      expect(find.byKey(k.listError), findsOneWidget);
      expect(find.byKey(k.count), findsNothing);

      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(find.byKey(k.row('pg1')), findsOneWidget);
    });
  });

  group('réordonner', () {
    testWidgets('« descendre » envoie la liste complète des identifiants, '
        'dans le nouvel ordre', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams, pages: pages);
      final int teamReads = teams.teamReads;

      await tester.tap(find.byKey(k.rowMoveDown('pg1')));
      await settle(tester);

      expect(pages.reorders, <List<String>>[
        <String>['pg2', 'pg1', 'pg3'],
      ]);
      expect(find.text('Pages réordonnées'), findsOneWidget);
      // La liste est relue, et la fiche de l'équipe — « À propos » lit son
      // `pages[]` — aussi ; « Mes équipes » non.
      expect(pages.listCalls, 2);
      expect(teams.teamReads, teamReads + 1);
      expect(teams.myTeamsReads, 0);
      expect(shownOrder(tester, <String>['pg1', 'pg2', 'pg3']), <String>[
        'pg2',
        'pg1',
        'pg3',
      ]);
    });

    testWidgets('« monter » aussi', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      await tester.tap(find.byKey(k.rowMoveUp('pg3')));
      await settle(tester);

      expect(pages.reorders.single, <String>['pg1', 'pg3', 'pg2']);
    });

    testWidgets('une page supprimée reste dans la liste envoyée, comme au '
        'site : le serveur ne range que les identifiants reçus', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages(<TeamPageSummaryDto>[
        _faq,
        _rules.copyWith(deleted: true),
        _gear,
      ]);
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      await tester.tap(find.byKey(k.rowMoveUp('pg3')));
      await settle(tester);

      expect(pages.reorders.single, <String>['pg1', 'pg3', 'pg2']);
    });

    testWidgets('pendant l\'écriture, les autres gestes attendent ; un '
        'second appui ne part pas', (WidgetTester tester) async {
      final _Pages pages = _Pages()..writeGate = Completer<void>();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      await tester.tap(find.byKey(k.rowMoveDown('pg1')));
      await tester.tap(find.byKey(k.rowMoveDown('pg1')), warnIfMissed: false);
      await settle(tester);

      for (final Key key in <Key>[
        k.rowMoveDown('pg1'),
        k.rowMoveUp('pg2'),
        k.rowDelete('pg2'),
        k.rowDelete('pg3'),
      ]) {
        expect(actionEnabled(tester, key), isFalse);
      }

      pages.writeGate!.complete();
      await settle(tester);
      expect(pages.reorders, hasLength(1));
      expect(actionEnabled(tester, k.rowDelete('pg3')), isTrue);
    });

    testWidgets('le serveur refuse : un bandeau, l\'ordre ne change pas', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages()..writeError = _apiError(403, 'FORBIDDEN');
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      await tester.tap(find.byKey(k.rowMoveDown('pg1')));
      await settle(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(find.text('Pages réordonnées'), findsNothing);
      expect(shownOrder(tester, <String>['pg1', 'pg2', 'pg3']), <String>[
        'pg1',
        'pg2',
        'pg3',
      ]);
      expect(actionEnabled(tester, k.rowMoveDown('pg1')), isTrue);
    });
  });

  group('supprimer et restaurer', () {
    testWidgets('la confirmation nomme la page ; confirmée, la page passe à '
        'la corbeille et la liste est relue', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams, pages: pages);
      final int teamReads = teams.teamReads;

      await tester.tap(find.byKey(k.rowDelete('pg2')));
      await settle(tester);
      expect(find.text('Supprimer la page'), findsOneWidget);
      expect(
        find.textContaining('supprimer la page « Règlement »'),
        findsOneWidget,
      );
      expect(pages.deleted, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(pages.deleted, <String>['reglement']);
      expect(find.text('Page supprimée'), findsOneWidget);
      expect(pages.listCalls, 2);
      expect(teams.teamReads, teamReads + 1);
      // Elle reste dans la liste, à restaurer, et ne compte plus.
      expect(find.byKey(k.rowDeleted('pg2')), findsOneWidget);
      expect(find.byKey(k.rowRestore('pg2')), findsOneWidget);
      expect(count(tester), '2 pages sur 3 maximum');
    });

    testWidgets('annulée : rien ne part, et les gestes sont rendus', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      await tester.tap(find.byKey(k.rowDelete('pg2')));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(pages.deleted, isEmpty);
      expect(pages.listCalls, 1);
      expect(actionEnabled(tester, k.rowDelete('pg2')), isTrue);
    });

    testWidgets('un double appui n\'ouvre qu\'une confirmation et n\'envoie '
        'qu\'une suppression', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      await tester.tap(find.byKey(k.rowDelete('pg2')));
      await tester.tap(find.byKey(k.rowDelete('pg2')), warnIfMissed: false);
      await settle(tester);

      expect(find.byKey(keys.profile.confirmDestructiveButton), findsOneWidget);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);
      expect(pages.deleted, hasLength(1));
    });

    testWidgets('le serveur refuse la suppression : un bandeau, la page '
        'reste', (WidgetTester tester) async {
      final _Pages pages = _Pages()..writeError = _apiError(403, 'FORBIDDEN');
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );

      await tester.tap(find.byKey(k.rowDelete('pg2')));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(find.byKey(k.rowDeleted('pg2')), findsNothing);
      expect(find.byKey(k.rowDelete('pg2')), findsOneWidget);
    });

    testWidgets('« Restaurer » part aussitôt ; la page revient', (
      WidgetTester tester,
    ) async {
      final _Restoring pages = _Restoring(<TeamPageSummaryDto>[
        _faq,
        _rules.copyWith(deleted: true),
      ]);
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        pages: pages,
      );
      expect(count(tester), '1 page sur 3 maximum');

      await tester.tap(find.byKey(k.rowRestore('pg2')));
      await settle(tester);

      expect(pages.restored, <String>['reglement']);
      expect(find.text('Page restaurée'), findsOneWidget);
      expect(find.byKey(k.rowDeleted('pg2')), findsNothing);
      expect(find.byKey(k.rowRestore('pg2')), findsNothing);
      expect(find.byKey(k.rowDelete('pg2')), findsOneWidget);
      expect(count(tester), '2 pages sur 3 maximum');
    });
  });
}

/// Une liste dont la première lecture échoue.
class _FailingOnce extends _Pages {
  bool _failed = false;

  @override
  Future<List<TeamPageSummaryDto>> listPages({required String teamSlug}) async {
    if (!_failed) {
      _failed = true;
      throw _apiError(500, 'UNKNOWN');
    }
    return super.listPages(teamSlug: teamSlug);
  }
}

/// Un serveur qui rend la page restaurée.
class _Restoring extends _Pages {
  _Restoring(super.pages);

  @override
  Future<TeamPageDto> undeletePage({
    required String pageSlug,
    required String teamSlug,
  }) async {
    restored.add(pageSlug);
    final TeamPageSummaryDto page = pages.firstWhere(
      (TeamPageSummaryDto p) => p.slug == pageSlug,
    );
    pages = <TeamPageSummaryDto>[
      for (final TeamPageSummaryDto p in pages)
        p.slug == pageSlug ? p.copyWith(deleted: false) : p,
    ];
    return TeamPageDto(
      team: kMemberTeam,
      id: page.id,
      title: page.title,
      slug: page.slug,
      media: kEmptyMedia,
      visibility: page.visibility,
      order: page.order,
      deleted: false,
      permissions: const ContentPermissionsDto(
        canEdit: true,
        canDelete: true,
        indexable: false,
      ),
    );
  }
}
