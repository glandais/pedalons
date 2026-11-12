import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/presentation/pages/verify_email_page.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/keys.dart';

/// Le lien de vérification ouvre une page qui lit le lien d'elle-même.
///
/// Elle ne modifie aucun provider pendant la construction : lancé depuis
/// `initState`, un appel qui pose `isLoading` avant son premier `await`
/// déclenchait l'assertion de Riverpod « Tried to modify a provider while the
/// widget tree was building ». Et au chargement, elle ne fait que **lire** le
/// lien : rien n'est activé tant que le mot de passe n'est pas choisi
/// (docs/LEDGER_*.md SEC-9 et SEC-24).
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.preview});

  /// La réponse de l'aperçu ; nulle, il échoue.
  final EmailLinkPreviewResponse? preview;
  final List<String> previewed = <String>[];
  final List<(String, String)> activated = <(String, String)>[];

  @override
  Future<EmailLinkPreviewResponse> previewEmailLink(String token) async {
    previewed.add(token);
    final EmailLinkPreviewResponse? response = preview;
    if (response == null) throw Exception('lien expiré');
    return response;
  }

  @override
  Future<AuthResponse> activateAccount(String token, String password) async {
    activated.add((token, password));
    throw Exception('arrêt du test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// L'app écoute l'état d'authentification au-dessus de chaque page (routeur,
/// shell) : sans écouteur, un changement d'état ne notifie personne et
/// l'assertion ne se déclenche pas.
class _AuthListener extends ConsumerWidget {
  const _AuthListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider.select((AuthState s) => s.isLoading));
    return child;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _FakeAuthRepository repository, {
    String? token,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: _AuthListener(child: VerifyEmailPage(token: token)),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets(
    'le lien est lu après la première image, sans modifier un provider '
    'pendant la construction',
    (WidgetTester tester) async {
      final _FakeAuthRepository repository = _FakeAuthRepository();

      await open(tester, repository, token: 't0k3n');

      expect(tester.takeException(), isNull);
      expect(repository.previewed, <String>['t0k3n']);
      expect(find.byKey(keys.login.verifyError), findsOneWidget);
      expect(find.byKey(keys.login.verifyBackToLoginButton), findsOneWidget);
    },
  );

  testWidgets(
    'un lien d\'inscription montre son adresse et n\'active rien avant le '
    'mot de passe',
    (WidgetTester tester) async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        preview: const EmailLinkPreviewResponse(
          email: 'bob@example.com',
          kind: 'SIGN_UP',
        ),
      );

      await open(tester, repository, token: 't0k3n');

      expect(tester.takeException(), isNull);
      expect(find.byKey(keys.login.verifyAddress), findsOneWidget);
      expect(find.byKey(keys.login.verifyPasswordField), findsOneWidget);
      expect(repository.activated, isEmpty);

      await tester.enterText(
        find.byKey(keys.login.verifyPasswordField),
        'ownerpass123',
      );
      await tester.enterText(
        find.byKey(keys.login.verifyConfirmField),
        'ownerpass123',
      );
      await tester.tap(find.byKey(keys.login.verifyActivateButton));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(repository.activated, <(String, String)>[
        ('t0k3n', 'ownerpass123'),
      ]);
    },
  );

  testWidgets('sans jeton, la page le dit sans appeler l\'API', (
    WidgetTester tester,
  ) async {
    final _FakeAuthRepository repository = _FakeAuthRepository();

    await open(tester, repository);

    expect(tester.takeException(), isNull);
    expect(repository.previewed, isEmpty);
    expect(find.byKey(keys.login.verifyError), findsOneWidget);
  });
}
