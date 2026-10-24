// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'relative_wind.dart';

part 'wind_segment_dto.freezed.dart';
part 'wind_segment_dto.g.dart';

/// The wind on the stretch between two checkpoints, as the rider meets it
@Freezed()
abstract class WindSegmentDto with _$WindSegmentDto {
  const factory WindSegmentDto({
    /// Start of the stretch, equal to its checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track).
    required double fromDistance,

    /// End of the stretch, equal to the next checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track).
    required double toDistance,

    /// HEAD when the head component exceeds half the wind speed, TAIL below minus half, CROSS otherwise. Always shown with its label and an arrow, not by colour alone.
    required String relativeWind,

    /// Mean head component, km/h, signed: positive against the rider
    required double headwind,
  }) = _WindSegmentDto;

  factory WindSegmentDto.fromJson(Map<String, Object?> json) =>
      _$WindSegmentDtoFromJson(json);
}
