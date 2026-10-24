// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geo_json_line_string.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GeoJsonLineString {

 GeoJsonLineStringTypeType get type;/// Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route.
 List<List<double>> get coordinates;
/// Create a copy of GeoJsonLineString
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeoJsonLineStringCopyWith<GeoJsonLineString> get copyWith => _$GeoJsonLineStringCopyWithImpl<GeoJsonLineString>(this as GeoJsonLineString, _$identity);

  /// Serializes this GeoJsonLineString to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GeoJsonLineString;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeoJsonLineString&&(identical(other.type, _this.type) || other.type == _this.type)&&const DeepCollectionEquality().equals(other.coordinates, _this.coordinates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GeoJsonLineString;
  return Object.hash(runtimeType,_this.type,const DeepCollectionEquality().hash(_this.coordinates));
}

@override
String toString() {
  final _this = this as GeoJsonLineString;
  return 'GeoJsonLineString(type: ${_this.type}, coordinates: ${_this.coordinates})';
}


}

/// @nodoc
abstract mixin class $GeoJsonLineStringCopyWith<$Res>  {
  factory $GeoJsonLineStringCopyWith(GeoJsonLineString value, $Res Function(GeoJsonLineString) _then) = _$GeoJsonLineStringCopyWithImpl;
@useResult
$Res call({
 GeoJsonLineStringTypeType type, List<List<double>> coordinates
});




}
/// @nodoc
class _$GeoJsonLineStringCopyWithImpl<$Res>
    implements $GeoJsonLineStringCopyWith<$Res> {
  _$GeoJsonLineStringCopyWithImpl(this._self, this._then);

  final GeoJsonLineString _self;
  final $Res Function(GeoJsonLineString) _then;

/// Create a copy of GeoJsonLineString
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? coordinates = null,}) {
  return _then(GeoJsonLineString(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as GeoJsonLineStringTypeType,coordinates: null == coordinates ? _self.coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as List<List<double>>,
  ));
}

}


/// Adds pattern-matching-related methods to [GeoJsonLineString].
extension GeoJsonLineStringPatterns on GeoJsonLineString {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeoJsonLineString value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeoJsonLineString() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeoJsonLineString value)  $default,){
final _that = this;
switch (_that) {
case _GeoJsonLineString():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeoJsonLineString value)?  $default,){
final _that = this;
switch (_that) {
case _GeoJsonLineString() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoJsonLineStringTypeType type,  List<List<double>> coordinates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeoJsonLineString() when $default != null:
return $default(_that.type,_that.coordinates);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoJsonLineStringTypeType type,  List<List<double>> coordinates)  $default,) {final _that = this;
switch (_that) {
case _GeoJsonLineString():
return $default(_that.type,_that.coordinates);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoJsonLineStringTypeType type,  List<List<double>> coordinates)?  $default,) {final _that = this;
switch (_that) {
case _GeoJsonLineString() when $default != null:
return $default(_that.type,_that.coordinates);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeoJsonLineString implements GeoJsonLineString {
  const _GeoJsonLineString({required this.type, required  List<List<double>> coordinates}): _coordinates = coordinates;
  factory _GeoJsonLineString.fromJson(Map<String, dynamic> json) => _$GeoJsonLineStringFromJson(json);

@override final  GeoJsonLineStringTypeType type;
/// Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route.
 final  List<List<double>> _coordinates;
/// Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route.
@override List<List<double>> get coordinates {
  if (_coordinates is EqualUnmodifiableListView) return _coordinates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_coordinates);
}


/// Create a copy of GeoJsonLineString
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeoJsonLineStringCopyWith<_GeoJsonLineString> get copyWith => __$GeoJsonLineStringCopyWithImpl<_GeoJsonLineString>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeoJsonLineStringToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeoJsonLineString&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.coordinates, _coordinates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_coordinates));
}

@override
String toString() {
    return 'GeoJsonLineString(type: $type, coordinates: $coordinates)';
}


}

/// @nodoc
abstract mixin class _$GeoJsonLineStringCopyWith<$Res> implements $GeoJsonLineStringCopyWith<$Res> {
  factory _$GeoJsonLineStringCopyWith(_GeoJsonLineString value, $Res Function(_GeoJsonLineString) _then) = __$GeoJsonLineStringCopyWithImpl;
@override @useResult
$Res call({
 GeoJsonLineStringTypeType type, List<List<double>> coordinates
});




}
/// @nodoc
class __$GeoJsonLineStringCopyWithImpl<$Res>
    implements _$GeoJsonLineStringCopyWith<$Res> {
  __$GeoJsonLineStringCopyWithImpl(this._self, this._then);

  final _GeoJsonLineString _self;
  final $Res Function(_GeoJsonLineString) _then;

/// Create a copy of GeoJsonLineString
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? coordinates = null,}) {
  return _then(_GeoJsonLineString(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as GeoJsonLineStringTypeType,coordinates: null == coordinates ? _self._coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as List<List<double>>,
  ));
}


}

// dart format on
