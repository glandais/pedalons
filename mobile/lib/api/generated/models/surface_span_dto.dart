// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'track_surface.dart';

part 'surface_span_dto.freezed.dart';
part 'surface_span_dto.g.dart';

/// A stretch of a track with one surface class, in metres along the track (the M of its line)
@Freezed()
abstract class SurfaceSpanDto with _$SurfaceSpanDto {
  const factory SurfaceSpanDto({
    /// Start, metres along the track
    required double from,

    /// End, metres along the track
    required double to,
    required TrackSurface surface,
  }) = _SurfaceSpanDto;

  factory SurfaceSpanDto.fromJson(Map<String, Object?> json) =>
      _$SurfaceSpanDtoFromJson(json);
}
