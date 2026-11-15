import 'backend_client.dart';

/// Seeding for teams, comments, posts and notifications beyond what [BackendClient] carries:
/// invitations, team pages, replies, reading a notification.
///
/// Mirrors `frontend/e2e/support/` (invitations, pages, comments): same endpoints, same bodies.
extension TeamsContentSeed on BackendClient {
  // ── Teams ───────────────────────────────────────────────────────────────

  /// The teams [who] belongs to (`TeamDetailDto`, `role` included) — what a team created from the
  /// app is read back from, its slug being the server's.
  Future<List<Json>> myTeams(TestUser who) async =>
      ((await get(who, '/api/teams', query: {'minRole': 'MEMBER'}))['teams']
              as List)
          .cast<Json>();

  /// Lets the team's administrators change its visibility — a platform attribute, set as the
  /// platform admin (`PATCH /api/admin/teams/{id}/attributes`), the others left as they are. A
  /// team is born without it (ledger `MOB-166`).
  Future<void> allowVisibilityEdit(Json team) async {
    final admin = await this.admin();
    final path = '/api/admin/teams/${team['id']}';
    final current = await get(admin, path);
    await patch(admin, '$path/attributes', {
      'visibilityEditable': true,
      'joinable': current['joinable'],
      'addMemberAllowed': current['addMemberAllowed'],
      'enableRoutePlanner': current['enableRoutePlanner'],
      'publicContentAllowed': current['publicContentAllowed'],
    });
  }

  // ── Invitations ─────────────────────────────────────────────────────────

  /// `POST /api/teams/{slug}/invitations` as [inviter], a team administrator. The team must allow
  /// adding members (`newTeam(addMemberAllowed: true)`), or the backend answers 403.
  Future<Json> invite(
    TestUser inviter,
    String teamSlug,
    String email, {
    String role = 'MEMBER',
  }) => post(inviter, '/api/teams/$teamSlug/invitations', {
    'email': email,
    'role': role,
  });

  /// The team's pending invitations, as [admin] — a team administrator — reads them
  /// (`TeamInvitationDto`).
  Future<List<Json>> pendingInvitations(
    TestUser admin,
    String teamSlug,
  ) async =>
      ((await get(
                admin,
                '/api/teams/$teamSlug/invitations',
                query: {'status': 'PENDING'},
              ))['invitations']
              as List)
          .cast<Json>();

  /// The team's members as [admin] reads them (`MemberDto`: `user.id`, `role`), first page.
  Future<List<Json>> teamMembers(TestUser admin, String teamSlug) async =>
      ((await get(
                admin,
                '/api/teams/$teamSlug/members',
                query: {'size': 100},
              ))['members']
              as List)
          .cast<Json>();

  /// The role of [member] in the team as [admin] reads it, or null when they are not a member.
  Future<String?> roleOf(
    TestUser admin,
    String teamSlug,
    TestUser member,
  ) async {
    for (final Json m in await teamMembers(admin, teamSlug)) {
      if ((m['user'] as Json)['id'] == member.id) return m['role'] as String?;
    }
    return null;
  }

  /// The invitations waiting for [who], newest first (`MyInvitationDto`).
  Future<List<Json>> myInvitations(TestUser who) async =>
      ((await get(who, '/api/users/me/invitations'))['invitations'] as List)
          .cast<Json>();

  // ── Notifications ───────────────────────────────────────────────────────

  Future<void> markRead(TestUser who, String notificationId) =>
      post(who, '/api/notifications/$notificationId/read');

  // ── Team pages ──────────────────────────────────────────────────────────

  /// A free page of the team, [visibility] `TEAM` (members only) or `PUBLIC`, whose body reads
  /// [markdown]. Returns the `TeamPageDto`, `slug` included.
  Future<Json> newTeamPage(
    TestUser by,
    String teamSlug,
    String title, {
    String visibility = 'TEAM',
    String markdown = 'Contenu de la page',
  }) => post(by, '/api/teams/$teamSlug/pages', {
    'title': title,
    'media': markdownMedia(markdown),
    'visibility': visibility,
  });

  Future<int> deleteTeamPage(TestUser by, String teamSlug, String pageSlug) =>
      status(by, 'DELETE', '/api/teams/$teamSlug/pages/$pageSlug');

  /// `GET` one team page as [who]: the HTTP status, 404 when it's none of their business.
  Future<int> teamPageStatus(TestUser who, String teamSlug, String pageSlug) =>
      status(who, 'GET', '/api/teams/$teamSlug/pages/$pageSlug');

  // ── Comments ────────────────────────────────────────────────────────────

  /// The top-level comments of the post as [who] reads them (`CommentDto`, replies embedded).
  Future<List<Json>> postComments(
    TestUser who,
    String teamSlug,
    String postSlug,
  ) async =>
      ((await get(
                who,
                '/api/teams/$teamSlug/posts/$postSlug/comments',
              ))['items']
              as List)
          .cast<Json>();

  /// The replies to [parentId], through `?parentId=` — what « Voir les réponses » asks for.
  Future<List<Json>> postCommentsOf(
    TestUser who,
    String teamSlug,
    String postSlug,
    String parentId,
  ) async =>
      ((await get(
                who,
                '/api/teams/$teamSlug/posts/$postSlug/comments',
                query: {'parentId': parentId, 'size': 100},
              ))['items']
              as List)
          .cast<Json>();
}
