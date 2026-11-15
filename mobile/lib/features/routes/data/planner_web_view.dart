import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// La page du planificateur, vue du pont : de quoi lui parler et de quoi la
/// montrer. Le pont (`PlannerBridge`) ne connaît que cette interface — la
/// WebView n'est **jamais réelle dans un test de widget**, qui remplace
/// [plannerWebViewFactoryProvider] par une fausse page (le pendant de
/// `RouteMap.debugSkipNativeMap` pour la carte native).
abstract interface class PlannerWebView {
  /// Appelle `window.pedalonsPlanner.<method>(<argument en JSON>)`.
  Future<void> call(String method, Object? argument);

  /// Le fond derrière la page tant qu'elle n'a rien peint.
  void setBackgroundColor(Color color);

  /// La page, à poser comme corps entier de l'écran. **Une seule à la fois** :
  /// un `WebViewController` ne sert qu'un `WebViewWidget` en même temps.
  Widget build(BuildContext context);

  /// La page est abandonnée : plus rien ne lui sera envoyé.
  void dispose();
}

/// Fabrique la page ; [onMessage] reçoit chaque message qu'elle poste sur
/// `PedalonsBridge`, en JSON.
typedef PlannerWebViewFactory = PlannerWebView Function({
  required void Function(String raw) onMessage,
});

final plannerWebViewFactoryProvider = Provider<PlannerWebViewFactory>(
  (Ref ref) => SystemPlannerWebView.new,
);

/// La vraie page : `assets/planner/index.html` (construit par
/// `pnpm build:mobile-planner` dans `frontend/`), chargé depuis les assets —
/// `file://`, origine `null`, ni jeton ni adresse.
///
/// **Le contrôleur vit plus longtemps que l'écran.** La WebView native est
/// créée ici, avec le contrôleur, et non par le `WebViewWidget` : quitter
/// l'écran du planificateur détache la vue sans la détruire, la page garde
/// son état, et un nouvel écran s'y rattache ([build]). C'est ce qui permet
/// de n'envoyer `load` qu'une fois par formulaire (docs/LEDGER_*.md MOB-170).
class SystemPlannerWebView implements PlannerWebView {
  SystemPlannerWebView({required void Function(String raw) onMessage}) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'PedalonsBridge',
        onMessageReceived: (JavaScriptMessage m) => onMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          // Rien ne navigue hors de la page : un lien d'attribution de carte
          // ne remplace pas le planificateur.
          onNavigationRequest: (NavigationRequest r) =>
              r.url.startsWith('file:') || r.url.startsWith('about:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadFlutterAsset('assets/planner/index.html');
  }

  late final WebViewController _controller;
  bool _disposed = false;

  @override
  Future<void> call(String method, Object? argument) async {
    if (_disposed) return;
    await _controller.runJavaScript(
      'pedalonsPlanner.$method(${jsonEncode(argument)})',
    );
  }

  @override
  void setBackgroundColor(Color color) {
    if (!_disposed) _controller.setBackgroundColor(color);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(
    controller: _controller,
    // La carte prend tous les gestes, comme l'éditeur riche (MOB-160).
    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
      Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
    },
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Le contrôleur n'a pas de `dispose` : la page vide rend tout de suite la
    // carte et son contexte WebGL, sans attendre le ramasse-miettes.
    _controller.loadRequest(Uri.parse('about:blank')).ignore();
  }
}
