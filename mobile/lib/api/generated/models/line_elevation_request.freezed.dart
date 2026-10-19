// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'line_elevation_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineElevationRequest {

/// Straight lines to read the relief of, 1 to 50, at most 100 km each and 200 km together
 List<StraightLine> get lines;/// Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
 String? get teamSlug;
/// Create a copy of LineElevationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineElevationRequestCopyWith<LineElevationRequest> get copyWith => _$LineElevationRequestCopyWithImpl<LineElevationRequest>(this as LineElevationRequest, _$identity);

  /// Serializes this LineElevationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LineElevationRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineElevationRequest&&const DeepCollectionEquality().equals(other.lines, _this.lines)&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LineElevationRequest;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.lines),_this.teamSlug);
}

@override
String toString() {
  final _this = this as LineElevationRequest;
  return 'LineElevationRequest(lines: ${_this.lines}, teamSlug: ${_this.teamSlug})';
}


}

/// @nodoc
abstract mixin class $LineElevationRequestCopyWith<$Res>  {
  factory $LineElevationRequestCopyWith(LineElevationRequest value, $Res Function(LineElevationRequest) _then) = _$LineElevationRequestCopyWithImpl;
@useResult
$Res call({
 List<StraightLine> lines, String? teamSlug
});




}
/// @nodoc
class _$LineElevationRequestCopyWithImpl<$Res>
    implements $LineElevationRequestCopyWith<$Res> {
  _$LineElevationRequestCopyWithImpl(this._self, this._then);

  final LineElevationRequest _self;
  final $Res Function(LineElevationRequest) _then;

/// Create a copy of LineElevationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lines = null,Object? teamSlug = freezed,}) {
  return _then(LineElevationRequest(
lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<StraightLine>,teamSlug: freezed == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LineElevationRequest].
extension LineElevationRequestPatterns on LineElevationRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineElevationRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineElevationRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineElevationRequest value)  $default,){
final _that = this;
switch (_that) {
case _LineElevationRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineElevationRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LineElevationRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<StraightLine> lines,  String? teamSlug)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineElevationRequest() when $default != null:
return $default(_that.lines,_that.teamSlug);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<StraightLine> lines,  String? teamSlug)  $default,) {final _that = this;
switch (_that) {
case _LineElevationRequest():
return $default(_that.lines,_that.teamSlug);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<StraightLine> lines,  String? teamSlug)?  $default,) {final _that = this;
switch (_that) {
case _LineElevationRequest() when $default != null:
return $default(_that.lines,_that.teamSlug);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineElevationRequest implements LineElevationRequest {
  const _LineElevationRequest({required  List<StraightLine> lines, this.teamSlug}): _lines = lines;
  factory _LineElevationRequest.fromJson(Map<String, dynamic> json) => _$LineElevationRequestFromJson(json);

/// Straight lines to read the relief of, 1 to 50, at most 100 km each and 200 km together
 final  List<StraightLine> _lines;
/// Straight lines to read the relief of, 1 to 50, at most 100 km each and 200 km together
@override List<StraightLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

/// Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
@override final  String? teamSlug;

/// Create a copy of LineElevationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineElevationRequestCopyWith<_LineElevationRequest> get copyWith => __$LineElevationRequestCopyWithImpl<_LineElevationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineElevationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineElevationRequest&&const DeepCollectionEquality().equals(other.lines, _lines)&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_lines),teamSlug);
}

@override
String toString() {
    return 'LineElevationRequest(lines: $lines, teamSlug: $teamSlug)';
}


}

/// @nodoc
abstract mixin class _$LineElevationRequestCopyWith<$Res> implements $LineElevationRequestCopyWith<$Res> {
  factory _$LineElevationRequestCopyWith(_LineElevationRequest value, $Res Function(_LineElevationRequest) _then) = __$LineElevationRequestCopyWithImpl;
@override @useResult
$Res call({
 List<StraightLine> lines, String? teamSlug
});




}
/// @nodoc
class __$LineElevationRequestCopyWithImpl<$Res>
    implements _$LineElevationRequestCopyWith<$Res> {
  __$LineElevationRequestCopyWithImpl(this._self, this._then);

  final _LineElevationRequest _self;
  final $Res Function(_LineElevationRequest) _then;

/// Create a copy of LineElevationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lines = null,Object? teamSlug = freezed,}) {
  return _then(_LineElevationRequest(
lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<StraightLine>,teamSlug: freezed == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
