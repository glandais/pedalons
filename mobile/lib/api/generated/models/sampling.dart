// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sampling.freezed.dart';
part 'sampling.g.dart';

@Freezed()
abstract class Sampling with _$Sampling {
  const factory Sampling({
    String? mode,
  }) = _Sampling;

  factory Sampling.fromJson(Map<String, Object?> json) =>
      _$SamplingFromJson(json);
}
