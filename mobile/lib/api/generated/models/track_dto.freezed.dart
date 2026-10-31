// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrackDto {

 GeoJsonLineString get line;/// List of climbs on the route
 List<ClimbDto> get climbs;/// Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)
 String? get surfaceState;/// Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles
 List<SurfaceSpanDto>? get surfaces;
/// Create a copy of TrackDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackDtoCopyWith<TrackDto> get copyWith => _$TrackDtoCopyWithImpl<TrackDto>(this as TrackDto, _$identity);

  /// Serializes this TrackDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TrackDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackDto&&(identical(other.line, _this.line) || other.line == _this.line)&&const DeepCollectionEquality().equals(other.climbs, _this.climbs)&&(identical(other.surfaceState, _this.surfaceState) || other.surfaceState == _this.surfaceState)&&const DeepCollectionEquality().equals(other.surfaces, _this.surfaces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TrackDto;
  return Object.hash(runtimeType,_this.line,const DeepCollectionEquality().hash(_this.climbs),_this.surfaceState,const DeepCollectionEquality().hash(_this.surfaces));
}

@override
String toString() {
  final _this = this as TrackDto;
  return 'TrackDto(line: ${_this.line}, climbs: ${_this.climbs}, surfaceState: ${_this.surfaceState}, surfaces: ${_this.surfaces})';
}


}

/// @nodoc
abstract mixin class $TrackDtoCopyWith<$Res>  {
  factory $TrackDtoCopyWith(TrackDto value, $Res Function(TrackDto) _then) = _$TrackDtoCopyWithImpl;
@useResult
$Res call({
 GeoJsonLineString line, List<ClimbDto> climbs, String? surfaceState, List<SurfaceSpanDto>? surfaces
});


$GeoJsonLineStringCopyWith<$Res> get line;

}
/// @nodoc
class _$TrackDtoCopyWithImpl<$Res>
    implements $TrackDtoCopyWith<$Res> {
  _$TrackDtoCopyWithImpl(this._self, this._then);

  final TrackDto _self;
  final $Res Function(TrackDto) _then;

/// Create a copy of TrackDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? line = null,Object? climbs = null,Object? surfaceState = freezed,Object? surfaces = freezed,}) {
  return _then(TrackDto(
line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as GeoJsonLineString,climbs: null == climbs ? _self.climbs : climbs // ignore: cast_nullable_to_non_nullable
as List<ClimbDto>,surfaceState: freezed == surfaceState ? _self.surfaceState : surfaceState // ignore: cast_nullable_to_non_nullable
as String?,surfaces: freezed == surfaces ? _self.surfaces : surfaces // ignore: cast_nullable_to_non_nullable
as List<SurfaceSpanDto>?,
  ));
}
/// Create a copy of TrackDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonLineStringCopyWith<$Res> get line {
  
  return $GeoJsonLineStringCopyWith<$Res>(_self.line, (value) {
    return _then(_self.copyWith(line: value));
  });
}
}


/// Adds pattern-matching-related methods to [TrackDto].
extension TrackDtoPatterns on TrackDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackDto value)  $default,){
final _that = this;
switch (_that) {
case _TrackDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackDto value)?  $default,){
final _that = this;
switch (_that) {
case _TrackDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoJsonLineString line,  List<ClimbDto> climbs,  String? surfaceState,  List<SurfaceSpanDto>? surfaces)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackDto() when $default != null:
return $default(_that.line,_that.climbs,_that.surfaceState,_that.surfaces);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoJsonLineString line,  List<ClimbDto> climbs,  String? surfaceState,  List<SurfaceSpanDto>? surfaces)  $default,) {final _that = this;
switch (_that) {
case _TrackDto():
return $default(_that.line,_that.climbs,_that.surfaceState,_that.surfaces);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoJsonLineString line,  List<ClimbDto> climbs,  String? surfaceState,  List<SurfaceSpanDto>? surfaces)?  $default,) {final _that = this;
switch (_that) {
case _TrackDto() when $default != null:
return $default(_that.line,_that.climbs,_that.surfaceState,_that.surfaces);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrackDto implements TrackDto {
  const _TrackDto({required this.line, required  List<ClimbDto> climbs, this.surfaceState,  List<SurfaceSpanDto>? surfaces}): _climbs = climbs,_surfaces = surfaces;
  factory _TrackDto.fromJson(Map<String, dynamic> json) => _$TrackDtoFromJson(json);

@override final  GeoJsonLineString line;
/// List of climbs on the route
 final  List<ClimbDto> _climbs;
/// List of climbs on the route
@override List<ClimbDto> get climbs {
  if (_climbs is EqualUnmodifiableListView) return _climbs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_climbs);
}

/// Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint with geometry=false, which carries no track)
@override final  String? surfaceState;
/// Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles
 final  List<SurfaceSpanDto>? _surfaces;
/// Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector tiles
@override List<SurfaceSpanDto>? get surfaces {
  final value = _surfaces;
  if (value == null) return null;
  if (_surfaces is EqualUnmodifiableListView) return _surfaces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of TrackDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackDtoCopyWith<_TrackDto> get copyWith => __$TrackDtoCopyWithImpl<_TrackDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackDto&&(identical(other.line, line) || other.line == line)&&const DeepCollectionEquality().equals(other.climbs, _climbs)&&(identical(other.surfaceState, surfaceState) || other.surfaceState == surfaceState)&&const DeepCollectionEquality().equals(other.surfaces, _surfaces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,line,const DeepCollectionEquality().hash(_climbs),surfaceState,const DeepCollectionEquality().hash(_surfaces));
}

@override
String toString() {
    return 'TrackDto(line: $line, climbs: $climbs, surfaceState: $surfaceState, surfaces: $surfaces)';
}


}

/// @nodoc
abstract mixin class _$TrackDtoCopyWith<$Res> implements $TrackDtoCopyWith<$Res> {
  factory _$TrackDtoCopyWith(_TrackDto value, $Res Function(_TrackDto) _then) = __$TrackDtoCopyWithImpl;
@override @useResult
$Res call({
 GeoJsonLineString line, List<ClimbDto> climbs, String? surfaceState, List<SurfaceSpanDto>? surfaces
});


@override $GeoJsonLineStringCopyWith<$Res> get line;

}
/// @nodoc
class __$TrackDtoCopyWithImpl<$Res>
    implements _$TrackDtoCopyWith<$Res> {
  __$TrackDtoCopyWithImpl(this._self, this._then);

  final _TrackDto _self;
  final $Res Function(_TrackDto) _then;

/// Create a copy of TrackDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? line = null,Object? climbs = null,Object? surfaceState = freezed,Object? surfaces = freezed,}) {
  return _then(_TrackDto(
line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as GeoJsonLineString,climbs: null == climbs ? _self._climbs : climbs // ignore: cast_nullable_to_non_nullable
as List<ClimbDto>,surfaceState: freezed == surfaceState ? _self.surfaceState : surfaceState // ignore: cast_nullable_to_non_nullable
as String?,surfaces: freezed == surfaces ? _self._surfaces : surfaces // ignore: cast_nullable_to_non_nullable
as List<SurfaceSpanDto>?,
  ));
}

/// Create a copy of TrackDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonLineStringCopyWith<$Res> get line {
  
  return $GeoJsonLineStringCopyWith<$Res>(_self.line, (value) {
    return _then(_self.copyWith(line: value));
  });
}
}

// dart format on
