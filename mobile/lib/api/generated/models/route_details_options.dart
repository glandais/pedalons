// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'elevation.dart';
import 'route_details_profile.dart';
import 'route_details_section.dart';
import 'sampling.dart';

part 'route_details_options.freezed.dart';
part 'route_details_options.g.dart';

@Freezed()
abstract class RouteDetailsOptions with _$RouteDetailsOptions {
  const factory RouteDetailsOptions({
    RouteDetailsProfile? profile,
    List<RouteDetailsSection>? sections,
    Sampling? sampling,
    Elevation? elevation,
    @JsonKey(name: 'accept_partial') bool? acceptPartial,
  }) = _RouteDetailsOptions;

  factory RouteDetailsOptions.fromJson(Map<String, Object?> json) =>
      _$RouteDetailsOptionsFromJson(json);
}
