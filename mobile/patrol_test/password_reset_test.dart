import 'api/account_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-account.e2e.ts` › forgotten password — the reset link works once, a
/// replayed one shows « Lien invalide », an unknown address gets the same screen and no mail, and
/// the page opened before signing in comes back after it.
void main() {
  testApp('A member resets a forgotten password from the app, lands on the link they had opened, and '
      'the replayed link is refused', ($, modules, apiClients) async {
    final backend = apiClients.backend;
    final mailpit = apiClients.mailpit;
    final owner = await backend.newUser('Reset owner');
    final rider = await backend.newUser('Reset rider');
    final team = await backend.newTeam(owner, 'Equipe reset');
    final teamSlug = team['slug'] as String;
    await backend.addMember(teamSlug, rider);
    final post = await backend.newPost(owner, teamSlug, 'Article reset');

    // A link opened signed out waits for the sign-in.
    await openApp($);
    await openLink($, Paths.post(teamSlug, post['slug'] as String));
    await modules.auth.waitUntilLoginPageIsVisible();

    await modules.auth.openForgotPassword();
    final seen = await mailpit.mailbox(rider.email);
    await modules.auth.requestPasswordReset(rider.email);
    final token = mailpit.linkTokenIn(
      await mailpit.waitForNewMail(rider.email, seen),
    );

    final resetLink = '${Paths.resetPassword()}?token=$token';
    const newPassword = 'e2e-new-password';
    await openLink($, resetLink);
    await modules.auth.setNewPassword(newPassword);

    await modules.post.waitUntilShown();
    expect(modules.post.title, post['name']);
    expect(await backend.loginStatus(rider.email, rider.password), isNot(200));
    expect(await backend.loginStatus(rider.email, newPassword), 200);

    // Signed out, the same link again: it served once, it is refused now.
    await openLink($, Paths.profile());
    await modules.profile.logOut();
    await modules.auth.waitUntilLoginPageIsVisible();
    await openLink($, resetLink);
    const replayedPassword = 'e2e-replayed-password';
    await modules.auth.setNewPassword(replayedPassword);
    await modules.auth.waitUntilResetLinkIsRefused();
    expect(await backend.loginStatus(rider.email, newPassword), 200);
    expect(
      await backend.loginStatus(rider.email, replayedPassword),
      isNot(200),
    );

    // « Demander un nouveau lien » for an unknown address: the same screen, and no mail.
    await modules.auth.requestNewResetLink();
    final unknown =
        'mobile-reset-unknown-${DateTime.now().microsecondsSinceEpoch}@e2e.test';
    await modules.auth.requestPasswordReset(unknown);
    await Future<void>.delayed(const Duration(seconds: 3));
    expect((await mailpit.mailbox(unknown)).length, 0);
  });
}
