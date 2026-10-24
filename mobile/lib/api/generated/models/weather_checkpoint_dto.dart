// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'relative_wind.dart';
import 'weather_checkpoint_kind.dart';
import 'weather_conditions_dto.dart';

part 'weather_checkpoint_dto.freezed.dart';
part 'weather_checkpoint_dto.g.dart';

/// A forecast point along a leg, about every 15 km plus the finish. Deliberately carries no coordinates: place it by distance on the route geometry the client may read.
@Freezed()
abstract class WeatherCheckpointDto with _$WeatherCheckpointDto {
  const factory WeatherCheckpointDto({
    @JsonKey(name: 'index') required int indexField,

    /// Where the point stands on the leg
    required String kind,

    /// Distance from the start of the leg's route, metres: its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next. To place the point on the geometry, add up the lengths of the previous tracks: the 4th coordinate of a track geometry restarts at 0 on each track.
    required double distance,

    /// Estimated passage, from the leg's start time and speed
    required String time,

    /// Elevation of the point, metres, from the track
    double? elevation,

    /// The forecast at the passage. Absent when nothing is in cache for that place yet.
    WeatherConditionsDto? weather,

    /// How the rider meets the wind on the stretch that starts here (for the finish, the stretch that ends here). Absent without weather.
    String? relativeWind,

    /// Mean head component of the wind on that stretch, km/h, signed: positive against the rider, negative behind
    double? headwind,

    /// Direction the wind blows TOWARDS, relative to the direction of travel, degrees clockwise: 0 = from behind (pushing), 90 = from the left, 180 = in the face. Draw the arrow pointing forward, then rotate it by this angle.
    double? relativeWindAngle,
  }) = _WeatherCheckpointDto;

  factory WeatherCheckpointDto.fromJson(Map<String, Object?> json) =>
      _$WeatherCheckpointDtoFromJson(json);
}
