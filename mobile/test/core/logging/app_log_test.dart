import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/interceptors/client_log_interceptor.dart';
import 'package:pedalons/core/logging/app_log.dart';
import 'package:pedalons/core/logging/client_context.dart';
import 'package:pedalons/core/logging/client_error.dart';

/// Un gestionnaire dont on ignore l'issue : `next` le termine en erreur, ce
/// que Dio attend et qu'aucune requête ne vient ici recueillir.
class _Handler extends ErrorInterceptorHandler {
  _Handler() {
    future.ignore();
  }
}

ErrorInterceptorHandler _handler() => _Handler();

void main() {
  late Directory dir;
  final List<AppLog> logs = <AppLog>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('app_log_test');
  });

  tearDown(() async {
    // Une entrée WARN ou ERROR programme une écriture qui part après la fin
    // d'un test synchrone : l'attendre, sans quoi elle pose son `.tmp` dans le
    // dossier pendant qu'on le supprime (« Directory not empty »).
    for (final AppLog log in logs) {
      await log.flush();
    }
    logs.clear();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  AppLog newLog({int capacity = 200}) {
    final AppLog log = AppLog(
      capacity: capacity,
      directory: () async => dir,
      flushDelay: Duration.zero,
    );
    logs.add(log);
    return log;
  }

  group('tampon', () {
    test('garde les N dernières entrées, plus ancienne d\'abord', () {
      final AppLog log = newLog(capacity: 3);
      for (int i = 0; i < 5; i++) {
        log.info('test', 'm$i');
      }
      expect(log.entries.map((AppLogEntry e) => e.message), <String>[
        'm2',
        'm3',
        'm4',
      ]);
    });

    test('tronque le message à 1 000 caractères et la source à 50', () {
      final AppLog log = newLog();
      log.info('s' * 80, 'x' * 1500);
      final AppLogEntry e = log.entries.single;
      expect(e.message.length, kAppLogMessageMaxLength);
      expect(e.message.endsWith('…'), isTrue);
      expect(e.source.length, kAppLogSourceMaxLength);
    });

    test('retire la query string des URL citées', () {
      final AppLog log = newLog();
      log.error(
        'error',
        'Failed https://x.fr/api/auth/reset?token=secret#frag then retried',
      );
      expect(
        log.entries.single.message,
        'Failed https://x.fr/api/auth/reset then retried',
      );
    });

    test('snapshot rend les dernières entrées au format du contrat', () {
      final AppLog log = newLog();
      log.info('a', 'one');
      log.warn('b', 'two');
      log.error('c', 'three');
      final List<ClientLogEntryDto> last = log.snapshot(max: 2);
      expect(last.map((ClientLogEntryDto e) => e.message), <String>[
        'two',
        'three',
      ]);
      expect(last.first.level, 'WARN');
      expect(last.last.level, 'ERROR');
      expect(DateTime.parse(last.first.ts).isUtc, isTrue);
    });
  });

  group('persistance', () {
    test(
      'une session suivante relit le journal, avant ses propres lignes',
      () async {
        final AppLog first = newLog();
        first.info('app', 'launch');
        first.error('error', 'boom');
        await first.flush();

        final AppLog second = newLog();
        second.info('app', 'second launch');
        await second.load();
        expect(second.entries.map((AppLogEntry e) => e.message), <String>[
          'launch',
          'boom',
          'second launch',
        ]);
        expect(second.entries[1].level, AppLogLevel.error);
      },
    );

    test('une entrée WARN ou ERROR suffit à écrire le fichier', () async {
      final AppLog log = newLog();
      log.info('app', 'not yet');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(File('${dir.path}/${AppLog.fileName}').existsSync(), isFalse);

      log.warn('http', 'GET /api/x → 500');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await log.flush();
      final List<String> lines = File('${dir.path}/${AppLog.fileName}')
          .readAsLinesSync();
      expect(lines, hasLength(2));
    });

    test('la relecture reste bornée et ignore une ligne tronquée', () async {
      File('${dir.path}/${AppLog.fileName}').writeAsStringSync(
        '${List<String>.generate(10, (int i) => '{"ts":"2026-01-01T00:00:00.000Z","level":"INFO","source":"t","message":"m$i"}').join('\n')}\n{"ts":"2026-01-01',
      );
      final AppLog log = newLog(capacity: 4);
      await log.load();
      expect(log.entries.map((AppLogEntry e) => e.message), <String>[
        'm6',
        'm7',
        'm8',
        'm9',
      ]);
    });

    test('sans dossier, le journal reste en mémoire', () async {
      final AppLog log = AppLog();
      log.error('error', 'boom');
      await log.load();
      await log.flush();
      expect(log.entries, hasLength(1));
    });
  });

  group('intercepteur HTTP', () {
    DioException failure(String path, {int? status, Object? data}) =>
        DioException(
          requestOptions: RequestOptions(
            path: path,
            method: 'GET',
            baseUrl: 'https://x.fr',
          ),
          type: status == null
              ? DioExceptionType.connectionError
              : DioExceptionType.badResponse,
          response: status == null
              ? null
              : Response<dynamic>(
                  requestOptions: RequestOptions(path: path),
                  statusCode: status,
                  data: data,
                ),
        );

    test('note méthode, chemin sans query, statut et code', () {
      final AppLog log = newLog();
      ClientLogInterceptor(log).onError(
        failure(
          '/api/rides/x?token=secret',
          status: 404,
          data: <String, dynamic>{'code': 'NOT_FOUND', 'message': 'secret'},
        ),
        _handler(),
      );
      expect(log.entries.single.message, 'GET /api/rides/x → 404 NOT_FOUND');
      expect(log.entries.single.level, AppLogLevel.warn);
      expect(log.entries.single.source, 'http');
    });

    test('une requête qui n\'a pas abouti est une erreur', () {
      final AppLog log = newLog();
      ClientLogInterceptor(log).onError(failure('/api/teams'), _handler());
      expect(log.entries.single.message, 'GET /api/teams → connectionError');
      expect(log.entries.single.level, AppLogLevel.error);
    });

    test('les échecs des endpoints de rapport ne sont pas notés', () {
      final AppLog log = newLog();
      final ClientLogInterceptor interceptor = ClientLogInterceptor(log);
      interceptor.onError(failure('/api/feedback', status: 500), _handler());
      interceptor.onError(failure('/api/feedback/errors'), _handler());
      expect(log.entries, isEmpty);
    });
  });

  group('contexte', () {
    test('le chemin perd sa query string, et le slug d\'équipe se lit', () {
      expect(
        stripQuery('/equipes/gaby/sorties?token=x#y'),
        '/equipes/gaby/sorties',
      );
      expect(stripQuery('?a=1'), '/');
      expect(teamSlugOf('/equipes/gaby/sorties'), 'gaby');
      expect(teamSlugOf('/teams/gaby'), 'gaby');
      expect(teamSlugOf('/teams/discover'), isNull);
      expect(teamSlugOf('/profil'), isNull);
    });

    test('une navigation se note une fois, sans query', () {
      final AppLog log = newLog();
      final ClientContextBuilder builder = ClientContextBuilder(
        log: log,
        platform: 'ANDROID',
        locale: () => 'fr',
      );
      builder.recordNavigation('/equipes/gaby?token=x');
      builder.recordNavigation('/equipes/gaby');
      expect(log.entries.single.message, '/equipes/gaby');
      final ClientContextDto dto = builder.build();
      expect(dto.route, '/equipes/gaby');
      expect(dto.teamSlug, 'gaby');
      expect(dto.appVersion, 'unknown');
      expect(dto.locale, 'fr');
    });

    test('une DioException ne cite ni l\'URL complète ni le corps', () {
      final ClientErrorDto dto = clientErrorFrom(
        DioException(
          requestOptions: RequestOptions(
            path: '/api/x?token=secret',
            method: 'POST',
          ),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/api/x'),
            statusCode: 500,
          ),
        ),
        StackTrace.current,
      );
      expect(dto.type, 'DioException');
      expect(dto.message, 'POST /api/x → 500');
      expect(dto.stack, contains('app_log_test.dart'));
    });
  });
}
