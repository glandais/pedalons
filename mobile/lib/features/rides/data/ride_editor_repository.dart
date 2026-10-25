import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final rideEditorRepositoryProvider = Provider<RideEditorRepository>((ref) {
  return RideEditorRepository(
    routes: ref.watch(routesClientProvider),
    places: ref.watch(placesClientProvider),
    members: ref.watch(teamMembersClientProvider),
    tags: ref.watch(tagsClientProvider),
    templates: ref.watch(rideTemplatesClientProvider),
    assets: ref.watch(assetsClientProvider),
    teams: ref.watch(teamsClientProvider),
  );
});

/// Taille des pages des sélecteurs de l'éditeur, comme les autocomplétions
/// du site (`placeAutocompleteParams`, `RoutePickerModal`).
const int kRideEditorPageSize = 20;

/// Ce que l'éditeur de sortie va chercher **autour** de la sortie : les
/// parcours, lieux, membres, tags et modèles de l'équipe, l'envoi d'un
/// fichier, et le fuseau d'un point (docs/LEDGER_*.md MOB-80).
///
/// Un seul dépôt plutôt que six : ces appels n'ont de sens qu'ensemble, dans
/// ce formulaire, et un test qui le remplace n'a qu'une classe à bouchonner.
class RideEditorRepository {
  RideEditorRepository({
    required this._routes,
    required this._places,
    required this._members,
    required this._tags,
    required this._templates,
    required this._assets,
    required this._teams,
  });

  final RoutesClient _routes;
  final PlacesClient _places;
  final TeamMembersClient _members;
  final TagsClient _tags;
  final RideTemplatesClient _templates;
  final AssetsClient _assets;
  final TeamsClient _teams;

  /// Une page de parcours de l'équipe, filtrée par [search].
  Future<RouteListResponse> searchRoutes(
    String teamSlug, {
    String? search,
    int page = 0,
  }) {
    return _routes.listRoutes(
      teamSlug: teamSlug,
      search: _query(search),
      page: page,
      size: kRideEditorPageSize,
    );
  }

  /// Les parcours nommés par [slugs], **sans géométrie** : l'éditeur ne
  /// dessine rien, il n'affiche que nom, distance et dénivelé.
  Future<List<RouteDetailDto>> routesBulk(
    String teamSlug,
    List<String> slugs,
  ) async {
    if (slugs.isEmpty) return const <RouteDetailDto>[];
    final RoutesBulkResponse response = await _routes.getRoutesBulk(
      teamSlug: teamSlug,
      slug: slugs,
      geometry: false,
    );
    return response.routes;
  }

  /// Un parcours avec son point de départ, pour le fuseau de la sortie.
  Future<RouteDetailDto> getRoute(String teamSlug, String routeSlug) {
    return _routes.getRoute(teamSlug: teamSlug, routeSlug: routeSlug);
  }

  /// Les lieux de départ ([start] vrai) ou d'arrivée de l'équipe. Réservé aux
  /// organisateurs côté serveur, ce que l'éditeur est déjà.
  Future<PlaceListResponse> searchPlaces(
    String teamSlug, {
    required bool start,
    String? search,
    int page = 0,
  }) {
    return _places.listPlaces(
      teamSlug: teamSlug,
      search: _query(search),
      filterStart: start,
      filterEnd: !start,
      page: page,
      size: kRideEditorPageSize,
    );
  }

  Future<PlaceDetailDto> getPlace(String teamSlug, String placeId) {
    return _places.getPlace(teamSlug: teamSlug, placeId: placeId);
  }

  /// Les membres dont le nom contient [search], pour désigner un meneur.
  Future<MemberListResponse> searchMembers(
    String teamSlug, {
    String? search,
    int page = 0,
  }) {
    return _members.getMembers(
      teamSlug: teamSlug,
      search: _query(search),
      page: page,
      size: kRideEditorPageSize,
    );
  }

  /// Le vocabulaire de tags « sortie » de l'équipe.
  Future<List<TagWithUsageDto>> listRideTags(String teamSlug) {
    return _tags.listTeamTags(teamSlug: teamSlug, type: TagTarget.ride);
  }

  Future<RideTemplateListResponse> searchTemplates(
    String teamSlug, {
    String? search,
    int page = 0,
  }) {
    return _templates.listTemplates(
      teamSlug: teamSlug,
      search: _query(search),
      page: page,
      size: kRideEditorPageSize,
    );
  }

  Future<RideTemplateDto> getTemplate(String teamSlug, String templateSlug) {
    return _templates.getTemplate(
      teamSlug: teamSlug,
      templateSlug: templateSlug,
    );
  }

  /// Envoie un fichier à l'équipe ; l'asset rendu se rattache à la sortie par
  /// `media.assets` à l'enregistrement. Tout membre peut envoyer.
  Future<AssetDto> uploadAsset(
    String teamSlug, {
    required String filePath,
    required AssetTypeRequest type,
    String? fileName,
  }) {
    return _assets.uploadAsset(
      teamSlug: teamSlug,
      assetType: type,
      file: MultipartFile.fromFileSync(filePath, filename: fileName),
    );
  }

  /// Le fuseau d'un point — celui du lieu de départ ou du départ du
  /// parcours, qui décide l'heure murale de la sortie (ledger `API-60`).
  Future<String> timezoneAt(String teamSlug, double lat, double lon) async {
    final TeamTimezoneDto dto = await _teams.getTeamTimezone(
      teamSlug: teamSlug,
      lat: lat,
      lon: lon,
    );
    return dto.timezone;
  }

  static String? _query(String? search) {
    final String? trimmed = search?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
