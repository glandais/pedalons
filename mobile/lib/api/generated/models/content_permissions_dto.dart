// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'visibility.dart';

part 'content_permissions_dto.freezed.dart';
part 'content_permissions_dto.g.dart';

/// What the caller may do with this entity, computed by the server from the rules that guard the matching endpoints. A client shows or hides its controls from these fields alone, and never derives them from the team's visibility or the caller's role.
@Freezed()
abstract class ContentPermissionsDto with _$ContentPermissionsDto {
  const factory ContentPermissionsDto({
    /// Whether the caller may edit this entity (the update endpoints would accept it). For a trip stage, whether they may edit its trip, which a stage is written through. For the team's about page, whether they may edit it through the team update, the only way it is written.
    required bool canEdit,

    /// Whether the caller may delete this entity. For a trip stage, whether they may delete its trip.
    required bool canDelete,

    /// Whether search engines may index the entity's page: the rule of the sitemap — entity PUBLIC, team PUBLIC, published or cancelled, not hidden by moderation. False means the page must carry noindex. A trip stage carries its trip's answer.
    required bool indexable,

    /// Rides and trips only: whether the caller may register — a member of the team (or a platform admin), the entity published. On a detail it is exact about timing too: false once every group of the ride has left or the trip is finished, as the join endpoints answer. On list rows it does not look at timing, so it may be true on a row and false on the detail of the same entity. Never counts capacity: a full group still refuses. Absent on the other types.
    bool? canRegister,

    /// Whether the caller may read and write the comment thread: a member of the team or a platform admin, whatever the entity's visibility. Absent on the types that carry no comments (team pages, ads).
    bool? canComment,

    /// Rides and trips only: whether the caller may see who takes part (names, the participants endpoints). Same rule as canComment. When false, only the counts are sent. Absent on the other types.
    bool? canSeeParticipants,

    /// The visibilities this entity may be saved with, in the order of the Visibility enum; an editor hides its selector when there is only one. For a route used by a ride or a trip that is not TEAM (drafts included, deleted ones not), TEAM is left out: saving it as TEAM is refused with INCOMPATIBLE_VISIBILITY. That can leave the list empty, when the team accepts nothing but TEAM any more: the route cannot be saved until those usages go TEAM. Present on a detail only: absent on list rows, on embedded summaries, on the types without a visibility of their own (trip stages) and on the team's about page, whose visibility no endpoint sets. Clients that create read TeamDetailDto.allowedContentVisibilities instead.
    List<Visibility>? allowedVisibilities,
  }) = _ContentPermissionsDto;

  factory ContentPermissionsDto.fromJson(Map<String, Object?> json) =>
      _$ContentPermissionsDtoFromJson(json);
}
