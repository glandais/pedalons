// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationDto {

/// Notification identifier
 String get id;/// What happened
 String get type;/// Whether the user has read it
 bool get read;/// When it was created
 String get createdAt;/// Slug of the team it happened in
 String get teamSlug;/// Name of the team it happened in
 String get teamName;/// Kind of page the notification opens
 String get subjectType;/// Slug of the ride, trip, post or route — of the team, for TEAM
 String get subjectSlug;/// Name of the ride, trip, post or route — of the team, for TEAM
 String get subjectName;/// What changed, for RIDE_UPDATED; empty otherwise
 List<NotificationChange> get changes;/// Display name of whoever caused it, when someone did (a scheduled publication has no actor)
 String? get actorName;/// Date of the ride or trip, publication date of a post. For a ride, the start of the recipient's own group when it concerns them: the group they are registered to (reminder, cancellation, change), joined (RIDE_JOINED) or lost (RIDE_GROUP_REMOVED); the ride's otherwise
 String? get subjectDateTime;/// IANA zone subjectDateTime reads in — the subject's own, as RideDto.timezone: a rendezvous, shown in it with a mention when the reader's differs. Present when subjectDateTime is, except on notifications sent before 10.20.0, which read in the reader's zone
 String? get subjectTimezone;/// A short quote: the comment, for COMMENT_REPLY and COMMENT_ON_MY_PUBLICATION; the name of the group joined, for RIDE_JOINED
 String? get excerpt;
/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationDtoCopyWith<NotificationDto> get copyWith => _$NotificationDtoCopyWithImpl<NotificationDto>(this as NotificationDto, _$identity);

  /// Serializes this NotificationDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as NotificationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.read, _this.read) || other.read == _this.read)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.teamName, _this.teamName) || other.teamName == _this.teamName)&&(identical(other.subjectType, _this.subjectType) || other.subjectType == _this.subjectType)&&(identical(other.subjectSlug, _this.subjectSlug) || other.subjectSlug == _this.subjectSlug)&&(identical(other.subjectName, _this.subjectName) || other.subjectName == _this.subjectName)&&const DeepCollectionEquality().equals(other.changes, _this.changes)&&(identical(other.actorName, _this.actorName) || other.actorName == _this.actorName)&&(identical(other.subjectDateTime, _this.subjectDateTime) || other.subjectDateTime == _this.subjectDateTime)&&(identical(other.subjectTimezone, _this.subjectTimezone) || other.subjectTimezone == _this.subjectTimezone)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as NotificationDto;
  return Object.hash(runtimeType,_this.id,_this.type,_this.read,_this.createdAt,_this.teamSlug,_this.teamName,_this.subjectType,_this.subjectSlug,_this.subjectName,const DeepCollectionEquality().hash(_this.changes),_this.actorName,_this.subjectDateTime,_this.subjectTimezone,_this.excerpt);
}

@override
String toString() {
  final _this = this as NotificationDto;
  return 'NotificationDto(id: ${_this.id}, type: ${_this.type}, read: ${_this.read}, createdAt: ${_this.createdAt}, teamSlug: ${_this.teamSlug}, teamName: ${_this.teamName}, subjectType: ${_this.subjectType}, subjectSlug: ${_this.subjectSlug}, subjectName: ${_this.subjectName}, changes: ${_this.changes}, actorName: ${_this.actorName}, subjectDateTime: ${_this.subjectDateTime}, subjectTimezone: ${_this.subjectTimezone}, excerpt: ${_this.excerpt})';
}


}

/// @nodoc
abstract mixin class $NotificationDtoCopyWith<$Res>  {
  factory $NotificationDtoCopyWith(NotificationDto value, $Res Function(NotificationDto) _then) = _$NotificationDtoCopyWithImpl;
@useResult
$Res call({
 String id, String type, bool read, String createdAt, String teamSlug, String teamName, String subjectType, String subjectSlug, String subjectName, List<NotificationChange> changes, String? actorName, String? subjectDateTime, String? subjectTimezone, String? excerpt
});




}
/// @nodoc
class _$NotificationDtoCopyWithImpl<$Res>
    implements $NotificationDtoCopyWith<$Res> {
  _$NotificationDtoCopyWithImpl(this._self, this._then);

  final NotificationDto _self;
  final $Res Function(NotificationDto) _then;

/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? read = null,Object? createdAt = null,Object? teamSlug = null,Object? teamName = null,Object? subjectType = null,Object? subjectSlug = null,Object? subjectName = null,Object? changes = null,Object? actorName = freezed,Object? subjectDateTime = freezed,Object? subjectTimezone = freezed,Object? excerpt = freezed,}) {
  return _then(NotificationDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,teamName: null == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String,subjectType: null == subjectType ? _self.subjectType : subjectType // ignore: cast_nullable_to_non_nullable
as String,subjectSlug: null == subjectSlug ? _self.subjectSlug : subjectSlug // ignore: cast_nullable_to_non_nullable
as String,subjectName: null == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String,changes: null == changes ? _self.changes : changes // ignore: cast_nullable_to_non_nullable
as List<NotificationChange>,actorName: freezed == actorName ? _self.actorName : actorName // ignore: cast_nullable_to_non_nullable
as String?,subjectDateTime: freezed == subjectDateTime ? _self.subjectDateTime : subjectDateTime // ignore: cast_nullable_to_non_nullable
as String?,subjectTimezone: freezed == subjectTimezone ? _self.subjectTimezone : subjectTimezone // ignore: cast_nullable_to_non_nullable
as String?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationDto].
extension NotificationDtoPatterns on NotificationDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationDto value)  $default,){
final _that = this;
switch (_that) {
case _NotificationDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationDto value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  bool read,  String createdAt,  String teamSlug,  String teamName,  String subjectType,  String subjectSlug,  String subjectName,  List<NotificationChange> changes,  String? actorName,  String? subjectDateTime,  String? subjectTimezone,  String? excerpt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
return $default(_that.id,_that.type,_that.read,_that.createdAt,_that.teamSlug,_that.teamName,_that.subjectType,_that.subjectSlug,_that.subjectName,_that.changes,_that.actorName,_that.subjectDateTime,_that.subjectTimezone,_that.excerpt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  bool read,  String createdAt,  String teamSlug,  String teamName,  String subjectType,  String subjectSlug,  String subjectName,  List<NotificationChange> changes,  String? actorName,  String? subjectDateTime,  String? subjectTimezone,  String? excerpt)  $default,) {final _that = this;
switch (_that) {
case _NotificationDto():
return $default(_that.id,_that.type,_that.read,_that.createdAt,_that.teamSlug,_that.teamName,_that.subjectType,_that.subjectSlug,_that.subjectName,_that.changes,_that.actorName,_that.subjectDateTime,_that.subjectTimezone,_that.excerpt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  bool read,  String createdAt,  String teamSlug,  String teamName,  String subjectType,  String subjectSlug,  String subjectName,  List<NotificationChange> changes,  String? actorName,  String? subjectDateTime,  String? subjectTimezone,  String? excerpt)?  $default,) {final _that = this;
switch (_that) {
case _NotificationDto() when $default != null:
return $default(_that.id,_that.type,_that.read,_that.createdAt,_that.teamSlug,_that.teamName,_that.subjectType,_that.subjectSlug,_that.subjectName,_that.changes,_that.actorName,_that.subjectDateTime,_that.subjectTimezone,_that.excerpt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationDto implements NotificationDto {
  const _NotificationDto({required this.id, required this.type, required this.read, required this.createdAt, required this.teamSlug, required this.teamName, required this.subjectType, required this.subjectSlug, required this.subjectName, required  List<NotificationChange> changes, this.actorName, this.subjectDateTime, this.subjectTimezone, this.excerpt}): _changes = changes;
  factory _NotificationDto.fromJson(Map<String, dynamic> json) => _$NotificationDtoFromJson(json);

/// Notification identifier
@override final  String id;
/// What happened
@override final  String type;
/// Whether the user has read it
@override final  bool read;
/// When it was created
@override final  String createdAt;
/// Slug of the team it happened in
@override final  String teamSlug;
/// Name of the team it happened in
@override final  String teamName;
/// Kind of page the notification opens
@override final  String subjectType;
/// Slug of the ride, trip, post or route — of the team, for TEAM
@override final  String subjectSlug;
/// Name of the ride, trip, post or route — of the team, for TEAM
@override final  String subjectName;
/// What changed, for RIDE_UPDATED; empty otherwise
 final  List<NotificationChange> _changes;
/// What changed, for RIDE_UPDATED; empty otherwise
@override List<NotificationChange> get changes {
  if (_changes is EqualUnmodifiableListView) return _changes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changes);
}

/// Display name of whoever caused it, when someone did (a scheduled publication has no actor)
@override final  String? actorName;
/// Date of the ride or trip, publication date of a post. For a ride, the start of the recipient's own group when it concerns them: the group they are registered to (reminder, cancellation, change), joined (RIDE_JOINED) or lost (RIDE_GROUP_REMOVED); the ride's otherwise
@override final  String? subjectDateTime;
/// IANA zone subjectDateTime reads in — the subject's own, as RideDto.timezone: a rendezvous, shown in it with a mention when the reader's differs. Present when subjectDateTime is, except on notifications sent before 10.20.0, which read in the reader's zone
@override final  String? subjectTimezone;
/// A short quote: the comment, for COMMENT_REPLY and COMMENT_ON_MY_PUBLICATION; the name of the group joined, for RIDE_JOINED
@override final  String? excerpt;

/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationDtoCopyWith<_NotificationDto> get copyWith => __$NotificationDtoCopyWithImpl<_NotificationDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.read, read) || other.read == read)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.teamName, teamName) || other.teamName == teamName)&&(identical(other.subjectType, subjectType) || other.subjectType == subjectType)&&(identical(other.subjectSlug, subjectSlug) || other.subjectSlug == subjectSlug)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&const DeepCollectionEquality().equals(other.changes, _changes)&&(identical(other.actorName, actorName) || other.actorName == actorName)&&(identical(other.subjectDateTime, subjectDateTime) || other.subjectDateTime == subjectDateTime)&&(identical(other.subjectTimezone, subjectTimezone) || other.subjectTimezone == subjectTimezone)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,type,read,createdAt,teamSlug,teamName,subjectType,subjectSlug,subjectName,const DeepCollectionEquality().hash(_changes),actorName,subjectDateTime,subjectTimezone,excerpt);
}

@override
String toString() {
    return 'NotificationDto(id: $id, type: $type, read: $read, createdAt: $createdAt, teamSlug: $teamSlug, teamName: $teamName, subjectType: $subjectType, subjectSlug: $subjectSlug, subjectName: $subjectName, changes: $changes, actorName: $actorName, subjectDateTime: $subjectDateTime, subjectTimezone: $subjectTimezone, excerpt: $excerpt)';
}


}

/// @nodoc
abstract mixin class _$NotificationDtoCopyWith<$Res> implements $NotificationDtoCopyWith<$Res> {
  factory _$NotificationDtoCopyWith(_NotificationDto value, $Res Function(_NotificationDto) _then) = __$NotificationDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, bool read, String createdAt, String teamSlug, String teamName, String subjectType, String subjectSlug, String subjectName, List<NotificationChange> changes, String? actorName, String? subjectDateTime, String? subjectTimezone, String? excerpt
});




}
/// @nodoc
class __$NotificationDtoCopyWithImpl<$Res>
    implements _$NotificationDtoCopyWith<$Res> {
  __$NotificationDtoCopyWithImpl(this._self, this._then);

  final _NotificationDto _self;
  final $Res Function(_NotificationDto) _then;

/// Create a copy of NotificationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? read = null,Object? createdAt = null,Object? teamSlug = null,Object? teamName = null,Object? subjectType = null,Object? subjectSlug = null,Object? subjectName = null,Object? changes = null,Object? actorName = freezed,Object? subjectDateTime = freezed,Object? subjectTimezone = freezed,Object? excerpt = freezed,}) {
  return _then(_NotificationDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,teamName: null == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String,subjectType: null == subjectType ? _self.subjectType : subjectType // ignore: cast_nullable_to_non_nullable
as String,subjectSlug: null == subjectSlug ? _self.subjectSlug : subjectSlug // ignore: cast_nullable_to_non_nullable
as String,subjectName: null == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String,changes: null == changes ? _self._changes : changes // ignore: cast_nullable_to_non_nullable
as List<NotificationChange>,actorName: freezed == actorName ? _self.actorName : actorName // ignore: cast_nullable_to_non_nullable
as String?,subjectDateTime: freezed == subjectDateTime ? _self.subjectDateTime : subjectDateTime // ignore: cast_nullable_to_non_nullable
as String?,subjectTimezone: freezed == subjectTimezone ? _self.subjectTimezone : subjectTimezone // ignore: cast_nullable_to_non_nullable
as String?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
