// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'asset_dimensions_dto.freezed.dart';
part 'asset_dimensions_dto.g.dart';

@Freezed()
abstract class AssetDimensionsDto with _$AssetDimensionsDto {
  const factory AssetDimensionsDto({
    int? width,
    int? height,
  }) = _AssetDimensionsDto;

  factory AssetDimensionsDto.fromJson(Map<String, Object?> json) =>
      _$AssetDimensionsDtoFromJson(json);
}
