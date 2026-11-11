// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'visibility.dart';

part 'incompatible_route_dto.freezed.dart';
part 'incompatible_route_dto.g.dart';

/// A route whose visibility does not fit the ride or trip being saved
@Freezed()
abstract class IncompatibleRouteDto with _$IncompatibleRouteDto {
  const factory IncompatibleRouteDto({
    /// Route URL slug
    required String slug,

    /// Route name
    required String name,

    /// The route's visibility today (TEAM)
    required String visibility,

    /// The visibility the route takes when the same request is replayed with alignVisibility = true: always PUBLIC_UNLISTED, even under a PUBLIC ride or trip — a route never becomes PUBLIC without an explicit decision.
    required String proposedVisibility,
  }) = _IncompatibleRouteDto;

  factory IncompatibleRouteDto.fromJson(Map<String, Object?> json) =>
      _$IncompatibleRouteDtoFromJson(json);
}
