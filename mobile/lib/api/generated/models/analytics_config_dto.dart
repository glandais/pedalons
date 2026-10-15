// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_config_dto.freezed.dart';
part 'analytics_config_dto.g.dart';

/// Audience measurement settings for the site
@Freezed()
abstract class AnalyticsConfigDto with _$AnalyticsConfigDto {
  const factory AnalyticsConfigDto({
    /// Same-origin path the site sends a page view to (for example /count), without the query string.
    required String countPath,
  }) = _AnalyticsConfigDto;

  factory AnalyticsConfigDto.fromJson(Map<String, Object?> json) =>
      _$AnalyticsConfigDtoFromJson(json);
}
