// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'thumbnail_catch_up_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ThumbnailCatchUpStatus {

/// Current version of the thumbnail drawing
 int get version;/// Whether the scheduled catch-up is switched on
 bool get enabled;/// Entities the catch-up redraws per hour, per backend
 int get perHour;/// Entities with thumbnails drawn before the current version that the catch-up still has to redraw, those waiting for a retry included
 int get behind;/// Among the entities behind, those waiting for the next attempt
 int get waiting;/// Entities the catch-up gave up on after repeated failures
 int get givenUp;
/// Create a copy of ThumbnailCatchUpStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThumbnailCatchUpStatusCopyWith<ThumbnailCatchUpStatus> get copyWith => _$ThumbnailCatchUpStatusCopyWithImpl<ThumbnailCatchUpStatus>(this as ThumbnailCatchUpStatus, _$identity);

  /// Serializes this ThumbnailCatchUpStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ThumbnailCatchUpStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThumbnailCatchUpStatus&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.perHour, _this.perHour) || other.perHour == _this.perHour)&&(identical(other.behind, _this.behind) || other.behind == _this.behind)&&(identical(other.waiting, _this.waiting) || other.waiting == _this.waiting)&&(identical(other.givenUp, _this.givenUp) || other.givenUp == _this.givenUp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ThumbnailCatchUpStatus;
  return Object.hash(runtimeType,_this.version,_this.enabled,_this.perHour,_this.behind,_this.waiting,_this.givenUp);
}

@override
String toString() {
  final _this = this as ThumbnailCatchUpStatus;
  return 'ThumbnailCatchUpStatus(version: ${_this.version}, enabled: ${_this.enabled}, perHour: ${_this.perHour}, behind: ${_this.behind}, waiting: ${_this.waiting}, givenUp: ${_this.givenUp})';
}


}

/// @nodoc
abstract mixin class $ThumbnailCatchUpStatusCopyWith<$Res>  {
  factory $ThumbnailCatchUpStatusCopyWith(ThumbnailCatchUpStatus value, $Res Function(ThumbnailCatchUpStatus) _then) = _$ThumbnailCatchUpStatusCopyWithImpl;
@useResult
$Res call({
 int version, bool enabled, int perHour, int behind, int waiting, int givenUp
});




}
/// @nodoc
class _$ThumbnailCatchUpStatusCopyWithImpl<$Res>
    implements $ThumbnailCatchUpStatusCopyWith<$Res> {
  _$ThumbnailCatchUpStatusCopyWithImpl(this._self, this._then);

  final ThumbnailCatchUpStatus _self;
  final $Res Function(ThumbnailCatchUpStatus) _then;

/// Create a copy of ThumbnailCatchUpStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? enabled = null,Object? perHour = null,Object? behind = null,Object? waiting = null,Object? givenUp = null,}) {
  return _then(ThumbnailCatchUpStatus(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,perHour: null == perHour ? _self.perHour : perHour // ignore: cast_nullable_to_non_nullable
as int,behind: null == behind ? _self.behind : behind // ignore: cast_nullable_to_non_nullable
as int,waiting: null == waiting ? _self.waiting : waiting // ignore: cast_nullable_to_non_nullable
as int,givenUp: null == givenUp ? _self.givenUp : givenUp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ThumbnailCatchUpStatus].
extension ThumbnailCatchUpStatusPatterns on ThumbnailCatchUpStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThumbnailCatchUpStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThumbnailCatchUpStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThumbnailCatchUpStatus value)  $default,){
final _that = this;
switch (_that) {
case _ThumbnailCatchUpStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThumbnailCatchUpStatus value)?  $default,){
final _that = this;
switch (_that) {
case _ThumbnailCatchUpStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  bool enabled,  int perHour,  int behind,  int waiting,  int givenUp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThumbnailCatchUpStatus() when $default != null:
return $default(_that.version,_that.enabled,_that.perHour,_that.behind,_that.waiting,_that.givenUp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  bool enabled,  int perHour,  int behind,  int waiting,  int givenUp)  $default,) {final _that = this;
switch (_that) {
case _ThumbnailCatchUpStatus():
return $default(_that.version,_that.enabled,_that.perHour,_that.behind,_that.waiting,_that.givenUp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  bool enabled,  int perHour,  int behind,  int waiting,  int givenUp)?  $default,) {final _that = this;
switch (_that) {
case _ThumbnailCatchUpStatus() when $default != null:
return $default(_that.version,_that.enabled,_that.perHour,_that.behind,_that.waiting,_that.givenUp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ThumbnailCatchUpStatus implements ThumbnailCatchUpStatus {
  const _ThumbnailCatchUpStatus({required this.version, required this.enabled, required this.perHour, required this.behind, required this.waiting, required this.givenUp});
  factory _ThumbnailCatchUpStatus.fromJson(Map<String, dynamic> json) => _$ThumbnailCatchUpStatusFromJson(json);

/// Current version of the thumbnail drawing
@override final  int version;
/// Whether the scheduled catch-up is switched on
@override final  bool enabled;
/// Entities the catch-up redraws per hour, per backend
@override final  int perHour;
/// Entities with thumbnails drawn before the current version that the catch-up still has to redraw, those waiting for a retry included
@override final  int behind;
/// Among the entities behind, those waiting for the next attempt
@override final  int waiting;
/// Entities the catch-up gave up on after repeated failures
@override final  int givenUp;

/// Create a copy of ThumbnailCatchUpStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThumbnailCatchUpStatusCopyWith<_ThumbnailCatchUpStatus> get copyWith => __$ThumbnailCatchUpStatusCopyWithImpl<_ThumbnailCatchUpStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ThumbnailCatchUpStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThumbnailCatchUpStatus&&(identical(other.version, version) || other.version == version)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.perHour, perHour) || other.perHour == perHour)&&(identical(other.behind, behind) || other.behind == behind)&&(identical(other.waiting, waiting) || other.waiting == waiting)&&(identical(other.givenUp, givenUp) || other.givenUp == givenUp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,enabled,perHour,behind,waiting,givenUp);
}

@override
String toString() {
    return 'ThumbnailCatchUpStatus(version: $version, enabled: $enabled, perHour: $perHour, behind: $behind, waiting: $waiting, givenUp: $givenUp)';
}


}

/// @nodoc
abstract mixin class _$ThumbnailCatchUpStatusCopyWith<$Res> implements $ThumbnailCatchUpStatusCopyWith<$Res> {
  factory _$ThumbnailCatchUpStatusCopyWith(_ThumbnailCatchUpStatus value, $Res Function(_ThumbnailCatchUpStatus) _then) = __$ThumbnailCatchUpStatusCopyWithImpl;
@override @useResult
$Res call({
 int version, bool enabled, int perHour, int behind, int waiting, int givenUp
});




}
/// @nodoc
class __$ThumbnailCatchUpStatusCopyWithImpl<$Res>
    implements _$ThumbnailCatchUpStatusCopyWith<$Res> {
  __$ThumbnailCatchUpStatusCopyWithImpl(this._self, this._then);

  final _ThumbnailCatchUpStatus _self;
  final $Res Function(_ThumbnailCatchUpStatus) _then;

/// Create a copy of ThumbnailCatchUpStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? enabled = null,Object? perHour = null,Object? behind = null,Object? waiting = null,Object? givenUp = null,}) {
  return _then(_ThumbnailCatchUpStatus(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,perHour: null == perHour ? _self.perHour : perHour // ignore: cast_nullable_to_non_nullable
as int,behind: null == behind ? _self.behind : behind // ignore: cast_nullable_to_non_nullable
as int,waiting: null == waiting ? _self.waiting : waiting // ignore: cast_nullable_to_non_nullable
as int,givenUp: null == givenUp ? _self.givenUp : givenUp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
