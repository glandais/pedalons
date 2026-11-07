// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';

part 'gpx_preview_summary_dto.freezed.dart';
part 'gpx_preview_summary_dto.g.dart';

/// Summary of an analysed GPX file, for listing
@Freezed()
abstract class GpxPreviewSummaryDto with _$GpxPreviewSummaryDto {
  const factory GpxPreviewSummaryDto({
    /// Public identifier used in URLs
    required String id,

    /// Track name
    required String name,

    /// Distance in meters
    required double distance,

    /// Total elevation gain in meters
    required double elevationGain,

    /// Total elevation loss in meters
    required double elevationLoss,

    /// Elevation gain per kilometer
    required double hilliness,

    /// Creation timestamp
    required String createdAt,

    /// Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone
    String? departureTime,

    /// IANA time zone of the first point of the track, the one the departure was entered in
    String? departureTimezone,
  }) = _GpxPreviewSummaryDto;

  factory GpxPreviewSummaryDto.fromJson(Map<String, Object?> json) =>
      _$GpxPreviewSummaryDtoFromJson(json);
}
