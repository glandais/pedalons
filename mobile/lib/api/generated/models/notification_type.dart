// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum NotificationType {
  @JsonValue('RIDE_PUBLISHED')
  ridePublished('RIDE_PUBLISHED'),
  @JsonValue('RIDE_CANCELLED')
  rideCancelled('RIDE_CANCELLED'),
  @JsonValue('TRIP_PUBLISHED')
  tripPublished('TRIP_PUBLISHED'),
  @JsonValue('TRIP_CANCELLED')
  tripCancelled('TRIP_CANCELLED'),
  @JsonValue('POST_PUBLISHED')
  postPublished('POST_PUBLISHED'),
  @JsonValue('COMMENT_REPLY')
  commentReply('COMMENT_REPLY'),
  @JsonValue('RIDE_REMINDER')
  rideReminder('RIDE_REMINDER'),
  @JsonValue('RIDE_UPDATED')
  rideUpdated('RIDE_UPDATED'),
  @JsonValue('RIDE_GROUP_REMOVED')
  rideGroupRemoved('RIDE_GROUP_REMOVED'),
  @JsonValue('RIDE_JOINED')
  rideJoined('RIDE_JOINED'),
  @JsonValue('COMMENT_ON_MY_PUBLICATION')
  commentOnMyPublication('COMMENT_ON_MY_PUBLICATION'),
  @JsonValue('TEAM_INVITATION')
  teamInvitation('TEAM_INVITATION'),
  @JsonValue('CONTENT_REPORTED')
  contentReported('CONTENT_REPORTED'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const NotificationType(this.json);

  factory NotificationType.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<NotificationType> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
