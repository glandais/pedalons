// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_code.dart';
import 'error_details.dart';
import 'incompatible_route_dto.dart';
import 'incompatible_route_usage_dto.dart';

part 'incompatible_visibility_details.freezed.dart';
part 'incompatible_visibility_details.g.dart';

@Freezed()
abstract class IncompatibleVisibilityDetails
    with _$IncompatibleVisibilityDetails {
  const factory IncompatibleVisibilityDetails({
    /// Type
    required String type,

    /// Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved.
    required List<IncompatibleRouteDto> routes,

    /// Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved.
    required List<IncompatibleRouteUsageDto> usages,
  }) = _IncompatibleVisibilityDetails;

  factory IncompatibleVisibilityDetails.fromJson(Map<String, Object?> json) =>
      _$IncompatibleVisibilityDetailsFromJson(json);
}
