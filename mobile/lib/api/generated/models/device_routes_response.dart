// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_registered_group_dto.dart';
import 'device_ride_dto.dart';
import 'device_route_dto.dart';

part 'device_routes_response.freezed.dart';
part 'device_routes_response.g.dart';

/// Response containing rides and routes for device applications
@Freezed()
abstract class DeviceRoutesResponse with _$DeviceRoutesResponse {
  const factory DeviceRoutesResponse({
    /// Upcoming rides with route entries
    required List<DeviceRideDto> rides,

    /// Latest standalone routes
    required List<DeviceRouteDto> routes,

    /// Upcoming ride groups the user is registered in (from 12 hours ago to 7 days ahead), earliest first, each with the route to load
    required List<DeviceRegisteredGroupDto> registeredGroups,
  }) = _DeviceRoutesResponse;

  factory DeviceRoutesResponse.fromJson(Map<String, Object?> json) =>
      _$DeviceRoutesResponseFromJson(json);
}
