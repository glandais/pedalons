import 'api/account_seed.dart';
import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `invitations.e2e.ts` › sign up through the link, verify, land in the team
/// (docs/LEDGER_*.md WEB-193, MOB-179).
///
/// The invitation e-mail's link, opened in the app by someone without an account: the page says
/// who invites to what before any session, « Se connecter ou créer un compte » leads through the
/// app's own sign-up, and the verification link — opened as a tapped mail link opens it — brings
/// the new account back to the invitation once activated. Joining lands on the team's page.
void main() {
  testApp('An invitation link opened without an account: sign up from it, verify, come back to it, '
      'and land in the team', ($, modules, apiClients) async {
    final backend = apiClients.backend;
    final mailpit = apiClients.mailpit;
    final owner = await backend.newUser('Invite link owner');
    final team = await backend.newTeam(
      owner,
      'Equipe lien invitation',
      addMemberAllowed: true,
    );
    final teamSlug = team['slug'] as String;
    final teamName = team['name'] as String;
    final email =
        'mobile-invited-${DateTime.now().microsecondsSinceEpoch}@e2e.test';
    const password = 'e2e-invited-password';

    final invitationSeen = await mailpit.mailbox(email);
    await backend.invite(owner, teamSlug, email);
    final invitationToken = mailpit.linkTokenIn(
      await mailpit.waitForNewMail(email, invitationSeen),
    );

    await openApp($);
    await modules.auth.waitUntilLoginPageIsVisible();
    await openLink($, '${Paths.invitation()}?token=$invitationToken');

    // Signed out, the link says who invites to what.
    await modules.teams.waitUntilInvitationPageIsShown();
    expect(modules.teams.invitationPageShows(teamName), isTrue);
    await modules.teams.signInFromInvitation();

    // The app's own sign-up, then the verification mail.
    await modules.auth.waitUntilLoginPageIsVisible();
    await modules.auth.showRegisterForm();
    await modules.auth.fillRegisterForm(
      email: email,
      displayName: unique('Invitee app'),
    );
    await modules.auth.acceptTerms();
    final verificationSeen = await mailpit.mailbox(email);
    await modules.auth.submitRegistration();
    await modules.auth.waitUntilLoginPageIsVisible();
    final verificationToken = mailpit.linkTokenIn(
      await mailpit.waitForNewMail(email, verificationSeen),
    );

    await openLink($, '${Paths.verifyEmail()}?token=$verificationToken');
    await modules.auth.activateAccount(password);
    await modules.auth.continueAfterVerification();

    // Activated: back on the invitation, signed in this time.
    await modules.teams.waitUntilInvitationPageIsShown();
    final invitee = await backend.sessionOf(email, password);
    expect(
      await backend.myInvitations(invitee),
      isNot(isEmpty),
      reason: 'signing up is not joining: the invitation still waits',
    );

    await modules.teams.joinFromInvitation();
    expect((await backend.team(invitee, teamSlug))['role'], 'MEMBER');
    expect(await backend.myInvitations(invitee), isEmpty);
  });
}
