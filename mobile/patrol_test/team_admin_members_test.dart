import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `invitations.e2e.ts` (an administrator invites by e-mail, the pending list,
/// revoking) and `flow-team.e2e.ts` › members (`TeamMembersPage`: role change, removal).
///
/// In the app (ledger `MOB-167`): a team's administrator reaches « Membres » from the
/// hub, invites an address — the e-mail really leaves, read in mailpit —, sees it in the pending
/// invitations and cancels it, promotes a member to organizer and removes another. Their own row
/// has no menu. A plain member reads a refusal from the same link.
///
/// Written, not yet run (ledger `MOB-167`).
void main() {
  testApp(
    'A team administrator invites by e-mail, cancels the invitation, changes a role and removes a member',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final mailpit = apiClients.mailpit;
      final owner = await backend.newUser('Members owner');
      final promoted = await backend.newUser('Members promoted');
      final removed = await backend.newUser('Members removed');
      final team = await backend.newTeam(
        owner,
        'Equipe membres',
        addMemberAllowed: true,
      );
      final slug = team['slug'] as String;
      await backend.addMember(slug, promoted);
      await backend.addMember(slug, removed);

      await openAppSignedIn($, owner);
      await openLink($, Paths.team(slug));
      await modules.teams.waitUntilTeamIsShown();

      // The hub's « Membres » row opens the app's screen.
      await modules.teamAdmin.openFromHeader();
      await modules.teamAdmin.openMembers();
      await modules.teamMembersAdmin.waitUntilShown();
      await modules.teamMembersAdmin.waitUntilMemberIsShown(promoted.id);
      expect(modules.teamMembersAdmin.showsMember(removed.id), isTrue);
      expect(modules.teamMembersAdmin.showsPendingInvitations, isFalse);
      // One's own row has no menu: no role change, no removal, no report.
      expect(modules.teamMembersAdmin.offersMenuFor(owner.id), isFalse);

      // An address that is no account's: the invitation is sent all the same, as an organizer.
      final address =
          'mobile-invitee-${DateTime.now().microsecondsSinceEpoch}@e2e.test';
      final seen = await mailpit.mailbox(address);
      await modules.teamMembersAdmin.openInviteSheet();
      await modules.teamMembersAdmin.submitInvitation(
        address,
        role: 'ORGANIZER',
      );
      await modules.teamMembersAdmin.waitUntilInviteSheetIsGone();

      final pending = await backend.pendingInvitations(owner, slug);
      expect(pending.length, 1);
      expect(pending.single['email'], address);
      expect(pending.single['role'], 'ORGANIZER');
      final invitationId = pending.single['id'] as String;

      // The e-mail left, and names the team.
      final mail = await mailpit.waitForNewMail(address, seen);
      expect(mail, contains(team['name'] as String));

      // Nobody joined: the invitation only waits, on its card.
      expect(
        (await backend.teamMembers(owner, slug)).length,
        3,
        reason: 'an invitation enrols nobody',
      );
      await modules.teamMembersAdmin.waitUntilInvitationIsShown(invitationId);
      expect(
        modules.teamMembersAdmin.invitationShows(invitationId, address),
        isTrue,
      );
      expect(
        modules.teamMembersAdmin.invitationShows(invitationId, 'ORGANISATEUR'),
        isTrue,
      );

      // Cancelling it asks first, then the section goes with its last card.
      await modules.teamMembersAdmin.revokeInvitation(invitationId);
      expect(await backend.pendingInvitations(owner, slug), isEmpty);
      expect(modules.teamMembersAdmin.showsPendingInvitations, isFalse);

      // A member becomes an organizer: the user id travels, the list is read again.
      await modules.teamMembersAdmin.changeRole(promoted.id, 'ORGANIZER');
      await modules.teamMembersAdmin.waitUntilMemberShowsRole(
        promoted.id,
        'ORGANISATEUR',
      );
      expect(await backend.roleOf(owner, slug, promoted), 'ORGANIZER');
      expect(await backend.roleOf(owner, slug, removed), 'MEMBER');

      // Another is removed after the confirmation.
      await modules.teamMembersAdmin.waitUntilMemberIsShown(removed.id);
      await modules.teamMembersAdmin.remove(removed.id);
      expect(await backend.roleOf(owner, slug, removed), isNull);
      expect(await backend.roleOf(owner, slug, promoted), 'ORGANIZER');
      expect((await backend.team(owner, slug))['memberCount'], 2);
    },
  );

  testApp(
    'An organizer is refused the members screen, and inviting oneself is refused in the sheet',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Members gate owner');
      final organizer = await backend.newUser('Members gate organizer');
      final team = await backend.newTeam(
        owner,
        'Equipe membres fermee',
        addMemberAllowed: true,
      );
      final slug = team['slug'] as String;
      await backend.addMember(slug, organizer, role: 'ORGANIZER');

      // An organizer manages the team, but not its members: the link reads a refusal.
      await openAppSignedIn($, organizer);
      await openLink($, Paths.teamAdminMembers(slug));
      expect(await modules.teamMembersAdmin.showsForbidden(), isTrue);

      // The administrator: `?invite=1` opens the sheet with the screen; their own address is
      // refused, the sheet stays open and nothing is recorded.
      await openAppSignedIn($, owner);
      await openLink($, '${Paths.teamAdminMembers(slug)}?invite=1');
      await modules.teamMembersAdmin.waitUntilInviteSheetIsShown();
      await modules.teamMembersAdmin.submitInvitation(owner.email);
      expect(
        await modules.teamMembersAdmin.inviteErrorShows('vous inviter'),
        isTrue,
      );
      expect(await backend.pendingInvitations(owner, slug), isEmpty);
    },
  );
}
