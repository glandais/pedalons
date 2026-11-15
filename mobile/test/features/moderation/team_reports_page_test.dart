import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/moderation/data/moderation_repository.dart';
import 'package:pedalons/features/moderation/presentation/pages/team_reports_page.dart';
import 'package:pedalons/features/posts/data/post_repository.dart';
import 'package:pedalons/features/posts/providers/post_providers.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/providers/team_dashboard_provider.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// « Signalements » (ledger `MOB-168`) : qui y entre — et que la file n'est
/// lue pour personne d'autre —, les deux onglets, ce que dit une carte selon
/// sa cible, les deux décisions et leurs requêtes exactes, et ce qui est relu
/// ensuite.
class _Teams implements TeamRepository {
  _Teams({this.role, this.refusedWith, this.gate});

  final String? role;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  final int? refusedWith;

  /// Si posé, `getTeam` attend qu'il soit complété.
  final Completer<void>? gate;

  int teamReads = 0;
  int myTeamsReads = 0;
  int dashboardReads = 0;

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
  Future<TeamDashboardDto> getDashboard(String slug) async {
    dashboardReads++;
    throw StateError('pas de tableau de bord dans ce test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Decision = ({
  String slug,
  String targetType,
  String targetId,
  ModerationAction action,
});

class _Moderation implements ModerationRepository {
  _Moderation({
    List<ModerationItemDto>? open,
    List<ModerationItemDto>? resolved,
  }) : open = open ?? <ModerationItemDto>[_post, _comment, _gone, _member],
       resolved = resolved ?? <ModerationItemDto>[];

  List<ModerationItemDto> open;
  List<ModerationItemDto> resolved;
  Object? listError;
  Object? resolveError;

  /// Si posé, `resolveTeamReports` attend qu'il soit complété.
  Completer<void>? resolveGate;

  final List<({String slug, ReportQueueStatus status})> listCalls =
      <({String slug, ReportQueueStatus status})>[];
  final List<_Decision> decisions = <_Decision>[];

  @override
  Future<List<ModerationItemDto>> listTeamReports(
    String teamSlug, {
    required ReportQueueStatus status,
  }) async {
    listCalls.add((slug: teamSlug, status: status));
    final Object? error = listError;
    if (error != null) throw error;
    return status == ReportQueueStatus.open ? open : resolved;
  }

  @override
  Future<void> resolveTeamReports(
    String teamSlug, {
    required String targetType,
    required String targetId,
    required ModerationAction action,
  }) async {
    await resolveGate?.future;
    final Object? error = resolveError;
    if (error != null) throw error;
    decisions.add((
      slug: teamSlug,
      targetType: targetType,
      targetId: targetId,
      action: action,
    ));
    // Le serveur : la cible quitte « À traiter » et entre dans « Traités ».
    final ModerationItemDto item = open.firstWhere(
      (ModerationItemDto i) => i.targetId == targetId,
    );
    open = <ModerationItemDto>[
      for (final ModerationItemDto i in open)
        if (i.targetId != targetId) i,
    ];
    resolved = <ModerationItemDto>[
      item.copyWith(
        status: action == ModerationAction.removeContent
            ? 'REMOVED'
            : 'DISMISSED',
      ),
      ...resolved,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le dépôt des publications : ce que la relecture d'un détail demande au
/// serveur.
class _Posts implements PostRepository {
  int reads = 0;

  @override
  Future<PostDto> getPost(String teamSlug, String postSlug) async {
    reads++;
    throw StateError('pas de publication dans ce test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ModerationItemDto _item({
  required String targetType,
  required String targetId,
  String author = 'Léa Martin',
  int reportCount = 1,
  List<ReportReason> reasons = const <ReportReason>[ReportReason.spam],
  List<String> messages = const <String>[],
  bool hidden = false,
  String status = 'OPEN',
  String? contentName,
  String? contentType,
  String? contentSlug,
  String? excerpt,
}) => ModerationItemDto(
  targetType: targetType,
  targetId: targetId,
  teamSlug: 'n-peloton',
  teamName: 'N-Peloton',
  targetUser: PublicUserDto(id: 'u-$targetId', displayName: author),
  reportCount: reportCount,
  reasons: reasons,
  messages: messages,
  firstReportedAt: '2026-11-10T08:00:00Z',
  lastReportedAt: '2026-11-14T18:30:00Z',
  hidden: hidden,
  status: status,
  contentName: contentName,
  contentType: contentType,
  contentSlug: contentSlug,
  excerpt: excerpt,
  // La file d'une équipe n'en porte jamais ; si elle en portait, l'écran ne
  // les montrerait pas davantage.
  reporters: const <PublicUserDto>[
    PublicUserDto(id: 'r1', displayName: 'Rita Rapporteuse'),
  ],
);

final ModerationItemDto _post = _item(
  targetType: 'POST',
  targetId: 't1',
  reportCount: 3,
  reasons: const <ReportReason>[ReportReason.spam, ReportReason.harassment],
  messages: const <String>['Publicité pour un site de paris.'],
  hidden: true,
  contentName: 'Bon plan vélo',
  contentType: 'POST',
  contentSlug: 'bon-plan-velo',
  excerpt: 'Bon plan vélo — cliquez ici pour gagner',
);

final ModerationItemDto _comment = _item(
  targetType: 'COMMENT',
  targetId: 't2',
  author: 'Bob Simple',
  contentName: 'Sortie du samedi',
  contentType: 'RIDE',
  contentSlug: 'sortie-du-samedi',
  excerpt: 'Commentaire déplacé',
);

final ModerationItemDto _gone = _item(
  targetType: 'AD',
  targetId: 't3',
  author: 'Oscar Orga',
  excerpt: 'Vélo à vendre',
);

final ModerationItemDto _member = _item(
  targetType: 'MEMBER',
  targetId: 't4',
  author: 'Max Membre',
  reasons: const <ReportReason>[ReportReason.harassment],
  excerpt: 'Max Membre',
);

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton/reports'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton/reports'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));

  final k = keys.teamReports;
  const ReportQueueStatus openTab = ReportQueueStatus.open;
  const ReportQueueStatus resolvedTab = ReportQueueStatus.resolved;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  late _Posts posts;
  setUp(() => posts = _Posts());

  Future<ProviderContainer> open(
    WidgetTester tester, {
    required _Teams teams,
    _Moderation? moderation,
    bool platformAdmin = false,
  }) async {
    tester.view.physicalSize = const Size(600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget named(String what, GoRouterState state) => Text(
      '$what ${state.pathParameters['teamSlug']} '
      '${state.pathParameters['slug'] ?? ''}',
    );

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('hub'),
        ),
        GoRoute(
          path: '/signalements',
          builder: (BuildContext _, GoRouterState _) =>
              const TeamReportsPage(teamSlug: 'n-peloton'),
        ),
        GoRoute(
          path: Paths.post(':teamSlug', ':slug'),
          builder: (BuildContext _, GoRouterState s) => named('publication', s),
        ),
        GoRoute(
          path: Paths.ride(':teamSlug', ':slug'),
          builder: (BuildContext _, GoRouterState s) => named('sortie', s),
        ),
        GoRoute(
          path: Paths.teamAdminMembers(':teamSlug'),
          builder: (BuildContext _, GoRouterState s) => named('membres', s),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams),
          moderationRepositoryProvider.overrideWithValue(
            moderation ?? _Moderation(),
          ),
          postRepositoryProvider.overrideWithValue(posts),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/signalements');
    await settle(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(TeamReportsPage)),
      listen: false,
    );
  }

  String badge(WidgetTester tester, Key key) =>
      tester.widget<PdlBadge>(find.byKey(key)).label;

  String text(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<PdlButton>(find.byKey(key)).enabled;

  group('accès', () {
    for (final String? role in <String?>['MEMBER', null]) {
      testWidgets('rôle $role : un refus, et la file n\'est pas lue', (
        WidgetTester tester,
      ) async {
        final _Moderation moderation = _Moderation();
        await open(
          tester,
          teams: _Teams(role: role),
          moderation: moderation,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.text('Réservé au rôle Organisateur'), findsOneWidget);
        expect(moderation.listCalls, isEmpty);
        expect(find.byKey(k.tab(openTab)), findsNothing);
        expect(find.text('Bon plan vélo'), findsNothing);
        expect(find.textContaining('Léa Martin'), findsNothing);

        await tester.tap(find.byKey(k.forbiddenBack));
        await settle(tester);
        expect(find.text('hub'), findsOneWidget);
      });
    }

    for (final int status in <int>[403, 404]) {
      testWidgets('une équipe que le serveur refuse ($status) : le refus, la '
          'file n\'est pas lue', (WidgetTester tester) async {
        final _Moderation moderation = _Moderation();
        await open(
          tester,
          teams: _Teams(refusedWith: status),
          moderation: moderation,
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.byKey(k.loadError), findsNothing);
        expect(moderation.listCalls, isEmpty);
      });
    }

    testWidgets('tant que la fiche charge : ni file, ni refus, ni requête', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final _Moderation moderation = _Moderation();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER', gate: gate),
        moderation: moderation,
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(moderation.listCalls, isEmpty);

      gate.complete();
      await settle(tester);
      expect(moderation.listCalls, hasLength(1));
    });

    for (final String role in <String>['ORGANIZER', 'ADMIN']) {
      testWidgets('rôle $role : la file « À traiter », lue une fois', (
        WidgetTester tester,
      ) async {
        final _Moderation moderation = _Moderation();
        await open(
          tester,
          teams: _Teams(role: role),
          moderation: moderation,
        );

        expect(find.byKey(k.forbidden), findsNothing);
        expect(
          moderation.listCalls,
          <({String slug, ReportQueueStatus status})>[
            (slug: 'n-peloton', status: openTab),
          ],
        );
        expect(find.byKey(k.card('POST_t1')), findsOneWidget);
      });
    }

    testWidgets('admin de plateforme non membre : la file — c\'est là que '
        'mène la notification', (WidgetTester tester) async {
      final _Moderation moderation = _Moderation();
      await open(
        tester,
        teams: _Teams(),
        moderation: moderation,
        platformAdmin: true,
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(find.byKey(k.card('POST_t1')), findsOneWidget);
      expect(moderation.listCalls, hasLength(1));
    });
  });

  group('onglets', () {
    testWidgets('« Traités » lit l\'autre file : la décision rendue, plus '
        'de geste', (WidgetTester tester) async {
      final _Moderation moderation = _Moderation(
        resolved: <ModerationItemDto>[
          _post.copyWith(status: 'REMOVED', hidden: false),
          _comment.copyWith(status: 'DISMISSED'),
        ],
      );
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );
      expect(find.text('À traiter'), findsOneWidget);
      expect(find.byKey(k.cardStatus('POST_t1')), findsNothing);

      await tester.tap(find.byKey(k.tab(resolvedTab)));
      await settle(tester);

      expect(moderation.listCalls.last, (
        slug: 'n-peloton',
        status: resolvedTab,
      ));
      expect(badge(tester, k.cardStatus('POST_t1')), 'Supprimé');
      expect(badge(tester, k.cardStatus('COMMENT_t2')), 'Rejeté');
      expect(find.byKey(k.removeButton('POST_t1')), findsNothing);
      expect(find.byKey(k.dismissButton('POST_t1')), findsNothing);
      expect(find.byKey(k.dismissButton('COMMENT_t2')), findsNothing);
      // La cible encore à traiter n'est pas dans cette file.
      expect(find.byKey(k.card('MEMBER_t4')), findsNothing);
    });

    testWidgets('aucun signalement : les deux états vides du site', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: _Moderation(open: <ModerationItemDto>[]),
      );

      expect(find.byKey(k.emptyOpen), findsOneWidget);
      expect(find.text('Aucun signalement en attente'), findsOneWidget);
      expect(
        find.text(
          'Les contenus signalés apparaîtront ici en attendant votre '
          'décision.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(k.tab(resolvedTab)));
      await settle(tester);
      expect(find.byKey(k.emptyResolved), findsOneWidget);
      expect(find.text('Aucun signalement traité'), findsOneWidget);
      expect(
        find.text('Les dernières décisions apparaîtront ici.'),
        findsOneWidget,
      );
    });

    testWidgets('la file en échec : une erreur, et « Réessayer » la relit', (
      WidgetTester tester,
    ) async {
      final _Moderation moderation = _Moderation()
        ..listError = StateError('indisponible');
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );

      expect(find.byKey(k.listError), findsOneWidget);
      expect(find.byKey(k.forbidden), findsNothing);

      moderation.listError = null;
      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(find.byKey(k.listError), findsNothing);
      expect(find.byKey(k.card('POST_t1')), findsOneWidget);
    });
  });

  group('carte', () {
    testWidgets('une publication : type, nombre, « Masqué aux membres », '
        'date, auteur, extrait, motifs, précisions — et personne qui '
        'signale', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ORGANIZER'));
      const String id = 'POST_t1';

      expect(
        find.text(
          'Les contenus signalés par les membres de l\'équipe. L\'identité '
          'des personnes qui signalent n\'est pas communiquée.',
        ),
        findsOneWidget,
      );
      expect(badge(tester, k.cardType(id)), 'Publication');
      expect(badge(tester, k.cardCount(id)), '3 signalements');
      expect(badge(tester, k.cardHidden(id)), 'Masqué aux membres');
      expect(find.byKey(k.cardStatus(id)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(k.card(id)),
          matching: find.textContaining('Dernier signalement : '),
        ),
        findsOneWidget,
      );
      expect(text(tester, k.cardUser(id)), 'Par Léa Martin');
      expect(
        text(tester, k.cardExcerpt(id)),
        'Bon plan vélo — cliquez ici pour gagner',
      );
      expect(
        badge(tester, k.cardReason(id, ReportReason.spam)),
        'Spam ou publicité',
      );
      expect(
        badge(tester, k.cardReason(id, ReportReason.harassment)),
        'Harcèlement ou intimidation',
      );
      expect(find.text('Précisions des signalements'), findsOneWidget);
      expect(find.text('Publicité pour un site de paris.'), findsOneWidget);
      // Anonymes : même si la réponse en portait, l'écran ne les montre pas.
      expect(find.textContaining('Rita'), findsNothing);
      expect(find.byKey(k.removeButton(id)), findsOneWidget);
      expect(find.byKey(k.dismissButton(id)), findsOneWidget);
    });

    testWidgets('le nom du contenu ouvre son écran dans l\'app', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ORGANIZER'));

      expect(
        find.descendant(
          of: find.byKey(k.cardContentLink('POST_t1')),
          matching: find.text('Bon plan vélo'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(k.cardContentLink('POST_t1')));
      await settle(tester);

      expect(find.text('publication n-peloton bon-plan-velo'), findsOneWidget);
    });

    testWidgets('un commentaire : « Commentaire sur « … » », et le lien mène '
        'au contenu commenté', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ORGANIZER'));
      const String id = 'COMMENT_t2';

      expect(badge(tester, k.cardType(id)), 'Commentaire');
      expect(badge(tester, k.cardCount(id)), '1 signalement');
      expect(find.byKey(k.cardHidden(id)), findsNothing);
      expect(text(tester, k.cardUser(id)), 'Par Bob Simple');
      expect(
        find.descendant(
          of: find.byKey(k.cardContentLink(id)),
          matching: find.text('Commentaire sur « Sortie du samedi »'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(k.cardContentLink(id)));
      await settle(tester);
      expect(find.text('sortie n-peloton sortie-du-samedi'), findsOneWidget);
    });

    testWidgets('un contenu disparu : « Le contenu n\'existe plus. », sans '
        'lien, les deux décisions offertes', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ORGANIZER'));
      const String id = 'AD_t3';

      expect(badge(tester, k.cardType(id)), 'Annonce');
      expect(text(tester, k.cardContentGone(id)), 'Le contenu n\'existe plus.');
      expect(find.byKey(k.cardContentLink(id)), findsNothing);
      expect(find.byKey(k.cardContentName(id)), findsNothing);
      expect(text(tester, k.cardUser(id)), 'Par Oscar Orga');
      expect(find.byKey(k.removeButton(id)), findsOneWidget);
      expect(find.byKey(k.dismissButton(id)), findsOneWidget);
    });

    testWidgets('un type de contenu que l\'app ne connaît pas : son nom, '
        'sans lien', (WidgetTester tester) async {
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: _Moderation(
          open: <ModerationItemDto>[
            _item(
              targetType: 'POLL',
              targetId: 't9',
              contentName: 'Sondage',
              contentType: 'POLL',
              contentSlug: 'sondage',
            ),
          ],
        ),
      );
      const String id = 'POLL_t9';

      expect(badge(tester, k.cardType(id)), 'Contenu');
      expect(text(tester, k.cardContentName(id)), 'Sondage');
      expect(find.byKey(k.cardContentLink(id)), findsNothing);
      expect(find.byKey(k.cardContentGone(id)), findsNothing);
    });

    testWidgets('un membre signalé, pour un rôle Organisateur : pas de '
        '« Supprimer le contenu », le renvoi vers les membres sans lien', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ORGANIZER'));
      const String id = 'MEMBER_t4';

      expect(badge(tester, k.cardType(id)), 'Membre');
      expect(text(tester, k.cardUser(id)), 'Membre signalé : Max Membre');
      expect(find.byKey(k.cardContentGone(id)), findsNothing);
      expect(find.byKey(k.removeButton(id)), findsNothing);
      expect(find.byKey(k.dismissButton(id)), findsOneWidget);
      expect(
        text(tester, k.memberHint(id)),
        'Pour retirer ce membre de l\'équipe, passez par la gestion des '
        'membres (rôle Administrateur).',
      );
      // L'écran des membres lui est refusé : pas de lien vers un refus.
      expect(find.byKey(k.membersLink(id)), findsNothing);
    });

    testWidgets('un membre signalé, pour qui administre : le lien ouvre la '
        'gestion des membres', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));
      const String id = 'MEMBER_t4';

      expect(find.byKey(k.memberHint(id)), findsOneWidget);
      await tester.tap(find.byKey(k.membersLink(id)));
      await settle(tester);

      expect(find.textContaining('membres n-peloton'), findsOneWidget);
    });

    testWidgets('admin de plateforme : le lien vers les membres aussi', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(), platformAdmin: true);

      expect(find.byKey(k.membersLink('MEMBER_t4')), findsOneWidget);
    });
  });

  group('décisions', () {
    testWidgets('« Rejeter le signalement » part aussitôt, avec la cible et '
        'l\'équipe ; la file et le tableau de bord sont relus, eux seuls', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ORGANIZER');
      final _Moderation moderation = _Moderation();
      final ProviderContainer container = await open(
        tester,
        teams: teams,
        moderation: moderation,
      );
      // Le tableau de bord de l'équipe, resté ouvert dessous.
      container.listen(teamDashboardProvider('n-peloton'), (_, _) {});
      await settle(tester);
      final int lists = moderation.listCalls.length;
      final int dashboards = teams.dashboardReads;
      final int teamReads = teams.teamReads;

      await tester.tap(find.byKey(k.dismissButton('COMMENT_t2')));
      await settle(tester);

      // Pas de confirmation.
      expect(moderation.decisions, <_Decision>[
        (
          slug: 'n-peloton',
          targetType: 'COMMENT',
          targetId: 't2',
          action: ModerationAction.dismiss,
        ),
      ]);
      expect(
        find.text('Signalement rejeté : le contenu reste visible.'),
        findsOneWidget,
      );
      // La file est relue, la carte la quitte, les autres restent.
      expect(moderation.listCalls.length, lists + 1);
      expect(moderation.listCalls.last.status, openTab);
      expect(find.byKey(k.card('COMMENT_t2')), findsNothing);
      expect(find.byKey(k.card('POST_t1')), findsOneWidget);
      // « À traiter » du tableau de bord compte les signalements ouverts.
      expect(teams.dashboardReads, dashboards + 1);
      // Ni la fiche ni « Mes équipes » n'en dépendent.
      expect(teams.teamReads, teamReads);
      expect(teams.myTeamsReads, 0);
      expect(find.byKey(k.errorBanner), findsNothing);
    });

    testWidgets('« Supprimer le contenu » se confirme, puis part ; le '
        'contenu supprimé est relu', (WidgetTester tester) async {
      final _Moderation moderation = _Moderation();
      final ProviderContainer container = await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );
      // Le détail de la publication, déjà lu ailleurs dans l'app.
      container.listen(
        postDetailProvider((teamSlug: 'n-peloton', postSlug: 'bon-plan-velo')),
        (_, _) {},
      );
      await settle(tester);
      expect(posts.reads, 1);

      await tester.tap(find.byKey(k.removeButton('POST_t1')));
      await settle(tester);
      expect(find.text('Supprimer ce contenu ?'), findsOneWidget);
      expect(
        find.text(
          'Le contenu sera supprimé pour tout le monde, et tous ses '
          'signalements seront clos.',
        ),
        findsOneWidget,
      );
      // Rien n'est parti avant la confirmation.
      expect(moderation.decisions, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(moderation.decisions, <_Decision>[
        (
          slug: 'n-peloton',
          targetType: 'POST',
          targetId: 't1',
          action: ModerationAction.removeContent,
        ),
      ]);
      expect(find.text('Contenu supprimé.'), findsOneWidget);
      expect(find.byKey(k.card('POST_t1')), findsNothing);
      expect(posts.reads, 2);

      // La cible est passée dans « Traités ».
      await tester.tap(find.byKey(k.tab(resolvedTab)));
      await settle(tester);
      expect(badge(tester, k.cardStatus('POST_t1')), 'Supprimé');
    });

    testWidgets('la confirmation annulée : rien ne part', (
      WidgetTester tester,
    ) async {
      final _Moderation moderation = _Moderation();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );

      await tester.tap(find.byKey(k.removeButton('POST_t1')));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(moderation.decisions, isEmpty);
      expect(find.byKey(k.card('POST_t1')), findsOneWidget);
    });

    testWidgets('un refus du serveur : un bandeau, la carte reste', (
      WidgetTester tester,
    ) async {
      final _Moderation moderation = _Moderation()
        ..resolveError = _apiError(403, 'FORBIDDEN');
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );
      final int lists = moderation.listCalls.length;

      await tester.tap(find.byKey(k.dismissButton('COMMENT_t2')));
      await settle(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(find.byKey(k.card('COMMENT_t2')), findsOneWidget);
      expect(
        find.text('Signalement rejeté : le contenu reste visible.'),
        findsNothing,
      );
      expect(moderation.listCalls.length, lists);
    });

    testWidgets('pendant une décision, les autres gestes sont inactifs — '
        'aucun n\'est perdu en silence', (WidgetTester tester) async {
      final _Moderation moderation = _Moderation()
        ..resolveGate = Completer<void>();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );

      await tester.tap(find.byKey(k.dismissButton('COMMENT_t2')));
      await settle(tester);
      expect(moderation.decisions, isEmpty);

      expect(enabled(tester, k.removeButton('POST_t1')), isFalse);
      expect(enabled(tester, k.dismissButton('POST_t1')), isFalse);
      expect(enabled(tester, k.dismissButton('MEMBER_t4')), isFalse);
      await tester.tap(
        find.byKey(k.removeButton('POST_t1')),
        warnIfMissed: false,
      );
      await settle(tester);
      expect(find.byKey(keys.profile.confirmDestructiveButton), findsNothing);

      moderation.resolveGate!.complete();
      await settle(tester);
      expect(moderation.decisions.single.targetId, 't2');
      expect(enabled(tester, k.removeButton('POST_t1')), isTrue);
      expect(enabled(tester, k.dismissButton('MEMBER_t4')), isTrue);
    });
  });

  group('revue du lot 4', () {
    bool loading(WidgetTester tester, Key key) =>
        tester.widget<PdlButton>(find.byKey(key)).loading;

    testWidgets('pendant « Supprimer le contenu », c\'est son bouton qui '
        'tourne, pas « Rejeter »', (WidgetTester tester) async {
      final _Moderation moderation = _Moderation()
        ..resolveGate = Completer<void>();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );

      await tester.tap(find.byKey(k.removeButton('POST_t1')));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(loading(tester, k.removeButton('POST_t1')), isTrue);
      expect(loading(tester, k.dismissButton('POST_t1')), isFalse);
      // Les autres cartes ne tournent pas.
      expect(loading(tester, k.dismissButton('COMMENT_t2')), isFalse);

      moderation.resolveGate!.complete();
      await settle(tester);
    });

    testWidgets('pendant « Rejeter le signalement », c\'est le sien', (
      WidgetTester tester,
    ) async {
      final _Moderation moderation = _Moderation()
        ..resolveGate = Completer<void>();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );

      await tester.tap(find.byKey(k.dismissButton('POST_t1')));
      await settle(tester);

      expect(loading(tester, k.dismissButton('POST_t1')), isTrue);
      expect(loading(tester, k.removeButton('POST_t1')), isFalse);

      moderation.resolveGate!.complete();
      await settle(tester);
    });

    testWidgets('un double appui sur « Supprimer le contenu » n\'ouvre '
        'qu\'une confirmation et n\'envoie qu\'une décision', (
      WidgetTester tester,
    ) async {
      final _Moderation moderation = _Moderation();
      await open(
        tester,
        teams: _Teams(role: 'ORGANIZER'),
        moderation: moderation,
      );

      await tester.tap(find.byKey(k.removeButton('POST_t1')));
      await tester.tap(
        find.byKey(k.removeButton('POST_t1')),
        warnIfMissed: false,
      );
      await settle(tester);

      expect(find.byKey(keys.profile.confirmDestructiveButton), findsOneWidget);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);
      expect(moderation.decisions, hasLength(1));
      expect(find.byKey(keys.profile.confirmDestructiveButton), findsNothing);
    });

    for (final int status in <int>[404, 409]) {
      testWidgets('une cible déjà traitée par quelqu\'un d\'autre ($status) : '
          'le bandeau, et la file est relue — la carte ne reste pas', (
        WidgetTester tester,
      ) async {
        final _Moderation moderation = _Moderation()
          ..resolveError = _apiError(status, 'NOT_FOUND');
        await open(
          tester,
          teams: _Teams(role: 'ORGANIZER'),
          moderation: moderation,
        );
        final int lists = moderation.listCalls.length;
        // Entre-temps, quelqu'un d'autre a rejeté ce signalement.
        moderation.open = <ModerationItemDto>[
          for (final ModerationItemDto i in moderation.open)
            if (i.targetId != 't2') i,
        ];

        await tester.tap(find.byKey(k.dismissButton('COMMENT_t2')));
        await settle(tester);

        expect(find.byKey(k.errorBanner), findsOneWidget);
        expect(moderation.listCalls.length, greaterThan(lists));
        expect(find.byKey(k.card('COMMENT_t2')), findsNothing);
        expect(find.byKey(k.card('POST_t1')), findsOneWidget);
      });
    }
  });
}
