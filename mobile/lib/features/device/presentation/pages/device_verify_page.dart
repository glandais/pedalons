import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/widgets/connected_services_section.dart';

/// Device verification page for Karoo/Garmin device code flow.
/// The user enters or receives a 6-character code from their GPS device,
/// then explicitly authorizes or denies it: opening a link that carries a code
/// is never enough to pair a device (docs/LEDGER_*.md SEC-2, audit H3).
///
/// A Karoo then needs Hammerhead, which carries the routes to it: once the
/// Karoo is authorized, the page goes straight on to that step unless the
/// account already has it, and ends on « ready » (docs/LEDGER_*.md API-63,
/// plan `docs/plans/2026-10-02-karoo-onboarding.md`). The Karoo follows
/// `/api/device/me` meanwhile, so the order of the two steps does not matter
/// to it.
class DeviceVerifyPage extends ConsumerStatefulWidget {
  final String? code;

  /// Opens on the Hammerhead step of a Karoo already authorized: the Karoo's
  /// fallback QR (`/karoo/hammerhead`), or the return of the OAuth.
  final bool hammerheadStep;

  /// `gps_error` of the OAuth return, when it failed.
  final String? gpsError;

  const DeviceVerifyPage({
    super.key,
    this.code,
    this.hammerheadStep = false,
    this.gpsError,
  });

  @override
  ConsumerState<DeviceVerifyPage> createState() => _DeviceVerifyPageState();
}

class _DeviceVerifyPageState extends ConsumerState<DeviceVerifyPage> {
  bool _isVerifying = false;
  bool _isCompleting = false;
  bool _isDenying = false;
  bool _completed = false;
  bool _denied = false;

  /// The code the backend knows, awaiting the rider's answer.
  VerifyResponse? _pending;
  String? _errorMessage;
  final _codeController = TextEditingController();

  /// `VerifyResponse.clientId` of the authorized code — what tells a Karoo
  /// from a Garmin, never the URL the page was opened on.
  String? _clientId;
  bool _connectingHammerhead = false;
  String? _hammerheadError;

  /// The OAuth ends in the browser, whose return does not bring the app back
  /// (on iOS a redirect on the same domain stays in Safari): coming back to
  /// the foreground is what re-reads the account's connections.
  late final AppLifecycleListener _resumeListener = AppLifecycleListener(
    onResume: () => unawaited(refreshCurrentUser(ref).catchError((_) {})),
  );

  @override
  void initState() {
    super.initState();
    _resumeListener;
    if (widget.hammerheadStep) {
      _completed = true;
      _clientId = 'karoo';
      _hammerheadError = switch (widget.gpsError) {
        null => null,
        'access_denied' => 'device.hammerhead.denied'.tr(),
        _ => 'device.hammerhead.failed'.tr(),
      };
      // Back from the OAuth: the connection was just made.
      unawaited(refreshCurrentUser(ref).catchError((_) {}));
    } else if (widget.code != null && widget.code!.isNotEmpty) {
      _verifyCode(widget.code!.toUpperCase());
    }
  }

  @override
  void dispose() {
    _resumeListener.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connectHammerhead() async {
    setState(() {
      _connectingHammerhead = true;
      _hammerheadError = null;
    });
    try {
      final String url = await ref
          .read(profileRepositoryProvider)
          .gpsConnectUrl(
            GpsServiceType.hammerhead,
            returnTo: GpsConnectReturn.deviceKaroo,
          );
      if (!mounted) return;
      // In the system browser: OAuth providers refuse embedded webviews.
      await openLink(context, url);
      if (mounted) setState(() => _connectingHammerhead = false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _connectingHammerhead = false;
        _hammerheadError = getErrorMessage(error, stackTrace);
      });
    }
  }

  Future<void> _verifyCode(String code) async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final client = DeviceOAuthClient(
        ref.read(dioProvider),
        baseUrl: ref.read(dioProvider).options.baseUrl,
      );
      final response = await client.verify(code: code);
      if (mounted) {
        if (response.authorized == true) {
          setState(() {
            _isVerifying = false;
            _completed = true;
            _clientId = response.clientId;
          });
        } else {
          setState(() {
            _isVerifying = false;
            _pending = response;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'device.errors.invalidCodeMessage'.tr();
        });
      }
    }
  }

  Future<void> _completeAuthorization(String code) async {
    setState(() {
      _isCompleting = true;
      _clientId = _pending?.clientId;
    });

    try {
      final client = DeviceOAuthClient(
        ref.read(dioProvider),
        baseUrl: ref.read(dioProvider).options.baseUrl,
      );
      await client.deviceComplete(
        body: CompleteRequest(userCode: code, confirmed: true),
      );
      if (mounted) {
        setState(() {
          _isCompleting = false;
          _completed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompleting = false;
          _errorMessage = getErrorMessage(e);
        });
      }
    }
  }

  Future<void> _denyAuthorization(String code) async {
    setState(() => _isDenying = true);

    try {
      final client = DeviceOAuthClient(
        ref.read(dioProvider),
        baseUrl: ref.read(dioProvider).options.baseUrl,
      );
      await client.deviceDeny(body: DenyRequest(userCode: code));
      if (mounted) {
        setState(() {
          _isDenying = false;
          _denied = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDenying = false;
          _errorMessage = getErrorMessage(e);
        });
      }
    }
  }

  void _submitCode() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length == 6) {
      _verifyCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('device.title'.tr()),
        centerTitle: true,
        leading: const BackOrHomeButton(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildContent(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isVerifying || _isCompleting || _isDenying) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _isCompleting ? 'device.completing'.tr() : 'device.verifying'.tr(),
          ),
        ],
      );
    }

    if (_completed) {
      if (_clientId == 'karoo') {
        final Widget? hammerhead = _buildHammerheadStep(theme);
        if (hammerhead != null) return hammerhead;
        return _buildReady(
          theme,
          title: 'device.ready.title'.tr(),
          message: 'device.ready.message'.tr(),
        );
      }
      return _buildReady(
        theme,
        title: 'device.success.title'.tr(),
        message: 'device.success.message'.tr(),
        hint: 'device.success.returnToDevice'.tr(),
      );
    }

    if (_denied) {
      return Column(
        key: keys.device.denied,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 80, color: theme.colorScheme.outline),
          const SizedBox(height: 24),
          Text(
            'device.denied.title'.tr(),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text('device.denied.message'.tr(), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(Paths.home()),
            child: Text('common.continue'.tr()),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Column(
        key: keys.device.error,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: theme.colorScheme.error),
          const SizedBox(height: 24),
          Text(
            'device.errors.title'.tr(),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: keys.device.tryAgainButton,
            onPressed: () {
              setState(() {
                _codeController.clear();
                _errorMessage = null;
                _pending = null;
              });
            },
            child: Text('device.manualEntry.tryAgain'.tr()),
          ),
        ],
      );
    }

    final pending = _pending;
    if (pending != null) {
      return _buildConfirmation(theme, pending);
    }

    // Manual code entry
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.devices, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'device.manualEntry.title'.tr(),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'device.manualEntry.description'.tr(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 240,
          child: TextField(
            key: keys.device.codeField,
            controller: _codeController,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _submitCode(),
            autofocus: true,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: keys.device.submitButton,
          onPressed: _submitCode,
          child: Text('common.continue'.tr()),
        ),
      ],
    );
  }

  Widget _buildReady(
    ThemeData theme, {
    required String title,
    required String message,
    String? hint,
  }) {
    return Column(
      key: keys.device.success,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, size: 80, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        if (hint != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go(Paths.home()),
          child: Text('common.continue'.tr()),
        ),
      ],
    );
  }

  /// The Hammerhead step of a Karoo, or `null` when there is nothing to do:
  /// the account already has Hammerhead, or this server does not offer it
  /// (the Karoo would then wait for something nobody can give it).
  Widget? _buildHammerheadStep(ThemeData theme) {
    final List<GpsServiceConnectionDto> connected =
        ref.watch(
          authProvider.select((AuthState s) => s.user?.connectedServices),
        ) ??
        const <GpsServiceConnectionDto>[];
    if (connected.any(
      (GpsServiceConnectionDto c) =>
          c.serviceType == GpsServiceType.hammerhead.json,
    )) {
      return null;
    }
    final AsyncValue<List<GpsServiceType>> available = ref.watch(
      availableGpsProvider,
    );
    if (available.isLoading && !available.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    // A failed read offers the step anyway: connecting will say what is wrong.
    if (available.hasValue &&
        !available.value!.contains(GpsServiceType.hammerhead)) {
      return null;
    }

    return Column(
      key: keys.device.hammerhead,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text('device.hammerhead.authorized'.tr())),
          ],
        ),
        const SizedBox(height: 24),
        Icon(Icons.sync, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'device.hammerhead.title'.tr(),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text('device.hammerhead.message'.tr(), textAlign: TextAlign.center),
        if (_hammerheadError != null) ...[
          const SizedBox(height: 16),
          Text(
            _hammerheadError!,
            key: keys.device.hammerheadError,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: keys.device.connectHammerheadButton,
          onPressed: _connectingHammerhead ? null : _connectHammerhead,
          child: _connectingHammerhead
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('device.hammerhead.connect'.tr()),
        ),
        const SizedBox(height: 16),
        Text(
          'device.hammerhead.hint'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Explicit confirmation (RFC 8628 §5.4): which device, which account, which
  /// code, how long ago it was asked for — then the rider decides.
  Widget _buildConfirmation(ThemeData theme, VerifyResponse pending) {
    final deviceName = switch (pending.clientId) {
      'karoo' => 'device.client.karoo'.tr(),
      'garmin' => 'device.client.garmin'.tr(),
      _ => 'device.client.other'.tr(),
    };
    final accountName = ref.read(authProvider).user?.displayName ?? '';
    final requestedAt = DateTime.tryParse(pending.requestedAt);

    return Column(
      key: keys.device.confirm,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.devices, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'device.confirm.title'.tr(),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'device.confirm.question'.tr(
            namedArgs: {'device': deviceName, 'name': accountName},
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          pending.userCode,
          style: theme.textTheme.headlineMedium?.copyWith(
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (requestedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'device.confirm.requestedAt'.tr(
              namedArgs: {'when': AppFormatters.formatRelative(requestedAt)},
            ),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'device.confirm.warning'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: keys.device.denyButton,
                onPressed: () => _denyAuthorization(pending.userCode),
                child: Text('device.confirm.deny'.tr()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                key: keys.device.authorizeButton,
                onPressed: () => _completeAuthorization(pending.userCode),
                child: Text('device.confirm.authorize'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
