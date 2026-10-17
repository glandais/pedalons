// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'asset_dimensions_dto.dart';

part 'asset_dto.freezed.dart';
part 'asset_dto.g.dart';

@Freezed()
abstract class AssetDto with _$AssetDto {
  const factory AssetDto({
    /// ID (TSID)
    required String id,

    /// Filename
    required String fileName,

    /// Content-Type
    required String contentType,

    /// Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.
    required String url,

    /// Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.
    String? imageUrl,

    /// image dimensions
    AssetDimensionsDto? imageDimensions,

    /// Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.
    int? size,
  }) = _AssetDto;

  factory AssetDto.fromJson(Map<String, Object?> json) =>
      _$AssetDtoFromJson(json);
}
