// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'asset_not_available_details.dart';
import 'entity_type.dart';
import 'error_code.dart';
import 'error_validation_details.dart';
import 'field_error.dart';
import 'incompatible_route_dto.dart';
import 'incompatible_route_usage_dto.dart';
import 'incompatible_visibility_details.dart';
import 'local_date.dart';
import 'not_found_details.dart';
import 'planner_quota_details.dart';
import 'planner_quota_scope.dart';
import 'searched_by.dart';
import 'team_member_limit_details.dart';

part 'error_details.freezed.dart';
part 'error_details.g.dart';

/// Error details
@Freezed(unionKey: 'type')
sealed class ErrorDetails with _$ErrorDetails {
  @FreezedUnionValue('VALIDATION')
  const factory ErrorDetails.validation({
    /// Field Errors
    required List<FieldError> fieldErrors,
  }) = ErrorDetailsValidation;

  @FreezedUnionValue('NOT_FOUND')
  const factory ErrorDetails.notFound({
    /// Entity type
    required String entityType,

    /// Search type
    required String searchedBy,

    /// id/slug
    required String id,
  }) = ErrorDetailsNotFound;

  @FreezedUnionValue('ASSET_NOT_AVAILABLE')
  const factory ErrorDetails.assetNotAvailable({
    /// Id of the asset, as the request cited it
    required String assetId,
  }) = ErrorDetailsAssetNotAvailable;

  @FreezedUnionValue('INCOMPATIBLE_VISIBILITY')
  const factory ErrorDetails.incompatibleVisibility({
    /// Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved.
    required List<IncompatibleRouteDto> routes,

    /// Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved.
    required List<IncompatibleRouteUsageDto> usages,
  }) = ErrorDetailsIncompatibleVisibility;

  @FreezedUnionValue('TEAM_MEMBER_LIMIT_REACHED')
  const factory ErrorDetails.teamMemberLimitReached({
    /// Member cap of the team's tier
    required int limit,

    /// What was counted against the cap: active members, plus pending invitations when sending one
    required int current,
  }) = ErrorDetailsTeamMemberLimitReached;

  @FreezedUnionValue('PLANNER_QUOTA_REACHED')
  const factory ErrorDetails.plannerQuotaReached({
    /// TEAM: the team is on the free plan and its monthly saves are spent. PERSONAL: the caller is a member of no unlocked team and their monthly saves in the GPX tools are spent.
    required String scope,

    /// Saves of a drawn track allowed per calendar month
    required int limit,

    /// Saves already counted this month
    required int current,

    /// The day the count starts again: the first day of next month, in the team's zone for TEAM, in UTC for PERSONAL
    required String resetsOn,

    /// Name of the team, for TEAM only
    String? teamName,
  }) = ErrorDetailsPlannerQuotaReached;

  factory ErrorDetails.fromJson(Map<String, Object?> json) =>
      _$ErrorDetailsFromJson(json);
}
