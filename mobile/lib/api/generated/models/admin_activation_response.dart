// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'admin_activation_week_dto.dart';

part 'admin_activation_response.freezed.dart';
part 'admin_activation_response.g.dart';

/// Activation of new accounts per sign-up week and domain, newest week first (ledger API-213)
@Freezed()
abstract class AdminActivationResponse with _$AdminActivationResponse {
  const factory AdminActivationResponse({
    /// One row per week and domain that has at least one sign-up; a week without any is absent
    required List<AdminActivationWeekDto> weeks,

    /// How many weeks back the rows go
    required int weeksBack,
  }) = _AdminActivationResponse;

  factory AdminActivationResponse.fromJson(Map<String, Object?> json) =>
      _$AdminActivationResponseFromJson(json);
}
