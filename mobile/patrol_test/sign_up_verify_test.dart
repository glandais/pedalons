import 'api/account_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-account.e2e.ts` › sign up, then the verification link.
///
/// Follows `sign_up_terms_test` to the end: the app's own sign-up form, then the link read from
/// mailpit, opened as a tapped mail link opens it. The verification page shows the address and
/// asks for the password; activating signs the rider in — the only way in before the address is
/// verified.
void main() {
  testApp('A rider signs up in the app, follows the verification link from the mail, and lands signed '
      'in', ($, modules, apiClients) async {
    final backend = apiClients.backend;
    final mailpit = apiClients.mailpit;
    final email =
        'mobile-verify-${DateTime.now().microsecondsSinceEpoch}@e2e.test';
    final displayName = unique('Verifiee app');
    const password = 'e2e-verify-password';

    await openApp($);
    await modules.auth.waitUntilLoginPageIsVisible();
    await modules.auth.showRegisterForm();
    await modules.auth.fillRegisterForm(email: email, displayName: displayName);
    await modules.auth.acceptTerms();
    final seen = await mailpit.mailbox(email);
    await modules.auth.submitRegistration();
    await modules.auth.waitUntilLoginPageIsVisible();
    final token = mailpit.linkTokenIn(
      await mailpit.waitForNewMail(email, seen),
    );
    expect(await backend.loginStatus(email, password), isNot(200));

    await openLink($, '${Paths.verifyEmail()}?token=$token');
    // The link opens nothing on its own: the page shows the address and asks for the password.
    expect(await modules.auth.showsActivationFor(email), isTrue);
    expect(await backend.loginStatus(email, password), isNot(200));
    await modules.auth.activateAccount(password);
    await modules.auth.continueAfterVerification();
    await modules.navigation.waitUntilTabBarIsVisible();

    expect(
      await backend.loginStatus(email, password),
      200,
      reason: 'the address is verified: the password now signs in',
    );
  });
}
