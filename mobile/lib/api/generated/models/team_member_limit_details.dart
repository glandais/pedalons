// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_code.dart';
import 'error_details.dart';

part 'team_member_limit_details.freezed.dart';
part 'team_member_limit_details.g.dart';

@Freezed()
abstract class TeamMemberLimitDetails with _$TeamMemberLimitDetails {
  const factory TeamMemberLimitDetails({
    /// Type
    required String type,

    /// Member cap of the team's tier
    required int limit,

    /// What was counted against the cap: active members, plus pending invitations when sending one
    required int current,
  }) = _TeamMemberLimitDetails;

  factory TeamMemberLimitDetails.fromJson(Map<String, Object?> json) =>
      _$TeamMemberLimitDetailsFromJson(json);
}
