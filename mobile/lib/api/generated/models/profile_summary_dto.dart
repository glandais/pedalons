// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'paired_device_dto.dart';
import 'profile_notification_summary_dto.dart';
import 'profile_team_dto.dart';

part 'profile_summary_dto.freezed.dart';
part 'profile_summary_dto.g.dart';

/// The state of each subject of the current user's profile, for its overview
@Freezed()
abstract class ProfileSummaryDto with _$ProfileSummaryDto {
  const factory ProfileSummaryDto({
    /// The user's teams on this site, in name order, each with the user's role in it
    required List<ProfileTeamDto> teams,

    /// Number of passkeys registered on the account
    required int passkeyCount,

    /// Devices (Karoo, Garmin) paired with the account, newest first — the same rows as GET /api/users/me/devices
    required List<PairedDeviceDto> pairedDevices,

    /// Number of live accounts the user blocked
    required int blockedUserCount,

    /// Where the user's notifications go
    required ProfileNotificationSummaryDto notifications,
  }) = _ProfileSummaryDto;

  factory ProfileSummaryDto.fromJson(Map<String, Object?> json) =>
      _$ProfileSummaryDtoFromJson(json);
}
