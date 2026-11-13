// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'output_point.freezed.dart';
part 'output_point.g.dart';

@Freezed()
abstract class OutputPoint with _$OutputPoint {
  const factory OutputPoint({
    @JsonKey(name: 'd_m') double? dM,
    @JsonKey(name: 'index') int? indexField,
    String? origin,
    List<String>? reasons,
    double? lat,
    double? lon,
    double? ele,
    @JsonKey(name: 'ele_smoothed') double? eleSmoothed,
    @JsonKey(name: 'ele_method') String? eleMethod,
    @JsonKey(name: 'gain_cum_m') double? gainCumM,
    @JsonKey(name: 'loss_cum_m') double? lossCumM,
    bool? inserted,
  }) = _OutputPoint;

  factory OutputPoint.fromJson(Map<String, Object?> json) =>
      _$OutputPointFromJson(json);
}
