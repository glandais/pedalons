// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'ride_template_group_dto.dart';
import 'status.dart';
import 'tag_dto.dart';
import 'team_publication_dto.dart';
import 'visibility.dart';

part 'ride_template_dto.freezed.dart';
part 'ride_template_dto.g.dart';

/// Ride template response
@Freezed()
abstract class RideTemplateDto with _$RideTemplateDto {
  const factory RideTemplateDto({
    /// Team
    required TeamPublicationDto team,

    /// Template ID (TSID)
    required String id,

    /// Template slug
    required String slug,

    /// Template name
    required String name,

    /// Template description (markdown)
    required String markdown,

    /// Visibility level
    required String visibility,

    /// Default status
    required String status,

    /// Creation timestamp
    required String createdAt,

    /// Last update timestamp
    required String updatedAt,

    /// Number of groups
    required int groupCount,

    /// Template groups
    required List<RideTemplateGroupDto> groups,

    /// The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after.
    required List<TagDto> tags,

    /// The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing.
    int? nextNumber,
  }) = _RideTemplateDto;

  factory RideTemplateDto.fromJson(Map<String, Object?> json) =>
      _$RideTemplateDtoFromJson(json);
}
