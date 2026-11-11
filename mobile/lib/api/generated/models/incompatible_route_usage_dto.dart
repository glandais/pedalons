// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'publication_type.dart';
import 'visibility.dart';

part 'incompatible_route_usage_dto.freezed.dart';
part 'incompatible_route_usage_dto.g.dart';

/// A ride or trip visible outside the team that uses the route
@Freezed()
abstract class IncompatibleRouteUsageDto with _$IncompatibleRouteUsageDto {
  const factory IncompatibleRouteUsageDto({
    /// RIDE or TRIP
    required String type,

    /// Ride or trip URL slug, in the route's team
    required String slug,

    /// Ride or trip name
    required String name,

    /// Its visibility: PUBLIC or PUBLIC_UNLISTED
    required String visibility,
  }) = _IncompatibleRouteUsageDto;

  factory IncompatibleRouteUsageDto.fromJson(Map<String, Object?> json) =>
      _$IncompatibleRouteUsageDtoFromJson(json);
}
