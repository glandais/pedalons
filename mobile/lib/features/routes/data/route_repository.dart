import 'package:dio/dio.dart' show DioMediaType, MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../../../core/pdl/map/pdl_map_controller.dart';
import '../domain/gpx_check.dart';
import '../domain/route_filters.dart';

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepository(ref.watch(routesClientProvider));
});

class RouteRepository {
  final RoutesClient _routesClient;

  RouteRepository(this._routesClient);

  /// One page of routes, filtered and sorted.
  ///
  /// La portée est dans [filters] : `teamSlug` nul interroge toutes les
  /// équipes visibles, sinon la liste est celle de cette équipe.
  Future<PageResult<RouteDto>> fetchRoutes({
    required RouteFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
    ListViewMode? view,
  }) async {
    final String? search = _search(filters);
    final String? teamSlug = filters.teamSlug;
    final response = teamSlug == null
        ? await _routesClient.listAllRoutes(
            page: page,
            size: size,
            hilliness: filters.hilliness,
            maxDistance: filters.maxDistance,
            maxElevationGain: filters.maxElevationGain,
            minDistance: filters.minDistance,
            minElevationGain: filters.minElevationGain,
            minRole: filters.minRole,
            nearLat: filters.hasProximity ? filters.nearLat : null,
            nearLon: filters.hasProximity ? filters.nearLon : null,
            nearRadius: filters.hasProximity
                ? filters.effectiveNearRadius
                : null,
            nearType: filters.hasProximity ? filters.nearType : null,
            search: search,
            sortBy: filters.sortBy,
            sortDir: filters.sortDir,
            surfaceType: filters.surfaceType,
            view: view,
            windDirection: filters.windDirection,
          )
        : await _routesClient.listRoutes(
            teamSlug: teamSlug,
            tags: _tags(filters),
            page: page,
            size: size,
            hilliness: filters.hilliness,
            maxDistance: filters.maxDistance,
            maxElevationGain: filters.maxElevationGain,
            minDistance: filters.minDistance,
            minElevationGain: filters.minElevationGain,
            nearLat: filters.hasProximity ? filters.nearLat : null,
            nearLon: filters.hasProximity ? filters.nearLon : null,
            nearRadius: filters.hasProximity
                ? filters.effectiveNearRadius
                : null,
            nearType: filters.hasProximity ? filters.nearType : null,
            search: search,
            sortBy: filters.sortBy,
            sortDir: filters.sortDir,
            surfaceType: filters.surfaceType,
            view: view,
            windDirection: filters.windDirection,
          );

    return PageResult(items: response.routes, total: response.total);
  }

  /// Number of routes matching [filters], without fetching them.
  ///
  /// Passe par `…/routes/count` et non par une page de taille 1 : le serveur
  /// ne lit alors **aucun** parcours, et le compte ne peut pas diverger de la
  /// liste puisqu'il accepte exactement les mêmes filtres.
  Future<int> countRoutes(RouteFilters filters) async {
    final String? search = _search(filters);
    final String? teamSlug = filters.teamSlug;
    final CountResponse response = teamSlug == null
        ? await _routesClient.countAllRoutes(
            hilliness: filters.hilliness,
            maxDistance: filters.maxDistance,
            maxElevationGain: filters.maxElevationGain,
            minDistance: filters.minDistance,
            minElevationGain: filters.minElevationGain,
            minRole: filters.minRole,
            nearLat: filters.hasProximity ? filters.nearLat : null,
            nearLon: filters.hasProximity ? filters.nearLon : null,
            nearRadius: filters.hasProximity
                ? filters.effectiveNearRadius
                : null,
            nearType: filters.hasProximity ? filters.nearType : null,
            search: search,
            surfaceType: filters.surfaceType,
            windDirection: filters.windDirection,
          )
        : await _routesClient.countRoutes(
            teamSlug: teamSlug,
            tags: _tags(filters),
            hilliness: filters.hilliness,
            maxDistance: filters.maxDistance,
            maxElevationGain: filters.maxElevationGain,
            minDistance: filters.minDistance,
            minElevationGain: filters.minElevationGain,
            nearLat: filters.hasProximity ? filters.nearLat : null,
            nearLon: filters.hasProximity ? filters.nearLon : null,
            nearRadius: filters.hasProximity
                ? filters.effectiveNearRadius
                : null,
            nearType: filters.hasProximity ? filters.nearType : null,
            search: search,
            surfaceType: filters.surfaceType,
            windDirection: filters.windDirection,
          );
    return response.total;
  }

  /// La boîte englobant les parcours de [filters], pour cadrer la carte
  /// **avant** son premier rendu. `null` quand aucun parcours ne correspond.
  Future<PdlMapBox?> fetchBounds(RouteFilters filters) async {
    final String? search = _search(filters);
    final String? teamSlug = filters.teamSlug;
    final RouteBoundsResponse response = teamSlug == null
        ? await _routesClient.getAllRoutesBounds(
            hilliness: filters.hilliness,
            maxDistance: filters.maxDistance,
            maxElevationGain: filters.maxElevationGain,
            minDistance: filters.minDistance,
            minElevationGain: filters.minElevationGain,
            minRole: filters.minRole,
            nearLat: filters.hasProximity ? filters.nearLat : null,
            nearLon: filters.hasProximity ? filters.nearLon : null,
            nearRadius: filters.hasProximity
                ? filters.effectiveNearRadius
                : null,
            nearType: filters.hasProximity ? filters.nearType : null,
            search: search,
            surfaceType: filters.surfaceType,
            windDirection: filters.windDirection,
          )
        : await _routesClient.getRoutesBounds(
            teamSlug: teamSlug,
            tags: _tags(filters),
            hilliness: filters.hilliness,
            maxDistance: filters.maxDistance,
            maxElevationGain: filters.maxElevationGain,
            minDistance: filters.minDistance,
            minElevationGain: filters.minElevationGain,
            nearLat: filters.hasProximity ? filters.nearLat : null,
            nearLon: filters.hasProximity ? filters.nearLon : null,
            nearRadius: filters.hasProximity
                ? filters.effectiveNearRadius
                : null,
            nearType: filters.hasProximity ? filters.nearType : null,
            search: search,
            surfaceType: filters.surfaceType,
            windDirection: filters.windDirection,
          );

    final BoundsDto? bounds = response.bounds;
    if (bounds == null) return null;
    return PdlMapBox(
      minLon: bounds.minLon,
      minLat: bounds.minLat,
      maxLon: bounds.maxLon,
      maxLat: bounds.maxLat,
    );
  }

  /// Le détail d'un parcours, géométrie stockée telle quelle.
  ///
  /// Il n'y a plus de négociation de finesse : l'API servait `simplify` et
  /// `points`, mesure faite ils ne servaient à rien. Les points stockés sont
  /// déjà rééchantillonnés puis filtrés Douglas-Peucker à l'import, soit ~90 m
  /// entre deux sommets et ~65 Ko par parcours médian — la fiche demandait
  /// `simplify: 5 / points: 3000`, ce qui ne retirait rien. La passe de
  /// simplification en lecture, elle, était purement 2D : elle rabotait
  /// l'altitude que ces mêmes coordonnées transportent.
  Future<RouteDetailDto> getRouteDetail(String teamSlug, String routeSlug) {
    return _routesClient.getRoute(teamSlug: teamSlug, routeSlug: routeSlug);
  }

  /// Le détail de plusieurs parcours en **un seul appel**, plus l'emprise
  /// combinée des tracés renvoyés.
  ///
  /// Remplace un ancien pattern de N appels à [getRouteDetail] (un par slug) :
  /// les écrans qui affichent plusieurs parcours à la fois — les tracés d'une
  /// sortie, la carte globale d'un voyage — n'ont plus qu'une requête à
  /// attendre. Les slugs inconnus ou illisibles par l'appelant sont
  /// **silencieusement absents** de `routes` plutôt que de faire échouer tout
  /// le lot ; c'est à l'appelant de repérer les slugs demandés qui manquent à
  /// la réponse s'il veut le signaler.
  ///
  /// Chaque ligne est ce que rendrait [getRouteDetail] pour ce slug. Passer
  /// `geometry: false` renvoie les métadonnées seules — nom, distances, liens
  /// d'asset — avec un `tracks` vide et pas d'`extent` : c'est pour les écrans
  /// qui nomment des parcours sans les dessiner.
  Future<RoutesBulkResponse> getRoutesBulk(
    String teamSlug,
    List<String> slugs, {
    bool geometry = true,
  }) {
    if (slugs.isEmpty) {
      return Future<RoutesBulkResponse>.value(
        RoutesBulkResponse(routes: const <RouteDetailDto>[], extent: null),
      );
    }
    return _routesClient.getRoutesBulk(
      teamSlug: teamSlug,
      slug: slugs,
      geometry: geometry,
    );
  }

  // ── Écriture (docs/LEDGER_*.md MOB-79) ─────────────────────────────────

  /// Crée un parcours de [teamSlug] depuis le fichier [gpx].
  ///
  /// **La forme sur le fil est celle du site** : la requête en champ `route`
  /// (JSON), le fichier en partie `gpxFile` (`application/gpx+xml`). Le client
  /// généré l'émet ainsi, et un test (`route_repository_write_test`) la fige
  /// pour qu'une régénération qui la changerait casse un test et non la
  /// production. Le serveur calcule distance, dénivelé, carte et vignettes ;
  /// il refuse un fichier illisible (`GPX_FAILURE`, `GPX_EMPTY`…).
  Future<RouteDto> createRoute(
    String teamSlug,
    RouteRequest request, {
    required GpxFile gpx,
  }) {
    return _routesClient.createRoute(
      teamSlug: teamSlug,
      route: request,
      gpxFile: _gpxPart(gpx),
    );
  }

  /// Réécrit le parcours [routeSlug]. Le serveur veut la requête **entière**.
  /// Avec [gpx], le nouveau fichier remplace tout le tracé ; sans, aucune
  /// partie fichier ne part et le tracé reste.
  Future<RouteDto> updateRoute(
    String teamSlug,
    String routeSlug,
    RouteRequest request, {
    GpxFile? gpx,
  }) {
    return _routesClient.updateRoute(
      teamSlug: teamSlug,
      routeSlug: routeSlug,
      route: request,
      gpxFile: gpx == null ? null : _gpxPart(gpx),
    );
  }

  /// Change l'adresse du parcours ; le détail rendu porte le nouveau slug.
  Future<RouteDetailDto> changeSlug(
    String teamSlug,
    String routeSlug,
    String slug,
  ) {
    return _routesClient.changeRouteSlug(
      teamSlug: teamSlug,
      routeSlug: routeSlug,
      body: SlugChangeRequest(slug: slug),
    );
  }

  /// Suppression douce : un organisateur peut le restaurer.
  Future<void> deleteRoute(String teamSlug, String routeSlug) {
    return _routesClient.deleteRoute(teamSlug: teamSlug, routeSlug: routeSlug);
  }

  Future<RouteDetailDto> undeleteRoute(String teamSlug, String routeSlug) {
    return _routesClient.undeleteRoute(
      teamSlug: teamSlug,
      routeSlug: routeSlug,
    );
  }

  static MultipartFile _gpxPart(GpxFile gpx) => MultipartFile.fromFileSync(
    gpx.path,
    filename: gpx.name,
    contentType: DioMediaType('application', 'gpx+xml'),
  );

  /// Les tags ne partent qu'aux endpoints d'équipe : les listes
  /// inter-équipes n'en ont pas (plan des tags, D7).
  static List<String>? _tags(RouteFilters filters) =>
      filters.tagIds.isEmpty ? null : filters.tagIds;

  static String? _search(RouteFilters filters) {
    final String? search = filters.search?.trim();
    return (search == null || search.isEmpty) ? null : search;
  }
}
