import 'backend_client.dart';

/// Seeding and reads for the list tests: enough entries for a second page, and which entry the
/// API puts on which page — asked, never assumed from the sort.
///
/// Every list of the app pages by 20 (`kDefaultPageSize`); mirrors `frontend/e2e/pagination.e2e.ts`
/// (which seeds one page and one entry, under a team of its own).
extension ListsSeed on BackendClient {
  static const int pageSize = 20;

  /// [count] published, members-only posts named « [label] n », one minute apart.
  Future<List<Json>> newPosts(
    TestUser by,
    String teamSlug,
    String label,
    int count,
  ) async {
    final now = DateTime.now().toUtc();
    return [
      for (var i = 0; i < count; i++)
        await post(by, '/api/teams/$teamSlug/posts', {
          'name': unique('$label $i'),
          'media': markdownMedia(),
          'dateTime': wallTimeOf(now.subtract(Duration(minutes: i))),
          'visibility': 'TEAM',
          'status': 'PUBLISHED',
        }),
    ];
  }

  /// [count] published ads of [adType] named « [label] n ».
  Future<List<Json>> newAds(
    TestUser by,
    String teamSlug,
    String label,
    int count, {
    String adType = 'SALE',
  }) async => [
    for (var i = 0; i < count; i++)
      await post(by, '/api/teams/$teamSlug/classifieds', {
        'name': unique('$label $i'),
        'status': 'PUBLISHED',
        'adType': adType,
        'price': 50,
        'media': markdownMedia(),
      }),
  ];

  /// The slugs of a team list's page [page] (0-based), as the app asks for it:
  /// the « Publications » with [type] `POST`, the « Agenda » with `when`.
  Future<List<String>> teamFeedSlugs(
    TestUser who,
    String teamSlug, {
    int page = 0,
    String? type,
    String? when,
  }) async {
    final list = await get(
      who,
      '/api/teams/$teamSlug/publications',
      query: {
        'page': page,
        'size': pageSize,
        'view': 'COMPACT',
        'type': ?type,
        'when': ?when,
      },
    );
    return _slugs(list['publications']);
  }

  /// The slugs of the home feed's page [page] (every team of [who]).
  /// The home feed as the app opens it: on « Membre » for whoever has a team (`MOB-123`), so
  /// another team's public publications stay out.
  Future<List<String>> homeFeedSlugs(TestUser who, {int page = 0}) async {
    final list = await get(
      who,
      '/api/publications',
      query: {
        'page': page,
        'size': pageSize,
        'view': 'COMPACT',
        'minRole': 'MEMBER',
      },
    );
    return _slugs(list['publications']);
  }

  Future<List<String>> adSlugs(
    TestUser who,
    String teamSlug, {
    int page = 0,
  }) async {
    final list = await get(
      who,
      '/api/teams/$teamSlug/classifieds',
      query: {'page': page, 'size': pageSize},
    );
    return _slugs(list['ads']);
  }

  /// The user ids of the members list's page [page].
  Future<List<String>> memberUserIds(
    TestUser who,
    String teamSlug, {
    int page = 0,
  }) async {
    final list = await get(
      who,
      '/api/teams/$teamSlug/members',
      query: {'page': page, 'size': pageSize},
    );
    return [
      for (final member in (list['members'] as List).cast<Json>())
        (member['user'] as Json)['id'] as String,
    ];
  }

  /// The ids of the post's top-level comments on page [page].
  Future<List<String>> postCommentIdsPage(
    TestUser who,
    String teamSlug,
    String postSlug, {
    int page = 0,
  }) async {
    final list = await get(
      who,
      '/api/teams/$teamSlug/posts/$postSlug/comments',
      query: {'page': page, 'size': pageSize},
    );
    return [
      for (final comment in (list['items'] as List).cast<Json>())
        comment['id'] as String,
    ];
  }

  List<String> _slugs(Object? items) => [
    for (final item in (items as List).cast<Json>()) item['slug'] as String,
  ];
}
