import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/router.dart';
import 'core/logging/app_log.dart';
import 'core/logging/client_context.dart';
import 'core/logging/error_reporter.dart';
import 'core/utils/link_launcher.dart';
import 'core/utils/provider_retry.dart';
import 'core/preferences/user_preferences_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/pending_sign_in_link.dart';
import 'features/feedback/presentation/unreported_fatal_prompt.dart';
import 'features/feedback/providers/error_reporter_binding.dart';
import 'features/notifications/providers/push_provider.dart';
import 'screenshots/screenshot_mode.dart';

void main() async {
  // Lets an AI assistant (or `flutter drive`) screenshot/tap/hot-reload this
  // build via the Dart/Flutter MCP server — never on by default, since it
  // disables real keyboard input. See mobile/CLAUDE.md.
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(await createApp());
}

/// Tout ce qui précède `runApp` : l'app prête à monter.
///
/// Séparé de [main] pour les tests de bout en bout (`patrol_test/`), qui
/// montent l'app eux-mêmes et ne doivent pas remplacer `FlutterError.onError`
/// — le moteur de test n'y verrait plus les erreurs, et un test en échec ne
/// s'arrêterait pas.
Future<Widget> createApp({bool installErrorHandlers = true}) async {
  // Le journal et les gestionnaires d'erreurs d'abord : une erreur du
  // démarrage lui-même est celle qu'on a le plus de mal à reproduire. Le
  // journal relu est celui de la session précédente — c'est lui qui dit ce
  // qui a précédé un plantage.
  final AppLog appLog = AppLog.instance..persistToAppSupport();
  await appLog.load();
  appLog.info('app', 'launch');

  // Le miroir des préférences se lit AVANT le premier cadre : sans lui, l'app
  // s'ouvre en clair puis bascule en sombre une fois `GET /api/users/me`
  // revenu. Une lecture asynchrone dans un provider arriverait trop tard.
  final sharedPreferences = await SharedPreferences.getInstance();

  final ClientContextBuilder clientContext = ClientContextBuilder.instance;
  unawaited(clientContext.init());
  final ErrorReporter errorReporter = ErrorReporter(
    preferences: sharedPreferences,
    log: appLog,
    context: clientContext,
    // Les erreurs d'un poste de développement n'ont rien à faire dans les
    // tickets ; `--dart-define=REPORT_ERRORS_IN_DEBUG=true` pour essayer.
    autoSendAllowed:
        !kDebugMode || const bool.fromEnvironment('REPORT_ERRORS_IN_DEBUG'),
  );
  if (installErrorHandlers) _installErrorHandlers(errorReporter);

  await EasyLocalization.ensureInitialized();

  // Firebase avant le premier cadre, et **sans bloquer le démarrage si elle
  // échoue** : une app qui ne s'ouvre pas parce que FCM est injoignable serait
  // un bien plus gros défaut que l'absence de push. `PushController` ne
  // trouvera alors pas de jeton, et le canal restera simplement muet.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    log('Firebase could not start, push disabled: $error', name: 'main');
  }

  await loadScreenshotLaunch();

  // Handle deep links
  final appLinks = AppLinks();

  // Handle initial deep link (app opened via link)
  final initialLink = await appLinks.getInitialLink();
  if (initialLink != null) {
    log('Initial deep link: $initialLink', name: 'main');
  }

  String? initialPath;
  if (initialLink != null) {
    final path = initialLink.path.isEmpty ? '/' : initialLink.path;
    final query = initialLink.query.isNotEmpty ? '?${initialLink.query}' : '';
    initialPath = path + query;
  }
  initialPath ??= screenshotInitialPath();

  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('fr')],
    path: 'assets/l10n',
    fallbackLocale: const Locale('fr'),
    child: ProviderScope(
      // Un 4xx s'affiche tout de suite ; seules les pannes passagères sont
      // rejouées — voir [providerRetry].
      retry: providerRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        errorReporterProvider.overrideWithValue(errorReporter),
        if (initialPath != null)
          initialDeepLinkProvider.overrideWithValue(initialPath),
      ],
      child: _DeepLinkHandler(appLinks: appLinks, child: const PedalonsApp()),
    ),
  );
}

/// Les deux points d'arrivée des erreurs que personne n'a rattrapées.
///
/// `FlutterError.onError` reçoit les erreurs du framework (construction,
/// mise en page, dessin) : elles s'affichent toujours comme avant
/// ([FlutterError.presentError]), puis partent au journal et au rapporteur.
/// Une erreur *silencieuse* — une image qui n'a pas chargé — ne va qu'au
/// journal. Seule une erreur de construction (`widgets library`) compte comme
/// un plantage : c'est l'écran gris ; un débordement de mise en page n'en est
/// pas un, et proposer de le signaler au lancement suivant serait du bruit.
///
/// `PlatformDispatcher.onError` reçoit les erreurs asynchrones que rien n'a
/// attendues : toutes comptent comme un plantage.
void _installErrorHandlers(ErrorReporter reporter) {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (details.silent) {
      AppLog.instance.warn('flutter', details.exceptionAsString());
      return;
    }
    unawaited(
      reporter.report(
        details.exception,
        details.stack,
        fatal: details.library == 'widgets library',
        source: 'flutter',
      ),
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    log('Unhandled error', name: 'main', error: error, stackTrace: stack);
    unawaited(reporter.report(error, stack, fatal: true));
    return true;
  };
}

/// Widget that handles deep links (initial + runtime), expanding detail-page
/// targets into a full ancestor stack so back navigates through the logical
/// hierarchy instead of closing the app.
class _DeepLinkHandler extends ConsumerStatefulWidget {
  final AppLinks appLinks;
  final Widget child;

  const _DeepLinkHandler({required this.appLinks, required this.child});

  @override
  ConsumerState<_DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

/// Give up waiting for the router to mount after this many rendered frames.
const int _maxRouterMountFrames = 120;

class _DeepLinkHandlerState extends ConsumerState<_DeepLinkHandler> {
  StreamSubscription<Uri>? _linkSubscription;
  ProviderSubscription<String?>? _pushSubscription;
  ProviderSubscription<bool>? _authSubscription;
  Completer<void>? _authInitialized;
  String? _pendingPath;
  bool _opening = false;

  @override
  void initState() {
    super.initState();

    // `uriLinkStream` also replays the launch link, so both sources funnel into
    // [_requestOpen], which keeps only the latest target.
    final initialPath = ref.read(initialDeepLinkProvider);
    if (initialPath != null) _requestOpen(initialPath);

    _linkSubscription = widget.appLinks.uriLinkStream.listen((Uri uri) {
      log('Deep link received: $uri', name: 'main');
      final path = uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
      _requestOpen(path);
    });

    // Le rapporteur d'erreurs suit la session : il envoie une fois le membre
    // connecté, et vide alors la file de ce qui attendait.
    ref.listenManual(errorReporterBindingProvider, (_, _) {});

    // Le plantage de la dernière session se propose au signalement une fois
    // le membre connecté — tout de suite, ou après son login.
    ref.listenManual(
      authProvider.select((s) => s.isInitialized && s.isAuthenticated),
      (_, bool authenticated) {
        if (authenticated) unawaited(_promptUnreportedFatal());
      },
      fireImmediately: true,
    );

    // Le contrôleur push n'existe que si quelqu'un le tient : sans cette
    // écoute, l'appareil ne s'inscrirait qu'à l'ouverture de l'écran des
    // notifications, et un membre qui ne l'ouvre jamais ne recevrait rien.
    ref.listenManual(pushAuthorizationProvider, (_, _) {});

    // Une notification tapée passe par le même tuyau qu'un lien web : elle
    // attend la session et la première route du routeur, et arrive avec ses
    // ancêtres. Le `path` est celui que le serveur a mis dans le message.
    _pushSubscription = ref.listenManual(pendingPushRouteProvider, (
      String? previous,
      String? next,
    ) {
      if (next == null) return;
      log('Push route received: $next', name: 'main');
      ref.read(pendingPushRouteProvider.notifier).state = null;
      // Un chemin que l'app ne route pas — la file de signalements, qui
      // n'existe que sur le site — s'ouvre dans le navigateur de l'appareil plutôt
      // que sur l'écran « page introuvable ».
      if (internalLocationFor(next) == null) {
        unawaited(openWebPage(next));
        return;
      }
      _requestOpen(next);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _pushSubscription?.close();
    _authSubscription?.close();
    super.dispose();
  }

  void _requestOpen(String path) {
    _pendingPath = path;
    if (_opening) return;
    _opening = true;
    _openWhenReady();
  }

  /// Waits until the app is ready to be navigated, then opens the pending link.
  ///
  /// Two conditions must hold. Auth must be initialized, since `app.dart` shows
  /// its loading scaffold until then — with no timeout, as restoring a session
  /// can take a network round trip. And the router must have parsed its first
  /// route: [GoRouter.push] stacks onto `routerDelegate.currentConfiguration`,
  /// which stays empty until then — pushing before that silently collapses the
  /// ancestors into a single-entry stack, leaving the page with no way back.
  Future<void> _openWhenReady() async {
    await _whenAuthInitialized();
    if (!mounted) return;
    await screenshotSignIn(ref);
    if (!mounted) return;

    final mountedRouter = await _whenRouterMounted();
    if (!mounted) return;
    if (!mountedRouter) {
      log(
        'Router did not mount in time, opening deep link anyway',
        name: 'main',
      );
    }

    final path = _pendingPath;
    _pendingPath = null;
    _opening = false;
    if (path != null) _openWithHierarchy(path);
  }

  /// Attend que le routeur ait analysé sa première route, [_maxRouterMountFrames]
  /// cadres au plus. Faux s'il ne l'a pas fait à temps.
  Future<bool> _whenRouterMounted() async {
    for (var i = 0; i < _maxRouterMountFrames; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      if (ref
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _fatalPrompted = false;

  /// Une seule fois par session, et seulement s'il y a quelque chose à
  /// proposer. Le lien profond éventuel s'ouvre d'abord : la question vient
  /// par-dessus l'écran demandé, pas à sa place.
  Future<void> _promptUnreportedFatal() async {
    final reporter = ref.read(errorReporterProvider);
    if (_fatalPrompted || reporter.unreportedFatal == null) return;
    _fatalPrompted = true;
    if (!await _whenRouterMounted()) return;
    // Laisse au lien profond le temps de construire sa pile.
    await WidgetsBinding.instance.endOfFrame;
    final navigatorContext = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;
    await promptUnreportedFatal(navigatorContext, reporter);
  }

  Future<void> _whenAuthInitialized() {
    if (ref.read(authProvider).isInitialized) return Future<void>.value();
    final completer = _authInitialized ??= Completer<void>();
    _authSubscription ??= ref.listenManual(
      authProvider.select((s) => s.isInitialized),
      (_, isInitialized) {
        if (isInitialized && !completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  void _openWithHierarchy(String path) {
    // Hors session, le lien attend la connexion au lieu d'être perdu.
    openDeepLink(
      ref.read(routerProvider),
      path,
      signedIn: ref.read(authProvider).isAuthenticated,
      pending: ref.read(pendingSignInLinkProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
