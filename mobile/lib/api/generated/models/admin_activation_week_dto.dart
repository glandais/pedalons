// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_date.dart';

part 'admin_activation_week_dto.freezed.dart';
part 'admin_activation_week_dto.g.dart';

/// Activation of the accounts created in one sign-up week on one domain: counts only, no person named. The rates are the client's to compute, over signedUp.
@Freezed()
abstract class AdminActivationWeekDto with _$AdminActivationWeekDto {
  const factory AdminActivationWeekDto({
    /// Domain ID (TSID)
    required String domainId,

    /// Domain name
    required String domainName,

    /// Monday of the sign-up week (ISO week, UTC)
    required String weekStart,

    /// Whether every account of the week has had its 7 days: the counts of a week that is not complete can still grow
    required bool complete,

    /// Accounts created that week, deleted ones left out
    required int signedUp,

    /// Of those, accounts whose address is verified
    required int verified,

    /// Of those, accounts that joined a team (or created one) within 7 days of their creation, and still belong to it
    required int joinedTeam,

    /// Of those, accounts that signed up to a ride within 7 days of their creation, and are still signed up
    required int joinedRide,
  }) = _AdminActivationWeekDto;

  factory AdminActivationWeekDto.fromJson(Map<String, Object?> json) =>
      _$AdminActivationWeekDtoFromJson(json);
}
