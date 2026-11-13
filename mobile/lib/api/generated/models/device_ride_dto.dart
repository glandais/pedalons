// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_ride_entry_dto.dart';
import 'instant.dart';

part 'device_ride_dto.freezed.dart';
part 'device_ride_dto.g.dart';

/// Ride information for device applications
@Freezed()
abstract class DeviceRideDto with _$DeviceRideDto {
  const factory DeviceRideDto({
    /// Team slug
    required String teamSlug,

    /// Ride slug
    required String rideSlug,

    /// Ride name
    required String rideName,

    /// IANA zone of the ride, as RideDto.timezone: the Karoo renders the starts in it, the Garmin app ignores it and renders in its own zone
    required String timezone,

    /// Route entries for this ride
    required List<DeviceRideEntryDto> entries,

    /// Start date/time
    String? startDateTime,
  }) = _DeviceRideDto;

  factory DeviceRideDto.fromJson(Map<String, Object?> json) =>
      _$DeviceRideDtoFromJson(json);
}
