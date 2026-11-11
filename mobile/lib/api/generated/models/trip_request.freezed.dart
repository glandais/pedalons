// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TripRequest {

/// Trip name
 String get name;/// Trip media
 MediaDto get media;/// Trip start date/time: a wall time without offset, read in the trip's zone (first stage, else route, else team).
 String get dateTime;/// Trip status
 String get status;/// Visibility level
 String get visibility;/// Trip stages to create
 List<StageRequest> get stages;/// Overall route slug for the trip
 String? get routeSlug;/// Publication time (for scheduled publishing), a wall time in the trip's zone like dateTime.
 String? get publishAt;/// IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
 List<String>? get tagIds;/// When the trip is not TEAM and uses TEAM routes (its own, its stages'), the save is refused with INCOMPATIBLE_VISIBILITY, listing them. Replayed with true, it raises those routes to PUBLIC_UNLISTED in the same transaction, then saves. Omitted or false: refused as before.
 bool? get alignVisibility;
/// Create a copy of TripRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripRequestCopyWith<TripRequest> get copyWith => _$TripRequestCopyWithImpl<TripRequest>(this as TripRequest, _$identity);

  /// Serializes this TripRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TripRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripRequest&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&const DeepCollectionEquality().equals(other.stages, _this.stages)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.publishAt, _this.publishAt) || other.publishAt == _this.publishAt)&&const DeepCollectionEquality().equals(other.tagIds, _this.tagIds)&&(identical(other.alignVisibility, _this.alignVisibility) || other.alignVisibility == _this.alignVisibility));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TripRequest;
  return Object.hash(runtimeType,_this.name,_this.media,_this.dateTime,_this.status,_this.visibility,const DeepCollectionEquality().hash(_this.stages),_this.routeSlug,_this.publishAt,const DeepCollectionEquality().hash(_this.tagIds),_this.alignVisibility);
}

@override
String toString() {
  final _this = this as TripRequest;
  return 'TripRequest(name: ${_this.name}, media: ${_this.media}, dateTime: ${_this.dateTime}, status: ${_this.status}, visibility: ${_this.visibility}, stages: ${_this.stages}, routeSlug: ${_this.routeSlug}, publishAt: ${_this.publishAt}, tagIds: ${_this.tagIds}, alignVisibility: ${_this.alignVisibility})';
}


}

/// @nodoc
abstract mixin class $TripRequestCopyWith<$Res>  {
  factory $TripRequestCopyWith(TripRequest value, $Res Function(TripRequest) _then) = _$TripRequestCopyWithImpl;
@useResult
$Res call({
 String name, MediaDto media, String dateTime, String status, String visibility, List<StageRequest> stages, String? routeSlug, String? publishAt, List<String>? tagIds, bool? alignVisibility
});


$MediaDtoCopyWith<$Res> get media;

}
/// @nodoc
class _$TripRequestCopyWithImpl<$Res>
    implements $TripRequestCopyWith<$Res> {
  _$TripRequestCopyWithImpl(this._self, this._then);

  final TripRequest _self;
  final $Res Function(TripRequest) _then;

/// Create a copy of TripRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? media = null,Object? dateTime = null,Object? status = null,Object? visibility = null,Object? stages = null,Object? routeSlug = freezed,Object? publishAt = freezed,Object? tagIds = freezed,Object? alignVisibility = freezed,}) {
  return _then(TripRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,stages: null == stages ? _self.stages : stages // ignore: cast_nullable_to_non_nullable
as List<StageRequest>,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,tagIds: freezed == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>?,alignVisibility: freezed == alignVisibility ? _self.alignVisibility : alignVisibility // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of TripRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}


/// Adds pattern-matching-related methods to [TripRequest].
extension TripRequestPatterns on TripRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripRequest value)  $default,){
final _that = this;
switch (_that) {
case _TripRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripRequest value)?  $default,){
final _that = this;
switch (_that) {
case _TripRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  MediaDto media,  String dateTime,  String status,  String visibility,  List<StageRequest> stages,  String? routeSlug,  String? publishAt,  List<String>? tagIds,  bool? alignVisibility)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripRequest() when $default != null:
return $default(_that.name,_that.media,_that.dateTime,_that.status,_that.visibility,_that.stages,_that.routeSlug,_that.publishAt,_that.tagIds,_that.alignVisibility);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  MediaDto media,  String dateTime,  String status,  String visibility,  List<StageRequest> stages,  String? routeSlug,  String? publishAt,  List<String>? tagIds,  bool? alignVisibility)  $default,) {final _that = this;
switch (_that) {
case _TripRequest():
return $default(_that.name,_that.media,_that.dateTime,_that.status,_that.visibility,_that.stages,_that.routeSlug,_that.publishAt,_that.tagIds,_that.alignVisibility);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  MediaDto media,  String dateTime,  String status,  String visibility,  List<StageRequest> stages,  String? routeSlug,  String? publishAt,  List<String>? tagIds,  bool? alignVisibility)?  $default,) {final _that = this;
switch (_that) {
case _TripRequest() when $default != null:
return $default(_that.name,_that.media,_that.dateTime,_that.status,_that.visibility,_that.stages,_that.routeSlug,_that.publishAt,_that.tagIds,_that.alignVisibility);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripRequest implements TripRequest {
  const _TripRequest({required this.name, required this.media, required this.dateTime, required this.status, required this.visibility, required  List<StageRequest> stages, this.routeSlug, this.publishAt,  List<String>? tagIds, this.alignVisibility}): _stages = stages,_tagIds = tagIds;
  factory _TripRequest.fromJson(Map<String, dynamic> json) => _$TripRequestFromJson(json);

/// Trip name
@override final  String name;
/// Trip media
@override final  MediaDto media;
/// Trip start date/time: a wall time without offset, read in the trip's zone (first stage, else route, else team).
@override final  String dateTime;
/// Trip status
@override final  String status;
/// Visibility level
@override final  String visibility;
/// Trip stages to create
 final  List<StageRequest> _stages;
/// Trip stages to create
@override List<StageRequest> get stages {
  if (_stages is EqualUnmodifiableListView) return _stages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stages);
}

/// Overall route slug for the trip
@override final  String? routeSlug;
/// Publication time (for scheduled publishing), a wall time in the trip's zone like dateTime.
@override final  String? publishAt;
/// IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
 final  List<String>? _tagIds;
/// IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
@override List<String>? get tagIds {
  final value = _tagIds;
  if (value == null) return null;
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// When the trip is not TEAM and uses TEAM routes (its own, its stages'), the save is refused with INCOMPATIBLE_VISIBILITY, listing them. Replayed with true, it raises those routes to PUBLIC_UNLISTED in the same transaction, then saves. Omitted or false: refused as before.
@override final  bool? alignVisibility;

/// Create a copy of TripRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripRequestCopyWith<_TripRequest> get copyWith => __$TripRequestCopyWithImpl<_TripRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&const DeepCollectionEquality().equals(other.stages, _stages)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&const DeepCollectionEquality().equals(other.tagIds, _tagIds)&&(identical(other.alignVisibility, alignVisibility) || other.alignVisibility == alignVisibility));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,media,dateTime,status,visibility,const DeepCollectionEquality().hash(_stages),routeSlug,publishAt,const DeepCollectionEquality().hash(_tagIds),alignVisibility);
}

@override
String toString() {
    return 'TripRequest(name: $name, media: $media, dateTime: $dateTime, status: $status, visibility: $visibility, stages: $stages, routeSlug: $routeSlug, publishAt: $publishAt, tagIds: $tagIds, alignVisibility: $alignVisibility)';
}


}

/// @nodoc
abstract mixin class _$TripRequestCopyWith<$Res> implements $TripRequestCopyWith<$Res> {
  factory _$TripRequestCopyWith(_TripRequest value, $Res Function(_TripRequest) _then) = __$TripRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, MediaDto media, String dateTime, String status, String visibility, List<StageRequest> stages, String? routeSlug, String? publishAt, List<String>? tagIds, bool? alignVisibility
});


@override $MediaDtoCopyWith<$Res> get media;

}
/// @nodoc
class __$TripRequestCopyWithImpl<$Res>
    implements _$TripRequestCopyWith<$Res> {
  __$TripRequestCopyWithImpl(this._self, this._then);

  final _TripRequest _self;
  final $Res Function(_TripRequest) _then;

/// Create a copy of TripRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? media = null,Object? dateTime = null,Object? status = null,Object? visibility = null,Object? stages = null,Object? routeSlug = freezed,Object? publishAt = freezed,Object? tagIds = freezed,Object? alignVisibility = freezed,}) {
  return _then(_TripRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,stages: null == stages ? _self._stages : stages // ignore: cast_nullable_to_non_nullable
as List<StageRequest>,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,tagIds: freezed == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>?,alignVisibility: freezed == alignVisibility ? _self.alignVisibility : alignVisibility // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of TripRequest
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
