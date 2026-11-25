import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../../routes/domain/gpx_check.dart';

/// Les appels des outils GPX (docs/LEDGER_*.md MOB-178), contrat inchangé :
/// `GpxPreviewsClient` tel quel, plus les parties de fichier.
class GpxPreviewRepository {
  const GpxPreviewRepository(this._client);

  final GpxPreviewsClient _client;

  /// « Visualiser un fichier » : le fichier part dès le choix, sans date ni
  /// vitesse — elles se posent ensuite, depuis la modification.
  Future<GpxPreviewDto> createFromFile(
    GpxFile file, {
    String? departure,
    double? averageSpeed,
  }) => _client.createPreview(
    gpxFile: gpxPart(file),
    departure: departure,
    averageSpeed: averageSpeed?.toString(),
  );

  /// « Tracer un fichier GPX » : le tracé dessiné dans le planificateur (son état
  /// d'édition, ou ses points), sans fichier.
  Future<GpxPreviewDto> createFromPoints(GpxPreviewFromPointsRequest request) =>
      _client.createPreviewFromPoints(body: request);

  /// La modification, réservée à qui a déposé l'aperçu : le nom toujours, le
  /// tracé s'il change ([gpx] passe devant un état d'édition), le départ.
  Future<GpxPreviewDto> update(
    String previewId,
    GpxPreviewUpdateRequest request, {
    GpxFile? gpx,
  }) => _client.updatePreview(
    previewId: previewId,
    preview: request,
    gpxFile: gpx == null ? null : gpxPart(gpx),
  );

  /// L'état d'édition enregistré de l'aperçu, `null` s'il n'en a pas (un
  /// fichier importé jamais redessiné).
  Future<PlannerState?> plannerState(String previewId) async =>
      (await _client.getPreviewPlannerState(previewId: previewId)).state;

  /// « Fusionner des fichiers » : de 2 à 10 fichiers, le serveur choisit
  /// l'ordre et le sens des traces (et revérifie les bornes).
  Future<GpxPreviewDto> merge(List<GpxFile> files) => _client.mergePreviews(
    gpxFiles: <MultipartFile>[for (final GpxFile f in files) gpxPart(f)],
  );

  Future<PageResult<GpxPreviewSummaryDto>> listMine({
    required int page,
    required int size,
  }) async {
    final GpxPreviewListResponse response = await _client.listMyPreviews(
      page: page,
      size: size,
    );
    return PageResult<GpxPreviewSummaryDto>(
      items: response.previews,
      total: response.total,
    );
  }

  /// L'aperçu, relu tout de suite — l'éditeur part de là, jamais d'un cache.
  Future<GpxPreviewDto> get(String previewId) =>
      _client.getPreview(previewId: previewId);

  Future<void> delete(String previewId) =>
      _client.deletePreview(previewId: previewId);

  /// Une copie à soi, sous [name] (`WEB-180` au site).
  Future<GpxPreviewDto> copy(String previewId, {required String name}) =>
      _client.copyGpxPreview(
        previewId: previewId,
        body: GpxPreviewCopyRequest(name: name),
      );

  /// « Enregistrer comme parcours » dans [teamSlug] : le serveur reprend le
  /// fichier d'origine de l'aperçu ; [request] porte ce qu'un parcours a en
  /// plus (surface, visibilité, description vide).
  Future<RouteDto> createRoute(
    String previewId, {
    required String teamSlug,
    required RouteRequest request,
  }) => _client.createRouteFromPreview(
    previewId: previewId,
    teamSlug: teamSlug,
    body: request,
  );

  Future<RideWeatherDto> weather(String previewId) =>
      _client.getPreviewWeather(previewId: previewId);

  /// Le fichier en partie `gpxFile`, avec son vrai type — celui que le
  /// serveur attend, comme pour un parcours.
  static MultipartFile gpxPart(GpxFile gpx) => MultipartFile.fromFileSync(
    gpx.path,
    filename: gpx.name,
    contentType: DioMediaType('application', 'gpx+xml'),
  );
}

final gpxPreviewRepositoryProvider = Provider<GpxPreviewRepository>(
  (Ref ref) => GpxPreviewRepository(ref.watch(gpxPreviewsClientProvider)),
);
