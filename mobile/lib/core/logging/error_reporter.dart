import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/generated/export.dart';
import '../preferences/error_reports_preference.dart';
import 'app_log.dart';
import 'client_context.dart';
import 'client_error.dart';

/// Envoie un rapport d'erreur automatique (`POST /api/feedback/errors`).
typedef ErrorReportSender = Future<void> Function(ErrorReportRequest request);

/// Nombre d'entrées de journal jointes à un rapport automatique (plafond du
/// contrat).
const int kErrorReportMaxLogs = 50;

const String _kQueueKey = 'errorReports.queue';
const String _kUnreportedFatalKey = 'errorReports.unreportedFatal';

/// Les rapports d'erreur automatiques.
///
/// **Discret par construction.** Un échec d'envoi ne se voit jamais, ne se
/// réessaie jamais en boucle : le serveur répond toujours 204, et c'est lui qui
/// dédoublonne et rationne. Côté app, deux freins de plus, par session : une
/// même erreur (type + message) ne part qu'une fois, et pas plus de
/// [maxPerSession] rapports au total — une erreur de rendu répétée à chaque
/// cadre ne doit pas devenir soixante requêtes par seconde.
///
/// **Sans session, rien ne part** — l'endpoint exige un membre connecté. Le
/// rapport attend alors dans une file persistée, vidée à la prochaine
/// connexion ([attach]) : au lancement suivant, ou après le login. Une erreur
/// réseau remet le rapport en file une fois, pour la même occasion suivante.
///
/// **Le réglage « Envoyer automatiquement les rapports d'erreur »**
/// ([kAutoErrorReportsKey]) coupe tout envoi et vide la file. Il ne coupe pas
/// [unreportedFatal] : proposer au membre de signaler lui-même un plantage,
/// c'est lui laisser la décision, pas envoyer à sa place.
class ErrorReporter {
  ErrorReporter({
    required SharedPreferences preferences,
    required this._log,
    required this._context,
    this.maxPerSession = 5,
    this.maxQueue = 5,
    this.autoSendAllowed = true,
  }) : _prefs = preferences {
    _previousFatal = _readFatal();
  }

  final SharedPreferences _prefs;
  final AppLog _log;
  final ClientContextBuilder _context;

  final int maxPerSession;
  final int maxQueue;

  /// Faux en build de développement (voir `main.dart`) : les erreurs d'un
  /// poste de dev n'ont rien à faire dans les tickets.
  final bool autoSendAllowed;

  ErrorReportSender? _sender;
  final Set<String> _seen = <String>{};
  int _reportedThisSession = 0;
  bool _reporting = false;
  bool _flushing = false;

  /// Le plantage de la session **précédente**, lu à la construction. Celui de
  /// la session en cours, persisté pour la suivante, n'y apparaît pas : on ne
  /// propose pas de signaler ce qui vient d'arriver sous les yeux du membre.
  ClientErrorDto? _previousFatal;

  bool get enabled =>
      autoSendAllowed && (_prefs.getBool(kAutoErrorReportsKey) ?? true);

  ClientErrorDto? get unreportedFatal => _previousFatal;

  /// Oublie le plantage précédent — que le membre l'ait signalé ou non.
  Future<void> clearUnreportedFatal() async {
    _previousFatal = null;
    await _prefs.remove(_kUnreportedFatalKey);
  }

  /// Branche l'envoi, une fois la session ouverte, et vide la file.
  Future<void> attach(ErrorReportSender sender) {
    _sender = sender;
    return flush();
  }

  /// Débranche l'envoi : les rapports suivants attendent en file.
  void detach() => _sender = null;

  /// Signale une erreur. Ne lève jamais.
  ///
  /// [fatal] : l'erreur n'a été rattrapée par personne. Elle est alors
  /// retenue pour la session suivante, où l'app proposera de la signaler.
  Future<void> report(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String source = 'error',
  }) async {
    // Une erreur levée pendant qu'on en signale une autre ne se signale pas :
    // c'est le chemin le plus court vers une boucle. Le verrou ne couvre que
    // la partie synchrone — le tenir pendant l'envoi ferait perdre toute
    // erreur survenue pendant l'aller-retour réseau. Une erreur asynchrone du
    // rapporteur lui-même reste bornée par la déduplication et le plafond.
    if (_reporting) return;
    final ErrorReportRequest? request;
    _reporting = true;
    try {
      request = _prepare(error, stackTrace, fatal: fatal, source: source);
    } catch (e) {
      developer.log('Error report dropped: $e', name: 'ErrorReporter');
      return;
    } finally {
      _reporting = false;
    }
    if (request == null) return;
    try {
      final ErrorReportSender? sender = _sender;
      if (sender == null) {
        await _enqueue(<ErrorReportRequest>[request]);
      } else {
        await _send(sender, request);
      }
    } catch (e) {
      developer.log('Error report dropped: $e', name: 'ErrorReporter');
    }
  }

  /// Journalise l'erreur, retient un plantage, et rend le rapport à envoyer —
  /// ou `null` quand il n'y a rien à envoyer.
  ///
  /// Une erreur **déjà vue dans la session** ne s'écrit même plus au journal :
  /// un débordement de mise en page répété à chaque cadre chasserait sinon du
  /// tampon toutes les lignes qui l'ont précédé, celles qui l'expliquent.
  ErrorReportRequest? _prepare(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    required String source,
  }) {
    final ClientErrorDto dto = clientErrorFrom(error, stackTrace);
    final String key = '${dto.type}\n${dto.message}';
    final bool firstTime = _seen.add(key);
    if (firstTime) _log.error(source, '${dto.type}: ${dto.message}');
    if (fatal) {
      unawaited(
        _prefs.setString(_kUnreportedFatalKey, jsonEncode(dto.toJson())),
      );
      // Le processus peut ne pas survivre à la minute : le journal part sur
      // disque tout de suite, pas après le délai de regroupement.
      unawaited(_log.flush());
    }
    if (!enabled || !firstTime || _reportedThisSession >= maxPerSession) {
      return null;
    }
    _reportedThisSession++;
    return ErrorReportRequest(
      context: _context.build(),
      error: dto,
      logs: _log.snapshot(max: kErrorReportMaxLogs),
    );
  }

  /// Envoie la file en attente. Appelé par [attach] ; jamais en boucle.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final List<ErrorReportRequest> queued = _readQueue();
      if (queued.isEmpty) return;
      await _prefs.remove(_kQueueKey);
      if (!enabled) return;
      for (final ErrorReportRequest request in queued) {
        final ErrorReportSender? sender = _sender;
        if (sender == null) {
          await _enqueue(<ErrorReportRequest>[request]);
          continue;
        }
        await _send(sender, request);
      }
    } catch (e) {
      developer.log('Error report queue dropped: $e', name: 'ErrorReporter');
    } finally {
      _flushing = false;
    }
  }

  /// Un envoi, une tentative. Hors ligne, le rapport retourne en file pour
  /// la prochaine connexion ; toute autre erreur le perd — le serveur
  /// l'aurait refusé de la même façon la fois suivante.
  Future<void> _send(
    ErrorReportSender sender,
    ErrorReportRequest request,
  ) async {
    try {
      await sender(request);
    } on DioException catch (e) {
      if (_isOffline(e)) await _enqueue(<ErrorReportRequest>[request]);
      developer.log('Error report not sent: ${e.type}', name: 'ErrorReporter');
    } catch (e) {
      developer.log('Error report not sent: $e', name: 'ErrorReporter');
    }
  }

  static bool _isOffline(DioException e) =>
      e.response == null &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout);

  Future<void> _enqueue(List<ErrorReportRequest> requests) async {
    final List<ErrorReportRequest> queue = <ErrorReportRequest>[
      ..._readQueue(),
      ...requests,
    ];
    // Les plus récents d'abord gardés : ce sont eux qui disent l'état actuel.
    final List<ErrorReportRequest> kept = queue.length > maxQueue
        ? queue.sublist(queue.length - maxQueue)
        : queue;
    await _prefs.setString(
      _kQueueKey,
      jsonEncode(kept.map((ErrorReportRequest r) => r.toJson()).toList()),
    );
  }

  List<ErrorReportRequest> _readQueue() {
    final String? raw = _prefs.getString(_kQueueKey);
    if (raw == null) return <ErrorReportRequest>[];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (dynamic e) =>
                ErrorReportRequest.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return <ErrorReportRequest>[];
    }
  }

  /// Les rapports en attente d'une session — pour les tests.
  List<ErrorReportRequest> get queued => _readQueue();

  ClientErrorDto? _readFatal() {
    final String? raw = _prefs.getString(_kUnreportedFatalKey);
    if (raw == null) return null;
    try {
      return ClientErrorDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Le rapporteur de l'app, construit dans `main()` — les gestionnaires
/// globaux d'erreurs s'exécutent hors de Riverpod — et injecté par
/// surcharge. Comme [sharedPreferencesProvider], un accès sans surcharge est
/// une erreur de câblage.
final Provider<ErrorReporter> errorReporterProvider = Provider<ErrorReporter>(
  (Ref ref) => throw StateError(
    'errorReporterProvider doit être surchargé dans main().',
  ),
);
