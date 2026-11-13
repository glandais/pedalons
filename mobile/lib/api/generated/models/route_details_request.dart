// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'point.dart';
import 'route_details_options.dart';

part 'route_details_request.freezed.dart';
part 'route_details_request.g.dart';

@Freezed()
abstract class RouteDetailsRequest with _$RouteDetailsRequest {
  const factory RouteDetailsRequest({
    String? polyline,
    @JsonKey(name: 'polyline_precision') int? polylinePrecision,
    List<Point>? points,
    RouteDetailsOptions? options,
  }) = _RouteDetailsRequest;

  factory RouteDetailsRequest.fromJson(Map<String, Object?> json) =>
      _$RouteDetailsRequestFromJson(json);
}
