import 'dart:io';

import 'package:dio/dio.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';
import 'mailpit_client.dart';

/// An account created for a test, verified, with its first session.
final class TestUser {
  const TestUser({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    required this.accessToken,
    required this.refreshToken,
  });

  final String id;
  final String email;
  final String password;
  final String displayName;

  /// Lives 15 minutes — longer than any test.
  final String accessToken;
  final String refreshToken;

  factory TestUser._fromAuth(Map<String, dynamic> auth, String password) {
    final user = auth['user'] as Map<String, dynamic>;
    return TestUser(
      id: user['id'] as String,
      email: user['email'] as String,
      password: password,
      displayName: user['displayName'] as String,
      accessToken: auth['accessToken'] as String,
      refreshToken: auth['refreshToken'] as String,
    );
  }
}

/// A JSON object from the API, read by key: the suite doesn't need the generated DTOs.
typedef Json = Map<String, dynamic>;

/// Seeds data through the REST API, the same endpoints the app uses — the backend has no
/// test-only backdoor. Each test creates what it needs under a unique name: the e2e database is
/// shared with the web suite and never reset between runs.
///
/// Mirrors `frontend/e2e/support/` (data.ts, rides.ts, posts.ts, …): same endpoints, same
/// defaults, so a scenario reads the same on both suites.
final class BackendClient {
  BackendClient(this._mailpit);

  final MailpitClient _mailpit;
  final Dio _dio = Dio(BaseOptions(baseUrl: E2eConfig.apiBaseUrl));

  static const String _password = 'e2e-password';

  // ── Accounts ────────────────────────────────────────────────────────────

  /// Signs up as the app does — register, then follow the verification link from the mail and
  /// choose the password there (sign-up itself takes none: SEC-24).
  Future<TestUser> newUser(String label) async {
    final email = '${_uniqueTag(label)}@e2e.test';
    final seen = await _mailpit.mailbox(email);
    await _dio.post<void>(
      '/api/auth/register',
      data: {'email': email, 'displayName': label, 'acceptTerms': true},
    );
    final token = _mailpit.linkTokenIn(
      await _mailpit.waitForNewMail(email, seen),
    );
    final response = await _dio.post<Json>(
      '/api/auth/verify-email',
      data: {'token': token, 'password': _password},
    );
    return TestUser._fromAuth(response.data!, _password);
  }

  TestUser? _admin;

  /// The platform admin the stack bootstraps (`PEDALONS_BOOTSTRAP_ADMIN_EMAIL`): the only one who
  /// may add members to a team born without `addMemberAllowed`, open a team to the public, or
  /// make it joinable.
  ///
  /// Its login is an OTP, rate-limited to 3 per 5 minutes per address — and each test is a fresh
  /// launch of the app. So its refresh token is kept in the app's temporary directory, which lives
  /// as long as the app stays installed (one `patrol test` run), and refreshed rather than
  /// replaced. A refresh rotates it (SEC-27): the one written back is the one the refresh returned,
  /// as the old one revokes the session once its grace is over.
  Future<TestUser> admin() async => _admin ??= await _adminSession();

  Future<TestUser> _adminSession() async {
    final saved = File('${Directory.systemTemp.path}/e2e-admin-refresh-token');
    if (saved.existsSync()) {
      final refreshed = await _refresh(saved.readAsStringSync().trim());
      if (refreshed != null) {
        saved.writeAsStringSync(refreshed.refreshToken);
        return refreshed;
      }
    }
    final email = E2eConfig.adminEmail;
    final seen = await _mailpit.mailbox(email);
    await _dio.post<void>('/api/auth/otp', data: {'email': email});
    final code = _mailpit.otpCodeIn(await _mailpit.waitForNewMail(email, seen));
    final response = await _dio.post<Json>(
      '/api/auth/otp/verify',
      data: {'email': email, 'code': code},
    );
    final admin = TestUser._fromAuth(response.data!, '');
    saved.writeAsStringSync(admin.refreshToken);
    return admin;
  }

  Future<TestUser?> _refresh(String refreshToken) async {
    final response = await _dio.post<Json>(
      '/api/auth/refresh',
      options: Options(
        headers: {'X-Refresh-Token': refreshToken},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode != 200) return null;
    // The rotated token; absent when [refreshToken] was presented again within its grace, which
    // then stays the one to use.
    return TestUser._fromAuth({
      ...response.data!,
      'refreshToken': response.data!['refreshToken'] ?? refreshToken,
    }, '');
  }

  // ── Teams ───────────────────────────────────────────────────────────────

  /// A team owned by [owner] (its ADMIN). `POST /api/teams` always creates a members-only team:
  /// any other [visibility], and the admin-only [joinable] / [addMemberAllowed] attributes, are
  /// applied afterwards as the platform admin — as `newTeam` does in the web suite.
  Future<Json> newTeam(
    TestUser owner,
    String label, {
    String visibility = 'TEAM',
    bool? joinable,
    bool? addMemberAllowed,
  }) async {
    final request = _teamRequest(unique(label));
    var team = await post(owner, '/api/teams', request);
    if (visibility != 'TEAM') {
      team = await put(await admin(), '/api/teams/${team['slug']}', {
        ...request,
        'visibility': visibility,
      });
    }
    if (joinable != null || addMemberAllowed != null) {
      final admin = await this.admin();
      final path = '/api/admin/teams/${team['id']}';
      final current = await get(admin, path);
      await patch(admin, '$path/attributes', {
        'visibilityEditable': current['visibilityEditable'],
        'joinable': joinable ?? current['joinable'],
        'addMemberAllowed': addMemberAllowed ?? current['addMemberAllowed'],
        'enableRoutePlanner': current['enableRoutePlanner'],
      });
    }
    return team;
  }

  Json _teamRequest(String name) => {
    'name': name,
    'visibility': 'TEAM',
    'media': markdownMedia(),
    'enableTrips': true,
    'enableAds': true,
    'enablePosts': true,
    'enableRides': true,
    'enableRoutes': true,
    'enableMemberDirectory': true,
  };

  /// The team as [who] reads it — its `role` is the caller's own role in the team.
  Future<Json> team(TestUser who, String slug) => get(who, '/api/teams/$slug');

  /// Adds [member] to the team, as the platform admin (who does not become a member by it).
  Future<void> addMember(
    String teamSlug,
    TestUser member, {
    String role = 'MEMBER',
  }) async {
    await post(await admin(), '/api/teams/$teamSlug/members', {
      'userId': member.id,
      'role': role,
    });
  }

  Future<void> leaveTeam(TestUser who, String teamSlug) =>
      post(who, '/api/teams/$teamSlug/members/leave');

  /// PATCH `{entity}/slug` as [who], what the web editor sends: the backend then keeps a redirect
  /// from the old slug. [apiPath] is the entity's resource (`/api/teams/{slug}`, …).
  Future<String> renameSlug(TestUser who, String apiPath, String label) async {
    final slug = unique(label)
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-');
    final renamed = await patch(who, '$apiPath/slug', {'slug': slug});
    return renamed['slug'] as String;
  }

  // ── Rides ───────────────────────────────────────────────────────────────

  /// A published, members-only ride two days ahead, with [groups] (one « Groupe A » by default).
  /// A group is `{'name': …}`, plus `'leaderId'` for a designated leader.
  Future<Json> newRide(
    TestUser by,
    String teamSlug,
    String label, {
    List<Json>? groups,
  }) => post(by, '/api/teams/$teamSlug/rides', {
    'name': unique(label),
    'media': markdownMedia(),
    'dateTime': wallTimeOf(DateTime.now().add(const Duration(days: 2))),
    'status': 'PUBLISHED',
    'visibility': 'TEAM',
    'groups':
        groups ??
        [
          {'name': 'Groupe A'},
        ],
  });

  Future<Json> ride(TestUser who, String teamSlug, String rideSlug) =>
      get(who, '/api/teams/$teamSlug/rides/$rideSlug');

  /// The ids of the ride's groups [who] is registered in, per the API.
  Future<List<String>> registeredGroupIds(
    TestUser who,
    String teamSlug,
    String rideSlug,
  ) async {
    final ride = await this.ride(who, teamSlug, rideSlug);
    return [
      for (final group in (ride['groups'] as List).cast<Json>())
        if (group['registered'] == true) group['id'] as String,
    ];
  }

  // ── Posts and comments ──────────────────────────────────────────────────

  /// A published, members-only post dated now.
  Future<Json> newPost(TestUser by, String teamSlug, String label) =>
      post(by, '/api/teams/$teamSlug/posts', {
        'name': unique(label),
        'media': markdownMedia(),
        'dateTime': wallTimeOf(DateTime.now()),
        'visibility': 'TEAM',
        'status': 'PUBLISHED',
      });

  Future<Json> commentOnPost(
    TestUser by,
    String teamSlug,
    String postSlug,
    String content,
  ) => post(by, '/api/teams/$teamSlug/posts/$postSlug/comments', {
    'content': content,
  });

  /// The post as [who] reads it, or null when the API answers 404 (hidden, deleted, unknown).
  Future<Json?> findPost(TestUser who, String teamSlug, String postSlug) =>
      getOrNull(who, '/api/teams/$teamSlug/posts/$postSlug');

  // ── Ads ─────────────────────────────────────────────────────────────────

  /// A published sale ad.
  Future<Json> newAd(TestUser by, String teamSlug, String label) =>
      post(by, '/api/teams/$teamSlug/classifieds', {
        'name': unique(label),
        'status': 'PUBLISHED',
        'adType': 'SALE',
        'price': 50,
        'media': markdownMedia(),
      });

  /// DELETE the ad as [who]: the HTTP status, whatever it is.
  Future<int> deleteAdStatus(TestUser who, String teamSlug, String adSlug) =>
      status(who, 'DELETE', '/api/teams/$teamSlug/classifieds/$adSlug');

  // ── Moderation ──────────────────────────────────────────────────────────

  Future<void> report(
    TestUser who,
    String teamSlug,
    String targetType,
    String targetId,
  ) => post(who, '/api/reports', {
    'teamSlug': teamSlug,
    'targetType': targetType,
    'targetId': targetId,
    'reason': 'SPAM',
  });

  /// The item of the team's open queue about [targetId], as [moderator]; null when there is none.
  Future<Json?> queueItem(
    TestUser moderator,
    String teamSlug,
    String targetId,
  ) async {
    final queue = await get(
      moderator,
      '/api/teams/$teamSlug/reports',
      query: {'status': 'OPEN'},
    );
    return (queue['items'] as List).cast<Json>().where((item) {
      return item['targetId'] == targetId;
    }).firstOrNull;
  }

  Future<List<String>> blockedIds(TestUser who) async {
    final blocked = await get(who, '/api/users/me/blocks');
    return [
      for (final user in (blocked['users'] as List).cast<Json>())
        user['id'] as String,
    ];
  }

  Future<List<String>> postCommentIds(
    TestUser who,
    String teamSlug,
    String postSlug,
  ) async {
    final comments = await get(
      who,
      '/api/teams/$teamSlug/posts/$postSlug/comments',
    );
    return [
      for (final comment in (comments['items'] as List).cast<Json>())
        comment['id'] as String,
    ];
  }

  // ── Notifications ───────────────────────────────────────────────────────

  Future<int> unreadCount(TestUser who) async =>
      (await get(who, '/api/notifications/unread-count'))['count'] as int;

  Future<List<Json>> notifications(TestUser who) async {
    final page = await get(
      who,
      '/api/notifications',
      query: {'size': 100, 'unreadOnly': false},
    );
    return (page['items'] as List).cast<Json>();
  }

  /// The notification of [type] about [subjectSlug] in [who]'s inbox, or null.
  Future<Json?> notificationAbout(
    TestUser who,
    String type,
    String subjectSlug,
  ) async =>
      (await notifications(who))
          .where((n) => n['type'] == type && n['subjectSlug'] == subjectSlug)
          .firstOrNull;

  /// Whether [who] receives [type] on [channel], per the API; null when the server offers no such
  /// cell.
  Future<bool?> notificationCellEnabled(
    TestUser who,
    String type,
    String channel,
  ) async {
    final preferences = await get(who, '/api/notifications/preferences');
    return (preferences['preferences'] as List)
            .cast<Json>()
            .where((p) => p['type'] == type && p['channel'] == channel)
            .firstOrNull?['enabled']
        as bool?;
  }

  /// Whether [who] muted the team, per the API; null when the team isn't among theirs.
  Future<bool?> isMuted(TestUser who, String teamSlug) async {
    final preferences = await get(who, '/api/notifications/preferences');
    return (preferences['teams'] as List)
            .cast<Json>()
            .where((t) => t['teamSlug'] == teamSlug)
            .firstOrNull?['muted']
        as bool?;
  }

  // ── Device pairing (RFC 8628) ───────────────────────────────────────────

  /// What a Garmin or Karoo app asks for first: `deviceCode`, and the `userCode` it shows.
  Future<Json> startDeviceFlow(String clientId) async => (await _dio.post<Json>(
    '/api/device/oauth/device',
    data: {'clientId': clientId},
  )).data!;

  /// One poll of `/token` as the device: the tokens once the rider authorized it, else the error
  /// code the backend answers (`AUTHORIZATION_PENDING`, …) under `code`.
  Future<Json> pollDeviceToken(String deviceCode) async {
    final response = await _dio.post<Json>(
      '/api/device/oauth/token',
      data: {
        'grantType': 'urn:ietf:params:oauth:grant-type:device_code',
        'deviceCode': deviceCode,
      },
      options: Options(validateStatus: (_) => true),
    );
    return response.data ?? const {};
  }

  /// `GET /api/users/me` with a device's access token: whose account it was paired with.
  Future<Json> me(String accessToken) async => (await _dio.get<Json>(
    '/api/users/me',
    options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
  )).data!;

  // ── HTTP ────────────────────────────────────────────────────────────────
  //
  // Public so that a feature's seeding can live in an extension in a file of
  // its own (`api/<feature>_seed.dart`) rather than all in this one.

  /// The raw client, for an anonymous call (no session) or a status to inspect.
  Dio get http => _dio;

  Options _as(TestUser who) =>
      Options(headers: {'Authorization': 'Bearer ${who.accessToken}'});

  Future<Json> get(TestUser who, String path, {Json? query}) async =>
      (await _dio.get<Json>(
        path,
        queryParameters: query,
        options: _as(who),
      )).data!;

  Future<Json?> getOrNull(TestUser who, String path) async {
    final response = await _dio.get<Json>(
      path,
      options: _as(who)
          .copyWith(validateStatus: (status) => status == 200 || status == 404),
    );
    return response.statusCode == 404 ? null : response.data;
  }

  Future<Json> post(TestUser who, String path, [Object? data]) async =>
      (await _dio.post<Json>(path, data: data, options: _as(who))).data ??
      const {};

  Future<Json> put(TestUser who, String path, Object data) async =>
      (await _dio.put<Json>(path, data: data, options: _as(who))).data!;

  Future<Json> patch(TestUser who, String path, Object data) async =>
      (await _dio.patch<Json>(path, data: data, options: _as(who))).data ??
      const {};

  Future<int> status(TestUser who, String method, String path) async =>
      (await _dio.request<void>(
        path,
        options: _as(who).copyWith(method: method, validateStatus: (_) => true),
      )).statusCode!;

  String _uniqueTag(String label) {
    final slug = label.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
    final short = slug.length > 30 ? slug.substring(0, 30) : slug;
    return 'mobile-$short-${DateTime.now().microsecondsSinceEpoch}';
  }
}

/// The `media` of a request body: [markdown], and no picture nor attachment.
/// [instant] as a wall time in [zone] — the team's, Paris unless a test chose another —
/// `2026-10-11T08:00:00`: what a request body carries since contract 11.0.0, whose
/// `EventDateTime` refuses an instant with `Z` or an offset (docs/LEDGER_*.md API-60). A date
/// read back from a DTO goes through here with that entity's `timezone`.
String wallTimeOf(Object instant, [String? zone]) {
  if (tz.timeZoneDatabase.locations.isEmpty) tz_data.initializeTimeZones();
  final DateTime at = instant is DateTime
      ? instant
      : DateTime.parse(instant as String);
  final tz.TZDateTime wall = tz.TZDateTime.from(
    at,
    tz.getLocation(zone ?? 'Europe/Paris'),
  );
  String two(int n) => n.toString().padLeft(2, '0');
  return '${wall.year.toString().padLeft(4, '0')}-${two(wall.month)}-${two(wall.day)}'
      'T${two(wall.hour)}:${two(wall.minute)}:${two(wall.second)}';
}

Json markdownMedia([String markdown = '']) => {
  'markdown': markdown,
  'assets': {'images': <Object>[], 'attachments': <Object>[]},
};

/// [label] made unique to this run — the database is never reset between runs.
String unique(String label) =>
    '$label ${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
