// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_point.dart';

part 'route_retouch_end.freezed.dart';
part 'route_retouch_end.g.dart';

/// The new finish of a retouch: exactly one of a point and a place of the team
@Freezed()
abstract class RouteRetouchEnd with _$RouteRetouchEnd {
  const factory RouteRetouchEnd({
    /// A position, e.g. a tap on the map
    GeoPoint? point,

    /// A place of the route's team, by id: its position is the finish (400 VALIDATION on end.placeId when it is not one of the team's)
    String? placeId,
  }) = _RouteRetouchEnd;

  factory RouteRetouchEnd.fromJson(Map<String, Object?> json) =>
      _$RouteRetouchEndFromJson(json);
}
