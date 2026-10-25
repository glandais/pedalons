import 'api/account_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-account.e2e.ts` › « the sole admin of a team with other members is
/// stopped before confirming… » and « an admin alone in their team is told the team goes too, then
/// signed out for good ».
///
/// The app asks the server what the deletion would do to the member's teams before offering the
/// confirmation (`data_and_account_section.dart`, `_deleteAccount`): blocked, it names the teams
/// and offers nothing to confirm; allowed, the sheet names the teams that go with the account.
void main() {
  testApp('Deleting the account is blocked while sole admin of a team with members, then allowed once '
      'alone, and signs out for good', ($, modules, apiClients) async {
    final backend = apiClients.backend;
    final owner = await backend.newUser('Deleting owner');
    final member = await backend.newUser('Deleting member');
    final team = await backend.newTeam(
      owner,
      'Equipe partante',
      visibility: 'PUBLIC',
    );
    final teamSlug = team['slug'] as String;
    final teamName = team['name'] as String;
    await backend.addMember(teamSlug, member);
    expect(await backend.anonymousTeamStatus(teamSlug), 200);
    // A second session of the owner, on another device: it must die with the account.
    final otherSession =
        (await backend.login(owner.email, owner.password))['refreshToken']
            as String;
    expect(await backend.refreshStatus(otherSession), 200);

    await openAppSignedIn($, owner);
    await modules.navigation.goToProfile();
    await modules.profile.waitUntilShown();
    await modules.profile.openAccount();

    // Sole admin of a team with another member: refused before any confirmation.
    await modules.profile.deleteAccount();
    await modules.profile.waitUntilDeletionIsBlocked();
    expect(modules.profile.deletionBlockedNames(teamName), isTrue);
    expect(modules.profile.isConfirmationShown, isFalse);
    expect(await backend.status(owner, 'GET', '/api/users/me'), 200);
    expect((await backend.team(owner, teamSlug))['role'], 'ADMIN');

    // Alone in the team: the sheet says the team goes with the account.
    await backend.leaveTeam(member, teamSlug);
    await modules.profile.deleteAccount();
    await modules.profile.waitUntilConfirmationIsShown();
    expect(modules.profile.isDeletionBlocked, isFalse);
    expect(modules.profile.confirmationSays(teamName), isTrue);
    await modules.profile.confirm();
    await modules.auth.waitUntilLoginPageIsVisible();

    expect(await backend.loginStatus(owner.email, owner.password), isNot(200));
    expect(await backend.refreshStatus(otherSession), isNot(200));
    expect(await backend.anonymousTeamStatus(teamSlug), 404);

    // The login form refuses the address too.
    await modules.auth.logInWithPassword(owner.email, owner.password);
    await modules.auth.waitUntilLoginErrorIsShown();
  });
}
