import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../api/generated/export.dart';

/// Gravité d'une entrée, alignée sur `ClientLogLevel` du contrat.
enum AppLogLevel {
  debug('DEBUG'),
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  const AppLogLevel(this.json);

  final String json;

  static AppLogLevel fromJson(String? value) => AppLogLevel.values.firstWhere(
    (AppLogLevel l) => l.json == value,
    orElse: () => AppLogLevel.info,
  );
}

/// Longueur maximale d'un message, celle de `ClientLogEntryDto.message`.
const int kAppLogMessageMaxLength = 1000;

/// Longueur maximale d'une source, celle de `ClientLogEntryDto.source`.
const int kAppLogSourceMaxLength = 50;

/// Une ligne du journal récent.
class AppLogEntry {
  AppLogEntry({
    required this.ts,
    required this.level,
    required String source,
    required String message,
  }) : source = truncate(source, kAppLogSourceMaxLength),
       message = truncate(sanitizeLogText(message), kAppLogMessageMaxLength);

  final DateTime ts;
  final AppLogLevel level;
  final String source;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'ts': ts.toUtc().toIso8601String(),
    'level': level.json,
    'source': source,
    'message': message,
  };

  static AppLogEntry? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final DateTime? ts = DateTime.tryParse(json['ts'] as String? ?? '');
    final Object? source = json['source'];
    final Object? message = json['message'];
    if (ts == null || source is! String || message is! String) return null;
    return AppLogEntry(
      ts: ts,
      level: AppLogLevel.fromJson(json['level'] as String?),
      source: source,
      message: message,
    );
  }

  ClientLogEntryDto toDto() => ClientLogEntryDto(
    ts: ts.toUtc().toIso8601String(),
    level: level.json,
    source: source,
    message: message,
  );
}

/// Coupe [value] à [max] caractères, points de suspension compris.
String truncate(String value, int max) {
  if (value.length <= max) return value;
  return '${value.substring(0, max - 1)}…';
}

final RegExp _urlQuery = RegExp(r'(https?://[^\s?#]+)[?#][^\s]*');

/// Retire la query string de toute URL citée dans un texte.
///
/// Les jetons voyagent en query string (vérification d'e-mail, mot de passe
/// oublié, tuiles signées) : un message d'exception qui cite l'URL complète les
/// ferait entrer dans un rapport.
String sanitizeLogText(String value) =>
    value.replaceAllMapped(_urlQuery, (Match m) => m.group(1)!);

/// Le journal récent de l'app : un tampon circulaire, persisté.
///
/// **Ce qu'il contient est ce qu'un rapport joint** — requêtes échouées
/// (méthode, chemin sans query, statut, code métier), navigations (chemin
/// seul), erreurs. Jamais un corps, un en-tête ni une query string : c'est la
/// règle, et c'est pourquoi rien n'écoute `debugPrint` ni les diagnostics de
/// GoRouter, qui citent les emplacements complets, jetons compris.
///
/// **Persisté pour survivre au plantage** : « l'app a planté, je la rouvre et
/// je signale » doit encore trouver les lignes qui précèdent le plantage. Le
/// fichier est réécrit en entier (il est borné) après chaque entrée WARN ou
/// ERROR, avec un léger délai pour regrouper les rafales, et relu au
/// démarrage.
class AppLog {
  AppLog({
    this.capacity = 200,
    this._directory,
    this.flushDelay = const Duration(milliseconds: 500),
  });

  /// Le journal de l'app. Les gestionnaires globaux de `main.dart` s'exécutent
  /// hors de Riverpod : ils écrivent ici, et [appLogProvider] rend la même
  /// instance aux écrans.
  ///
  /// **En mémoire seulement** tant que `main()` n'a pas appelé
  /// [persistToAppSupport] : un test qui passe par une erreur n'écrit rien sur
  /// disque et ne laisse aucun minuteur en attente.
  static final AppLog instance = AppLog();

  static const String fileName = 'client_log.jsonl';

  final int capacity;
  final Duration flushDelay;
  Future<Directory> Function()? _directory;

  /// Persiste désormais dans le dossier de support de l'app.
  void persistToAppSupport() => _directory ??= getApplicationSupportDirectory;

  final ListQueue<AppLogEntry> _entries = ListQueue<AppLogEntry>();
  Timer? _flushTimer;
  Future<void>? _pendingWrite;

  /// Les entrées, de la plus ancienne à la plus récente.
  List<AppLogEntry> get entries => List<AppLogEntry>.unmodifiable(_entries);

  void debug(String source, String message) =>
      add(AppLogLevel.debug, source, message);
  void info(String source, String message) =>
      add(AppLogLevel.info, source, message);
  void warn(String source, String message) =>
      add(AppLogLevel.warn, source, message);
  void error(String source, String message) =>
      add(AppLogLevel.error, source, message);

  void add(AppLogLevel level, String source, String message) {
    _push(
      AppLogEntry(
        ts: DateTime.now(),
        level: level,
        source: source,
        message: message,
      ),
    );
    if (level == AppLogLevel.warn || level == AppLogLevel.error) {
      _scheduleFlush();
    }
  }

  void _push(AppLogEntry entry) {
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  /// Les [max] dernières entrées, au format du contrat, plus ancienne d'abord.
  List<ClientLogEntryDto> snapshot({int? max}) {
    final int count = max == null
        ? _entries.length
        : (max < _entries.length ? max : _entries.length);
    return _entries
        .skip(_entries.length - count)
        .map((AppLogEntry e) => e.toDto())
        .toList(growable: false);
  }

  /// Relit le fichier d'une session précédente. Les entrées relues passent
  /// **avant** celles déjà écrites dans cette session.
  Future<void> load() async {
    if (_directory == null) return;
    try {
      final File file = await _file();
      if (!await file.exists()) return;
      final List<String> lines = await file.readAsLines();
      final List<AppLogEntry> restored = <AppLogEntry>[];
      for (final String line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final AppLogEntry? entry = AppLogEntry.tryFromJson(jsonDecode(line));
          if (entry != null) restored.add(entry);
        } catch (_) {
          // Une ligne tronquée par un plantage en pleine écriture : on l'ignore.
        }
      }
      final List<AppLogEntry> current = _entries.toList();
      _entries.clear();
      for (final AppLogEntry e in <AppLogEntry>[...restored, ...current]) {
        _push(e);
      }
    } catch (error) {
      developer.log('Client log not restored: $error', name: 'AppLog');
    }
  }

  void _scheduleFlush() {
    if (_directory == null) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(flushDelay, () => unawaited(flush()));
  }

  /// Écrit le tampon sur disque, tout de suite. Les écritures se suivent,
  /// jamais ne se chevauchent.
  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final String content = _entries
        .map((AppLogEntry e) => jsonEncode(e.toJson()))
        .join('\n');
    final Future<void> previous = _pendingWrite ?? Future<void>.value();
    final Future<void> write = previous.then((_) => _write(content));
    _pendingWrite = write;
    return write;
  }

  Future<void> _write(String content) async {
    if (_directory == null) return;
    try {
      final File file = await _file();
      final File tmp = File('${file.path}.tmp');
      await tmp.writeAsString(content, flush: true);
      await tmp.rename(file.path);
    } catch (error) {
      // Jamais d'entrée de journal ici : ce serait une boucle.
      developer.log('Client log not persisted: $error', name: 'AppLog');
    }
  }

  Future<File> _file() async {
    final Directory dir = await _directory!();
    return File('${dir.path}/$fileName');
  }

  /// Vide le tampon et le fichier — pour les tests.
  Future<void> clear() async {
    _entries.clear();
    await flush();
  }
}

/// Le journal de l'app, pour les écrans. Surchargeable en test.
final Provider<AppLog> appLogProvider = Provider<AppLog>(
  (Ref ref) => AppLog.instance,
);
