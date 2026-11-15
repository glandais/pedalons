import 'common.dart';

/// Web counterpart: `flow-ads.e2e.ts` › « ad rights » (audit P0 #4), the author's side: one
/// doesn't write to oneself, report oneself or block oneself, so the ad offers none of it. Its `⋯`
/// is « Gérer l'annonce » since ledger `MOB-158`, without « Signaler ».
void main() {
  testApp(
    'The author of an ad is offered no contact button, and a `⋯` that manages it without reporting it',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final author = await backend.newUser('Ad own author');
      final team = await backend.newTeam(author, 'Equipe mes annonces');
      final teamSlug = team['slug'] as String;
      final ad = await backend.newAd(author, teamSlug, 'Mon velo');

      await openAppSignedIn($, author);
      await openLink($, Paths.ad(teamSlug, ad['slug'] as String));
      await modules.ad.waitUntilShown();
      expect(await modules.ad.offersContact(), isFalse);
      await modules.ad.openMoreMenu();
      await modules.ad.waitUntilManageMenuIsShown();
      expect(modules.ad.manageMenuOffersReport, isFalse);
    },
  );
}
