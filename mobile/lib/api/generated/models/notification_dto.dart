// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'notification_change.dart';
import 'notification_subject_type.dart';
import 'notification_type.dart';

part 'notification_dto.freezed.dart';
part 'notification_dto.g.dart';

/// A notification in the current user's inbox
@Freezed()
abstract class NotificationDto with _$NotificationDto {
  const factory NotificationDto({
    /// Notification identifier
    required String id,

    /// What happened
    required String type,

    /// Whether the user has read it
    required bool read,

    /// When it was created
    required String createdAt,

    /// Slug of the team it happened in
    required String teamSlug,

    /// Name of the team it happened in
    required String teamName,

    /// Kind of page the notification opens
    required String subjectType,

    /// Slug of the ride, trip, post or route — of the team, for TEAM
    required String subjectSlug,

    /// Name of the ride, trip, post or route — of the team, for TEAM
    required String subjectName,

    /// What changed, for RIDE_UPDATED; empty otherwise
    required List<NotificationChange> changes,

    /// Display name of whoever caused it, when someone did (a scheduled publication has no actor)
    String? actorName,

    /// Date of the ride or trip, publication date of a post. For a ride, the start of the recipient's own group when it concerns them: the group they are registered to (reminder, cancellation, change), joined (RIDE_JOINED) or lost (RIDE_GROUP_REMOVED); the ride's otherwise
    String? subjectDateTime,

    /// IANA zone subjectDateTime reads in — the subject's own, as RideDto.timezone: a rendezvous, shown in it with a mention when the reader's differs. Present when subjectDateTime is, except on notifications sent before 10.20.0, which read in the reader's zone
    String? subjectTimezone,

    /// A short quote: the comment, for COMMENT_REPLY and COMMENT_ON_MY_PUBLICATION; the name of the group joined, for RIDE_JOINED
    String? excerpt,
  }) = _NotificationDto;

  factory NotificationDto.fromJson(Map<String, Object?> json) =>
      _$NotificationDtoFromJson(json);
}
