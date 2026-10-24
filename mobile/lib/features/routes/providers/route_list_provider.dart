import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../../../core/pdl/map/pdl_map_controller.dart';
import '../../../core/preferences/user_preferences_provider.dart';
import '../data/route_repository.dart';
import '../domain/route_filters.dart';

/// Filters currently applied to a route list, **keyed by the screen's fixed
/// scope**.
///
/// La clé de famille n'est pas la portée choisie mais celle que l'écran
/// impose : `null` pour l'onglet Explorer, le slug pour la section d'une
/// équipe. La portée *choisie*, elle, vit dans `RouteFilters.teamSlug`, ce qui
/// la fait participer à la clé de liste — changer d'équipe crée un jeu de
/// résultats neuf, comme n'importe quel autre filtre.
final routeFiltersProvider = StateProvider.autoDispose
    .family<RouteFilters, String?>(
      (ref, teamSlug) => RouteFilters(teamSlug: teamSlug),
    );

/// The paginated route list for one filter set.
///
/// Auto-disposed, so abandoning a filter combination frees it, while the list
/// the user is actually reading stays alive as long as the page is mounted —
/// which is what preserves loaded pages and scroll position when they open a
/// route and come back.
final routeListProvider = StateNotifierProvider.autoDispose
    .family<RouteListNotifier, PagedListState<RouteDto>, RouteFilters>((
      ref,
      filters,
    ) {
      return RouteListNotifier(ref.watch(routeRepositoryProvider), filters);
    });

class RouteListNotifier extends PagedListNotifier<RouteDto> {
  final RouteRepository _repository;
  final RouteFilters _filters;

  RouteListNotifier(this._repository, this._filters);

  @override
  Future<PageResult<RouteDto>> fetchPage(int page) {
    return _repository.fetchRoutes(
      filters: _filters,
      page: page,
      size: pageSize,
      // Une ligne de liste n'a jamais besoin du markdown, des pièces jointes
      // ni des images au-delà de la première : `COMPACT` les laisse au
      // serveur, ce qui divise le poids d'une page par un ordre de grandeur.
      view: ListViewMode.compact,
    );
  }

  @override
  Object? itemKey(RouteDto item) => item.id;
}

/// A short preview of what the list would hold under the given filters.
///
/// Feeds the dead-end empty state: rather than claiming that dropping a filter
/// helps, it shows the routes that would actually come back.
final routePreviewProvider = FutureProvider.autoDispose
    .family<List<RouteDto>, RouteFilters>((ref, filters) async {
      final RouteRepository repository = ref.watch(routeRepositoryProvider);
      final PageResult<RouteDto> page = await repository.fetchRoutes(
        filters: filters,
        size: 3,
        view: ListViewMode.compact,
      );
      return page.items;
    });

/// Le cadrage initial de la carte, **figé au montage**.
///
/// `GET …/routes/bounds` est lu une fois, avec les filtres tels qu'ils sont à
/// l'ouverture, et n'est **jamais rejoué** sur changement de filtre (§3.1) :
/// une carte qui se recadre toute seule pendant qu'on la déplace est une carte
/// qu'on ne peut pas lire.
final routeBoundsProvider = FutureProvider.autoDispose
    .family<PdlMapBox?, RouteFilters>(
      (ref, filters) => ref.watch(routeRepositoryProvider).fetchBounds(filters),
    );

// ── Vue et densité ───────────────────────────────────────────────────────────
//
// Ni l'une ni l'autre n'est un filtre : elles ne changent pas le jeu de
// résultats, seulement son rendu. Les faire entrer dans `RouteFilters` — qui
// est la clé de famille de la liste — rejouerait tout le jeu à chaque bascule.

const String _kRouteViewKey = 'routes.view';
const String _kRouteDensityKey = 'routes.density';

/// Liste ou carte. Persistée : revenir sur l'onglet Explorer restitue la vue
/// qu'on y avait laissée.
final routeViewModeProvider =
    NotifierProvider<RouteViewModeNotifier, RouteViewMode>(
      RouteViewModeNotifier.new,
    );

class RouteViewModeNotifier extends Notifier<RouteViewMode> {
  @override
  RouteViewMode build() {
    final String? stored = ref
        .watch(sharedPreferencesProvider)
        .getString(_kRouteViewKey);
    return stored == RouteViewMode.map.name
        ? RouteViewMode.map
        : RouteViewMode.list;
  }

  Future<void> select(RouteViewMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kRouteViewKey, mode.name);
  }
}

/// Densité **choisie** par l'utilisateur, ou `null` tant qu'il n'a rien choisi.
///
/// Le nul est significatif : c'est lui qui laisse la règle automatique
/// (vignettes sous [kRouteCompactThreshold] résultats, compact au-delà)
/// s'appliquer. Un choix manuel l'écrase et survit au redémarrage.
final routeDensityProvider =
    NotifierProvider<RouteDensityNotifier, RouteListDensity?>(
      RouteDensityNotifier.new,
    );

class RouteDensityNotifier extends Notifier<RouteListDensity?> {
  @override
  RouteListDensity? build() {
    final String? stored = ref
        .watch(sharedPreferencesProvider)
        .getString(_kRouteDensityKey);
    return switch (stored) {
      'cards' => RouteListDensity.cards,
      'compact' => RouteListDensity.compact,
      _ => null,
    };
  }

  Future<void> select(RouteListDensity density) async {
    state = density;
    final SharedPreferences prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kRouteDensityKey, density.name);
  }
}

/// La densité effectivement rendue pour [total] résultats.
///
/// Le choix manuel gagne toujours ; à défaut, la règle de seuil tranche.
RouteListDensity effectiveRouteDensity(RouteListDensity? chosen, int? total) {
  if (chosen != null) return chosen;
  if (total != null && total > kRouteCompactThreshold) {
    return RouteListDensity.compact;
  }
  return RouteListDensity.cards;
}
