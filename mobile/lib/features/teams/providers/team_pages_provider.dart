import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../presentation/pages/team_custom_page.dart' show teamPageProvider;
import 'team_providers.dart';

/// Les pages personnalisées d'une équipe telles que l'écran d'administration
/// les lit (`GET …/pages`, docs/LEDGER_*.md MOB-169) : dans l'ordre de
/// l'équipe, et — pour qui l'administre — **pages supprimées comprises**, à
/// restaurer. Trois pages au plus : la liste n'est pas paginée.
///
/// Réservé à l'écran rendu à qui administre l'équipe : personne d'autre ne
/// l'écoute. « À propos », lui, lit `TeamDetailDto.pages`.
final teamAdminPagesProvider = FutureProvider.autoDispose
    .family<List<TeamPageSummaryDto>, String>((Ref ref, String teamSlug) {
      return ref.watch(teamPagesClientProvider).listPages(teamSlug: teamSlug);
    });

/// **Le** point où l'app dit « les pages de l'équipe [teamSlug] viennent de
/// changer » — une page créée, réécrite, renommée d'adresse, supprimée,
/// restaurée, ou leur ordre modifié (docs/LEDGER_*.md MOB-169).
///
/// Sont relus :
///
/// * la liste de l'écran d'administration ([teamAdminPagesProvider]) — ses
///   lignes restent à l'écran pendant la relecture ;
/// * **la fiche de l'équipe seule** ([teamDetailProvider]) : elle porte
///   `pages[]`, que lit « À propos ». Ni « Mes équipes », ni le tableau de
///   bord, ni la découverte ne montrent une page : `notifyTeamChanged` les
///   relirait pour rien, liste des équipes vidée comprise ;
/// * le contenu des pages nommées par [pageSlugs] ([teamPageProvider]), qu'un
///   écran de lecture resté ouvert montrerait sinon tel qu'avant — après un
///   changement d'adresse, l'ancienne et la nouvelle.
///
/// Prend le **conteneur**, comme `notifyTeamChanged` : l'écriture est une
/// requête, et l'écran qui l'a lancée peut être quitté avant sa réponse.
void notifyTeamPagesChanged(
  ProviderContainer container,
  String teamSlug, {
  List<String> pageSlugs = const <String>[],
}) {
  container.invalidate(teamAdminPagesProvider(teamSlug));
  container.invalidate(teamDetailProvider(teamSlug));
  for (final String pageSlug in pageSlugs) {
    container.invalidate(
      teamPageProvider((teamSlug: teamSlug, pageSlug: pageSlug)),
    );
  }
}
