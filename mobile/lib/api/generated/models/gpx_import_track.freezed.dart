// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gpx_import_track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GpxImportTrack {

/// Polyline (precision 6, latitude then longitude) of the processed track, as PlannerSource.line
 String get line;/// Length in metres
 double get dist;/// Reported ascent in metres
 double get ascend;/// One-dimension polyline (tenths of a metre), one value per point of line; absent when an elevation is not finite
 String? get ele;/// One-dimension polyline (tenths of a metre): the ascent accumulated up to each point of line (dead-band, non-decreasing, first 0, last = ascend); absent when ele is
 String? get climb;
/// Create a copy of GpxImportTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpxImportTrackCopyWith<GpxImportTrack> get copyWith => _$GpxImportTrackCopyWithImpl<GpxImportTrack>(this as GpxImportTrack, _$identity);

  /// Serializes this GpxImportTrack to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GpxImportTrack;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpxImportTrack&&(identical(other.line, _this.line) || other.line == _this.line)&&(identical(other.dist, _this.dist) || other.dist == _this.dist)&&(identical(other.ascend, _this.ascend) || other.ascend == _this.ascend)&&(identical(other.ele, _this.ele) || other.ele == _this.ele)&&(identical(other.climb, _this.climb) || other.climb == _this.climb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GpxImportTrack;
  return Object.hash(runtimeType,_this.line,_this.dist,_this.ascend,_this.ele,_this.climb);
}

@override
String toString() {
  final _this = this as GpxImportTrack;
  return 'GpxImportTrack(line: ${_this.line}, dist: ${_this.dist}, ascend: ${_this.ascend}, ele: ${_this.ele}, climb: ${_this.climb})';
}


}

/// @nodoc
abstract mixin class $GpxImportTrackCopyWith<$Res>  {
  factory $GpxImportTrackCopyWith(GpxImportTrack value, $Res Function(GpxImportTrack) _then) = _$GpxImportTrackCopyWithImpl;
@useResult
$Res call({
 String line, double dist, double ascend, String? ele, String? climb
});




}
/// @nodoc
class _$GpxImportTrackCopyWithImpl<$Res>
    implements $GpxImportTrackCopyWith<$Res> {
  _$GpxImportTrackCopyWithImpl(this._self, this._then);

  final GpxImportTrack _self;
  final $Res Function(GpxImportTrack) _then;

/// Create a copy of GpxImportTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? line = null,Object? dist = null,Object? ascend = null,Object? ele = freezed,Object? climb = freezed,}) {
  return _then(GpxImportTrack(
line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as String,dist: null == dist ? _self.dist : dist // ignore: cast_nullable_to_non_nullable
as double,ascend: null == ascend ? _self.ascend : ascend // ignore: cast_nullable_to_non_nullable
as double,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as String?,climb: freezed == climb ? _self.climb : climb // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GpxImportTrack].
extension GpxImportTrackPatterns on GpxImportTrack {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpxImportTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpxImportTrack() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpxImportTrack value)  $default,){
final _that = this;
switch (_that) {
case _GpxImportTrack():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpxImportTrack value)?  $default,){
final _that = this;
switch (_that) {
case _GpxImportTrack() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String line,  double dist,  double ascend,  String? ele,  String? climb)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpxImportTrack() when $default != null:
return $default(_that.line,_that.dist,_that.ascend,_that.ele,_that.climb);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String line,  double dist,  double ascend,  String? ele,  String? climb)  $default,) {final _that = this;
switch (_that) {
case _GpxImportTrack():
return $default(_that.line,_that.dist,_that.ascend,_that.ele,_that.climb);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String line,  double dist,  double ascend,  String? ele,  String? climb)?  $default,) {final _that = this;
switch (_that) {
case _GpxImportTrack() when $default != null:
return $default(_that.line,_that.dist,_that.ascend,_that.ele,_that.climb);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpxImportTrack implements GpxImportTrack {
  const _GpxImportTrack({required this.line, required this.dist, required this.ascend, this.ele, this.climb});
  factory _GpxImportTrack.fromJson(Map<String, dynamic> json) => _$GpxImportTrackFromJson(json);

/// Polyline (precision 6, latitude then longitude) of the processed track, as PlannerSource.line
@override final  String line;
/// Length in metres
@override final  double dist;
/// Reported ascent in metres
@override final  double ascend;
/// One-dimension polyline (tenths of a metre), one value per point of line; absent when an elevation is not finite
@override final  String? ele;
/// One-dimension polyline (tenths of a metre): the ascent accumulated up to each point of line (dead-band, non-decreasing, first 0, last = ascend); absent when ele is
@override final  String? climb;

/// Create a copy of GpxImportTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpxImportTrackCopyWith<_GpxImportTrack> get copyWith => __$GpxImportTrackCopyWithImpl<_GpxImportTrack>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpxImportTrackToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpxImportTrack&&(identical(other.line, line) || other.line == line)&&(identical(other.dist, dist) || other.dist == dist)&&(identical(other.ascend, ascend) || other.ascend == ascend)&&(identical(other.ele, ele) || other.ele == ele)&&(identical(other.climb, climb) || other.climb == climb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,line,dist,ascend,ele,climb);
}

@override
String toString() {
    return 'GpxImportTrack(line: $line, dist: $dist, ascend: $ascend, ele: $ele, climb: $climb)';
}


}

/// @nodoc
abstract mixin class _$GpxImportTrackCopyWith<$Res> implements $GpxImportTrackCopyWith<$Res> {
  factory _$GpxImportTrackCopyWith(_GpxImportTrack value, $Res Function(_GpxImportTrack) _then) = __$GpxImportTrackCopyWithImpl;
@override @useResult
$Res call({
 String line, double dist, double ascend, String? ele, String? climb
});




}
/// @nodoc
class __$GpxImportTrackCopyWithImpl<$Res>
    implements _$GpxImportTrackCopyWith<$Res> {
  __$GpxImportTrackCopyWithImpl(this._self, this._then);

  final _GpxImportTrack _self;
  final $Res Function(_GpxImportTrack) _then;

/// Create a copy of GpxImportTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? line = null,Object? dist = null,Object? ascend = null,Object? ele = freezed,Object? climb = freezed,}) {
  return _then(_GpxImportTrack(
line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as String,dist: null == dist ? _self.dist : dist // ignore: cast_nullable_to_non_nullable
as double,ascend: null == ascend ? _self.ascend : ascend // ignore: cast_nullable_to_non_nullable
as double,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as String?,climb: freezed == climb ? _self.climb : climb // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
