// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'structure.dart';

part 'summary.freezed.dart';
part 'summary.g.dart';

@Freezed()
abstract class Summary with _$Summary {
  const factory Summary({
    @JsonKey(name: 'length_m') double? lengthM,
    @JsonKey(name: 'gain_m') double? gainM,
    @JsonKey(name: 'loss_m') double? lossM,
    @JsonKey(name: 'ele_min_m') double? eleMinM,
    @JsonKey(name: 'ele_max_m') double? eleMaxM,
    List<Structure>? structures,
    @JsonKey(name: 'terrain_m') Map<String, double>? terrainM,
  }) = _Summary;

  factory Summary.fromJson(Map<String, Object?> json) =>
      _$SummaryFromJson(json);
}
