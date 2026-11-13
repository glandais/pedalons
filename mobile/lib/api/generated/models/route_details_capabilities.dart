// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'data.dart';
import 'enums.dart';
import 'limits.dart';

part 'route_details_capabilities.freezed.dart';
part 'route_details_capabilities.g.dart';

@Freezed()
abstract class RouteDetailsCapabilities with _$RouteDetailsCapabilities {
  const factory RouteDetailsCapabilities({
    @JsonKey(name: 'api_version') String? apiVersion,
    Limits? limits,
    Enums? enums,
    Data? data,
  }) = _RouteDetailsCapabilities;

  factory RouteDetailsCapabilities.fromJson(Map<String, Object?> json) =>
      _$RouteDetailsCapabilitiesFromJson(json);
}
