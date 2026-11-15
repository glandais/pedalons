// Page de DEBUG : le planificateur de parcours du site, embarqué
// (`assets/planner/`, construit par `pnpm build:mobile-planner` dans
// `frontend/`), dans une WebView plein écran et branché sur un pont minimal.
//
// Elle sert à recetter le bundle sur un appareil avant que l'écran de l'app
// n'existe (docs/LEDGER_*.md WEB-183, MOB-170) : premier affichage, fonds de
// carte, gestes. Le protocole du pont est décrit dans
// `frontend/src/embed/mobile-planner/README.md`. Chaque message part dans le
// journal, préfixé `[planner-embed]`.
//
//   flutter run --dart-define=DEV_ROUTE=/dev/planificateur \
//     --dart-define=PLANNER_TEAM=<slug d'équipe>
//
// Sans session, les appels au routeur reviennent en 401 : la carte, les fonds
// et les gestes se recettent quand même.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/pedalons_api_client.dart';
import '../config/app_config.dart';
import '../core/material.dart';

const String kPlannerEmbedPath = '/dev/planificateur';

const String _team = String.fromEnvironment('PLANNER_TEAM');

/// Les seuls chemins que la page a le droit de demander.
bool _allowed(String method, String path) {
  if (method == 'POST') {
    return path == '/api/router' ||
        path == '/api/router/elevation' ||
        path == '/api/router/import-gpx';
  }
  return method == 'GET' &&
      (path.startsWith('/api/geocode/search?') ||
          path.startsWith('/api/geocode/place?'));
}

class PlannerEmbedPage extends ConsumerStatefulWidget {
  const PlannerEmbedPage({super.key});

  @override
  ConsumerState<PlannerEmbedPage> createState() => _PlannerEmbedPageState();
}

class _PlannerEmbedPageState extends ConsumerState<PlannerEmbedPage> {
  late final WebViewController _web;
  final Map<Object, CancelToken> _pending = <Object, CancelToken>{};
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'PedalonsBridge',
        onMessageReceived: (JavaScriptMessage m) => _onMessage(m.message),
      )
      ..setOnConsoleMessage(
        (JavaScriptConsoleMessage m) =>
            _log('console.${m.level.name} ${m.message}'),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _log('pageFinished'),
          onWebResourceError: (WebResourceError e) =>
              _log('resourceError ${e.errorCode} ${e.description} ${e.url}'),
          onNavigationRequest: (NavigationRequest r) =>
              r.url.startsWith('file:') || r.url.startsWith('about:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadFlutterAsset('assets/planner/index.html');
  }

  void _log(String line) {
    final String cut = line.length > 400 ? '${line.substring(0, 400)}…' : line;
    debugPrint('[planner-embed] +${_clock.elapsedMilliseconds}ms $cut');
  }

  Future<void> _call(String method, Object? argument) =>
      _web.runJavaScript('pedalonsPlanner.$method(${jsonEncode(argument)})');

  Future<void> _onMessage(String raw) async {
    final Map<String, dynamic> message =
        jsonDecode(raw) as Map<String, dynamic>;
    final String type = message['type'] as String? ?? '';
    _log(raw);
    switch (type) {
      case 'ready':
        await _load();
      case 'request':
        await _request(message);
      case 'cancel':
        _pending.remove(message['id'])?.cancel();
      case 'pickGpx':
        await _call('gpx', null);
      case 'locate':
        await _call('position', null);
      case 'done' || 'close':
        if (mounted) Navigator.of(context).maybePop();
    }
  }

  /// Les fonds servis par notre API ne passent pas le CORS depuis la page
  /// (origine `null`) : leur document de style est lu ici et passé tel quel.
  Future<void> _load() async {
    final Dio dio = ref.read(baseDioProvider);
    try {
      final Response<dynamic> config = await dio.get<dynamic>(
        '${AppConfig.apiBaseUrl}/api/config',
      );
      final Map<String, dynamic> data = config.data as Map<String, dynamic>;
      final List<Map<String, dynamic>> styles = <Map<String, dynamic>>[];
      for (final dynamic entry in data['mapStyles'] as List<dynamic>) {
        final Map<String, dynamic> style = Map<String, dynamic>.of(
          entry as Map<String, dynamic>,
        );
        await _inline(dio, style, 'url', 'style');
        await _inline(dio, style, 'darkVariant', 'darkStyle');
        styles.add(style);
      }
      _log(
        'styles ${styles.map((Map<String, dynamic> s) => s['id']).toList()}',
      );
      await _call('load', <String, dynamic>{
        'teamSlug': _team,
        'routeName': 'Essai',
        'create': true,
        'styles': styles,
        'terrain': data['terrain'],
        'defaultCenter': data['defaultCenter'],
        'theme': 'light',
        'locale': 'fr',
        'units': 'METRIC',
      });
    } on Object catch (e) {
      _log('loadFailed $e');
    }
  }

  Future<void> _inline(
    Dio dio,
    Map<String, dynamic> style,
    String urlKey,
    String documentKey,
  ) async {
    final Object? url = style[urlKey];
    if (url is! String || !url.startsWith(AppConfig.apiBaseUrl)) return;
    final Response<dynamic> document = await dio.get<dynamic>(url);
    style
      ..remove(urlKey)
      ..[documentKey] = document.data;
  }

  Future<void> _request(Map<String, dynamic> message) async {
    final Object id = message['id'] as Object;
    final String method = message['method'] as String;
    final String path = message['path'] as String;
    if (!_allowed(method, path)) {
      await _call('response', <String, dynamic>{'id': id, 'status': 0});
      return;
    }
    final CancelToken token = CancelToken();
    _pending[id] = token;
    try {
      final Response<dynamic> response = await ref
          .read(dioProvider)
          .request<dynamic>(
            '${AppConfig.apiBaseUrl}$path',
            data: _body(message['body']),
            cancelToken: token,
            options: Options(method: method, validateStatus: (_) => true),
          );
      _log('response $id ${response.statusCode}');
      await _call('response', <String, dynamic>{
        'id': id,
        'status': response.statusCode ?? 0,
        'body': response.data,
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _log('requestFailed $id ${e.type}');
      await _call('response', <String, dynamic>{
        'id': id,
        'status': e.response?.statusCode ?? 0,
        'body': e.response?.data,
      });
    } finally {
      _pending.remove(id);
    }
  }

  Object? _body(Object? body) {
    if (body is! Map<String, dynamic> || body['multipart'] is! Map) return body;
    final Map<String, dynamic> multipart =
        body['multipart'] as Map<String, dynamic>;
    final Map<String, dynamic> file = multipart['file'] as Map<String, dynamic>;
    return FormData.fromMap(<String, dynamic>{
      ...(multipart['fields'] as Map<String, dynamic>? ??
          const <String, dynamic>{}),
      'gpxFile': MultipartFile.fromBytes(
        base64Decode(file['base64'] as String),
        filename: file['name'] as String?,
        contentType: DioMediaType.parse(
          file['contentType'] as String? ?? 'application/gpx+xml',
        ),
      ),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(
          controller: _web,
          // La carte prend tous les gestes, comme l'éditeur riche.
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
          },
        ),
      ),
    );
  }
}
