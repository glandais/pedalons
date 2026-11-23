import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/geo/location_service.dart';
import 'package:pedalons/core/geo/polyline_index.dart';
import 'package:pedalons/features/routes/data/gpx_file_source.dart';
import 'package:pedalons/features/routes/data/planner_bridge.dart';
import 'package:pedalons/features/routes/data/planner_load.dart';
import 'package:pedalons/features/routes/data/planner_web_view.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';
import 'package:pedalons/features/routes/domain/planner_quota.dart';
import 'package:pedalons/features/routes/domain/planner_result.dart';

import 'route_fixtures.dart';

/// Le pont du planificateur embarqué (ledger `MOB-170`) : ce que l'app envoie
/// pour la page, et seulement cela.
class _Web implements PlannerWebView {
  final List<({String method, Object? argument})> calls =
      <({String method, Object? argument})>[];
  bool disposed = false;

  List<Object?> of(String method) => <Object?>[
    for (final ({String method, Object? argument}) c in calls)
      if (c.method == method) c.argument,
  ];

  @override
  Future<void> call(String method, Object? argument) async {
    calls.add((method: method, argument: jsonDecode(jsonEncode(argument))));
  }

  @override
  void setBackgroundColor(Color color) {}

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() => disposed = true;
}

/// Ce que le serveur répond, requête par requête. [hold] : la réponse attend
/// (une requête que la page annule).
class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];
  int status = 200;
  Object body = <String, Object?>{};
  Map<String, List<String>> headers = <String, List<String>>{};
  bool fail = false;
  Completer<void>? hold;
  bool cancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    unawaited(cancelFuture?.then((_) => cancelled = true));
    if (hold != null) await hold!.future;
    if (fail) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'réseau coupé',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Picker implements GpxFilePicker {
  _Picker(this.files);

  final List<GpxFile?> files;
  int calls = 0;

  @override
  Future<GpxFile?> pick() async {
    final int i = calls++;
    return i < files.length ? files[i] : null;
  }
}

class _Location extends LocationService {
  _Location(this.position);

  final LngLat? position;

  @override
  Future<LngLat?> coarsePosition({
    Duration timeLimit = const Duration(seconds: 10),
  }) async => position;
}

void main() {
  late _Web web;
  late _Adapter adapter;
  late _Picker picker;
  late Directory dir;
  int loads = 0;

  setUp(() {
    web = _Web();
    adapter = _Adapter();
    picker = _Picker(<GpxFile?>[]);
    loads = 0;
    dir = Directory.systemTemp.createTempSync('planner_bridge_');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  GpxFile write(String name, String content) {
    final File f = File('${dir.path}/$name')..writeAsStringSync(content);
    return GpxFile(path: f.path, name: name, size: f.lengthSync());
  }

  PlannerBridge bridge({
    LngLat? position,
    Future<PlannerLoad> Function()? load,
    void Function(PlannerResult)? onDone,
    void Function(PlannerQuotaRefusal)? onQuotaRefused,
  }) {
    final PlannerBridge b = PlannerBridge(
      dio: Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
      picker: () => picker,
      location: _Location(position),
      webViewFactory: ({required void Function(String raw) onMessage}) => web,
      load:
          load ??
          () async {
            loads++;
            return const PlannerLoad(<String, dynamic>{'teamSlug': 'x'});
          },
      onDone: onDone,
      onQuotaRefused: onQuotaRefused,
    );
    addTearDown(b.dispose);
    return b;
  }

  Future<void> send(PlannerBridge b, Map<String, dynamic> message) =>
      b.handleMessage(jsonEncode(message));

  Map<String, dynamic> response(int index) =>
      web.of('response')[index]! as Map<String, dynamic>;

  group('liste fermée des chemins', () {
    test('les six appels du planificateur, et rien d\'autre', () {
      expect(plannerRequestAllowed('POST', '/api/router'), isTrue);
      expect(plannerRequestAllowed('POST', '/api/router/elevation'), isTrue);
      expect(plannerRequestAllowed('POST', '/api/router/import-gpx'), isTrue);
      expect(
        plannerRequestAllowed('GET', '/api/geocode/search?q=annecy%20lac'),
        isTrue,
      );
      expect(plannerRequestAllowed('GET', '/api/geocode/place?id=42'), isTrue);
      expect(plannerRequestAllowed('GET', '/api/router/engines'), isTrue);
      expect(
        plannerRequestAllowed(
          'GET',
          '/api/router/engines?teamSlug=les-mollets',
        ),
        isTrue,
      );

      for (final (String method, String path) in <(String, String)>[
        ('GET', '/api/router'),
        ('POST', '/api/router?x=1'),
        ('POST', '/api/router/'),
        ('POST', '/api/router/elevation/../../users/me'),
        ('POST', '/api/teams/x/routes'),
        ('PUT', '/api/router'),
        ('DELETE', '/api/teams/x/routes/col'),
        ('GET', '/api/users/me'),
        ('GET', '/api/geocode/search'),
        ('POST', '/api/router/engines'),
        ('GET', '/api/router/engines/'),
        ('GET', '/api/router/engines?x=1'),
        ('GET', '/api/router/engines?teamSlug=a&x=1'),
        ('GET', 'https://evil.test/api/router/engines'),
        ('GET', '/api/geocode/reverse?lat=1'),
        ('GET', '/api/geocode/search/../../users/me?q=1'),
        ('POST', '/api/geocode/search?q=annecy'),
        ('GET', 'https://evil.test/api/geocode/search?q=1'),
        ('GET', '//evil.test/api/geocode/search?q=1'),
        ('POST', 'https://evil.test/api/router'),
      ]) {
        expect(
          plannerRequestAllowed(method, path),
          isFalse,
          reason: '$method $path',
        );
      }
      expect(plannerRequestAllowed(null, '/api/router'), isFalse);
      expect(plannerRequestAllowed('POST', 42), isFalse);
    });

    test('un chemin refusé répond 0 sans rien envoyer', () async {
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{
        'type': 'request',
        'id': '1',
        'method': 'GET',
        'path': '/api/users/me',
      });

      expect(adapter.requests, isEmpty);
      expect(response(0), <String, dynamic>{'id': '1', 'status': 0});
    });
  });

  group('requêtes', () {
    test('un tronçon : POST JSON, la réponse revient décodée', () async {
      adapter.body = <String, Object?>{'dist': 1234.5};
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{
        'type': 'request',
        'id': '7',
        'method': 'POST',
        'path': '/api/router',
        'body': <String, dynamic>{'teamSlug': 'x', 'profile': 'FASTBIKE'},
      });

      final RequestOptions sent = adapter.requests.single;
      expect(sent.method, 'POST');
      expect(sent.uri.toString(), 'https://api.test/api/router');
      expect(sent.data, <String, dynamic>{
        'teamSlug': 'x',
        'profile': 'FASTBIKE',
      });
      expect(response(0), <String, dynamic>{
        'id': '7',
        'status': 200,
        'body': <String, dynamic>{'dist': 1234.5},
      });
    });

    test('la recherche de lieux garde sa chaîne de requête', () async {
      adapter.body = <Object?>[];
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{
        'type': 'request',
        'id': '2',
        'method': 'GET',
        'path': '/api/geocode/search?q=col%20de%20la%20croix',
      });

      expect(
        adapter.requests.single.uri.toString(),
        'https://api.test/api/geocode/search?q=col%20de%20la%20croix',
      );
      expect(response(0)['status'], 200);
      expect(response(0)['body'], isEmpty);
    });

    test('un refus du serveur : statut, corps et Retry-After', () async {
      adapter
        ..status = 429
        ..body = <String, Object?>{'code': 'RATE_LIMITED'}
        ..headers = <String, List<String>>{
          'retry-after': <String>['30'],
        };
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{
        'type': 'request',
        'id': '3',
        'method': 'POST',
        'path': '/api/router',
        'body': <String, dynamic>{},
      });

      expect(response(0), <String, dynamic>{
        'id': '3',
        'status': 429,
        'body': <String, dynamic>{'code': 'RATE_LIMITED'},
        'retryAfter': 30,
      });
    });

    test('aucune réponse (réseau coupé) : statut 0', () async {
      adapter.fail = true;
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{
        'type': 'request',
        'id': '4',
        'method': 'POST',
        'path': '/api/router/elevation',
        'body': <String, dynamic>{},
      });

      expect(response(0), <String, dynamic>{'id': '4', 'status': 0});
    });

    test('`cancel` annule la requête, et rien ne répond', () async {
      adapter.hold = Completer<void>();
      final PlannerBridge b = bridge();
      final Future<void> pending = send(b, <String, dynamic>{
        'type': 'request',
        'id': '5',
        'method': 'POST',
        'path': '/api/router',
        'body': <String, dynamic>{},
      });
      await pumpEventQueue();
      expect(adapter.requests, hasLength(1));

      await send(b, <String, dynamic>{'type': 'cancel', 'id': '5'});
      await pending;
      await pumpEventQueue();

      expect(adapter.cancelled, isTrue);
      expect(web.of('response'), isEmpty);
      // Une annulation qui arrive après coup n'a rien à annuler.
      await send(b, <String, dynamic>{'type': 'cancel', 'id': '5'});
      adapter.hold!.complete();
    });

    test('quitter le formulaire annule ce qui est en vol', () async {
      adapter.hold = Completer<void>();
      final PlannerBridge b = bridge();
      final Future<void> pending = send(b, <String, dynamic>{
        'type': 'request',
        'id': '6',
        'method': 'POST',
        'path': '/api/router',
        'body': <String, dynamic>{},
      });
      await pumpEventQueue();

      b.dispose();
      await pending;

      expect(adapter.cancelled, isTrue);
      expect(web.disposed, isTrue);
      expect(web.of('response'), isEmpty);
      adapter.hold!.complete();
    });

    test(
      'import : le multipart décrit en base64 repart en `gpxFile`',
      () async {
        adapter.body = <String, Object?>{'name': 'Col'};
        final PlannerBridge b = bridge();
        await send(b, <String, dynamic>{
          'type': 'request',
          'id': '8',
          'method': 'POST',
          'path': '/api/router/import-gpx',
          'body': <String, dynamic>{
            'multipart': <String, dynamic>{
              'fields': <String, dynamic>{'teamSlug': 'n-peloton'},
              'file': <String, dynamic>{
                'name': 'col.gpx',
                'base64': base64Encode(utf8.encode('<gpx/>')),
                'contentType': 'application/gpx+xml',
              },
            },
          },
        });

        final RequestOptions sent = adapter.requests.single;
        expect(sent.contentType, startsWith('multipart/form-data'));
        final FormData form = sent.data as FormData;
        expect(
          <String, String>{
            for (final MapEntry<String, String> f in form.fields)
              f.key: f.value,
          },
          <String, String>{'teamSlug': 'n-peloton'},
        );
        final MapEntry<String, MultipartFile> file = form.files.single;
        expect(file.key, 'gpxFile');
        expect(file.value.filename, 'col.gpx');
        expect(file.value.contentType?.mimeType, 'application/gpx+xml');
        expect(file.value.length, 6);
        expect(response(0)['status'], 200);
      },
    );

    test('un base64 invalide ne part pas : statut 0', () async {
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{
        'type': 'request',
        'id': '9',
        'method': 'POST',
        'path': '/api/router/import-gpx',
        'body': <String, dynamic>{
          'multipart': <String, dynamic>{
            'fields': <String, dynamic>{},
            'file': <String, dynamic>{'name': 'col.gpx', 'base64': '%%%'},
          },
        },
      });

      expect(adapter.requests, isEmpty);
      expect(response(0), <String, dynamic>{'id': '9', 'status': 0});
    });
  });

  group('load', () {
    test('part à `ready`, une fois, sans `testCommands`', () async {
      final PlannerBridge b = bridge();
      expect(b.loaded.value, isFalse);
      await send(b, <String, dynamic>{'type': 'ready'});

      expect(loads, 1);
      expect(web.of('load'), <Object?>[
        <String, dynamic>{'teamSlug': 'x'},
      ]);
      expect(b.loaded.value, isTrue);
    });

    test('une préparation en échec se réessaie', () async {
      bool failing = true;
      final PlannerBridge b = bridge(
        load: () async {
          if (failing) throw StateError('config');
          return const PlannerLoad(<String, dynamic>{
            'teamSlug': 'x',
          }, stateReadFailed: true);
        },
      );
      await send(b, <String, dynamic>{'type': 'ready'});
      expect(b.loadError.value, isA<StateError>());
      expect(web.of('load'), isEmpty);

      failing = false;
      await b.retryLoad();
      expect(b.loadError.value, isNull);
      expect(web.of('load'), hasLength(1));
      expect(b.stateReadFailed.value, isTrue);
    });
  });

  group('fichier et position', () {
    test(
      '`pickGpx` : le fichier est contrôlé, gardé, et ses octets rendus',
      () async {
        final GpxFile file = write('col.gpx', fixtureGpx());
        picker = _Picker(<GpxFile?>[file]);
        final PlannerBridge b = bridge();
        await send(b, <String, dynamic>{'type': 'pickGpx'});

        final Map<String, dynamic> sent =
            web.of('gpx').single! as Map<String, dynamic>;
        expect(sent['name'], 'col.gpx');
        expect(
          utf8.decode(base64Decode(sent['base64'] as String)),
          fixtureGpx(),
        );
        final PlannerResult result = PlannerResult.fromMessage(
          <String, dynamic>{
            'payload': <String, dynamic>{'file': true, 'fileId': sent['id']},
            'stats': <String, dynamic>{},
          },
        );
        expect(b.fileFor(result), file);
      },
    );

    test('sans `fileId`, le dernier fichier choisi', () async {
      final GpxFile first = write('un.gpx', fixtureGpx());
      final GpxFile second = write('deux.gpx', fixtureGpx());
      picker = _Picker(<GpxFile?>[first, second]);
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{'type': 'pickGpx'});
      await send(b, <String, dynamic>{'type': 'pickGpx'});

      expect(
        b.fileFor(
          PlannerResult.fromMessage(<String, dynamic>{
            'payload': <String, dynamic>{'file': true},
            'stats': <String, dynamic>{},
          }),
        ),
        second,
      );
    });

    test('un sélecteur quitté répond `null`', () async {
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{'type': 'pickGpx'});

      expect(web.of('gpx'), <Object?>[null]);
    });

    test('un fichier qui n\'est pas un GPX est refusé, et dit', () async {
      picker = _Picker(<GpxFile?>[write('notes.txt', 'pas un gpx')]);
      final PlannerBridge b = bridge();
      GpxRefused? refused;
      b.onGpxRefused = (GpxRefused r) => refused = r;
      await send(b, <String, dynamic>{'type': 'pickGpx'});

      expect(web.of('gpx'), <Object?>[null]);
      expect(refused?.fileName, 'notes.txt');
      expect(refused?.refusal, GpxRefusal.notGpx);
    });

    test('`locate` : la position approximative, ou `null`', () async {
      final PlannerBridge here = bridge(position: const LngLat(6.1, 45.9));
      await send(here, <String, dynamic>{'type': 'locate'});
      expect(web.of('position'), <Object?>[
        <String, dynamic>{'lng': 6.1, 'lat': 45.9},
      ]);

      web.calls.clear();
      final PlannerBridge nowhere = bridge();
      await send(nowhere, <String, dynamic>{'type': 'locate'});
      expect(web.of('position'), <Object?>[null]);
    });
  });

  group('état de la page', () {
    test('`busy` et `dirty` se lisent', () async {
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{'type': 'busy', 'busy': true});
      await send(b, <String, dynamic>{'type': 'dirty', 'dirty': true});
      expect(b.busy.value, isTrue);
      expect(b.dirty.value, isTrue);
      await send(b, <String, dynamic>{'type': 'busy', 'busy': false});
      expect(b.busy.value, isFalse);
    });

    test('`done` rend le résultat et ferme l\'écran', () async {
      PlannerResult? result;
      int left = 0;
      final PlannerBridge b = bridge(onDone: (PlannerResult r) => result = r);
      b.onLeave = () {
        left++;
        b.screenLeft();
      };
      await send(b, <String, dynamic>{
        'type': 'done',
        'payload': <String, dynamic>{'plannerState': fixturePlannerStateJson},
        'stats': <String, dynamic>{
          'distance': 18000,
          'ascend': 240.5,
          'pointCount': 2,
          'line': '_sqytA_sdpH_pR_pR',
        },
        'dirty': true,
        'nameSuggestion': ' Tour du lac ',
      });

      expect(left, 1);
      expect(
        result!.plannerState,
        PlannerState.fromJson(fixturePlannerStateJson),
      );
      expect(result!.points, isNull);
      expect(result!.hasTrack, isTrue);
      expect(result!.nameSuggestion, 'Tour du lac');
      expect(result!.stats.distance, 18000);
      expect(result!.stats.ascend, 240.5);
      expect(result!.stats.pointCount, 2);
      expect(
        result!.stats.line.map((LngLat p) => <double>[p.lng, p.lat]),
        <List<double>>[
          <double>[5, 45],
          <double>[5.01, 45.01],
        ],
      );
      // Quitté par « Terminer » : rien en suspens.
      expect(b.unvalidated.value, isFalse);
    });

    test('quitté sans « Terminer » après des retouches : en suspens', () async {
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{'type': 'dirty', 'dirty': true});
      // Le retour du système : la page n'en sait rien.
      b.screenLeft();
      expect(b.unvalidated.value, isTrue);

      // Rouvert, puis « Terminer » : repris.
      b.onLeave = b.screenLeft;
      await send(b, <String, dynamic>{
        'type': 'done',
        'payload': <String, dynamic>{},
        'stats': <String, dynamic>{},
        'dirty': true,
      });
      expect(b.unvalidated.value, isFalse);
    });

    test(
      'rouvert après « Terminer » et quitté sans retouche : rien en suspens',
      () async {
        final PlannerBridge b = bridge();
        b.onLeave = b.screenLeft;
        await send(b, <String, dynamic>{
          'type': 'dirty',
          'dirty': true,
          'pending': true,
        });
        await send(b, <String, dynamic>{
          'type': 'done',
          'payload': <String, dynamic>{},
          'stats': <String, dynamic>{},
          'dirty': true,
        });
        // Rouvert : la page garde ses retouches d'avant, déjà reprises.
        await send(b, <String, dynamic>{
          'type': 'dirty',
          'dirty': true,
          'pending': false,
        });
        // Le retour du système, sans rien toucher (MOB-170).
        b.screenLeft();
        expect(b.unvalidated.value, isFalse);
        expect(b.dirty.value, isTrue);

        // Une retouche après le « Terminer », puis le retour : en suspens.
        await send(b, <String, dynamic>{
          'type': 'dirty',
          'dirty': true,
          'pending': true,
        });
        b.screenLeft();
        expect(b.unvalidated.value, isTrue);
      },
    );

    test('une page sans `pending` : `dirty` en tient lieu', () async {
      final PlannerBridge b = bridge();
      await send(b, <String, dynamic>{'type': 'dirty', 'dirty': true});
      expect(b.pending.value, isTrue);
      b.screenLeft();
      expect(b.unvalidated.value, isTrue);
    });

    test('quitté sans rien avoir touché : rien en suspens', () async {
      final PlannerBridge b = bridge();
      int left = 0;
      b.onLeave = () {
        left++;
        b.screenLeft();
      };
      await send(b, <String, dynamic>{'type': 'close', 'dirty': false});
      expect(left, 1);
      expect(b.unvalidated.value, isFalse);
    });

    test('`quotaRefused` : les détails du refus', () async {
      PlannerQuotaRefusal? refusal;
      final PlannerBridge b = bridge(
        onQuotaRefused: (PlannerQuotaRefusal r) => refusal = r,
      );
      await send(b, <String, dynamic>{
        'type': 'quotaRefused',
        'scope': 'TEAM',
        'limit': 20,
        'current': 20,
        'resetsOn': '2026-12-01',
        'teamName': 'N-Peloton',
      });

      expect(refusal!.team, isTrue);
      expect(refusal!.limit, 20);
      expect(refusal!.resetsOn, '2026-12-01');
      expect(refusal!.teamName, 'N-Peloton');
    });

    test('un message illisible ou inconnu ne casse rien', () async {
      final PlannerBridge b = bridge();
      await b.handleMessage('pas du json');
      await send(b, <String, dynamic>{'type': 'inconnu'});
      await send(b, <String, dynamic>{'type': 'error', 'message': 'boum'});
      await send(b, <String, dynamic>{'type': 'done', 'payload': 'faux'});

      expect(web.calls, isEmpty);
    });
  });

  group('`load` tiré des données de l\'app', () {
    test(
      'un style de notre API devient son document, un tiers reste une adresse',
      () async {
        adapter.body = <String, Object?>{'version': 8, 'layers': <Object?>[]};
        final Dio dio = Dio()..httpClientAdapter = adapter;
        final List<Map<String, dynamic>> styles = await plannerMapStyles(
          const <MapStyleDto>[
            MapStyleDto(
              id: 'osm',
              label: 'OSM',
              group: 'Raster',
              url: 'https://api.test/api/map/styles/osm.json',
              darkVariant: 'https://api.test/api/map/styles/osm-dark.json',
            ),
            MapStyleDto(
              id: 'route',
              label: 'Route',
              group: 'Vectoriel',
              url: 'https://cdn.test/route.json',
              darkVariant: 'https://cdn.test/route-dark.json',
            ),
          ],
          dio: dio,
          apiBaseUrl: 'https://api.test',
        );

        expect(styles[0], <String, dynamic>{
          'id': 'osm',
          'label': 'OSM',
          'group': 'Raster',
          'style': <String, dynamic>{'version': 8, 'layers': <dynamic>[]},
          'darkStyle': <String, dynamic>{'version': 8, 'layers': <dynamic>[]},
        });
        expect(styles[1], <String, dynamic>{
          'id': 'route',
          'label': 'Route',
          'group': 'Vectoriel',
          'url': 'https://cdn.test/route.json',
          'darkVariant': 'https://cdn.test/route-dark.json',
        });
        expect(
          adapter.requests.map((RequestOptions r) => r.uri.toString()).toSet(),
          <String>{
            'https://api.test/api/map/styles/osm.json',
            'https://api.test/api/map/styles/osm-dark.json',
          },
        );
      },
    );

    test(
      'un document illisible retire le fond plutôt que de laisser son adresse',
      () async {
        adapter.fail = true;
        final List<Map<String, dynamic>> styles = await plannerMapStyles(
          const <MapStyleDto>[
            MapStyleDto(
              id: 'osm',
              label: 'OSM',
              group: 'Raster',
              url: '/api/map/styles/osm.json',
            ),
          ],
          dio: Dio()..httpClientAdapter = adapter,
          apiBaseUrl: 'https://api.test',
        );

        expect(styles.single, <String, dynamic>{
          'id': 'osm',
          'label': 'OSM',
          'group': 'Raster',
        });
      },
    );
  });
}
