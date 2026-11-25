// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum EntityType {
  @JsonValue('TEAM')
  team('TEAM'),
  @JsonValue('USER')
  user('USER'),
  @JsonValue('USER_TEAM')
  userTeam('USER_TEAM'),
  @JsonValue('RIDE_TEMPLATE')
  rideTemplate('RIDE_TEMPLATE'),
  @JsonValue('RIDE_TEMPLATE_GROUP')
  rideTemplateGroup('RIDE_TEMPLATE_GROUP'),
  @JsonValue('PLACE')
  place('PLACE'),
  @JsonValue('COMMENT')
  comment('COMMENT'),
  @JsonValue('ASSET')
  asset('ASSET'),
  @JsonValue('TRIP')
  trip('TRIP'),
  @JsonValue('TRIP_STAGE')
  tripStage('TRIP_STAGE'),
  @JsonValue('ROUTE')
  route('ROUTE'),
  @JsonValue('RIDE')
  ride('RIDE'),
  @JsonValue('RIDE_GROUP')
  rideGroup('RIDE_GROUP'),
  @JsonValue('AD')
  ad('AD'),
  @JsonValue('POST')
  post('POST'),
  @JsonValue('TEAM_PAGE')
  teamPage('TEAM_PAGE'),
  @JsonValue('CALENDAR')
  calendar('CALENDAR'),
  @JsonValue('TAG')
  tag('TAG'),
  @JsonValue('PUBLICATION')
  publication('PUBLICATION'),
  @JsonValue('ANY')
  any('ANY'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const EntityType(this.json);

  factory EntityType.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<EntityType> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
