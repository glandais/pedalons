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
  Future<GpxPreviewDto> createFromFile(GpxFile file) =>
      _client.createPreview(gpxFile: gpxPart(file));

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
