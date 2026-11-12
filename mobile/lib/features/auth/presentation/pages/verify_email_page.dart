import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../config/router.dart';
import '../../../../core/material.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../data/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../services/passkey_service.dart';

enum _Step { loading, activate, activated, emailChanged, error }

/// La page d'un lien d'inscription ou de changement d'adresse.
///
/// Au chargement, elle ne fait que lire le lien : elle montre l'adresse, et une
/// inscription n'aboutit qu'une fois le mot de passe choisi ici. Le lien seul
/// connectait son lecteur au compte — celui de n'importe qui, si on lui avait
/// transmis le lien d'un autre (docs/LEDGER_*.md SEC-9, audit M5) — avec le mot
/// de passe tapé à l'inscription (SEC-24, audit L4).
class VerifyEmailPage extends ConsumerStatefulWidget {
  final String? token;

  const VerifyEmailPage({super.key, this.token});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  _Step _step = _Step.loading;
  String? _email;
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _showPasskeyPrompt = false;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Après la première image, jamais pendant `initState` : modifier un
    // provider pendant que l'arbre se construit est refusé par Riverpod
    // (test/features/auth/verify_email_page_test.dart).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _readLink();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _step = _Step.error;
      _errorMessage = message;
      _isSubmitting = false;
    });
  }

  Future<void> _readLink() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      _fail('auth.verifyEmail.tokenMissing'.tr());
      return;
    }

    try {
      final link = await ref
          .read(authRepositoryProvider)
          .previewEmailLink(token);
      if (!mounted) return;
      if (EmailLinkKind.fromJson(link.kind) == EmailLinkKind.signUp) {
        setState(() {
          _email = link.email;
          _step = _Step.activate;
        });
        return;
      }
      // Un changement d'adresse ne demande rien et n'ouvre aucune session.
      await ref.read(authProvider.notifier).confirmEmailChange(token);
      if (mounted) {
        setState(() {
          _email = link.email;
          _step = _Step.emailChanged;
        });
      }
    } catch (e) {
      _fail(_messageFor(e));
    }
  }

  String _messageFor(Object e) {
    final code = resolveApiError(e).code;
    if (code == 'EMAIL_ALREADY_EXISTS') {
      return 'auth.verifyEmail.emailTaken'.tr();
    }
    if (code == 'TOKEN_INVALID') {
      return 'auth.verifyEmail.invalidLink'.tr();
    }
    return getErrorMessage(e);
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(authProvider.notifier)
          .activateAccount(widget.token!, _passwordController.text);
      TextInput.finishAutofillContext();
      final supported = await ref.read(passkeyServiceProvider).isSupported();
      if (mounted) {
        setState(() {
          _step = _Step.activated;
          _showPasskeyPrompt = supported;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      _fail(_messageFor(e));
    }
  }

  Future<void> _registerPasskey() async {
    setState(() => _isSubmitting = true);

    try {
      final passkeyService = ref.read(passkeyServiceProvider);
      await passkeyService.register(deviceName: 'Mobile');
      if (mounted) {
        goAfterSignIn(ref);
      }
    } catch (e) {
      _fail(getErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('auth.verifyEmail.title'.tr()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (_step) {
              _Step.loading => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text('auth.verifyEmail.verifying'.tr()),
                ],
              ),
              _Step.activate => _buildActivate(context),
              _Step.activated => _buildActivated(context),
              _Step.emailChanged => _buildEmailChanged(context),
              _Step.error => _buildError(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActivate(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(authProvider.select((s) => s.user?.email));

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'auth.verifyEmail.activateTitle'.tr(),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'auth.verifyEmail.activateMessage'.tr(
                namedArgs: {'email': _email ?? ''},
              ),
              key: keys.login.verifyAddress,
              textAlign: TextAlign.center,
            ),
            if (current != null && current != _email) ...[
              const SizedBox(height: 16),
              Card(
                key: keys.login.verifySignedInWarning,
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'auth.verifyEmail.signedInAs'.tr(
                      namedArgs: {'current': current, 'email': _email ?? ''},
                    ),
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextFormField(
              key: keys.login.verifyPasswordField,
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'auth.password'.tr(),
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'auth.validation.passwordMin'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: keys.login.verifyConfirmField,
              controller: _confirmController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'auth.confirmPassword'.tr(),
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'auth.validation.passwordMismatch'.tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: keys.login.verifyActivateButton,
              onPressed: _isSubmitting ? null : _activate,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('auth.verifyEmail.activate'.tr()),
            ),
            const SizedBox(height: 16),
            Text(
              'auth.verifyEmail.notYours'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivated(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 80, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'auth.verifyEmail.success'.tr(),
          key: keys.login.verifySuccess,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'auth.verifyEmail.accountCreated'.tr(),
          textAlign: TextAlign.center,
        ),
        if (_showPasskeyPrompt) ...[
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'auth.passkey.prompt'.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'auth.passkey.description'.tr(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _registerPasskey,
                    icon: const Icon(Icons.fingerprint),
                    label: Text('auth.passkey.register'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: keys.login.verifyLaterButton,
                    onPressed: () => goAfterSignIn(ref),
                    child: Text('common.later'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 24),
          FilledButton(
            key: keys.login.verifyContinueButton,
            onPressed: () => goAfterSignIn(ref),
            child: Text('common.continue'.tr()),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailChanged(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 80, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'auth.verifyEmail.emailChangedTitle'.tr(),
          key: keys.login.verifyEmailChanged,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'auth.verifyEmail.emailChangedMessage'.tr(
            namedArgs: {'email': _email ?? ''},
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        signedIn
            ? FilledButton(
                key: keys.login.verifyContinueButton,
                onPressed: () => goAfterSignIn(ref),
                child: Text('common.continue'.tr()),
              )
            : FilledButton(
                key: keys.login.verifyBackToLoginButton,
                onPressed: () => context.go(Paths.login()),
                child: Text('auth.verifyEmail.backToLogin'.tr()),
              ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 80, color: theme.colorScheme.error),
        const SizedBox(height: 24),
        Text('common.error'.tr(), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? '',
          key: keys.login.verifyError,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: keys.login.verifyBackToLoginButton,
          onPressed: () => context.go(Paths.login()),
          child: Text('auth.verifyEmail.backToLogin'.tr()),
        ),
      ],
    );
  }
}
