import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/paths.dart';
import '../../../../config/router.dart';
import '../../../../core/material.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../providers/auth_provider.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  final String token;

  const ResetPasswordPage({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _tokenInvalid = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.resetPassword(widget.token, _passwordController.text);
      if (mounted) {
        goAfterSignIn(ref);
      }
    } catch (e) {
      if (mounted) {
        String? apiCode;
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map<String, dynamic>) {
            apiCode = data['code'] as String?;
          }
        }
        setState(() {
          if (apiCode == 'TOKEN_INVALID') {
            _tokenInvalid = true;
          } else {
            _errorMessage = getErrorMessage(e);
          }
        });
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
      appBar: AppBar(
        title: Text('auth.resetPassword.title'.tr()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: widget.token.isEmpty || _tokenInvalid
                  ? _buildErrorState(theme)
                  : _buildForm(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'auth.resetPassword.error.title'.tr(),
          key: keys.login.resetInvalidState,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'auth.resetPassword.error.message'.tr(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: keys.login.resetRequestNewButton,
          onPressed: () => context.go(Paths.forgotPassword()),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text('auth.resetPassword.error.requestNew'.tr()),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go(Paths.login()),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text('auth.forgotPassword.backToLogin'.tr()),
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'auth.resetPassword.subtitle'.tr(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

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

          // New password
          TextFormField(
            key: keys.login.resetPasswordField,
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'auth.resetPassword.newPasswordLabel'.tr(),
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

          // Confirm password
          TextFormField(
            key: keys.login.resetConfirmField,
            controller: _confirmPasswordController,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'auth.resetPassword.confirmPasswordLabel'.tr(),
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
            key: keys.login.resetSubmitButton,
            onPressed: _isLoading ? null : _handleReset,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('auth.resetPassword.submit'.tr()),
          ),
        ],
      ),
    );
  }
}
