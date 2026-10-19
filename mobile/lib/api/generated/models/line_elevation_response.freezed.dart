// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'line_elevation_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineElevationResponse {

/// One track per requested line, in the same order, from its start to its end
 List<GpxImportTrack> get lines;/// True when part of the elevations could not be read from the elevation source
 bool get elevationFallback;
/// Create a copy of LineElevationResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineElevationResponseCopyWith<LineElevationResponse> get copyWith => _$LineElevationResponseCopyWithImpl<LineElevationResponse>(this as LineElevationResponse, _$identity);

  /// Serializes this LineElevationResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LineElevationResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineElevationResponse&&const DeepCollectionEquality().equals(other.lines, _this.lines)&&(identical(other.elevationFallback, _this.elevationFallback) || other.elevationFallback == _this.elevationFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LineElevationResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.lines),_this.elevationFallback);
}

@override
String toString() {
  final _this = this as LineElevationResponse;
  return 'LineElevationResponse(lines: ${_this.lines}, elevationFallback: ${_this.elevationFallback})';
}


}

/// @nodoc
abstract mixin class $LineElevationResponseCopyWith<$Res>  {
  factory $LineElevationResponseCopyWith(LineElevationResponse value, $Res Function(LineElevationResponse) _then) = _$LineElevationResponseCopyWithImpl;
@useResult
$Res call({
 List<GpxImportTrack> lines, bool elevationFallback
});




}
/// @nodoc
class _$LineElevationResponseCopyWithImpl<$Res>
    implements $LineElevationResponseCopyWith<$Res> {
  _$LineElevationResponseCopyWithImpl(this._self, this._then);

  final LineElevationResponse _self;
  final $Res Function(LineElevationResponse) _then;

/// Create a copy of LineElevationResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lines = null,Object? elevationFallback = null,}) {
  return _then(LineElevationResponse(
lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<GpxImportTrack>,elevationFallback: null == elevationFallback ? _self.elevationFallback : elevationFallback // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LineElevationResponse].
extension LineElevationResponsePatterns on LineElevationResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineElevationResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineElevationResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineElevationResponse value)  $default,){
final _that = this;
switch (_that) {
case _LineElevationResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineElevationResponse value)?  $default,){
final _that = this;
switch (_that) {
case _LineElevationResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GpxImportTrack> lines,  bool elevationFallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineElevationResponse() when $default != null:
return $default(_that.lines,_that.elevationFallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GpxImportTrack> lines,  bool elevationFallback)  $default,) {final _that = this;
switch (_that) {
case _LineElevationResponse():
return $default(_that.lines,_that.elevationFallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GpxImportTrack> lines,  bool elevationFallback)?  $default,) {final _that = this;
switch (_that) {
case _LineElevationResponse() when $default != null:
return $default(_that.lines,_that.elevationFallback);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineElevationResponse implements LineElevationResponse {
  const _LineElevationResponse({required  List<GpxImportTrack> lines, required this.elevationFallback}): _lines = lines;
  factory _LineElevationResponse.fromJson(Map<String, dynamic> json) => _$LineElevationResponseFromJson(json);

/// One track per requested line, in the same order, from its start to its end
 final  List<GpxImportTrack> _lines;
/// One track per requested line, in the same order, from its start to its end
@override List<GpxImportTrack> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

/// True when part of the elevations could not be read from the elevation source
@override final  bool elevationFallback;

/// Create a copy of LineElevationResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineElevationResponseCopyWith<_LineElevationResponse> get copyWith => __$LineElevationResponseCopyWithImpl<_LineElevationResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineElevationResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineElevationResponse&&const DeepCollectionEquality().equals(other.lines, _lines)&&(identical(other.elevationFallback, elevationFallback) || other.elevationFallback == elevationFallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_lines),elevationFallback);
}

@override
String toString() {
    return 'LineElevationResponse(lines: $lines, elevationFallback: $elevationFallback)';
}


}

/// @nodoc
abstract mixin class _$LineElevationResponseCopyWith<$Res> implements $LineElevationResponseCopyWith<$Res> {
  factory _$LineElevationResponseCopyWith(_LineElevationResponse value, $Res Function(_LineElevationResponse) _then) = __$LineElevationResponseCopyWithImpl;
@override @useResult
$Res call({
 List<GpxImportTrack> lines, bool elevationFallback
});




}
/// @nodoc
class __$LineElevationResponseCopyWithImpl<$Res>
    implements _$LineElevationResponseCopyWith<$Res> {
  __$LineElevationResponseCopyWithImpl(this._self, this._then);

  final _LineElevationResponse _self;
  final $Res Function(_LineElevationResponse) _then;

/// Create a copy of LineElevationResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lines = null,Object? elevationFallback = null,}) {
  return _then(_LineElevationResponse(
lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<GpxImportTrack>,elevationFallback: null == elevationFallback ? _self.elevationFallback : elevationFallback // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
