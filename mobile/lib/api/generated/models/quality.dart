// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_node.dart';
import 'terrain_range.dart';
import 'warning.dart';

part 'quality.freezed.dart';
part 'quality.g.dart';

@Freezed()
abstract class Quality with _$Quality {
  const factory Quality({
    List<TerrainRange>? terrain,
    List<Warning>? warnings,
    @JsonKey(name: 'structure_correction') JsonNode? structureCorrection,
  }) = _Quality;

  factory Quality.fromJson(Map<String, Object?> json) =>
      _$QualityFromJson(json);
}
