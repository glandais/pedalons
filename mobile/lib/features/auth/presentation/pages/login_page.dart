import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/paths.dart';
import '../../../../config/router.dart';
import '../../../../core/material.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../keys.dart';
import '../../providers/auth_provider.dart';
import '../../services/passkey_service.dart';

enum _Mode { login, register }

class LoginPage extends ConsumerStatefulWidget {
  final bool initialRegister;

  const LoginPage({super.key, this.initialRegister = false});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late _Mode _mode = widget.initialRegister ? _Mode.register : _Mode.login;

  // Login fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Register fields
  final _regEmailController = TextEditingController();
  final _regDisplayNameController = TextEditingController();

  /// La case des conditions d'utilisation, obligatoire. Gardée hors du
  /// `FormField` pour survivre à un aller-retour vers la page des conditions.
  bool _acceptTerms = false;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _passkeySupported = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPasskeySupport();
  }

  Future<void> _checkPasskeySupport() async {
    final passkeyService = ref.read(passkeyServiceProvider);
    final supported = await passkeyService.isSupported();
    if (mounted) {
      setState(() => _passkeySupported = supported);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _regEmailController.dispose();
    _regDisplayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.loginWithPassword(email, password);
      TextInput.finishAutofillContext();
      if (mounted) {
        goAfterSignIn(ref);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePasskeyLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final passkeyService = ref.read(passkeyServiceProvider);
      await passkeyService.authenticate();
      if (mounted) {
        goAfterSignIn(ref);
      }
    } catch (e) {
      if (mounted) {
        // Don't show an error when the user cancels the biometric prompt
        final msg = e.toString().toLowerCase();
        final isCancelled =
            msg.contains('cancelled') ||
            msg.contains('canceled') ||
            msg.contains('user canceled');
        if (!isCancelled) {
          setState(() => _errorMessage = 'auth.errors.authFailed'.tr());
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.register(
        email: _regEmailController.text.trim(),
        displayName: _regDisplayNameController.text.trim(),
        acceptTerms: _acceptTerms,
      );
      TextInput.finishAutofillContext();
      if (mounted) {
        setState(() => _mode = _Mode.login);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'auth.verifyEmail.verificationSent'.tr(
                namedArgs: {'email': _regEmailController.text.trim()},
              ),
            ),
          ),
        );
        _emailController.text = _regEmailController.text.trim();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('auth.login'.tr()), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Image.asset('assets/icon.png', width: 80, height: 80),
                  const SizedBox(height: 16),
                  Text(
                    'app.name'.tr(),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  if (_mode == _Mode.login)
                    _buildLoginForm(theme)
                  else
                    _buildRegisterForm(theme),

                  // Une porte vers la présentation du produit, pour qui arrive
                  // sans savoir à quoi sert l'app. La page n'existe que sur le
                  // site : elle s'ouvre dans le navigateur, sur le domaine de
                  // cette installation.
                  const SizedBox(height: 16),
                  TextButton.icon(
                    key: keys.login.discoverFeaturesButton,
                    onPressed: () => openWebPage(Paths.features()),
                    icon: const Icon(PdlIcons.openExternal),
                    label: Text('auth.discoverFeatures'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Card(
            key: keys.login.loginError,
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Form(
          key: _loginFormKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: keys.login.emailField,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'auth.email'.tr(),
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.errors.emailRequired'.tr();
                    }
                    if (!value.contains('@')) {
                      return 'auth.errors.emailInvalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: keys.login.passwordField,
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'auth.password'.tr(),
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.errors.passwordRequired'.tr();
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: keys.login.forgotPasswordButton,
                    onPressed: () => context.push(Paths.forgotPassword()),
                    child: Text('auth.forgotPassword.title'.tr()),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: keys.login.submitButton,
                  onPressed: _isLoading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('auth.login'.tr()),
                ),
              ],
            ),
          ),
        ),

        if (_passkeySupported) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('common.or'.tr()),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _handlePasskeyLogin,
            icon: const Icon(Icons.fingerprint),
            label: Text('auth.passkey.login'.tr()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],

        const SizedBox(height: 24),
        TextButton(
          key: keys.login.showRegisterButton,
          onPressed: () => setState(() => _mode = _Mode.register),
          child: Text('auth.register'.tr()),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Form(
          key: _registerFormKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: keys.login.registerEmailField,
                  controller: _regEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.newUsername,
                    AutofillHints.email,
                  ],
                  decoration: InputDecoration(
                    labelText: 'auth.email'.tr(),
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.errors.emailRequired'.tr();
                    }
                    if (!value.contains('@')) {
                      return 'auth.errors.emailInvalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: keys.login.registerDisplayNameField,
                  controller: _regDisplayNameController,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: 'auth.displayName'.tr(),
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.errors.displayNameRequired'.tr();
                    }
                    if (value.length < 2) {
                      return 'auth.errors.displayNameTooShort'.tr();
                    }
                    if (value.length > 100) {
                      return 'auth.errors.displayNameTooLong'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _termsField(),
                const SizedBox(height: 24),
                FilledButton(
                  key: keys.login.registerSubmitButton,
                  onPressed: _isLoading ? null : _handleRegister,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('auth.register'.tr()),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _mode = _Mode.login;
            _errorMessage = null;
          }),
          child: Text('auth.login'.tr()),
        ),
      ],
    );
  }

  /// La case des conditions d'utilisation — obligatoire, et le serveur la
  /// refuse absente (`acceptTerms`). Les conditions et la politique de
  /// confidentialité s'ouvrent dans l'app, sur les pages embarquées.
  Widget _termsField() {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return FormField<bool>(
      initialValue: _acceptTerms,
      validator: (_) => _acceptTerms ? null : 'auth.terms.required'.tr(),
      builder: (FormFieldState<bool> field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: keys.login.termsCheckbox,
            value: _acceptTerms,
            onChanged: _isLoading
                ? null
                : (bool? value) {
                    setState(() => _acceptTerms = value ?? false);
                    field.didChange(_acceptTerms);
                  },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text('auth.terms.accept'.tr(), style: t.sub),
            subtitle: field.hasError
                ? Text(
                    field.errorText!,
                    key: keys.login.termsError,
                    style: t.xs.copyWith(color: c.dangerOnSoft),
                  )
                : null,
          ),
          Wrap(
            spacing: PdlSpacing.chipGap,
            children: [
              TextButton(
                key: keys.login.termsLink,
                onPressed: () => context.push(Paths.terms()),
                child: Text('auth.terms.read'.tr()),
              ),
              TextButton(
                key: keys.login.privacyLink,
                onPressed: () => context.push(Paths.privacy()),
                child: Text('auth.terms.privacy'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
