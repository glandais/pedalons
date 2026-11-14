import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../rides/providers/ride_editor_providers.dart';
import '../../tags/providers/team_tags_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import '../data/ad_repository.dart';
import '../domain/ad_form.dart';
import 'ad_list_provider.dart';

typedef AdKey = ({String teamSlug, String adSlug});

final adDetailProvider = FutureProvider.family<AdDto, AdKey>((
  ref,
  params,
) async {
  final repository = ref.watch(adRepositoryProvider);
  return repository.getAd(params.teamSlug, params.adSlug);
});

/// L'annonce telle que son formulaire la lit (`GET …/edit`). Auto-disposée :
/// chaque ouverture de l'éditeur relit le serveur, et la position exacte de
/// l'auteur ne reste pas en mémoire une fois l'écran fermé.
final adEditProvider = FutureProvider.autoDispose.family<AdEditDto, AdKey>(
  (Ref ref, AdKey key) =>
      ref.watch(adRepositoryProvider).getAdEdit(key.teamSlug, key.adSlug),
);

/// L'utilisateur peut-il publier une annonce dans [teamSlug] ? `null` tant
/// que « Mes équipes » n'est pas chargé et qu'il n'est pas admin de
/// plateforme : l'écran n'affiche alors ni bouton ni refus (docs/LEDGER_*.md
/// MOB-158). Tout membre le peut, module annonces actif — [canCreateTeamAds].
final canCreateAdsProvider = Provider.family<bool?, String>(
  (Ref ref, String teamSlug) =>
      teamManagePermission(ref, teamSlug, canCreateTeamAds),
);

/// **Le** point où l'app dit « une annonce vient de changer » — créée,
/// réécrite, publiée, dépubliée, renommée d'adresse, supprimée ou restaurée
/// (ledger `MOB-158`). Le pendant de `notifyRideChanged`.
///
/// Une annonce paraît dans la liste de son équipe (et le compte de la feuille
/// de prix), dans le tableau de bord (« Dernières annonces ») et dans les
/// compteurs d'usage des tags ; le détail et la vue du formulaire ne sont
/// invalidés que si [adKey] la nomme.
void notifyAdChanged(WidgetRef ref, {required String teamSlug, AdKey? adKey}) {
  if (adKey != null) {
    ref.invalidate(adDetailProvider(adKey));
    ref.invalidate(adEditProvider(adKey));
  }
  ref.invalidate(adListProvider);
  ref.invalidate(adCountProvider);
  ref.invalidate(teamDashboardProvider);
  ref.invalidate(teamTagsProvider((teamSlug: teamSlug, type: TagTarget.ad)));
}
