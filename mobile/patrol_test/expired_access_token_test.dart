import 'api/account_seed.dart';
import 'common.dart';

/// MOB-38 — an access token refused with a 401 is refreshed, and the call it failed is retried.
///
/// The authentication interceptor does this on the app's own `Dio`, which a unit test cannot
/// intercept: its tests only check which paths are eligible (`refreshesOn401`). Here the app is
/// signed in, then handed an access token the server refuses — the refresh token stays valid, as
/// after a phone left open past the access token's lifetime. Two calls must go through anyway: an
/// ordinary one (the profile's summary) and one under `/api/auth/` (`logout-all`),
/// which MOB-32 used to leave failing with a 401.
void main() {
  testApp(
    'A refused access token is refreshed: the profile loads and « Déconnecter tous les appareils » reaches the server',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final user = await backend.newUser('Expired token');
      // Another device's session: only a logout-all that reached the server ends it.
      final elsewhere = await backend.login(user.email, user.password);
      final otherRefreshToken = elsewhere['refreshToken'] as String;

      await openAppSignedIn($, user);
      await modules.home.waitUntilShown();

      replaceAccessToken($, 'expired-access-token');
      await modules.navigation.goToProfile();
      await modules.profile.waitUntilShown();
      // « Sécurité » only shows its state line once `GET /api/users/me/profile-summary` has
      // answered.
      await modules.profile.waitUntilSummaryLoaded();
      expect(currentAccessToken($), isNot(equals('expired-access-token')));
      expect(currentAccessToken($), isNotNull);

      await modules.profile.openSecurity();
      replaceAccessToken($, 'expired-access-token');
      await modules.profileSettings.logOutEverywhere();
      await modules.auth.waitUntilLoginPageIsVisible();

      // `logoutAll` keeps the local session when the server refuses: the login page alone would
      // not prove the call went through, the other device's session does.
      expect(await backend.refreshStatus(otherRefreshToken), isNot(200));
    },
  );
}
