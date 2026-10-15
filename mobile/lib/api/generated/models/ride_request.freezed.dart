// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideRequest {

/// Ride name
 String get name;/// Ride media
 MediaDto get media;/// Ride date/time: a wall time without offset, read in the ride's zone (start place, else route, else team).
 String get dateTime;/// Ride status
 String get status;/// Visibility level
 String get visibility;/// Ride groups to create
 List<GroupRequest> get groups;/// Route slug
 String? get routeSlug;/// Start place ID (TSID)
 String? get startPlaceId;/// End place ID (TSID)
 String? get endPlaceId;/// Publication time (for scheduled publishing), a wall time in the ride's zone like dateTime.
 String? get publishAt;/// IDs (TSID) of the team's RIDE tags the ride carries, replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
 List<String>? get tagIds;/// ID (TSID) of the team's template the ride is created from. On a creation, raises the template's nextNumber by one when it has one; ignored on an update, and when the template no longer exists.
 String? get templateId;
/// Create a copy of RideRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideRequestCopyWith<RideRequest> get copyWith => _$RideRequestCopyWithImpl<RideRequest>(this as RideRequest, _$identity);

  /// Serializes this RideRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RideRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideRequest&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.startPlaceId, _this.startPlaceId) || other.startPlaceId == _this.startPlaceId)&&(identical(other.endPlaceId, _this.endPlaceId) || other.endPlaceId == _this.endPlaceId)&&(identical(other.publishAt, _this.publishAt) || other.publishAt == _this.publishAt)&&const DeepCollectionEquality().equals(other.tagIds, _this.tagIds)&&(identical(other.templateId, _this.templateId) || other.templateId == _this.templateId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RideRequest;
  return Object.hash(runtimeType,_this.name,_this.media,_this.dateTime,_this.status,_this.visibility,const DeepCollectionEquality().hash(_this.groups),_this.routeSlug,_this.startPlaceId,_this.endPlaceId,_this.publishAt,const DeepCollectionEquality().hash(_this.tagIds),_this.templateId);
}

@override
String toString() {
  final _this = this as RideRequest;
  return 'RideRequest(name: ${_this.name}, media: ${_this.media}, dateTime: ${_this.dateTime}, status: ${_this.status}, visibility: ${_this.visibility}, groups: ${_this.groups}, routeSlug: ${_this.routeSlug}, startPlaceId: ${_this.startPlaceId}, endPlaceId: ${_this.endPlaceId}, publishAt: ${_this.publishAt}, tagIds: ${_this.tagIds}, templateId: ${_this.templateId})';
}


}

/// @nodoc
abstract mixin class $RideRequestCopyWith<$Res>  {
  factory $RideRequestCopyWith(RideRequest value, $Res Function(RideRequest) _then) = _$RideRequestCopyWithImpl;
@useResult
$Res call({
 String name, MediaDto media, String dateTime, String status, String visibility, List<GroupRequest> groups, String? routeSlug, String? startPlaceId, String? endPlaceId, String? publishAt, List<String>? tagIds, String? templateId
});


$MediaDtoCopyWith<$Res> get media;

}
/// @nodoc
class _$RideRequestCopyWithImpl<$Res>
    implements $RideRequestCopyWith<$Res> {
  _$RideRequestCopyWithImpl(this._self, this._then);

  final RideRequest _self;
  final $Res Function(RideRequest) _then;

/// Create a copy of RideRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? media = null,Object? dateTime = null,Object? status = null,Object? visibility = null,Object? groups = null,Object? routeSlug = freezed,Object? startPlaceId = freezed,Object? endPlaceId = freezed,Object? publishAt = freezed,Object? tagIds = freezed,Object? templateId = freezed,}) {
  return _then(RideRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<GroupRequest>,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,startPlaceId: freezed == startPlaceId ? _self.startPlaceId : startPlaceId // ignore: cast_nullable_to_non_nullable
as String?,endPlaceId: freezed == endPlaceId ? _self.endPlaceId : endPlaceId // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,tagIds: freezed == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>?,templateId: freezed == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of RideRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}


/// Adds pattern-matching-related methods to [RideRequest].
extension RideRequestPatterns on RideRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideRequest value)  $default,){
final _that = this;
switch (_that) {
case _RideRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RideRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  MediaDto media,  String dateTime,  String status,  String visibility,  List<GroupRequest> groups,  String? routeSlug,  String? startPlaceId,  String? endPlaceId,  String? publishAt,  List<String>? tagIds,  String? templateId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideRequest() when $default != null:
return $default(_that.name,_that.media,_that.dateTime,_that.status,_that.visibility,_that.groups,_that.routeSlug,_that.startPlaceId,_that.endPlaceId,_that.publishAt,_that.tagIds,_that.templateId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  MediaDto media,  String dateTime,  String status,  String visibility,  List<GroupRequest> groups,  String? routeSlug,  String? startPlaceId,  String? endPlaceId,  String? publishAt,  List<String>? tagIds,  String? templateId)  $default,) {final _that = this;
switch (_that) {
case _RideRequest():
return $default(_that.name,_that.media,_that.dateTime,_that.status,_that.visibility,_that.groups,_that.routeSlug,_that.startPlaceId,_that.endPlaceId,_that.publishAt,_that.tagIds,_that.templateId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  MediaDto media,  String dateTime,  String status,  String visibility,  List<GroupRequest> groups,  String? routeSlug,  String? startPlaceId,  String? endPlaceId,  String? publishAt,  List<String>? tagIds,  String? templateId)?  $default,) {final _that = this;
switch (_that) {
case _RideRequest() when $default != null:
return $default(_that.name,_that.media,_that.dateTime,_that.status,_that.visibility,_that.groups,_that.routeSlug,_that.startPlaceId,_that.endPlaceId,_that.publishAt,_that.tagIds,_that.templateId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideRequest implements RideRequest {
  const _RideRequest({required this.name, required this.media, required this.dateTime, required this.status, required this.visibility, required  List<GroupRequest> groups, this.routeSlug, this.startPlaceId, this.endPlaceId, this.publishAt,  List<String>? tagIds, this.templateId}): _groups = groups,_tagIds = tagIds;
  factory _RideRequest.fromJson(Map<String, dynamic> json) => _$RideRequestFromJson(json);

/// Ride name
@override final  String name;
/// Ride media
@override final  MediaDto media;
/// Ride date/time: a wall time without offset, read in the ride's zone (start place, else route, else team).
@override final  String dateTime;
/// Ride status
@override final  String status;
/// Visibility level
@override final  String visibility;
/// Ride groups to create
 final  List<GroupRequest> _groups;
/// Ride groups to create
@override List<GroupRequest> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

/// Route slug
@override final  String? routeSlug;
/// Start place ID (TSID)
@override final  String? startPlaceId;
/// End place ID (TSID)
@override final  String? endPlaceId;
/// Publication time (for scheduled publishing), a wall time in the ride's zone like dateTime.
@override final  String? publishAt;
/// IDs (TSID) of the team's RIDE tags the ride carries, replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
 final  List<String>? _tagIds;
/// IDs (TSID) of the team's RIDE tags the ride carries, replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
@override List<String>? get tagIds {
  final value = _tagIds;
  if (value == null) return null;
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// ID (TSID) of the team's template the ride is created from. On a creation, raises the template's nextNumber by one when it has one; ignored on an update, and when the template no longer exists.
@override final  String? templateId;

/// Create a copy of RideRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideRequestCopyWith<_RideRequest> get copyWith => __$RideRequestCopyWithImpl<_RideRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&const DeepCollectionEquality().equals(other.groups, _groups)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.startPlaceId, startPlaceId) || other.startPlaceId == startPlaceId)&&(identical(other.endPlaceId, endPlaceId) || other.endPlaceId == endPlaceId)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&const DeepCollectionEquality().equals(other.tagIds, _tagIds)&&(identical(other.templateId, templateId) || other.templateId == templateId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,media,dateTime,status,visibility,const DeepCollectionEquality().hash(_groups),routeSlug,startPlaceId,endPlaceId,publishAt,const DeepCollectionEquality().hash(_tagIds),templateId);
}

@override
String toString() {
    return 'RideRequest(name: $name, media: $media, dateTime: $dateTime, status: $status, visibility: $visibility, groups: $groups, routeSlug: $routeSlug, startPlaceId: $startPlaceId, endPlaceId: $endPlaceId, publishAt: $publishAt, tagIds: $tagIds, templateId: $templateId)';
}


}

/// @nodoc
abstract mixin class _$RideRequestCopyWith<$Res> implements $RideRequestCopyWith<$Res> {
  factory _$RideRequestCopyWith(_RideRequest value, $Res Function(_RideRequest) _then) = __$RideRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, MediaDto media, String dateTime, String status, String visibility, List<GroupRequest> groups, String? routeSlug, String? startPlaceId, String? endPlaceId, String? publishAt, List<String>? tagIds, String? templateId
});


@override $MediaDtoCopyWith<$Res> get media;

}
/// @nodoc
class __$RideRequestCopyWithImpl<$Res>
    implements _$RideRequestCopyWith<$Res> {
  __$RideRequestCopyWithImpl(this._self, this._then);

  final _RideRequest _self;
  final $Res Function(_RideRequest) _then;

/// Create a copy of RideRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? media = null,Object? dateTime = null,Object? status = null,Object? visibility = null,Object? groups = null,Object? routeSlug = freezed,Object? startPlaceId = freezed,Object? endPlaceId = freezed,Object? publishAt = freezed,Object? tagIds = freezed,Object? templateId = freezed,}) {
  return _then(_RideRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<GroupRequest>,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,startPlaceId: freezed == startPlaceId ? _self.startPlaceId : startPlaceId // ignore: cast_nullable_to_non_nullable
as String?,endPlaceId: freezed == endPlaceId ? _self.endPlaceId : endPlaceId // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,tagIds: freezed == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>?,templateId: freezed == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of RideRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}

// dart format on
