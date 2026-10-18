import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';

/// L'écriture d'un parcours sur le fil (ledger `MOB-79`).
///
/// **La forme du multipart est celle du site** (`routes.ts` :
/// `formData.append('route', JSON.stringify(request))`, partie sans type, puis
/// `gpxFile`), et le serveur la lit avec `@RestForm("route") @PartType(JSON)`.
/// Le client généré l'émet ainsi aujourd'hui ; ce test la fige, pour qu'une
/// régénération qui la changerait casse un test et non la production.
class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];
  Object body = <String, Object?>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const MediaDto _media = MediaDto(
  markdown: 'Un beau col.',
  assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
);

RouteDto _route({String slug = 'col', bool deleted = false}) => RouteDto(
  id: 'r1',
  slug: slug,
  team: const TeamPublicationDto(
    id: 't1',
    slug: 'x',
    name: 'X',
    visibility: 'PUBLIC',
  ),
  name: 'Col',
  media: _media,
  distance: 1000,
  elevationGain: 10,
  elevationLoss: 10,
  surfaceType: 'ROAD',
  visibility: 'PUBLIC',
  createdAt: '2026-01-01T10:00:00Z',
  deleted: deleted,
  tags: const <TagDto>[],
);

RouteDetailDto _detail({String slug = 'col', bool deleted = false}) =>
    RouteDetailDto(
      id: 'r1',
      slug: slug,
      team: const TeamPublicationDto(
        id: 't1',
        slug: 'x',
        name: 'X',
        visibility: 'PUBLIC',
      ),
      name: 'Col',
      media: _media,
      distance: 1000,
      elevationGain: 10,
      elevationLoss: 10,
      surfaceType: 'ROAD',
      visibility: 'PUBLIC',
      createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
      createdAt: '2026-01-01T10:00:00Z',
      updatedAt: '2026-01-01T10:00:00Z',
      tracks: const <TrackDto>[],
      waypoints: const <WaypointDto>[],
      deleted: deleted,
      tags: const <TagDto>[],
    );

void main() {
  late _Adapter adapter;
  late RouteRepository repo;
  late Directory dir;
  late GpxFile gpx;

  const RouteRequest request = RouteRequest(
    name: 'Boucle du Vercors',
    media: _media,
    surfaceType: 'GRAVEL',
    visibility: 'PUBLIC',
    tagIds: <String>['a'],
  );

  setUp(() {
    adapter = _Adapter();
    final Dio dio = Dio()..httpClientAdapter = adapter;
    repo = RouteRepository(RoutesClient(dio));
    dir = Directory.systemTemp.createTempSync('route_write_');
    final File file = File('${dir.path}/col-test.gpx')
      ..writeAsStringSync('<gpx/>');
    gpx = GpxFile(path: file.path, name: 'col-test.gpx', size: 6);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Map<String, String> fields(FormData form) => <String, String>{
    for (final MapEntry<String, String> f in form.fields) f.key: f.value,
  };

  test(
    'créer : POST multipart, route en JSON, gpxFile en application/gpx+xml',
    () async {
      adapter.body = _route(slug: 'boucle-du-vercors').toJson();

      final RouteDto created = await repo.createRoute('x', request, gpx: gpx);

      expect(created.slug, 'boucle-du-vercors');
      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/teams/x/routes');
      expect(sent.contentType, startsWith('multipart/form-data'));
      final FormData form = sent.data as FormData;
      // Le champ `route` : la requête, en JSON.
      expect(form.fields.map((MapEntry<String, String> f) => f.key), <String>[
        'route',
      ]);
      final Map<String, dynamic> route =
          jsonDecode(fields(form)['route']!) as Map<String, dynamic>;
      expect(route, jsonDecode(jsonEncode(request.toJson())));
      expect(route['name'], 'Boucle du Vercors');
      expect(route['tagIds'], <String>['a']);
      // Le fichier, sous son nom d'origine.
      final MapEntry<String, MultipartFile> file = form.files.single;
      expect(file.key, 'gpxFile');
      expect(file.value.filename, 'col-test.gpx');
      expect(file.value.contentType?.mimeType, 'application/gpx+xml');
      expect(file.value.length, 6);
    },
  );

  test('modifier avec un GPX : PUT multipart, les deux parties', () async {
    adapter.body = _route().toJson();

    await repo.updateRoute('x', 'col', request, gpx: gpx);

    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'PUT');
    expect(sent.path, '/api/teams/x/routes/col');
    final FormData form = sent.data as FormData;
    expect(fields(form).keys, <String>['route']);
    expect(form.files.single.key, 'gpxFile');
  });

  test('modifier sans GPX : aucune partie fichier, le tracé reste', () async {
    adapter.body = _route().toJson();

    await repo.updateRoute('x', 'col', request);

    final FormData form = adapter.requests.single.data as FormData;
    expect(form.files, isEmpty);
    final Map<String, dynamic> route =
        jsonDecode(fields(form)['route']!) as Map<String, dynamic>;
    expect(route['name'], 'Boucle du Vercors');
  });

  test("changer l'adresse : PATCH …/slug avec le nouveau slug", () async {
    adapter.body = _detail(slug: 'nouveau').toJson();

    final RouteDetailDto updated = await repo.changeSlug('x', 'col', 'nouveau');

    expect(updated.slug, 'nouveau');
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'PATCH');
    expect(sent.path, '/api/teams/x/routes/col/slug');
    expect(sent.data, <String, dynamic>{'slug': 'nouveau'});
  });

  test('supprimer : DELETE du parcours', () async {
    await repo.deleteRoute('x', 'col');

    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'DELETE');
    expect(sent.path, '/api/teams/x/routes/col');
  });

  test('restaurer : POST …/undelete, rend le parcours', () async {
    adapter.body = _detail().toJson();

    final RouteDetailDto restored = await repo.undeleteRoute('x', 'col');

    expect(restored.deleted, isFalse);
    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'POST');
    expect(sent.path, '/api/teams/x/routes/col/undelete');
  });
}
