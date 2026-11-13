// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'meta.dart';
import 'output_point.dart';
import 'quality.dart';
import 'segment.dart';
import 'summary.dart';

part 'route_details_response.freezed.dart';
part 'route_details_response.g.dart';

@Freezed()
abstract class RouteDetailsResponse with _$RouteDetailsResponse {
  const factory RouteDetailsResponse({
    Meta? meta,
    String? status,
    List<OutputPoint>? points,
    List<Segment>? segments,
    Summary? summary,
    Quality? quality,
    bool? partial,
  }) = _RouteDetailsResponse;

  factory RouteDetailsResponse.fromJson(Map<String, Object?> json) =>
      _$RouteDetailsResponseFromJson(json);
}
