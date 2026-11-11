// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'visibility.dart';

part 'admin_team_dto.freezed.dart';
part 'admin_team_dto.g.dart';

/// Admin team view with domain info
@Freezed()
abstract class AdminTeamDto with _$AdminTeamDto {
  const factory AdminTeamDto({
    /// Team ID (TSID)
    required String id,

    /// Team name
    required String name,

    /// Team URL slug
    required String slug,

    /// Domain ID this team belongs to
    required String domainId,

    /// Domain hostname
    required String domainName,

    /// Team visibility
    required String visibility,

    /// Whether visibility is editable by team admins
    required bool visibilityEditable,

    /// Whether any domain user can join this team
    required bool joinable,

    /// Whether team admins can add members
    required bool addMemberAllowed,

    /// Whether the interactive route planner is open to this team
    required bool enableRoutePlanner,

    /// Whether a private team may publish content as public or unlisted, readable by link only and kept out of every listing
    required bool publicContentAllowed,

    /// Is team soft-deleted
    required bool deleted,

    /// Number of members
    required int memberCount,

    /// Team creation timestamp
    required String createdAt,
  }) = _AdminTeamDto;

  factory AdminTeamDto.fromJson(Map<String, Object?> json) =>
      _$AdminTeamDtoFromJson(json);
}
