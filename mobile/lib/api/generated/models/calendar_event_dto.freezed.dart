// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'calendar_event_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CalendarEventDto {

/// Event ID (TSID)
 String get id;/// Event title
 String get title;/// Event start date/time
 String get start;/// Is all-day event
 bool get allDay;/// Event type
 String get type;/// Team slug
 String get teamSlug;/// Team name
 String get teamName;/// Entity slug (ride or stage)
 String get entitySlug;/// Whether the current user is registered to this ride, or to the trip this stage belongs to. False for an anonymous caller.
 bool get registered;/// Publication status of the ride or stage
 String get status;/// IANA zone of the ride or stage, as RideDto.timezone / TripStageDto.timezone: start and end are rendezvous in it. The calendar grid itself stays in the reader's zone.
 String get timezone;/// Whether the ride or stage is over, computed by the server when the response is built: its end (or its start, when it has no end) has passed. Independent of status.
 bool get finished;/// Event end date/time: the end the server computes for a ride (its latest group at its pace, 3 hours when nothing tells) or for a trip stage (its route at its pace, likewise) — the same as RideDto.endDateTime. On an all-day stage it is still that instant: the stage occupies every day up to it.
 String? get end;/// Parent trip slug (for stages only)
 String? get tripSlug;/// Name of the meeting place, null when the ride or stage has no start place
 String? get startPlaceName;/// Distance in meters of the attached route, null when there is no route
 double? get distance;/// Total elevation gain in meters of the attached route, null when there is no route
 double? get elevationGain;/// Thumbnail image URL template (contains a {size} placeholder), light variant preferred. Falls back to the route's thumbnail when the ride or stage has none of its own. For a client that renders one picture and does not follow a colour scheme; prefer thumbnailLightUrl/thumbnailDarkUrl otherwise. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Light-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a dark variant. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailLightUrl;/// Dark-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a light variant. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailDarkUrl;/// Name of the ride group the current user joined. Null when not registered, and always null for trip stages, which have no groups.
 String? get groupName;
/// Create a copy of CalendarEventDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarEventDtoCopyWith<CalendarEventDto> get copyWith => _$CalendarEventDtoCopyWithImpl<CalendarEventDto>(this as CalendarEventDto, _$identity);

  /// Serializes this CalendarEventDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CalendarEventDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarEventDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.allDay, _this.allDay) || other.allDay == _this.allDay)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.teamName, _this.teamName) || other.teamName == _this.teamName)&&(identical(other.entitySlug, _this.entitySlug) || other.entitySlug == _this.entitySlug)&&(identical(other.registered, _this.registered) || other.registered == _this.registered)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.finished, _this.finished) || other.finished == _this.finished)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.tripSlug, _this.tripSlug) || other.tripSlug == _this.tripSlug)&&(identical(other.startPlaceName, _this.startPlaceName) || other.startPlaceName == _this.startPlaceName)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.thumbnailLightUrl, _this.thumbnailLightUrl) || other.thumbnailLightUrl == _this.thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, _this.thumbnailDarkUrl) || other.thumbnailDarkUrl == _this.thumbnailDarkUrl)&&(identical(other.groupName, _this.groupName) || other.groupName == _this.groupName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CalendarEventDto;
  return Object.hashAll([runtimeType,_this.id,_this.title,_this.start,_this.allDay,_this.type,_this.teamSlug,_this.teamName,_this.entitySlug,_this.registered,_this.status,_this.timezone,_this.finished,_this.end,_this.tripSlug,_this.startPlaceName,_this.distance,_this.elevationGain,_this.thumbnailUrl,_this.thumbnailLightUrl,_this.thumbnailDarkUrl,_this.groupName]);
}

@override
String toString() {
  final _this = this as CalendarEventDto;
  return 'CalendarEventDto(id: ${_this.id}, title: ${_this.title}, start: ${_this.start}, allDay: ${_this.allDay}, type: ${_this.type}, teamSlug: ${_this.teamSlug}, teamName: ${_this.teamName}, entitySlug: ${_this.entitySlug}, registered: ${_this.registered}, status: ${_this.status}, timezone: ${_this.timezone}, finished: ${_this.finished}, end: ${_this.end}, tripSlug: ${_this.tripSlug}, startPlaceName: ${_this.startPlaceName}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, thumbnailUrl: ${_this.thumbnailUrl}, thumbnailLightUrl: ${_this.thumbnailLightUrl}, thumbnailDarkUrl: ${_this.thumbnailDarkUrl}, groupName: ${_this.groupName})';
}


}

/// @nodoc
abstract mixin class $CalendarEventDtoCopyWith<$Res>  {
  factory $CalendarEventDtoCopyWith(CalendarEventDto value, $Res Function(CalendarEventDto) _then) = _$CalendarEventDtoCopyWithImpl;
@useResult
$Res call({
 String id, String title, String start, bool allDay, String type, String teamSlug, String teamName, String entitySlug, bool registered, String status, String timezone, bool finished, String? end, String? tripSlug, String? startPlaceName, double? distance, double? elevationGain, String? thumbnailUrl, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? groupName
});




}
/// @nodoc
class _$CalendarEventDtoCopyWithImpl<$Res>
    implements $CalendarEventDtoCopyWith<$Res> {
  _$CalendarEventDtoCopyWithImpl(this._self, this._then);

  final CalendarEventDto _self;
  final $Res Function(CalendarEventDto) _then;

/// Create a copy of CalendarEventDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? start = null,Object? allDay = null,Object? type = null,Object? teamSlug = null,Object? teamName = null,Object? entitySlug = null,Object? registered = null,Object? status = null,Object? timezone = null,Object? finished = null,Object? end = freezed,Object? tripSlug = freezed,Object? startPlaceName = freezed,Object? distance = freezed,Object? elevationGain = freezed,Object? thumbnailUrl = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? groupName = freezed,}) {
  return _then(CalendarEventDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,allDay: null == allDay ? _self.allDay : allDay // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,teamName: null == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String,entitySlug: null == entitySlug ? _self.entitySlug : entitySlug // ignore: cast_nullable_to_non_nullable
as String,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String?,tripSlug: freezed == tripSlug ? _self.tripSlug : tripSlug // ignore: cast_nullable_to_non_nullable
as String?,startPlaceName: freezed == startPlaceName ? _self.startPlaceName : startPlaceName // ignore: cast_nullable_to_non_nullable
as String?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,groupName: freezed == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CalendarEventDto].
extension CalendarEventDtoPatterns on CalendarEventDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarEventDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarEventDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarEventDto value)  $default,){
final _that = this;
switch (_that) {
case _CalendarEventDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarEventDto value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarEventDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String start,  bool allDay,  String type,  String teamSlug,  String teamName,  String entitySlug,  bool registered,  String status,  String timezone,  bool finished,  String? end,  String? tripSlug,  String? startPlaceName,  double? distance,  double? elevationGain,  String? thumbnailUrl,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? groupName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalendarEventDto() when $default != null:
return $default(_that.id,_that.title,_that.start,_that.allDay,_that.type,_that.teamSlug,_that.teamName,_that.entitySlug,_that.registered,_that.status,_that.timezone,_that.finished,_that.end,_that.tripSlug,_that.startPlaceName,_that.distance,_that.elevationGain,_that.thumbnailUrl,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.groupName);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String start,  bool allDay,  String type,  String teamSlug,  String teamName,  String entitySlug,  bool registered,  String status,  String timezone,  bool finished,  String? end,  String? tripSlug,  String? startPlaceName,  double? distance,  double? elevationGain,  String? thumbnailUrl,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? groupName)  $default,) {final _that = this;
switch (_that) {
case _CalendarEventDto():
return $default(_that.id,_that.title,_that.start,_that.allDay,_that.type,_that.teamSlug,_that.teamName,_that.entitySlug,_that.registered,_that.status,_that.timezone,_that.finished,_that.end,_that.tripSlug,_that.startPlaceName,_that.distance,_that.elevationGain,_that.thumbnailUrl,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.groupName);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String start,  bool allDay,  String type,  String teamSlug,  String teamName,  String entitySlug,  bool registered,  String status,  String timezone,  bool finished,  String? end,  String? tripSlug,  String? startPlaceName,  double? distance,  double? elevationGain,  String? thumbnailUrl,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? groupName)?  $default,) {final _that = this;
switch (_that) {
case _CalendarEventDto() when $default != null:
return $default(_that.id,_that.title,_that.start,_that.allDay,_that.type,_that.teamSlug,_that.teamName,_that.entitySlug,_that.registered,_that.status,_that.timezone,_that.finished,_that.end,_that.tripSlug,_that.startPlaceName,_that.distance,_that.elevationGain,_that.thumbnailUrl,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.groupName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CalendarEventDto implements CalendarEventDto {
  const _CalendarEventDto({required this.id, required this.title, required this.start, required this.allDay, required this.type, required this.teamSlug, required this.teamName, required this.entitySlug, required this.registered, required this.status, required this.timezone, required this.finished, this.end, this.tripSlug, this.startPlaceName, this.distance, this.elevationGain, this.thumbnailUrl, this.thumbnailLightUrl, this.thumbnailDarkUrl, this.groupName});
  factory _CalendarEventDto.fromJson(Map<String, dynamic> json) => _$CalendarEventDtoFromJson(json);

/// Event ID (TSID)
@override final  String id;
/// Event title
@override final  String title;
/// Event start date/time
@override final  String start;
/// Is all-day event
@override final  bool allDay;
/// Event type
@override final  String type;
/// Team slug
@override final  String teamSlug;
/// Team name
@override final  String teamName;
/// Entity slug (ride or stage)
@override final  String entitySlug;
/// Whether the current user is registered to this ride, or to the trip this stage belongs to. False for an anonymous caller.
@override final  bool registered;
/// Publication status of the ride or stage
@override final  String status;
/// IANA zone of the ride or stage, as RideDto.timezone / TripStageDto.timezone: start and end are rendezvous in it. The calendar grid itself stays in the reader's zone.
@override final  String timezone;
/// Whether the ride or stage is over, computed by the server when the response is built: its end (or its start, when it has no end) has passed. Independent of status.
@override final  bool finished;
/// Event end date/time: the end the server computes for a ride (its latest group at its pace, 3 hours when nothing tells) or for a trip stage (its route at its pace, likewise) — the same as RideDto.endDateTime. On an all-day stage it is still that instant: the stage occupies every day up to it.
@override final  String? end;
/// Parent trip slug (for stages only)
@override final  String? tripSlug;
/// Name of the meeting place, null when the ride or stage has no start place
@override final  String? startPlaceName;
/// Distance in meters of the attached route, null when there is no route
@override final  double? distance;
/// Total elevation gain in meters of the attached route, null when there is no route
@override final  double? elevationGain;
/// Thumbnail image URL template (contains a {size} placeholder), light variant preferred. Falls back to the route's thumbnail when the ride or stage has none of its own. For a client that renders one picture and does not follow a colour scheme; prefer thumbnailLightUrl/thumbnailDarkUrl otherwise. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Light-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a dark variant. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailLightUrl;
/// Dark-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a light variant. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailDarkUrl;
/// Name of the ride group the current user joined. Null when not registered, and always null for trip stages, which have no groups.
@override final  String? groupName;

/// Create a copy of CalendarEventDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarEventDtoCopyWith<_CalendarEventDto> get copyWith => __$CalendarEventDtoCopyWithImpl<_CalendarEventDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CalendarEventDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarEventDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.start, start) || other.start == start)&&(identical(other.allDay, allDay) || other.allDay == allDay)&&(identical(other.type, type) || other.type == type)&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.teamName, teamName) || other.teamName == teamName)&&(identical(other.entitySlug, entitySlug) || other.entitySlug == entitySlug)&&(identical(other.registered, registered) || other.registered == registered)&&(identical(other.status, status) || other.status == status)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.end, end) || other.end == end)&&(identical(other.tripSlug, tripSlug) || other.tripSlug == tripSlug)&&(identical(other.startPlaceName, startPlaceName) || other.startPlaceName == startPlaceName)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.thumbnailLightUrl, thumbnailLightUrl) || other.thumbnailLightUrl == thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, thumbnailDarkUrl) || other.thumbnailDarkUrl == thumbnailDarkUrl)&&(identical(other.groupName, groupName) || other.groupName == groupName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,title,start,allDay,type,teamSlug,teamName,entitySlug,registered,status,timezone,finished,end,tripSlug,startPlaceName,distance,elevationGain,thumbnailUrl,thumbnailLightUrl,thumbnailDarkUrl,groupName]);
}

@override
String toString() {
    return 'CalendarEventDto(id: $id, title: $title, start: $start, allDay: $allDay, type: $type, teamSlug: $teamSlug, teamName: $teamName, entitySlug: $entitySlug, registered: $registered, status: $status, timezone: $timezone, finished: $finished, end: $end, tripSlug: $tripSlug, startPlaceName: $startPlaceName, distance: $distance, elevationGain: $elevationGain, thumbnailUrl: $thumbnailUrl, thumbnailLightUrl: $thumbnailLightUrl, thumbnailDarkUrl: $thumbnailDarkUrl, groupName: $groupName)';
}


}

/// @nodoc
abstract mixin class _$CalendarEventDtoCopyWith<$Res> implements $CalendarEventDtoCopyWith<$Res> {
  factory _$CalendarEventDtoCopyWith(_CalendarEventDto value, $Res Function(_CalendarEventDto) _then) = __$CalendarEventDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String start, bool allDay, String type, String teamSlug, String teamName, String entitySlug, bool registered, String status, String timezone, bool finished, String? end, String? tripSlug, String? startPlaceName, double? distance, double? elevationGain, String? thumbnailUrl, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? groupName
});




}
/// @nodoc
class __$CalendarEventDtoCopyWithImpl<$Res>
    implements _$CalendarEventDtoCopyWith<$Res> {
  __$CalendarEventDtoCopyWithImpl(this._self, this._then);

  final _CalendarEventDto _self;
  final $Res Function(_CalendarEventDto) _then;

/// Create a copy of CalendarEventDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? start = null,Object? allDay = null,Object? type = null,Object? teamSlug = null,Object? teamName = null,Object? entitySlug = null,Object? registered = null,Object? status = null,Object? timezone = null,Object? finished = null,Object? end = freezed,Object? tripSlug = freezed,Object? startPlaceName = freezed,Object? distance = freezed,Object? elevationGain = freezed,Object? thumbnailUrl = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? groupName = freezed,}) {
  return _then(_CalendarEventDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,allDay: null == allDay ? _self.allDay : allDay // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,teamName: null == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String,entitySlug: null == entitySlug ? _self.entitySlug : entitySlug // ignore: cast_nullable_to_non_nullable
as String,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String?,tripSlug: freezed == tripSlug ? _self.tripSlug : tripSlug // ignore: cast_nullable_to_non_nullable
as String?,startPlaceName: freezed == startPlaceName ? _self.startPlaceName : startPlaceName // ignore: cast_nullable_to_non_nullable
as String?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,groupName: freezed == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
