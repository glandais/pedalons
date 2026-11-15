import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

/// Le vocabulaire de tags d'une équipe pour un type de contenu (ledger
/// `MOB-39`) : ce que proposent les filtres des listes et les éditeurs.
///
/// Une liste vide est la réponse attendue pour la plupart des équipes, et
/// elle **cache** le filtre — une puce qui n'ouvre qu'une feuille vide est une
/// action sans effet.
///
/// Un échec se replie aussi sur « pas de filtre » côté écran : le filtre par
/// tag est un raffinement, pas une raison de mettre la liste en erreur.
///
/// L'app **administre** aussi ce vocabulaire depuis `MOB-169` (la décision
/// D20 du plan des tags, « affichage et filtre seulement », est rouverte) :
/// l'écran « Tags » de la gestion de l'équipe lit [teamAllTagsProvider], et
/// chaque écriture passe par `notifyTeamTagsChanged`
/// (`team_tags_change.dart`), qui relit aussi ce provider.
final teamTagsProvider = FutureProvider.autoDispose
    .family<List<TagWithUsageDto>, ({String teamSlug, TagTarget type})>((
      Ref ref,
      ({String teamSlug, TagTarget type}) key,
    ) {
      return ref
          .watch(tagsClientProvider)
          .listTeamTags(teamSlug: key.teamSlug, type: key.type);
    });

/// Les tags de [key] une fois chargés, ou une liste vide tant qu'ils ne le
/// sont pas — ou s'ils ne le seront pas. Le raccourci des barres de filtres.
List<TagWithUsageDto> teamTagsOrEmpty(
  WidgetRef ref,
  ({String teamSlug, TagTarget type}) key,
) => ref.watch(teamTagsProvider(key)).value ?? const <TagWithUsageDto>[];

/// **Tout** le vocabulaire d'une équipe, tous types confondus (`GET …/tags`
/// sans `type`) : ce que lit l'écran d'administration des tags
/// (docs/LEDGER_*.md MOB-169), comme `useTeamTagsData` du site — changer de
/// type ne coûte alors aucune requête, et chaque puce porte son compte. Cent
/// tags par type au plus (D16) gardent la liste courte.
///
/// Réservé à l'écran rendu à qui administre l'équipe : personne d'autre ne
/// l'écoute.
final teamAllTagsProvider = FutureProvider.autoDispose
    .family<List<TagWithUsageDto>, String>((Ref ref, String teamSlug) {
      return ref.watch(tagsClientProvider).listTeamTags(teamSlug: teamSlug);
    });
