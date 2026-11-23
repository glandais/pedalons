import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/config/router.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/provider_retry.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/auth/providers/pending_sign_in_link.dart';
import 'package:pedalons/features/teams/data/invitations_repository.dart';
import 'package:pedalons/features/teams/presentation/pages/invitation_page.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// La page du lien d'un e-mail d'invitation (docs/LEDGER_*.md MOB-179) : ce
/// qu'elle montre avant toute session, le détour par la connexion qui y
/// ramène, et l'arrivée sur l'équipe une fois l'invitation acceptée.
class _FakeInvitations implements InvitationsRepository {
  _FakeInvitations({this.previewed, this.acceptError});

  /// L'aperçu ; nul, il échoue comme un jeton inconnu.
  final InvitationPreviewDto? previewed;
  final Object? acceptError;
  final List<String> acceptedTokens = <String>[];

  @override
  Future<InvitationPreviewDto> preview(String token) async {
    final InvitationPreviewDto? response = previewed;
    if (response == null) throw _apiError('TEAM_INVITE_INVALID');
    return response;
  }

  @override
  Future<void> acceptToken(String token) async {
    if (acceptError != null) throw acceptError!;
    acceptedTokens.add(token);
  }

  @override
  Future<List<MyInvitationDto>> listMine() async => const <MyInvitationDto>[];

  @override
  Future<void> accept(String invitationId) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref, AuthState initial)
    : super(_FakeAuthRepository(), _FakeSecureStorage(), ref) {
    state = initial;
  }
}

const AuthState _signedOut = AuthState(isInitialized: true);

const AuthState _signedIn = AuthState(
  isInitialized: true,
  user: UserDto(
    plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
    id: 'u-me',
    email: 'lea@example.org',
    displayName: 'Léa',
    emailVerified: true,
    contactableByMembers: true,
  ),
  accessToken: 'token',
);

InvitationPreviewDto _preview({bool redeemable = true}) => InvitationPreviewDto(
  teamName: 'N-Peloton',
  teamSlug: 'n-peloton',
  inviterName: 'Gaby',
  maskedEmail: 'l***@example.org',
  role: 'MEMBER',
  status: redeemable ? 'PENDING' : 'REVOKED',
  redeemable: redeemable,
);

DioException _apiError(String code) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 403,
    data: <String, dynamic>{'code': code},
  ),
);

/// Des pas fixes plutôt que `pumpAndSettle` : l'icône de l'état indisponible
/// respire en boucle, et ne se pose donc jamais.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(loadTestTranslations);

  late GoRouter router;
  late PendingSignInLink pending;

  Future<void> open(
    WidgetTester tester,
    _FakeInvitations invitations, {
    required AuthState auth,
    String? token = 't0k3n',
  }) async {
    pending = PendingSignInLink();
    final String location = token == null
        ? Paths.invitation()
        : '${Paths.invitation()}?token=$token';
    router = GoRouter(
      initialLocation: location,
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const Text('accueil')),
        GoRoute(
          path: Paths.invitation(),
          builder: (_, GoRouterState s) =>
              InvitationPage(token: s.uri.queryParameters['token']),
        ),
        GoRoute(
          path: Paths.login(),
          builder: (_, _) => const Text('connexion'),
        ),
        GoRoute(path: Paths.teams(), builder: (_, _) => const Text('équipes')),
        GoRoute(
          path: Paths.team('n-peloton'),
          builder: (_, _) => const Text('page de l’équipe'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: providerRetry,
        overrides: [
          invitationsRepositoryProvider.overrideWithValue(invitations),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref, auth)),
          pendingSignInLinkProvider.overrideWithValue(pending),
          routerProvider.overrideWithValue(router),
          myTeamsProvider.overrideWith((ref) async => const <TeamDetailDto>[]),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('hors session : qui invite, et la connexion qui ramène ici', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _FakeInvitations(previewed: _preview()),
      auth: _signedOut,
    );

    expect(find.text('Gaby vous invite à rejoindre N-Peloton'), findsOneWidget);
    expect(find.byKey(keys.invitation.joinButton), findsNothing);

    await tester.tap(find.byKey(keys.invitation.signInButton));
    await settle(tester);

    expect(find.text('connexion'), findsOneWidget);
    expect(
      pending.location,
      '${Paths.invitation()}?token=t0k3n',
      reason: 'la connexion, ou l’activation du compte, reprend ce lien',
    );
  });

  testWidgets('connecté : rejoindre accepte le jeton et mène à l’équipe', (
    WidgetTester tester,
  ) async {
    final _FakeInvitations invitations = _FakeInvitations(
      previewed: _preview(),
    );
    await open(tester, invitations, auth: _signedIn);

    expect(find.byKey(keys.invitation.signInButton), findsNothing);
    await tester.tap(find.byKey(keys.invitation.joinButton));
    await settle(tester);

    expect(invitations.acceptedTokens, <String>['t0k3n']);
    expect(find.text('page de l’équipe'), findsOneWidget);
  });

  testWidgets('connecté avec un autre compte : la cause reste sur la page', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _FakeInvitations(
        previewed: _preview(),
        acceptError: _apiError('TEAM_INVITE_EMAIL_MISMATCH'),
      ),
      auth: _signedIn,
    );

    await tester.tap(find.byKey(keys.invitation.joinButton));
    await settle(tester);

    expect(find.byKey(keys.invitation.acceptError), findsOneWidget);
    expect(
      find.textContaining('adressée à quelqu\'un d\'autre'),
      findsOneWidget,
    );
    expect(find.byKey(keys.invitation.switchAccountButton), findsOneWidget);
  });

  testWidgets('une invitation qui n’est plus en attente ne propose rien', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _FakeInvitations(previewed: _preview(redeemable: false)),
      auth: _signedOut,
    );

    expect(find.byKey(keys.invitation.notRedeemable), findsOneWidget);
    expect(find.byKey(keys.invitation.signInButton), findsNothing);
    expect(find.byKey(keys.invitation.joinButton), findsNothing);
  });

  testWidgets('un jeton inconnu : invitation indisponible, avec sa cause', (
    WidgetTester tester,
  ) async {
    await open(tester, _FakeInvitations(), auth: _signedOut);
    expect(find.byKey(keys.invitation.unavailable), findsOneWidget);
    expect(find.textContaining('plus valide'), findsOneWidget);
  });

  testWidgets('un lien sans jeton : invitation indisponible', (
    WidgetTester tester,
  ) async {
    await open(tester, _FakeInvitations(), auth: _signedOut, token: null);
    expect(find.byKey(keys.invitation.unavailable), findsOneWidget);
  });
}
