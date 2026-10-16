// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';

part 'device_registered_group_dto.freezed.dart';
part 'device_registered_group_dto.g.dart';

/// Upcoming ride group the user is registered in, with the route to load on the device
@Freezed()
abstract class DeviceRegisteredGroupDto with _$DeviceRegisteredGroupDto {
  const factory DeviceRegisteredGroupDto({
    /// Team slug
    required String teamSlug,

    /// Ride slug
    required String rideSlug,

    /// Ride name
    required String rideName,

    /// Name of the group the user is registered in
    required String groupName,

    /// Slug of the route to load: the group's own route, or the ride's when the group has none
    required String routeSlug,

    /// Route name
    required String routeName,

    /// Distance in meters
    required double distance,

    /// Elevation gain in meters
    required double elevationGain,

    /// When the group leaves, as an absolute instant (UTC): the group's startAt, the ride's own start when the group has no time. Devices render it in their own zone.
    required String startDateTime,

    /// IANA time zone of the ride (e.g. Europe/Paris)
    required String timezone,
  }) = _DeviceRegisteredGroupDto;

  factory DeviceRegisteredGroupDto.fromJson(Map<String, Object?> json) =>
      _$DeviceRegisteredGroupDtoFromJson(json);
}
