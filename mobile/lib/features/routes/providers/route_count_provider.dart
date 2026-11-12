import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/route_repository.dart';
import '../domain/route_filters.dart';

/// Le temps qu'on laisse à l'utilisateur avant d'aller compter.
///
/// 350 ms, la même valeur que le champ de recherche : c'est la durée au-delà
/// de laquelle un glissement de curseur devient une intention.
const Duration kRouteCountDebounce = Duration(milliseconds: 350);

/// Combien de parcours ce jeu de filtres rendrait.
///
/// Une seule famille, deux usages, et c'est le point : **le compte et la
/// liste ne peuvent pas diverger** puisqu'ils partent des mêmes
/// [RouteFilters]. (Le compteur de la liste, lui, lit le total de la page :
/// sous un filtre, il dit le total filtré seul, « 2 parcours » — règle RL8.)
///
/// * le CTA de la feuille de filtres, sur le brouillon en cours d'édition ;
/// * la règle de suggestion du « cul-de-sac », sur chaque filtre levé.
///
/// **Débounce et annulation.** Le délai est dans le provider et non dans
/// l'appelant : glisser un curseur change la clé de famille à chaque pixel,
/// et Riverpod dispose alors l'instance précédente *avant* que sa temporisation
/// n'expire — la requête HTTP ne part donc jamais. Celle qui serait déjà en vol
/// voit son résultat abandonné avec le provider qui l'attendait. C'est
/// l'annulation demandée par S21-2, obtenue sans `CancelToken` — que les
/// clients Retrofit générés n'exposent pas.
final routeCountProvider = FutureProvider.autoDispose.family<int, RouteFilters>(
  (ref, filters) async {
    await Future<void>.delayed(kRouteCountDebounce);
    // Le provider a été disposé pendant la temporisation : la valeur rendue
    // ici n'est observée par personne, mais partir compter le serait.
    if (!ref.mounted) return 0;
    return ref.watch(routeRepositoryProvider).countRoutes(filters);
  },
);

/// Le filtre à proposer de retirer dans l'état « cul-de-sac ».
///
/// La règle du §3.1, littéralement : pour chaque filtre actif, un compte avec
/// **ce seul filtre levé** ; on retient celui qui *maximise* le total, et à
/// égalité le plus récemment ajouté. Les comptes ne partent que d'ici, donc
/// seulement quand la liste est vide et que cet état est monté.
///
/// Tant qu'ils n'ont pas tous répondu, [RouteFilters.narrowestField] tient
/// lieu de réponse : un état vide qui n'offre rien pendant deux secondes est
/// pire qu'un état vide qui offre un filtre plausible tout de suite.
final routeDeadEndSuggestionProvider = Provider.autoDispose
    .family<RouteFilterField?, RouteFilters>((ref, filters) {
      final List<RouteFilterField> candidates = filters.activeFieldsNewestFirst;
      if (candidates.isEmpty) return null;

      RouteFilterField? best;
      int bestTotal = -1;
      bool complete = true;

      // `activeFieldsNewestFirst` est déjà du plus récent au plus ancien : un
      // `>` strict retient donc le plus récent à égalité, sans comparaison de
      // dates.
      for (final RouteFilterField field in candidates) {
        final AsyncValue<int> count = ref.watch(
          routeCountProvider(filters.without(field)),
        );
        final int? total = count.value;
        if (total == null) {
          complete = false;
          continue;
        }
        if (total > bestTotal) {
          bestTotal = total;
          best = field;
        }
      }

      // Un filtre dont la levée ne ramène toujours rien n'est pas une offre :
      // c'est « Tout réinitialiser » qui reste.
      if (bestTotal <= 0) {
        return complete ? null : filters.narrowestField;
      }
      return best;
    });
