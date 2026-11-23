import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../../../core/geo/location_service.dart';
import '../../../core/geo/polyline_index.dart';
import '../../../core/logging/app_log.dart';
import '../domain/gpx_check.dart';
import '../domain/planner_quota.dart';
import '../domain/planner_result.dart';
import 'gpx_file_source.dart';
import 'planner_web_view.dart';

/// Les seules requêtes que la page a le droit de faire passer par l'app
/// (`frontend/src/embed/mobile-planner/README.md`) : les trois appels du
/// routeur, la liste de ses moteurs et la recherche de lieux. Tout le reste est refusé (statut 0) —
/// la page ne choisit ni l'hôte ni un autre chemin de l'API.
@visibleForTesting
bool plannerRequestAllowed(Object? method, Object? path) {
  if (method is! String || path is! String) return false;
  if (method == 'POST') {
    return path == '/api/router' ||
        path == '/api/router/elevation' ||
        path == '/api/router/import-gpx';
  }
  if (method != 'GET') return false;
  final Uri? uri = Uri.tryParse(path);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
  // Les moteurs offerts : avec ou sans `teamSlug`, aucun autre paramètre.
  if (uri.path == '/api/router/engines') {
    final Set<String> keys = uri.queryParameters.keys.toSet();
    return keys.isEmpty || keys.length == 1 && keys.single == 'teamSlug';
  }
  if (!uri.hasQuery) return false;
  return uri.path == '/api/geocode/search' || uri.path == '/api/geocode/place';
}

/// Ce que `load` porte, et ce que sa préparation a appris en route.
@immutable
class PlannerLoad {
  const PlannerLoad(this.input, {this.stateReadFailed = false});

  /// L'argument de `window.pedalonsPlanner.load`.
  final Map<String, dynamic> input;

  /// L'état d'édition enregistré n'a pas pu être relu : le tracé s'ouvre
  /// comme un import, et l'écran le dit (`planner.state.readFailed` du site).
  final bool stateReadFailed;
}

/// Le pont entre le planificateur embarqué et l'app (docs/LEDGER_*.md
/// MOB-170 ; protocole : `frontend/src/embed/mobile-planner/README.md`).
///
/// **Flutter est le seul client HTTP** : la page n'a ni jeton ni adresse, et
/// chaque `request` part par le Dio authentifié de l'app (rafraîchissement du
/// 401 compris), sur la liste fermée de [plannerRequestAllowed].
///
/// **Le pont vit le temps du formulaire, pas de l'écran.** Il possède la page
/// ([webView]) : l'écran du planificateur s'y attache et s'en détache sans la
/// détruire. `done` ne rend qu'un fragment *relatif à l'état sur lequel la
/// page s'est ouverte* et aucun état : la recharger entre deux ouvertures
/// laisserait une réouverture sans retouche effacer le premier résultat.
/// `load` ne part donc qu'une fois (à chaque `ready` de la page, qui n'en
/// poste qu'un par chargement).
class PlannerBridge {
  PlannerBridge({
    required this._dio,
    required this._picker,
    required this._location,
    required PlannerWebViewFactory webViewFactory,
    required this._load,
    this.onDone,
    this.onQuotaRefused,
  }) {
    webView = webViewFactory(onMessage: handleMessage);
    if (debugTestCommands) debugCurrent = this;
    // Préparé pendant que la page charge : `ready` n'attend que le reste.
    _prepared = _prepare();
  }

  /// Test Patrol uniquement : `load` porte `testCommands`, et [debugCurrent]
  /// donne le pont ouvert, pour poser des points sans toucher la carte
  /// ([debugPlace]). Jamais posé par l'app.
  static bool debugTestCommands = false;
  static PlannerBridge? debugCurrent;

  final Dio _dio;
  final GpxFilePicker Function() _picker;
  final LocationService _location;
  final Future<PlannerLoad> Function() _load;

  /// « Terminer » : le résultat, pour le formulaire. L'écran, s'il est
  /// ouvert, se ferme ensuite ([onLeave]).
  void Function(PlannerResult result)? onDone;

  /// Un calcul refusé parce que le quota est épuisé : la feuille de quota et
  /// la relecture de l'équipe sont au formulaire.
  void Function(PlannerQuotaRefusal refusal)? onQuotaRefused;

  /// Posé par l'écran ouvert : le fermer (« Terminer », flèche de retour).
  VoidCallback? onLeave;

  /// Posé par l'écran ouvert : un fichier choisi dans le planificateur a été
  /// refusé par le contrôle local.
  void Function(GpxRefused refused)? onGpxRefused;

  late final PlannerWebView webView;
  late Future<PlannerLoad?> _prepared;

  /// Un calcul (un tronçon, un import) est en vol : rien à enregistrer.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// Quelque chose a changé dans la page depuis `load`.
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);

  /// Quelque chose a changé dans la page depuis le dernier « Terminer »
  /// (depuis `load` avant le premier) : ce que le formulaire n'a pas.
  /// Une page d'avant ce champ ne l'envoie pas : [dirty] en tient lieu.
  final ValueNotifier<bool> pending = ValueNotifier<bool>(false);

  /// L'écran a été quitté sans « Terminer » alors que la page avait changé :
  /// ce qu'elle montre n'est pas (ou plus) ce que le formulaire enverrait.
  final ValueNotifier<bool> unvalidated = ValueNotifier<bool>(false);

  /// `load` est parti : la page s'affiche.
  final ValueNotifier<bool> loaded = ValueNotifier<bool>(false);

  /// La préparation de `load` a échoué : l'écran propose de réessayer.
  final ValueNotifier<Object?> loadError = ValueNotifier<Object?>(null);

  /// L'état enregistré n'a pas pu être relu ([PlannerLoad.stateReadFailed]).
  final ValueNotifier<bool> stateReadFailed = ValueNotifier<bool>(false);

  final Map<String, CancelToken> _pending = <String, CancelToken>{};
  final Map<String, GpxFile> _files = <String, GpxFile>{};
  int _fileSeq = 0;
  String? _lastFileId;
  bool _ready = false;
  bool _leavingAfterDone = false;
  bool _disposed = false;

  /// Le fichier que le pont a gardé pour un résultat `file` : celui que la
  /// page nomme ([PlannerResult.fileId]), sinon le dernier choisi.
  GpxFile? fileFor(PlannerResult result) =>
      _files[result.fileId ?? _lastFileId];

  Future<PlannerLoad?> _prepare() async {
    loadError.value = null;
    try {
      final PlannerLoad load = await _load();
      if (_disposed) return null;
      stateReadFailed.value = load.stateReadFailed;
      return load;
    } on Object catch (error) {
      if (!_disposed) loadError.value = error;
      return null;
    }
  }

  /// Après un échec de la préparation : la refaire, et charger la page si
  /// elle attend déjà.
  Future<void> retryLoad() async {
    _prepared = _prepare();
    if (_ready) await _sendLoad();
  }

  Future<void> _sendLoad() async {
    final PlannerLoad? load = await _prepared;
    if (load == null || _disposed) return;
    await _call('load', <String, dynamic>{
      ...load.input,
      if (debugTestCommands) 'testCommands': true,
    });
    if (!_disposed) loaded.value = true;
  }

  /// Test Patrol : pose [points] en ligne droite (aucun appel au routeur),
  /// puis fait ce que fait « Terminer ». Sans effet hors [debugTestCommands].
  Future<void> debugPlace(List<LngLat> points, {bool done = true}) =>
      _call('test', <String, dynamic>{
        'place': <Map<String, double>>[
          for (final LngLat p in points)
            <String, double>{'lng': p.lng, 'lat': p.lat},
        ],
        'done': done,
      });

  Future<void> _call(String method, Object? argument) async {
    if (_disposed) return;
    try {
      await webView.call(method, argument);
    } on Object catch (error) {
      // La page a disparu (processus de rendu tué) : rien à lui dire.
      AppLog.instance.warn('planner', '$method: $error');
    }
  }

  /// Un message de la page, en JSON. Ne lève jamais : un message mal formé
  /// part au journal.
  Future<void> handleMessage(String raw) async {
    if (_disposed) return;
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      AppLog.instance.warn('planner', 'message illisible');
      return;
    }
    switch (message['type']) {
      case 'ready':
        _ready = true;
        await _sendLoad();
      case 'request':
        await _request(message);
      case 'cancel':
        _pending.remove(message['id'])?.cancel();
      case 'pickGpx':
        await _pickGpx();
      case 'locate':
        await _locate();
      case 'busy':
        busy.value = message['busy'] == true;
      case 'dirty':
        _readDirty(message);
      case 'quotaRefused':
        final PlannerQuotaRefusal? refusal = PlannerQuotaRefusal.fromJson(
          message,
        );
        if (refusal != null) onQuotaRefused?.call(refusal);
      case 'done':
        _done(message);
      case 'close':
        _readDirty(message);
        onLeave?.call();
      case 'error':
        AppLog.instance.error('planner', '${message['message']}');
    }
  }

  void _readDirty(Map<String, dynamic> message) {
    dirty.value = message['dirty'] == true;
    final Object? sinceDone = message['pending'];
    pending.value = sinceDone is bool ? sinceDone : dirty.value;
  }

  void _done(Map<String, dynamic> message) {
    final PlannerResult result;
    try {
      result = PlannerResult.fromMessage(message);
    } on Object catch (error) {
      // Un fragment hors contrat : le résultat précédent reste, l'écran aussi.
      AppLog.instance.error('planner', 'done illisible : $error');
      return;
    }
    dirty.value = result.dirty;
    pending.value = false;
    unvalidated.value = false;
    _leavingAfterDone = true;
    onDone?.call(result);
    onLeave?.call();
  }

  /// L'écran du planificateur vient d'être quitté — par « Terminer », par la
  /// flèche de la page ou par le retour du système, que la page ne voit pas.
  /// La page reste en vie avec ce qu'elle montre.
  void screenLeft() {
    if (_disposed) return;
    // Rouvert après un « Terminer » et quitté sans rien toucher : le formulaire
    // a déjà tout, rien n'est en suspens.
    if (!_leavingAfterDone && pending.value) unvalidated.value = true;
    _leavingAfterDone = false;
  }

  // ── Requêtes ───────────────────────────────────────────────────────────

  Future<void> _request(Map<String, dynamic> message) async {
    final Object? id = message['id'];
    if (id is! String) return;
    final Object? method = message['method'];
    final Object? path = message['path'];
    if (!plannerRequestAllowed(method, path)) {
      await _respond(id, 0);
      return;
    }
    final CancelToken token = CancelToken();
    _pending[id] = token;
    try {
      final Response<dynamic> response = await _dio.request<dynamic>(
        path! as String,
        data: _body(message['body']),
        cancelToken: token,
        options: Options(method: method! as String),
      );
      await _respond(id, response.statusCode ?? 0, response);
    } on DioException catch (error) {
      // Annulée par la page : elle n'attend plus de réponse.
      if (CancelToken.isCancel(error) || token.isCancelled) return;
      final Response<dynamic>? response = error.response;
      await _respond(id, response?.statusCode ?? 0, response);
    } on Object catch (error) {
      // Un corps hors contrat (base64 invalide…) : pas de réponse du serveur.
      AppLog.instance.warn('planner', 'request $path: $error');
      await _respond(id, 0);
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> _respond(String id, int status, [Response<dynamic>? response]) {
    final int? retryAfter = int.tryParse(
      response?.headers.value('retry-after') ?? '',
    );
    return _call('response', <String, dynamic>{
      'id': id,
      'status': status,
      'body': ?_encodable(response?.data),
      'retryAfter': ?retryAfter,
    });
  }

  /// Le corps tel que `jsonEncode` le passera : le JSON décodé par Dio, sinon
  /// son texte.
  static Object? _encodable(Object? body) {
    if (body == null || body is String || body is num || body is bool) {
      return body;
    }
    try {
      jsonEncode(body);
      return body;
    } on Object {
      return body.toString();
    }
  }

  /// Un `FormData` ne traverse pas le pont : le multipart arrive décrit, son
  /// fichier en base64, et repart en vraie partie `gpxFile`.
  static Object? _body(Object? body) {
    if (body is! Map<String, dynamic>) return body;
    final Object? multipart = body['multipart'];
    if (multipart is! Map<String, dynamic>) return body;
    final Map<String, dynamic> file = multipart['file'] as Map<String, dynamic>;
    final Object? fields = multipart['fields'];
    return FormData.fromMap(<String, dynamic>{
      if (fields is Map<String, dynamic>) ...fields,
      'gpxFile': MultipartFile.fromBytes(
        base64Decode(file['base64'] as String),
        filename: file['name'] as String?,
        contentType: DioMediaType.parse(
          file['contentType'] as String? ?? 'application/gpx+xml',
        ),
      ),
    });
  }

  // ── Fichier et position ────────────────────────────────────────────────

  /// Ouvre le sélecteur de l'app, passe le fichier au contrôle local de
  /// l'éditeur (`inspectGpxFile`), **le garde** et rend ses octets. Un fichier
  /// refusé ou un sélecteur quitté répondent `null`.
  Future<void> _pickGpx() async {
    GpxFile? accepted;
    try {
      final GpxFile? picked = await _picker().pick();
      if (picked != null) {
        switch (await inspectGpxFile(picked)) {
          case final GpxAccepted check:
            accepted = check.file;
          case final GpxRefused refused:
            onGpxRefused?.call(refused);
        }
      }
      if (accepted == null) {
        await _call('gpx', null);
        return;
      }
      final Uint8List bytes = await File(accepted.path).readAsBytes();
      final String id = '${++_fileSeq}';
      _files[id] = accepted;
      _lastFileId = id;
      await _call('gpx', <String, dynamic>{
        'name': accepted.name,
        'base64': base64Encode(bytes),
        'id': id,
      });
    } on Object catch (error) {
      // Sélecteur en échec (`PlatformException`) ou fichier devenu illisible.
      if (error is! PlatformException && error is! FileSystemException) {
        AppLog.instance.warn('planner', 'pickGpx: $error');
      }
      if (accepted != null) {
        onGpxRefused?.call(GpxRefused(accepted.name, GpxRefusal.notGpx));
      }
      await _call('gpx', null);
    }
  }

  /// La position approximative, une fois, sans nouvelle permission
  /// (docs/LEDGER_*.md MOB-131) ; `null` quand il n'y en a pas.
  Future<void> _locate() async {
    final LngLat? position = await _location.coarsePosition();
    await _call(
      'position',
      position == null
          ? null
          : <String, double>{'lng': position.lng, 'lat': position.lat},
    );
  }

  /// Le formulaire s'en va : les requêtes en vol sont annulées, la page
  /// abandonnée.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (identical(debugCurrent, this)) debugCurrent = null;
    for (final CancelToken token in _pending.values) {
      token.cancel();
    }
    _pending.clear();
    webView.dispose();
    busy.dispose();
    dirty.dispose();
    pending.dispose();
    unvalidated.dispose();
    loaded.dispose();
    loadError.dispose();
    stateReadFailed.dispose();
  }
}
