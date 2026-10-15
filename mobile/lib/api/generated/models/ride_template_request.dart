// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'ride_template_group_request.dart';
import 'status.dart';
import 'visibility.dart';

part 'ride_template_request.freezed.dart';
part 'ride_template_request.g.dart';

/// Ride template request
@Freezed()
abstract class RideTemplateRequest with _$RideTemplateRequest {
  const factory RideTemplateRequest({
    /// Template name
    required String name,

    /// Template description (markdown)
    required String markdown,

    /// Visibility level
    required String visibility,

    /// Default status for rides created from this template
    required String status,

    /// Template groups
    required List<RideTemplateGroupRequest> groups,

    /// IDs (TSID) of the team's RIDE tags the template carries (copied onto the rides created from it), replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
    List<String>? tagIds,

    /// The number the next ride created from this template takes: a client titles it « name #nextNumber » and the creation of that ride (RideRequest.templateId) raises it by one. Null: the template numbers nothing.
    int? nextNumber,
  }) = _RideTemplateRequest;

  factory RideTemplateRequest.fromJson(Map<String, Object?> json) =>
      _$RideTemplateRequestFromJson(json);
}
