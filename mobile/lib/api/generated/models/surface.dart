// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'surface.freezed.dart';
part 'surface.g.dart';

@Freezed()
abstract class Surface with _$Surface {
  const factory Surface({
    @JsonKey(name: 'class') String? classField,
    String? detail,
    String? source,
  }) = _Surface;

  factory Surface.fromJson(Map<String, Object?> json) =>
      _$SurfaceFromJson(json);
}
