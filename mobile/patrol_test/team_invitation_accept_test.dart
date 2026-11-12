import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `invitations.e2e.ts` › the invitee accepts on « Mes équipes », and
/// `flow-notifications.e2e.ts` › an entry opens its subject. On mobile the `TEAM_INVITATION` entry
/// goes to the Teams tab, whose pending-invitations card holds the « Accepter » button.
void main() {
  testApp(
    'A team invitation reaches the invitee’s inbox, opens « Mes équipes », and is accepted there',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Invite owner');
      final invitee = await backend.newUser('Invite invitee');
      final team = await backend.newTeam(
        owner,
        'Equipe invitante',
        addMemberAllowed: true,
      );
      final teamSlug = team['slug'] as String;
      await backend.invite(owner, teamSlug, invitee.email);

      final notification = await eventually(
        () => backend.notificationAbout(invitee, 'TEAM_INVITATION', teamSlug),
        until: (Json? n) => n != null,
        description: 'the TEAM_INVITATION notification',
      );
      final id = notification!['id'] as String;

      await openAppSignedIn($, invitee);
      expect(await modules.notifications.waitForBellBadge(), '1');
      await modules.notifications.openInboxFromBell();
      await modules.notifications.waitUntilEntryIsShown(id);
      expect(
        modules.notifications.entryShows(id, team['name'] as String),
        isTrue,
      );

      await modules.notifications.openEntry(id);
      await modules.teams.waitUntilInvitationIsShown(teamSlug);
      expect(
        modules.teams.pendingInvitationsShow(team['name'] as String),
        isTrue,
      );
      expect(modules.teams.showsMyTeam(teamSlug), isFalse);

      await modules.teams.acceptInvitation(teamSlug);
      expect(modules.teams.showsPendingInvitations, isFalse);
      expect((await backend.team(invitee, teamSlug))['role'], 'MEMBER');
      expect(await backend.myInvitations(invitee), isEmpty);
      expect(modules.teams.myTeamShowsRole(teamSlug, 'Membre'), isTrue);

      await modules.teams.openMyTeam(teamSlug);
      expect(modules.teams.offersLeave, isTrue);
      expect(modules.teams.offersJoin, isFalse);
    },
  );
}
