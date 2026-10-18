import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/interceptors/auth_interceptor.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/config/app_config.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';

/// Rejouer un `FormData` après un 401 (ledger `MOB-79`).
///
/// Le premier envoi **finalise** le `FormData` ; le rejouer tel quel lève
/// `StateError`, que le `catch` du rejeu prendrait pour un échec du
/// rafraîchissement : l'organisateur qui envoie un GPX avec un jeton expiré
/// serait déconnecté.
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('retry_'));
  tearDown(() => dir.deleteSync(recursive: true));

  FormData form() {
    final File file = File('${dir.path}/col.gpx')..writeAsStringSync('<gpx/>');
    return FormData()
      ..fields.add(const MapEntry<String, String>('route', '{"name":"x"}'))
      ..files.add(
        MapEntry<String, MultipartFile>(
          'gpxFile',
          MultipartFile.fromFileSync(
            file.path,
            filename: 'col.gpx',
            contentType: DioMediaType('application', 'gpx+xml'),
          ),
        ),
      );
  }

  test('un FormData finalisé est remplacé par une copie neuve', () async {
    final FormData original = form();
    // Le premier envoi : le corps est lu jusqu'au bout.
    await original.finalize().drain<void>();
    expect(original.isFinalized, isTrue);
    expect(() => original.finalize(), throwsStateError);

    final RequestOptions options = RequestOptions(
      path: '/api/teams/x/routes',
      method: 'POST',
      data: original,
    );
    final RequestOptions retry = retryableOptions(options);

    final FormData copy = retry.data as FormData;
    expect(copy, isNot(same(original)));
    expect(copy.isFinalized, isFalse);
    expect(copy.fields.single.key, 'route');
    expect(copy.fields.single.value, '{"name":"x"}');
    expect(copy.files.single.key, 'gpxFile');
    expect(copy.files.single.value.filename, 'col.gpx');
    expect(
      copy.files.single.value.contentType?.mimeType,
      'application/gpx+xml',
    );
    // Et la copie se relit en entier.
    final String body = utf8.decode(
      await copy.finalize().expand((List<int> c) => c).toList(),
    );
    expect(body, contains('name="gpxFile"'));
    expect(body, contains('<gpx/>'));
  });

  test('un corps JSON reste tel quel', () {
    final Map<String, Object?> json = <String, Object?>{'slug': 'nouveau'};
    final RequestOptions options = RequestOptions(
      path: '/api/teams/x/routes/col/slug',
      method: 'PATCH',
      data: json,
    );

    final RequestOptions retry = retryableOptions(options);

    expect(retry, same(options));
    expect(retry.data, same(json));
  });

  test('sans corps, rien ne change', () {
    final RequestOptions options = RequestOptions(path: '/api/x');
    expect(retryableOptions(options).data, isNull);
  });

  group('rejeu après rafraîchissement', () {
    late ProviderContainer container;
    late _Storage storage;
    late _Scripted api;
    late Dio dio;

    setUp(() {
      storage = _Storage();
      api = _Scripted();
      container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      container.read(accessTokenHolderProvider.notifier).state = 'ancien';
      dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
        ..httpClientAdapter = api;
      final AuthInterceptor interceptor = container.read(
        Provider<AuthInterceptor>(
          (ref) => AuthInterceptor(ref, dio, refreshAdapter: _Refresh()),
        ),
      );
      dio.interceptors.add(interceptor);
    });

    test(
      'un rejeu refusé (400 GPX) remonte tel quel, sans déconnecter',
      () async {
        api.replies = <int>[401, 400];

        await expectLater(
          dio.post<Object?>('/api/teams/x/routes', data: form()),
          throwsA(
            isA<DioException>()
                .having((e) => e.response?.statusCode, 'statut', 400)
                .having(
                  (e) => (e.response?.data as Map)['code'],
                  'code',
                  'GPX_FAILURE',
                ),
          ),
        );

        expect(api.calls, 2);
        expect(container.read(accessTokenHolderProvider), 'nouveau');
        expect(storage.deleted, isFalse);
        expect(storage.saved, 'nouveau-refresh');
      },
    );

    test('un rejeu réussi rend la réponse', () async {
      api.replies = <int>[401, 200];

      final Response<Object?> response = await dio.post<Object?>(
        '/api/teams/x/routes',
        data: form(),
      );

      expect(response.statusCode, 200);
      expect(api.calls, 2);
      expect(storage.deleted, isFalse);
    });
  });
}

class _Storage extends Fake implements SecureTokenStorage {
  bool deleted = false;
  String? saved;

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<void> saveRefreshToken(String token) async => saved = token;

  @override
  Future<void> deleteRefreshToken() async => deleted = true;
}

/// L'API : réponses scriptées, dans l'ordre.
class _Scripted implements HttpClientAdapter {
  List<int> replies = <int>[];
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Le corps est lu en entier, comme le fait un vrai envoi.
    if (requestStream != null) await requestStream.drain<void>();
    final int status = replies[calls++];
    final Object body = status == 400
        ? <String, Object?>{'code': 'GPX_FAILURE'}
        : <String, Object?>{};
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// `POST /api/auth/refresh` : toujours réussi.
class _Refresh implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'accessToken': 'nouveau',
        'refreshToken': 'nouveau-refresh',
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
