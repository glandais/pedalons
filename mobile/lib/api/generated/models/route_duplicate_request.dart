// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_duplicate_request.freezed.dart';
part 'route_duplicate_request.g.dart';

/// Route duplication request
@Freezed()
abstract class RouteDuplicateRequest with _$RouteDuplicateRequest {
  const factory RouteDuplicateRequest({
    /// Name of the copy
    required String name,
  }) = _RouteDuplicateRequest;

  factory RouteDuplicateRequest.fromJson(Map<String, Object?> json) =>
      _$RouteDuplicateRequestFromJson(json);
}
