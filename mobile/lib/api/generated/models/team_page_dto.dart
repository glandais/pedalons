// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'content_permissions_dto.dart';
import 'media_dto.dart';
import 'team_publication_dto.dart';
import 'visibility.dart';

part 'team_page_dto.freezed.dart';
part 'team_page_dto.g.dart';

/// Team page detail
@Freezed()
abstract class TeamPageDto with _$TeamPageDto {
  const factory TeamPageDto({
    /// Team
    required TeamPublicationDto team,

    /// Page ID (TSID)
    required String id,

    /// Page title
    required String title,

    /// Page URL slug
    required String slug,

    /// Page content
    required MediaDto media,

    /// Visibility level
    required String visibility,

    /// Page order
    required int order,

    /// Whether the page is soft-deleted
    required bool deleted,

    /// What the caller may do with the page: edit, delete (never the about page), and the visibilities it may be saved with.
    required ContentPermissionsDto permissions,
  }) = _TeamPageDto;

  factory TeamPageDto.fromJson(Map<String, Object?> json) =>
      _$TeamPageDtoFromJson(json);
}
