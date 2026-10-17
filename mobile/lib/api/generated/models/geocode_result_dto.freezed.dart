// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'geocode_result_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GeocodeResultDto {

/// Opaque identifier of the result, stable enough to key a list on; what GET /api/geocode/place takes to resolve the position
 String get id;/// Full human-readable name of the place
 String get displayName;/// Latitude in degrees (WGS 84). Null on a search suggestion the provider gave no position for: resolve it with GET /api/geocode/place once the user picks it. Always set in that endpoint's answer.
 double? get lat;/// Longitude in degrees (WGS 84). Null exactly when lat is null: resolve it with GET /api/geocode/place once the user picks the suggestion.
 double? get lon;
/// Create a copy of GeocodeResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeocodeResultDtoCopyWith<GeocodeResultDto> get copyWith => _$GeocodeResultDtoCopyWithImpl<GeocodeResultDto>(this as GeocodeResultDto, _$identity);

  /// Serializes this GeocodeResultDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GeocodeResultDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeocodeResultDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.lat, _this.lat) || other.lat == _this.lat)&&(identical(other.lon, _this.lon) || other.lon == _this.lon));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GeocodeResultDto;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.lat,_this.lon);
}

@override
String toString() {
  final _this = this as GeocodeResultDto;
  return 'GeocodeResultDto(id: ${_this.id}, displayName: ${_this.displayName}, lat: ${_this.lat}, lon: ${_this.lon})';
}


}

/// @nodoc
abstract mixin class $GeocodeResultDtoCopyWith<$Res>  {
  factory $GeocodeResultDtoCopyWith(GeocodeResultDto value, $Res Function(GeocodeResultDto) _then) = _$GeocodeResultDtoCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, double? lat, double? lon
});




}
/// @nodoc
class _$GeocodeResultDtoCopyWithImpl<$Res>
    implements $GeocodeResultDtoCopyWith<$Res> {
  _$GeocodeResultDtoCopyWithImpl(this._self, this._then);

  final GeocodeResultDto _self;
  final $Res Function(GeocodeResultDto) _then;

/// Create a copy of GeocodeResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? lat = freezed,Object? lon = freezed,}) {
  return _then(GeocodeResultDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lon: freezed == lon ? _self.lon : lon // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [GeocodeResultDto].
extension GeocodeResultDtoPatterns on GeocodeResultDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeocodeResultDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeocodeResultDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeocodeResultDto value)  $default,){
final _that = this;
switch (_that) {
case _GeocodeResultDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeocodeResultDto value)?  $default,){
final _that = this;
switch (_that) {
case _GeocodeResultDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  double? lat,  double? lon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeocodeResultDto() when $default != null:
return $default(_that.id,_that.displayName,_that.lat,_that.lon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  double? lat,  double? lon)  $default,) {final _that = this;
switch (_that) {
case _GeocodeResultDto():
return $default(_that.id,_that.displayName,_that.lat,_that.lon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  double? lat,  double? lon)?  $default,) {final _that = this;
switch (_that) {
case _GeocodeResultDto() when $default != null:
return $default(_that.id,_that.displayName,_that.lat,_that.lon);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeocodeResultDto implements GeocodeResultDto {
  const _GeocodeResultDto({required this.id, required this.displayName, this.lat, this.lon});
  factory _GeocodeResultDto.fromJson(Map<String, dynamic> json) => _$GeocodeResultDtoFromJson(json);

/// Opaque identifier of the result, stable enough to key a list on; what GET /api/geocode/place takes to resolve the position
@override final  String id;
/// Full human-readable name of the place
@override final  String displayName;
/// Latitude in degrees (WGS 84). Null on a search suggestion the provider gave no position for: resolve it with GET /api/geocode/place once the user picks it. Always set in that endpoint's answer.
@override final  double? lat;
/// Longitude in degrees (WGS 84). Null exactly when lat is null: resolve it with GET /api/geocode/place once the user picks the suggestion.
@override final  double? lon;

/// Create a copy of GeocodeResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeocodeResultDtoCopyWith<_GeocodeResultDto> get copyWith => __$GeocodeResultDtoCopyWithImpl<_GeocodeResultDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeocodeResultDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeocodeResultDto&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lon, lon) || other.lon == lon));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,lat,lon);
}

@override
String toString() {
    return 'GeocodeResultDto(id: $id, displayName: $displayName, lat: $lat, lon: $lon)';
}


}

/// @nodoc
abstract mixin class _$GeocodeResultDtoCopyWith<$Res> implements $GeocodeResultDtoCopyWith<$Res> {
  factory _$GeocodeResultDtoCopyWith(_GeocodeResultDto value, $Res Function(_GeocodeResultDto) _then) = __$GeocodeResultDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, double? lat, double? lon
});




}
/// @nodoc
class __$GeocodeResultDtoCopyWithImpl<$Res>
    implements _$GeocodeResultDtoCopyWith<$Res> {
  __$GeocodeResultDtoCopyWithImpl(this._self, this._then);

  final _GeocodeResultDto _self;
  final $Res Function(_GeocodeResultDto) _then;

/// Create a copy of GeocodeResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? lat = freezed,Object? lon = freezed,}) {
  return _then(_GeocodeResultDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lon: freezed == lon ? _self.lon : lon // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
