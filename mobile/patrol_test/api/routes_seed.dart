import 'dart:convert';

import 'package:dio/dio.dart';

import 'backend_client.dart';

/// Seeding for the routes tests: a route uploaded from a GPX, and the rides and trips that use it.
///
/// Mirrors `frontend/e2e/support/routes.ts` (`newRoute`, `gpxOf`, `newTrip`) and `support/rides.ts`
/// (`newRide` with a group's `routeSlug`): same endpoints, same request shapes.
extension RoutesSeed on BackendClient {
  /// A route created from a GPX upload, as the « Nouveau parcours » form does: a multipart of the
  /// `RouteRequest` (`route`, JSON) and the track (`gpxFile`). [visibility] `TEAM` keeps it to the
  /// team's members, `PUBLIC` opens it to anyone (in a public team). [tagIds] are the team's
  /// `ROUTE` tags the route carries.
  Future<Json> newRoute(
    TestUser by,
    String teamSlug,
    String name, {
    String visibility = 'TEAM',
    String surfaceType = 'ROAD',
    List<String>? tagIds,
  }) async {
    final request = {
      'name': name,
      'media': markdownMedia(),
      'surfaceType': surfaceType,
      'visibility': visibility,
      'tagIds': ?tagIds,
    };
    final form = FormData.fromMap({
      'route': MultipartFile.fromString(
        jsonEncode(request),
        filename: 'route.json',
        contentType: DioMediaType('application', 'json'),
      ),
      'gpxFile': MultipartFile.fromString(
        gpxOf(name, eastward()),
        filename: 'trace.gpx',
        contentType: DioMediaType('application', 'gpx+xml'),
      ),
    });
    final response = await http.post<Json>(
      '/api/teams/$teamSlug/routes',
      data: form,
      options: Options(headers: {'Authorization': 'Bearer ${by.accessToken}'}),
    );
    return response.data!;
  }

  /// The route [routeSlug] of [teamSlug] as [who] reads it, or `null` once it is out of reach.
  /// An organizer still reads a deleted route (`deleted: true`); anyone else gets 403 or 404 —
  /// the pattern of `rideTemplateOrNull` (ledger `MOB-79`).
  Future<Json?> teamRouteOrNull(
    TestUser who,
    String teamSlug,
    String routeSlug,
  ) async {
    final path = '/api/teams/$teamSlug/routes/$routeSlug';
    final code = await status(who, 'GET', path);
    if (code == 403 || code == 404) return null;
    return get(who, path);
  }

  /// The route named [name] in [teamSlug], found by `GET …/routes?search=` as [who] reads the
  /// list, or `null` while the API doesn't list it (ledger `MOB-79`).
  Future<Json?> teamRouteNamed(
    TestUser who,
    String teamSlug,
    String name,
  ) async {
    final list = await get(
      who,
      '/api/teams/$teamSlug/routes',
      query: {'search': name, 'size': 20},
    );
    for (final route in (list['routes'] as List).cast<Json>()) {
      if (route['name'] == name) return route;
    }
    return null;
  }

  /// A published ride two days ahead whose one group, « Groupe A », rides [routeSlug].
  Future<Json> newRideOnRoute(
    TestUser by,
    String teamSlug,
    String label, {
    String? routeSlug,
    String visibility = 'TEAM',
  }) => post(by, '/api/teams/$teamSlug/rides', {
    'name': unique(label),
    'media': markdownMedia(),
    'dateTime': wallTimeOf(DateTime.now().add(const Duration(days: 2))),
    'status': 'PUBLISHED',
    'visibility': visibility,
    'groups': [
      {'name': 'Groupe A', 'routeSlug': ?routeSlug},
    ],
  });

  /// A published, members-only trip two days ahead, whose one stage, [stageName], rides
  /// [routeSlug].
  Future<Json> newTripOnRoute(
    TestUser by,
    String teamSlug,
    String label, {
    required String stageName,
    required String routeSlug,
  }) {
    final at = DateTime.now().toUtc().add(const Duration(days: 2));
    return post(by, '/api/teams/$teamSlug/trips', {
      'name': unique(label),
      'media': markdownMedia(),
      'dateTime': wallTimeOf(at),
      'status': 'PUBLISHED',
      'visibility': 'TEAM',
      'stages': [
        {
          'name': stageName,
          'dateTime': wallTimeOf(at),
          'routeSlug': routeSlug,
          'media': markdownMedia(),
        },
      ],
    });
  }

  /// `GET /api/routes?search=` — the routes of every team [who] may read, as the Parcours tab asks.
  Future<List<String>> platformRouteNames(TestUser who, String search) async {
    final list = await get(who, '/api/routes', query: {'search': search});
    return [
      for (final route in (list['routes'] as List).cast<Json>())
        route['name'] as String,
    ];
  }

  /// `GET …/routes/{slug}/usages` as [who]: the slugs of the rides and trips it may read.
  Future<List<String>> routeUsageSlugs(
    TestUser who,
    String teamSlug,
    String routeSlug,
  ) async {
    final usages = await get(
      who,
      '/api/teams/$teamSlug/routes/$routeSlug/usages',
    );
    return [
      for (final usage in (usages['usages'] as List).cast<Json>())
        usage['slug'] as String,
    ];
  }
}

/// Due east out of Grenoble, [count] points 50 m apart — 4 km by default, climbing gently. The
/// web suite's `eastward`.
List<(double, double, double)> eastward([int count = 81]) {
  const lat0 = 45.1885;
  const lon0 = 5.7245;
  const metresPerDegLon = 111320 * 0.7051; // cos(45.1885°)
  return [
    for (var i = 0; i < count; i++)
      (lat0, lon0 + (i * 50) / metresPerDegLon, 400 + i * 2.5),
  ];
}

String gpxOf(String name, List<(double, double, double)> points) {
  final trkpts = points
      .map(
        (p) =>
            '<trkpt lat="${p.$1}" lon="${p.$2.toStringAsFixed(7)}"><ele>${p.$3}</ele></trkpt>',
      )
      .join('\n      ');
  return '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="pedalons-e2e" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>${const HtmlEscape().convert(name)}</name>
    <trkseg>
      $trkpts
    </trkseg>
  </trk>
</gpx>
''';
}
