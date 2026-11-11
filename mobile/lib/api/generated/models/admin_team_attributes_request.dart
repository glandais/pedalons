// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_team_attributes_request.freezed.dart';
part 'admin_team_attributes_request.g.dart';

/// Platform admin request to update team governance attributes
@Freezed()
abstract class AdminTeamAttributesRequest with _$AdminTeamAttributesRequest {
  const factory AdminTeamAttributesRequest({
    /// Whether team admins can change visibility
    required bool visibilityEditable,

    /// Whether any domain user can join this public team
    required bool joinable,

    /// Whether team admins can add members
    required bool addMemberAllowed,

    /// Whether the interactive route planner is open to this team
    required bool enableRoutePlanner,

    /// Whether a private team may publish content as public or unlisted, readable by link only and kept out of every listing. Omitted: left as it is (off for a new team).
    bool? publicContentAllowed,
  }) = _AdminTeamAttributesRequest;

  factory AdminTeamAttributesRequest.fromJson(Map<String, Object?> json) =>
      _$AdminTeamAttributesRequestFromJson(json);
}
