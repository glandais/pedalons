// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_month_count_dto.freezed.dart';
part 'admin_month_count_dto.g.dart';

/// A count for one calendar month (UTC)
@Freezed()
abstract class AdminMonthCountDto with _$AdminMonthCountDto {
  const factory AdminMonthCountDto({
    /// Calendar month, YYYY-MM (UTC)
    required String month,

    /// How many
    required int count,
  }) = _AdminMonthCountDto;

  factory AdminMonthCountDto.fromJson(Map<String, Object?> json) =>
      _$AdminMonthCountDtoFromJson(json);
}
