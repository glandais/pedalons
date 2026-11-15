import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/utils/link_launcher.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/teams/data/team_invitations_repository.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/domain/member_filters.dart';
import 'package:pedalons/features/teams/presentation/pages/team_admin_members_page.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// « Gestion des membres » (ledger `MOB-167`) : qui y entre — et qu'aucune
/// requête de membres ni d'invitations ne part pour les autres —, l'en-tête
/// d'une équipe plafonnée, la recherche et le filtre de rôle, ce que propose
/// la feuille d'une ligne, les identifiants exacts envoyés, l'invitation et
/// les invitations en attente.
class _Teams implements TeamRepository {
  _Teams({
    this.role,
    this.refusedWith,
    this.memberCount = 4,
    this.memberLimit,
    this.addMemberAllowed = true,
    this.gate,
  });

  final String? role;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  final int? refusedWith;
  final int memberCount;
  final int? memberLimit;
  final bool addMemberAllowed;

  /// Si posé, `getTeam` attend qu'il soit complété.
  final Completer<void>? gate;

  List<MemberDto> members = _members;
  Object? roleError;
  Object? removeError;

  int teamReads = 0;
  final List<({String? search, TeamRole? role, int page})> memberCalls =
      <({String? search, TeamRole? role, int page})>[];
  final List<({String slug, String userId, TeamRole role})> roleUpdates =
      <({String slug, String userId, TeamRole role})>[];
  final List<({String slug, String userId})> removals =
      <({String slug, String userId})>[];

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    teamReads++;
    await gate?.future;
    final int? status = refusedWith;
    if (status != null) throw _apiError(status, 'NOT_FOUND');
    return fixtureTeam(
      slug: slug,
      role: role,
      memberCount: memberCount,
    ).copyWith(memberLimit: memberLimit, addMemberAllowed: addMemberAllowed);
  }

  @override
  Future<PageResult<MemberDto>> fetchMembers({
    required MemberFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    memberCalls.add((search: filters.search, role: filters.role, page: page));
    final List<MemberDto> found = <MemberDto>[
      for (final MemberDto m in members)
        if ((filters.role == null || m.role == filters.role!.json) &&
            (filters.search == null ||
                m.user.displayName.toLowerCase().contains(
                  filters.search!.toLowerCase(),
                )))
          m,
    ];
    return PageResult<MemberDto>(items: found, total: found.length);
  }

  @override
  Future<MemberDto> updateMemberRole(
    String slug, {
    required String userId,
    required TeamRole role,
  }) async {
    final Object? error = roleError;
    if (error != null) throw error;
    roleUpdates.add((slug: slug, userId: userId, role: role));
    return members.firstWhere((MemberDto m) => m.user.id == userId);
  }

  @override
  Future<void> removeMember(String slug, {required String userId}) async {
    final Object? error = removeError;
    if (error != null) throw error;
    removals.add((slug: slug, userId: userId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Invitations implements TeamInvitationsRepository {
  _Invitations([this.pending = const <TeamInvitationDto>[]]);

  List<TeamInvitationDto> pending;
  Object? inviteError;
  Object? revokeError;

  int lists = 0;
  final List<({String slug, String email, String role})> invites =
      <({String slug, String email, String role})>[];
  final List<({String slug, String id})> revokes =
      <({String slug, String id})>[];

  @override
  Future<List<TeamInvitationDto>> listPending(String teamSlug) async {
    lists++;
    return pending;
  }

  @override
  Future<TeamInvitationDto> invite(
    String teamSlug, {
    required String email,
    required String role,
  }) async {
    final Object? error = inviteError;
    if (error != null) throw error;
    invites.add((slug: teamSlug, email: email, role: role));
    return _invitation.copyWith(email: email, role: role);
  }

  @override
  Future<void> revoke(String teamSlug, String invitationId) async {
    final Object? error = revokeError;
    if (error != null) throw error;
    revokes.add((slug: teamSlug, id: invitationId));
    pending = <TeamInvitationDto>[];
  }
}

class _NoAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// La personne connectée : `u1`, dont la ligne est dans la liste.
class _Me extends AuthNotifier {
  _Me(Ref ref) : super(_NoAuth(), _NoStorage(), ref) {
    state = const AuthState(
      isInitialized: true,
      accessToken: 'token',
      user: UserDto(
        plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
        id: 'u1',
        email: 'moi@example.org',
        displayName: 'Moi',
        contactableByMembers: true,
        emailVerified: true,
      ),
    );
  }
}

MemberDto _member(int index, String name, String role) => MemberDto(
  team: kMemberTeam,
  // L'identifiant de l'adhésion, **différent** de celui de la personne.
  id: 'm$index',
  user: PublicUserDto(id: 'u$index', displayName: name),
  role: role,
  joinedAt: '2019-03-08T10:00:00Z',
);

final List<MemberDto> _members = <MemberDto>[
  _member(0, 'Bob Simple', 'MEMBER'),
  _member(1, 'Moi', 'ADMIN'),
  _member(2, 'Alice Admin', 'ADMIN'),
  _member(3, 'Oscar Orga', 'ORGANIZER'),
];

const TeamInvitationDto _invitation = TeamInvitationDto(
  id: 'inv1',
  email: 'lea@example.org',
  role: 'ORGANIZER',
  status: 'PENDING',
  expiresAt: '2026-11-29T10:00:00Z',
  createdAt: '2026-11-15T10:00:00Z',
  invitedBy: PublicUserDto(id: 'u2', displayName: 'Alice Admin'),
);

DioException _apiError(
  int status,
  String code, {
  Map<String, Object?>? details,
}) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton'),
    statusCode: status,
    data: <String, Object?>{'code': code, 'errorDetails': ?details},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));
  tearDown(() => debugLinkOpener = null);

  final k = keys.teamAdminMembers;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    required _Teams teams,
    _Invitations? invitations,
    bool platformAdmin = false,
    bool openInvite = false,
  }) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('équipe'),
        ),
        GoRoute(
          path: '/membres',
          builder: (BuildContext _, GoRouterState _) => TeamAdminMembersPage(
            teamSlug: 'n-peloton',
            openInvite: openInvite,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams),
          teamInvitationsRepositoryProvider.overrideWithValue(
            invitations ?? _Invitations(),
          ),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
          authProvider.overrideWith((Ref ref) => _Me(ref)),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/membres');
    await settle(tester);
  }

  String badgeOf(WidgetTester tester, String userId) =>
      tester.widget<PdlBadge>(find.byKey(k.rowRole(userId))).label;

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<PdlButton>(find.byKey(key)).enabled;

  group('accès', () {
    for (final String? role in <String?>['MEMBER', 'ORGANIZER', null]) {
      testWidgets('rôle $role : un refus, et aucune requête de membres ni '
          'd\'invitations', (WidgetTester tester) async {
        final _Teams teams = _Teams(role: role);
        final _Invitations invitations = _Invitations(<TeamInvitationDto>[
          _invitation,
        ]);
        await open(tester, teams: teams, invitations: invitations);

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.text('Réservé au rôle Administrateur'), findsOneWidget);
        expect(teams.memberCalls, isEmpty);
        expect(invitations.lists, 0);
        expect(find.byKey(k.searchField), findsNothing);
        expect(find.text('Bob Simple'), findsNothing);
        expect(find.text('lea@example.org'), findsNothing);

        await tester.tap(find.byKey(k.forbiddenBack));
        await settle(tester);
        expect(find.text('équipe'), findsOneWidget);
      });
    }

    for (final int status in <int>[403, 404]) {
      testWidgets('une équipe que le serveur refuse ($status) : le refus, '
          'aucune requête de membres', (WidgetTester tester) async {
        final _Teams teams = _Teams(refusedWith: status);
        final _Invitations invitations = _Invitations();
        await open(tester, teams: teams, invitations: invitations);

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.byKey(k.loadError), findsNothing);
        expect(teams.memberCalls, isEmpty);
        expect(invitations.lists, 0);
      });
    }

    testWidgets('tant que la fiche charge : ni liste, ni refus, ni requête', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final _Teams teams = _Teams(role: 'ADMIN', gate: gate);
      final _Invitations invitations = _Invitations();
      await open(tester, teams: teams, invitations: invitations);

      expect(find.byKey(k.forbidden), findsNothing);
      expect(teams.memberCalls, isEmpty);
      expect(invitations.lists, 0);

      gate.complete();
      await settle(tester);
      expect(teams.memberCalls, hasLength(1));
      expect(invitations.lists, 1);
    });

    testWidgets('admin de l\'équipe : la liste, lue une fois, sans filtre', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);

      expect(find.byKey(k.forbidden), findsNothing);
      expect(teams.memberCalls, <({String? search, TeamRole? role, int page})>[
        (search: null, role: null, page: 0),
      ]);
      for (final String id in <String>['u0', 'u1', 'u2', 'u3']) {
        expect(find.byKey(k.row(id)), findsOneWidget);
      }
    });

    testWidgets('admin de plateforme non membre : la liste', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams();
      await open(tester, teams: teams, platformAdmin: true);

      expect(find.byKey(k.forbidden), findsNothing);
      expect(find.byKey(k.row('u0')), findsOneWidget);
      expect(teams.memberCalls, hasLength(1));
    });
  });

  group('en-tête', () {
    testWidgets('sans plafond : pas de compteur, « Inviter par e-mail »', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      expect(find.byKey(k.counter), findsNothing);
      expect(find.text('Inviter par e-mail'), findsOneWidget);
      expect(enabled(tester, k.inviteButton), isTrue);
      expect(find.byKey(k.fullNotice), findsNothing);
    });

    testWidgets('sous le plafond : « 24 / 25 membres », invitation ouverte', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN', memberCount: 24, memberLimit: 25),
      );

      expect(find.text('24 / 25\u00A0membres'), findsOneWidget);
      expect(enabled(tester, k.inviteButton), isTrue);
      expect(find.byKey(k.fullNotice), findsNothing);
    });

    testWidgets('équipe pleine : invitation inactive, la notice de l\'offre '
        'gratuite et son lien de contact vers le site', (
      WidgetTester tester,
    ) async {
      final List<Uri> launched = <Uri>[];
      debugLinkOpener = (Uri url) async {
        launched.add(url);
        return true;
      };
      await open(
        tester,
        teams: _Teams(role: 'ADMIN', memberCount: 25, memberLimit: 25),
      );

      expect(find.text('25 / 25\u00A0membres'), findsOneWidget);
      expect(enabled(tester, k.inviteButton), isFalse);
      expect(find.byKey(k.fullNotice), findsOneWidget);
      expect(
        find.text(
          'L\'équipe a atteint 25 membres, la limite de l\'offre gratuite.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(k.inviteButton), warnIfMissed: false);
      await settle(tester);
      expect(find.byKey(k.inviteSheet), findsNothing);

      await tester.tap(find.byKey(k.contactLink));
      await settle(tester);
      expect(launched.single.path, '/support');
    });

    testWidgets('équipe pleine, admin de plateforme : invitation ouverte, '
        'pas de notice', (WidgetTester tester) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN', memberCount: 25, memberLimit: 25),
        platformAdmin: true,
      );

      expect(enabled(tester, k.inviteButton), isTrue);
      expect(find.byKey(k.fullNotice), findsNothing);
    });

    testWidgets('ajout de membres non permis : pas de bouton, pas de notice', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(
          role: 'ADMIN',
          memberCount: 25,
          memberLimit: 25,
          addMemberAllowed: false,
        ),
      );

      expect(find.byKey(k.inviteButton), findsNothing);
      expect(find.byKey(k.fullNotice), findsNothing);
      expect(find.text('25 / 25\u00A0membres'), findsOneWidget);
    });
  });

  group('liste', () {
    testWidgets('une ligne : nom, « (vous) » sur la sienne, ancienneté, rôle', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      expect(find.text('Moi (vous)'), findsOneWidget);
      expect(find.text('Bob Simple'), findsOneWidget);
      expect(find.text('Bob Simple (vous)'), findsNothing);
      expect(find.text('Membre depuis mars 2019'), findsNWidgets(4));
      expect(badgeOf(tester, 'u0'), 'Membre');
      expect(badgeOf(tester, 'u1'), 'Administrateur');
      expect(badgeOf(tester, 'u3'), 'Organisateur');
      // Pas de tri : aucune puce de tri, seulement les rôles.
      expect(find.text('Rechercher par nom ou e-mail…'), findsOneWidget);
    });

    testWidgets('la recherche part au serveur', (WidgetTester tester) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);

      await tester.enterText(find.byKey(k.searchField), 'oscar');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      expect(teams.memberCalls.last, (search: 'oscar', role: null, page: 0));
      expect(find.byKey(k.row('u3')), findsOneWidget);
      expect(find.byKey(k.row('u0')), findsNothing);
    });

    testWidgets('le filtre de rôle part au serveur, puis « Tous » le lève', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);

      await tester.tap(find.byKey(k.roleChip('ORGANIZER')));
      await settle(tester);
      expect(teams.memberCalls.last, (
        search: null,
        role: TeamRole.organizer,
        page: 0,
      ));
      expect(find.byKey(k.row('u3')), findsOneWidget);
      expect(find.byKey(k.row('u0')), findsNothing);

      await tester.tap(find.byKey(k.roleChip('all')));
      await settle(tester);
      expect(find.byKey(k.row('u0')), findsOneWidget);
    });

    testWidgets('aucun résultat sous un filtre : l\'état filtré, et '
        '« effacer » rend la liste', (WidgetTester tester) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);

      await tester.enterText(find.byKey(k.searchField), 'personne');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      expect(find.byKey(k.filteredEmpty), findsOneWidget);
      expect(find.byKey(k.empty), findsNothing);
    });

    testWidgets('aucun membre : l\'état vide', (WidgetTester tester) async {
      final _Teams teams = _Teams(role: 'ADMIN')..members = <MemberDto>[];
      await open(tester, teams: teams);

      expect(find.byKey(k.empty), findsOneWidget);
      expect(find.byKey(k.filteredEmpty), findsNothing);
    });
  });

  group('feuille d\'une ligne', () {
    testWidgets('sa propre ligne ne s\'ouvre pas', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      expect(find.byKey(k.rowMore('u1')), findsNothing);
      await tester.tap(find.byKey(k.row('u1')));
      await settle(tester);
      expect(find.byKey(k.removeAction), findsNothing);
      expect(find.byKey(keys.moderation.reportAction), findsNothing);
    });

    testWidgets('un membre : modifier le rôle, retirer, signaler, bloquer', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      await tester.tap(find.byKey(k.row('u0')));
      await settle(tester);

      expect(find.byKey(k.changeRoleAction), findsOneWidget);
      expect(find.byKey(k.removeAction), findsOneWidget);
      expect(find.byKey(keys.moderation.reportAction), findsOneWidget);
      expect(find.byKey(keys.moderation.blockAction), findsOneWidget);
    });

    testWidgets('une personne qui administre : pas de « Modifier le rôle » '
        '(parité avec le site), mais retirer, signaler, bloquer', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      await tester.tap(find.byKey(k.rowMore('u2')));
      await settle(tester);

      expect(find.byKey(k.changeRoleAction), findsNothing);
      expect(find.byKey(k.removeAction), findsOneWidget);
      expect(find.byKey(keys.moderation.reportAction), findsOneWidget);
      expect(find.byKey(keys.moderation.blockAction), findsOneWidget);
    });
  });

  group('changer un rôle', () {
    testWidgets('envoie l\'identifiant de la personne — pas celui de '
        'l\'adhésion — et le rôle choisi, puis relit', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);
      final int memberReads = teams.memberCalls.length;
      final int teamReads = teams.teamReads;

      await tester.tap(find.byKey(k.row('u0')));
      await settle(tester);
      await tester.tap(find.byKey(k.changeRoleAction));
      await settle(tester);
      expect(find.text('Rôle de Bob Simple'), findsOneWidget);
      await tester.tap(find.byKey(k.roleOption('ORGANIZER')));
      await settle(tester);

      expect(teams.roleUpdates, <({String slug, String userId, TeamRole role})>[
        (slug: 'n-peloton', userId: 'u0', role: TeamRole.organizer),
      ]);
      expect(teams.roleUpdates.single.userId, isNot('m0'));
      // La liste et la fiche (compteurs du tableau de bord) sont relues.
      expect(teams.memberCalls.length, greaterThan(memberReads));
      expect(teams.teamReads, greaterThan(teamReads));
      expect(find.text('Rôle mis à jour'), findsOneWidget);
      expect(find.byKey(k.errorBanner), findsNothing);
    });

    testWidgets('choisir le rôle actuel n\'envoie rien', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);

      await tester.tap(find.byKey(k.row('u3')));
      await settle(tester);
      await tester.tap(find.byKey(k.changeRoleAction));
      await settle(tester);
      await tester.tap(find.byKey(k.roleOption('ORGANIZER')));
      await settle(tester);

      expect(teams.roleUpdates, isEmpty);
    });

    testWidgets('un refus du serveur se lit dans le bandeau', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN')
        ..roleError = _apiError(409, 'LAST_ADMIN');
      await open(tester, teams: teams);

      await tester.tap(find.byKey(k.row('u3')));
      await settle(tester);
      await tester.tap(find.byKey(k.changeRoleAction));
      await settle(tester);
      await tester.tap(find.byKey(k.roleOption('MEMBER')));
      await settle(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(find.text('Rôle mis à jour'), findsNothing);
    });
  });

  group('retirer', () {
    testWidgets('confirmé : envoie l\'identifiant de la personne, puis relit', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);
      final int memberReads = teams.memberCalls.length;
      final int teamReads = teams.teamReads;

      await tester.tap(find.byKey(k.row('u0')));
      await settle(tester);
      await tester.tap(find.byKey(k.removeAction));
      await settle(tester);
      expect(
        find.text('Voulez-vous vraiment retirer Bob Simple de l\'équipe ?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(teams.removals, <({String slug, String userId})>[
        (slug: 'n-peloton', userId: 'u0'),
      ]);
      expect(teams.removals.single.userId, isNot('m0'));
      expect(teams.memberCalls.length, greaterThan(memberReads));
      expect(teams.teamReads, greaterThan(teamReads));
      expect(find.text('Membre retiré de l\'équipe'), findsOneWidget);
    });

    testWidgets('annulé : rien ne part', (WidgetTester tester) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);

      await tester.tap(find.byKey(k.row('u0')));
      await settle(tester);
      await tester.tap(find.byKey(k.removeAction));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(teams.removals, isEmpty);
    });

    testWidgets('une personne qui administre se retire aussi', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      await open(tester, teams: teams);

      await tester.tap(find.byKey(k.row('u2')));
      await settle(tester);
      await tester.tap(find.byKey(k.removeAction));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(teams.removals.single, (slug: 'n-peloton', userId: 'u2'));
    });

    testWidgets('LAST_ADMIN : le bandeau le dit, la ligne reste', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN')
        ..removeError = _apiError(409, 'LAST_ADMIN');
      await open(tester, teams: teams);

      await tester.tap(find.byKey(k.row('u2')));
      await settle(tester);
      await tester.tap(find.byKey(k.removeAction));
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(
        find.text(
          'L\'équipe doit garder au moins une personne pour l\'administrer',
        ),
        findsOneWidget,
      );
      expect(find.byKey(k.row('u2')), findsOneWidget);
      expect(find.text('Membre retiré de l\'équipe'), findsNothing);
    });
  });

  group('inviter', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(k.inviteButton));
      await settle(tester);
      expect(find.byKey(k.inviteSheet), findsOneWidget);
    }

    String typed(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(k.inviteEmailField))
        .controller!
        .text;

    testWidgets('la feuille rappelle que l\'invitation doit être acceptée', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));
      await openSheet(tester);

      expect(
        find.textContaining('Nous n\'inscrivons personne d\'office'),
        findsOneWidget,
      );
      expect(
        find.text(
          'La personne recevra un e-mail et rejoindra l\'équipe seulement si '
          'elle accepte.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sans adresse, ou mal formée : rien ne part, le champ le dit', (
      WidgetTester tester,
    ) async {
      final _Invitations invitations = _Invitations();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        invitations: invitations,
      );
      await openSheet(tester);

      // Pas d'erreur avant une tentative.
      expect(find.text('L\'adresse e-mail est requise'), findsNothing);
      await tester.tap(find.byKey(k.inviteSubmit));
      await settle(tester);
      expect(find.text('L\'adresse e-mail est requise'), findsOneWidget);

      for (final String bad in <String>['lea', 'lea@exemple', 'l ea@ex.fr']) {
        await tester.enterText(find.byKey(k.inviteEmailField), bad);
        await tester.tap(find.byKey(k.inviteSubmit));
        await settle(tester);
        expect(find.text('Adresse e-mail invalide'), findsOneWidget);
      }

      expect(invitations.invites, isEmpty);
      expect(find.byKey(k.inviteSheet), findsOneWidget);
    });

    testWidgets('une adresse de plus de 250 caractères ne se saisit pas', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));
      await openSheet(tester);

      await tester.enterText(
        find.byKey(k.inviteEmailField),
        '${'a' * 300}@example.org',
      );
      await settle(tester);

      expect(typed(tester), hasLength(250));
    });

    testWidgets('envoi : l\'adresse rognée, « Membre » par défaut, la feuille '
        'se ferme, les invitations sont relues', (WidgetTester tester) async {
      final _Invitations invitations = _Invitations();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        invitations: invitations,
      );
      final int lists = invitations.lists;
      await openSheet(tester);

      await tester.enterText(
        find.byKey(k.inviteEmailField),
        '  lea@example.org ',
      );
      await tester.tap(find.byKey(k.inviteSubmit));
      await settle(tester);

      expect(invitations.invites, <({String slug, String email, String role})>[
        (slug: 'n-peloton', email: 'lea@example.org', role: 'MEMBER'),
      ]);
      expect(find.byKey(k.inviteSheet), findsNothing);
      expect(
        find.text('Invitation envoyée à lea@example.org.'),
        findsOneWidget,
      );
      expect(invitations.lists, greaterThan(lists));
    });

    testWidgets('le rôle choisi part avec l\'invitation', (
      WidgetTester tester,
    ) async {
      final _Invitations invitations = _Invitations();
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        invitations: invitations,
      );
      await openSheet(tester);

      await tester.enterText(find.byKey(k.inviteEmailField), 'lea@example.org');
      await tester.tap(find.byKey(k.inviteRole('ADMIN')));
      await settle(tester);
      await tester.tap(find.byKey(k.inviteSubmit));
      await settle(tester);

      expect(invitations.invites.single.role, 'ADMIN');
    });

    for (final String code in <String>[
      'TEAM_INVITE_SELF',
      'TEAM_INVITE_ALREADY_MEMBER',
      'TEAM_MEMBER_LIMIT_REACHED',
      'TEAM_INVITE_RATE_LIMITED',
      'TEAM_INVITE_DELIVERY_FAILED',
    ]) {
      testWidgets('$code : la feuille reste ouverte, la saisie gardée, le '
          'bandeau dit pourquoi', (WidgetTester tester) async {
        final _Invitations invitations = _Invitations()
          ..inviteError = _apiError(
            409,
            code,
            details: code == 'TEAM_MEMBER_LIMIT_REACHED'
                ? <String, Object?>{'limit': 25, 'current': 25}
                : null,
          );
        await open(
          tester,
          teams: _Teams(role: 'ADMIN'),
          invitations: invitations,
        );
        await openSheet(tester);

        await tester.enterText(
          find.byKey(k.inviteEmailField),
          'lea@example.org',
        );
        await tester.tap(find.byKey(k.inviteSubmit));
        await settle(tester);

        expect(find.byKey(k.inviteSheet), findsOneWidget);
        expect(typed(tester), 'lea@example.org');
        final String message = tester
            .widget<PdlBanner>(find.byKey(k.inviteErrorBanner))
            .message;
        // Le texte du code, pas l'« Erreur » générique d'une clé absente.
        expect(message, isNot('common.error'.tr()));
        expect(
          message,
          'errors.api.$code'.tr(namedArgs: <String, String>{'limit': '25'}),
        );
        expect(message, isNot(contains('{')));
        expect(find.textContaining('Invitation envoyée'), findsNothing);
      });
    }

    testWidgets('?invite=1 ouvre la feuille avec l\'écran', (
      WidgetTester tester,
    ) async {
      await open(tester, teams: _Teams(role: 'ADMIN'), openInvite: true);

      expect(find.byKey(k.inviteSheet), findsOneWidget);
    });

    testWidgets('?invite=1 sur une équipe pleine : pas de feuille', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN', memberCount: 25, memberLimit: 25),
        openInvite: true,
      );

      expect(find.byKey(k.inviteSheet), findsNothing);
      expect(find.byKey(k.fullNotice), findsOneWidget);
    });

    testWidgets('?invite=1 pour qui n\'administre pas : le refus, pas de '
        'feuille', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ORGANIZER'), openInvite: true);

      expect(find.byKey(k.forbidden), findsOneWidget);
      expect(find.byKey(k.inviteSheet), findsNothing);
    });
  });

  group('invitations en attente', () {
    testWidgets('aucune : la section est absente', (WidgetTester tester) async {
      await open(tester, teams: _Teams(role: 'ADMIN'));

      expect(find.byKey(k.pendingSection), findsNothing);
      expect(find.text('Invitations en attente'), findsNothing);
    });

    testWidgets('une carte : adresse, rôle, qui l\'a envoyée, son expiration', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        invitations: _Invitations(<TeamInvitationDto>[_invitation]),
      );

      expect(find.text('Invitations en attente'), findsOneWidget);
      final Finder card = find.byKey(k.invitation('inv1'));
      expect(card, findsOneWidget);
      Finder inCard(String text) =>
          find.descendant(of: card, matching: find.text(text));
      expect(inCard('lea@example.org'), findsOneWidget);
      expect(inCard('Invitation de Alice Admin'), findsOneWidget);
      final String expires = AppFormatters.formatLongDateWithoutWeekday(
        AppFormatters.tryParseDisplayTime(_invitation.expiresAt)!,
      );
      expect(inCard('Expire le $expires'), findsOneWidget);
      expect(
        tester
            .widget<PdlBadge>(
              find.descendant(of: card, matching: find.byType(PdlBadge)),
            )
            .label,
        'Organisateur',
      );
    });

    testWidgets('« Renvoyer » réinvite la même adresse avec le même rôle', (
      WidgetTester tester,
    ) async {
      final _Invitations invitations = _Invitations(<TeamInvitationDto>[
        _invitation,
      ]);
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        invitations: invitations,
      );
      final int lists = invitations.lists;

      await tester.tap(find.byKey(k.invitationResend('inv1')));
      await settle(tester);

      expect(invitations.invites, <({String slug, String email, String role})>[
        (slug: 'n-peloton', email: 'lea@example.org', role: 'ORGANIZER'),
      ]);
      expect(invitations.lists, greaterThan(lists));
      expect(
        find.text('Invitation envoyée à lea@example.org.'),
        findsOneWidget,
      );
    });

    testWidgets('« Annuler l\'invitation » confirme, révoque, puis relit', (
      WidgetTester tester,
    ) async {
      final _Invitations invitations = _Invitations(<TeamInvitationDto>[
        _invitation,
      ]);
      await open(
        tester,
        teams: _Teams(role: 'ADMIN'),
        invitations: invitations,
      );

      await tester.tap(find.byKey(k.invitationRevoke('inv1')));
      await settle(tester);
      expect(
        find.text('Annuler l\'invitation envoyée à lea@example.org ?'),
        findsOneWidget,
      );
      expect(invitations.revokes, isEmpty);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(invitations.revokes, <({String slug, String id})>[
        (slug: 'n-peloton', id: 'inv1'),
      ]);
      expect(find.text('Invitation annulée.'), findsOneWidget);
      expect(find.byKey(k.pendingSection), findsNothing);
    });

    testWidgets('409 à l\'annulation : déjà acceptée, annulée ou expirée — '
        'les invitations et les membres sont relus', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(role: 'ADMIN');
      final _Invitations invitations = _Invitations(<TeamInvitationDto>[
        _invitation,
      ])..revokeError = _apiError(409, 'TEAM_INVITE_NOT_PENDING');
      await open(tester, teams: teams, invitations: invitations);
      final int lists = invitations.lists;
      final int memberReads = teams.memberCalls.length;

      await tester.tap(find.byKey(k.invitationRevoke('inv1')));
      await settle(tester);
      // Entre-temps, le serveur ne la compte plus en attente.
      invitations.pending = <TeamInvitationDto>[];
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(invitations.lists, greaterThan(lists));
      expect(teams.memberCalls.length, greaterThan(memberReads));
      expect(find.byKey(k.pendingSection), findsNothing);
      expect(find.text('Invitation annulée.'), findsNothing);
      expect(
        find.text('Cette invitation n\'est plus en attente.'),
        findsOneWidget,
      );
    });
  });
}
