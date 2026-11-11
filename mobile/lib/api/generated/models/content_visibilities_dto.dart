// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'visibility.dart';

part 'content_visibilities_dto.freezed.dart';
part 'content_visibilities_dto.g.dart';

/// The visibilities the team accepts for each type of content, in the order of the Visibility enum. What a creation form offers; an editor hides its selector when a list has a single value. Never empty: TEAM is always accepted.
@Freezed()
abstract class ContentVisibilitiesDto with _$ContentVisibilitiesDto {
  const factory ContentVisibilitiesDto({
    required List<Visibility> ride,
    required List<Visibility> rideTemplate,
    required List<Visibility> route,
    required List<Visibility> post,
    required List<Visibility> trip,
    required List<Visibility> teamPage,

    /// Always [TEAM]: ads are members-only in every team.
    required List<Visibility> ad,
  }) = _ContentVisibilitiesDto;

  factory ContentVisibilitiesDto.fromJson(Map<String, Object?> json) =>
      _$ContentVisibilitiesDtoFromJson(json);
}
