// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

part 'downloads_client.g.dart';

@RestApi()
abstract class DownloadsClient {
  factory DownloadsClient(Dio dio, {String? baseUrl}) = _DownloadsClient;

  /// Download a file.
  ///
  /// Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
  ///
  /// [assetId] - Asset ID.
  ///
  /// [fileName] - File name: the last segment of the URL, not used to find the file.
  ///
  /// [teamSlug] - Team slug.
  @GET('/api/download/public/assets/{teamSlug}/{assetId}/{fileName}')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadPublicAsset({
    @Path('assetId') required String assetId,
    @Path('fileName') required String fileName,
    @Path('teamSlug') required String teamSlug,
  });

  /// Download a user's avatar.
  ///
  /// Serves an avatar under the URL the API gave for it (avatarUrl), in the best format the Accept header allows. Avatars are stored at 256 px: a larger size is served at 256.
  ///
  /// [fileId] - Avatar file ID, from avatarUrl.
  ///
  /// [size] - Requested square size in pixels.
  @GET('/api/download/public/avatars/{fileId}/{size}')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadAvatar({
    @Path('fileId') required String fileId,
    @Path('size') required int size,
  });

  /// Download an image.
  ///
  /// Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
  ///
  /// [assetId] - Asset ID.
  ///
  /// [size] - Requested square size in pixels.
  ///
  /// [teamSlug] - Team slug.
  @GET('/api/download/public/images/{teamSlug}/{assetId}/{size}')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadPublicImage({
    @Path('assetId') required String assetId,
    @Path('size') required int size,
    @Path('teamSlug') required String teamSlug,
  });

  /// Download a file.
  ///
  /// Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
  ///
  /// [assetId] - Asset ID.
  ///
  /// [fileName] - File name: the last segment of the URL, not used to find the file.
  ///
  /// [teamSlug] - Team slug.
  @GET('/api/download/public_unlisted/assets/{teamSlug}/{assetId}/{fileName}')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadUnlistedAsset({
    @Path('assetId') required String assetId,
    @Path('fileName') required String fileName,
    @Path('teamSlug') required String teamSlug,
  });

  /// Download an image.
  ///
  /// Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
  ///
  /// [assetId] - Asset ID.
  ///
  /// [size] - Requested square size in pixels.
  ///
  /// [teamSlug] - Team slug.
  @GET('/api/download/public_unlisted/images/{teamSlug}/{assetId}/{size}')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadUnlistedImage({
    @Path('assetId') required String assetId,
    @Path('size') required int size,
    @Path('teamSlug') required String teamSlug,
  });

  /// Download a file.
  ///
  /// Streams a file attached to a team's content — a route's GPX or FIT, a document — under the URL the API gave for it (AssetDto.url and the like): follow that URL rather than build one. Access is checked against the asset on every request, whatever the visibility segment of the path.
  ///
  /// [assetId] - Asset ID.
  ///
  /// [fileName] - File name: the last segment of the URL, not used to find the file.
  ///
  /// [teamSlug] - Team slug.
  @GET('/api/download/team/assets/{teamSlug}/{assetId}/{fileName}')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadTeamAsset({
    @Path('assetId') required String assetId,
    @Path('fileName') required String fileName,
    @Path('teamSlug') required String teamSlug,
  });

  /// Download an image.
  ///
  /// Serves an image attached to a team's content, resized to fit a square of the requested size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG). Access is checked against the asset on every request, whatever the visibility segment of the path.
  ///
  /// [assetId] - Asset ID.
  ///
  /// [size] - Requested square size in pixels.
  ///
  /// [teamSlug] - Team slug.
  @GET('/api/download/team/images/{teamSlug}/{assetId}/{size}')
  @DioResponseType(ResponseType.bytes)
  Future<HttpResponse<List<int>>> downloadTeamImage({
    @Path('assetId') required String assetId,
    @Path('size') required int size,
    @Path('teamSlug') required String teamSlug,
  });
}
