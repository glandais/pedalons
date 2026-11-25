import 'package:flutter_test/flutter_test.dart';

import 'module.dart';

/// « Membres » (ledger `MOB-167`): the members of a team with their role, the
/// pending invitations, and what an administrator does there — invite by e-mail, change a role,
/// remove someone.
final class TeamMembersAdmin extends Module {
  TeamMembersAdmin(super.$);

  /// The screen is on screen once its search field is: only an administrator gets it.
  Future<void> waitUntilShown() async {
    await $(keys.teamAdminMembers.searchField).waitUntilVisible();
  }

  /// The refusal someone who does not administer the team reads instead of the list.
  Future<bool> showsForbidden() async {
    await $(keys.teamAdminMembers.forbidden).waitUntilExists();
    return !isShown(keys.teamAdminMembers.searchField);
  }

  // ── Members ─────────────────────────────────────────────────────────────

  /// Waits for the row of the member whose **user** id is [userId].
  Future<void> waitUntilMemberIsShown(String userId) async {
    await scrolledTo(keys.teamAdminMembers.row(userId));
  }

  bool showsMember(String userId) => isShown(keys.teamAdminMembers.row(userId));

  /// Whether the row of [userId] carries [role] on its badge, as displayed (« ORGANISATEUR »).
  bool memberShowsRole(String userId, String role) =>
      shows(keys.teamAdminMembers.row(userId), role);

  /// Waits until the row of [userId] shows [role] — the list is read again after a change.
  Future<void> waitUntilMemberShowsRole(
    String userId,
    String role, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!memberShowsRole(userId, role)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('member $userId does not show $role after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Whether the member's own row can be opened: it has no `⋯`.
  bool offersMenuFor(String userId) =>
      isShown(keys.teamAdminMembers.rowMore(userId));

  /// The row of [userId] → its sheet.
  Future<void> openMemberMenu(String userId) async {
    await (await scrolledTo(keys.teamAdminMembers.rowMore(userId))).tap();
    await $(keys.teamAdminMembers.removeAction).waitUntilVisible();
  }

  /// The row of [userId] → « Modifier le rôle » → [role] (`ADMIN`, `ORGANIZER`, `MEMBER`).
  Future<void> changeRole(String userId, String role) async {
    await openMemberMenu(userId);
    await $(keys.teamAdminMembers.changeRoleAction).tap();
    await $(keys.teamAdminMembers.roleOption(role)).waitUntilVisible();
    await $(keys.teamAdminMembers.roleOption(role)).tap();
    await waitUntilGone(keys.teamAdminMembers.roleOption(role));
  }

  /// The row of [userId] → « Retirer de l'équipe » → the confirmation; the row is gone after.
  Future<void> remove(String userId) async {
    await openMemberMenu(userId);
    await $(keys.teamAdminMembers.removeAction).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilGone(keys.teamAdminMembers.row(userId));
  }

  /// Whether the banner of a refused change shows [text] (`LAST_ADMIN`…).
  Future<bool> errorShows(String text) async {
    await $(keys.teamAdminMembers.errorBanner).waitUntilVisible();
    return shows(keys.teamAdminMembers.errorBanner, text);
  }

  // ── Invitations ─────────────────────────────────────────────────────────

  /// Whether « Inviter par e-mail » is offered — absent when the team may not add members.
  bool get offersInvite => isShown(keys.teamAdminMembers.inviteButton);

  /// Whether the invitation sheet is open — `?invite=1` opens it with the screen.
  Future<void> waitUntilInviteSheetIsShown() async {
    await $(keys.teamAdminMembers.inviteEmailField).waitUntilVisible();
  }

  /// « Inviter par e-mail » → the sheet.
  Future<void> openInviteSheet() async {
    await scrolledUpTo(keys.teamAdminMembers.inviteButton);
    await $(keys.teamAdminMembers.inviteButton).tap();
    await waitUntilInviteSheetIsShown();
  }

  /// Fills the open sheet — [email], then [role] (`MEMBER`, `ORGANIZER`, `ADMIN`) — and sends.
  /// Does not wait for the sheet to close: a refused invitation keeps it open.
  Future<void> submitInvitation(String email, {String? role}) async {
    await $(keys.teamAdminMembers.inviteEmailField).enterText(email);
    if (role != null) await $(keys.teamAdminMembers.inviteRole(role)).tap();
    await $(keys.teamAdminMembers.inviteSubmit).tap();
  }

  /// The sheet closed: the invitation was sent.
  Future<void> waitUntilInviteSheetIsGone() =>
      waitUntilGone(keys.teamAdminMembers.inviteSheet);

  /// Whether the sheet, still open, says [text] in its error banner.
  Future<bool> inviteErrorShows(String text) async {
    await $(keys.teamAdminMembers.inviteErrorBanner).waitUntilVisible();
    return shows(keys.teamAdminMembers.inviteErrorBanner, text);
  }

  /// Waits for the card of the pending invitation [invitationId].
  Future<void> waitUntilInvitationIsShown(String invitationId) async {
    await scrolledUpTo(keys.teamAdminMembers.invitation(invitationId));
  }

  bool invitationShows(String invitationId, String text) =>
      shows(keys.teamAdminMembers.invitation(invitationId), text);

  bool get showsPendingInvitations =>
      isShown(keys.teamAdminMembers.pendingSection);

  /// « Annuler l'invitation » on the card of [invitationId] → the confirmation; the card is gone
  /// after.
  Future<void> revokeInvitation(String invitationId) async {
    await scrolledUpTo(keys.teamAdminMembers.invitationRevoke(invitationId));
    await $(keys.teamAdminMembers.invitationRevoke(invitationId)).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilGone(keys.teamAdminMembers.invitation(invitationId));
  }
}
