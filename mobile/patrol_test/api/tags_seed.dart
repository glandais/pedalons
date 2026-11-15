import 'package:dio/dio.dart';

import 'backend_client.dart';

/// Seeding of a team's tags (ledger `MOB-39`), and reading them back once the app has
/// administered the vocabulary (ledger `MOB-169`).
extension TagsSeed on BackendClient {
  /// A tag of [teamSlug] for one kind of content ([type]: `ROUTE`, `RIDE`, `AD`…), created by a
  /// team admin as the web's tag manager does. Its `id` goes into a content's `tagIds`.
  Future<Json> newTag(
    TestUser by,
    String teamSlug, {
    required String type,
    required String label,
    String color = 'BLUE',
  }) => post(by, '/api/teams/$teamSlug/tags', {
    'type': type,
    'label': label,
    'color': color,
  });

  /// The team's vocabulary as [who] reads it (`TagWithUsageDto`, `usageCount` included) — every
  /// kind, or only [type]. The endpoint answers a bare array.
  Future<List<Json>> teamTags(
    TestUser who,
    String teamSlug, {
    String? type,
  }) async {
    final response = await http.get<List<dynamic>>(
      '/api/teams/$teamSlug/tags',
      queryParameters: {'type': ?type},
      options: Options(headers: {'Authorization': 'Bearer ${who.accessToken}'}),
    );
    return response.data!.cast<Json>();
  }

  /// The team's tag labelled [label], or null — a tag created from the app is read back by its
  /// label, its id being the server's.
  Future<Json?> tagLabelled(
    TestUser who,
    String teamSlug,
    String label,
  ) async => (await teamTags(
    who,
    teamSlug,
  )).where((tag) => tag['label'] == label).firstOrNull;

  /// The labels of the tags the route carries, as [who] reads its detail.
  Future<List<String>> routeTagLabels(
    TestUser who,
    String teamSlug,
    String routeSlug,
  ) async => [
    for (final tag
        in ((await get(who, '/api/teams/$teamSlug/routes/$routeSlug'))['tags']
                as List)
            .cast<Json>())
      tag['label'] as String,
  ];
}
