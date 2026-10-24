// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weather_checkpoint_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WeatherCheckpointDto {

@JsonKey(name: 'index') int get indexField;/// Where the point stands on the leg
 String get kind;/// Distance from the start of the leg's route, metres: its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next. To place the point on the geometry, add up the lengths of the previous tracks: the 4th coordinate of a track geometry restarts at 0 on each track.
 double get distance;/// Estimated passage, from the leg's start time and speed
 String get time;/// Elevation of the point, metres, from the track
 double? get elevation;/// The forecast at the passage. Absent when nothing is in cache for that place yet.
 WeatherConditionsDto? get weather;/// How the rider meets the wind on the stretch that starts here (for the finish, the stretch that ends here). Absent without weather.
 String? get relativeWind;/// Mean head component of the wind on that stretch, km/h, signed: positive against the rider, negative behind
 double? get headwind;/// Direction the wind blows TOWARDS, relative to the direction of travel, degrees clockwise: 0 = from behind (pushing), 90 = from the left, 180 = in the face. Draw the arrow pointing forward, then rotate it by this angle.
 double? get relativeWindAngle;
/// Create a copy of WeatherCheckpointDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherCheckpointDtoCopyWith<WeatherCheckpointDto> get copyWith => _$WeatherCheckpointDtoCopyWithImpl<WeatherCheckpointDto>(this as WeatherCheckpointDto, _$identity);

  /// Serializes this WeatherCheckpointDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WeatherCheckpointDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherCheckpointDto&&(identical(other.indexField, _this.indexField) || other.indexField == _this.indexField)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.elevation, _this.elevation) || other.elevation == _this.elevation)&&(identical(other.weather, _this.weather) || other.weather == _this.weather)&&(identical(other.relativeWind, _this.relativeWind) || other.relativeWind == _this.relativeWind)&&(identical(other.headwind, _this.headwind) || other.headwind == _this.headwind)&&(identical(other.relativeWindAngle, _this.relativeWindAngle) || other.relativeWindAngle == _this.relativeWindAngle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WeatherCheckpointDto;
  return Object.hash(runtimeType,_this.indexField,_this.kind,_this.distance,_this.time,_this.elevation,_this.weather,_this.relativeWind,_this.headwind,_this.relativeWindAngle);
}

@override
String toString() {
  final _this = this as WeatherCheckpointDto;
  return 'WeatherCheckpointDto(indexField: ${_this.indexField}, kind: ${_this.kind}, distance: ${_this.distance}, time: ${_this.time}, elevation: ${_this.elevation}, weather: ${_this.weather}, relativeWind: ${_this.relativeWind}, headwind: ${_this.headwind}, relativeWindAngle: ${_this.relativeWindAngle})';
}


}

/// @nodoc
abstract mixin class $WeatherCheckpointDtoCopyWith<$Res>  {
  factory $WeatherCheckpointDtoCopyWith(WeatherCheckpointDto value, $Res Function(WeatherCheckpointDto) _then) = _$WeatherCheckpointDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'index') int indexField, String kind, double distance, String time, double? elevation, WeatherConditionsDto? weather, String? relativeWind, double? headwind, double? relativeWindAngle
});


$WeatherConditionsDtoCopyWith<$Res>? get weather;

}
/// @nodoc
class _$WeatherCheckpointDtoCopyWithImpl<$Res>
    implements $WeatherCheckpointDtoCopyWith<$Res> {
  _$WeatherCheckpointDtoCopyWithImpl(this._self, this._then);

  final WeatherCheckpointDto _self;
  final $Res Function(WeatherCheckpointDto) _then;

/// Create a copy of WeatherCheckpointDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? indexField = null,Object? kind = null,Object? distance = null,Object? time = null,Object? elevation = freezed,Object? weather = freezed,Object? relativeWind = freezed,Object? headwind = freezed,Object? relativeWindAngle = freezed,}) {
  return _then(WeatherCheckpointDto(
indexField: null == indexField ? _self.indexField : indexField // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,elevation: freezed == elevation ? _self.elevation : elevation // ignore: cast_nullable_to_non_nullable
as double?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as WeatherConditionsDto?,relativeWind: freezed == relativeWind ? _self.relativeWind : relativeWind // ignore: cast_nullable_to_non_nullable
as String?,headwind: freezed == headwind ? _self.headwind : headwind // ignore: cast_nullable_to_non_nullable
as double?,relativeWindAngle: freezed == relativeWindAngle ? _self.relativeWindAngle : relativeWindAngle // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of WeatherCheckpointDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherConditionsDtoCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $WeatherConditionsDtoCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
  });
}
}


/// Adds pattern-matching-related methods to [WeatherCheckpointDto].
extension WeatherCheckpointDtoPatterns on WeatherCheckpointDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeatherCheckpointDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeatherCheckpointDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeatherCheckpointDto value)  $default,){
final _that = this;
switch (_that) {
case _WeatherCheckpointDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeatherCheckpointDto value)?  $default,){
final _that = this;
switch (_that) {
case _WeatherCheckpointDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'index')  int indexField,  String kind,  double distance,  String time,  double? elevation,  WeatherConditionsDto? weather,  String? relativeWind,  double? headwind,  double? relativeWindAngle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeatherCheckpointDto() when $default != null:
return $default(_that.indexField,_that.kind,_that.distance,_that.time,_that.elevation,_that.weather,_that.relativeWind,_that.headwind,_that.relativeWindAngle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'index')  int indexField,  String kind,  double distance,  String time,  double? elevation,  WeatherConditionsDto? weather,  String? relativeWind,  double? headwind,  double? relativeWindAngle)  $default,) {final _that = this;
switch (_that) {
case _WeatherCheckpointDto():
return $default(_that.indexField,_that.kind,_that.distance,_that.time,_that.elevation,_that.weather,_that.relativeWind,_that.headwind,_that.relativeWindAngle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'index')  int indexField,  String kind,  double distance,  String time,  double? elevation,  WeatherConditionsDto? weather,  String? relativeWind,  double? headwind,  double? relativeWindAngle)?  $default,) {final _that = this;
switch (_that) {
case _WeatherCheckpointDto() when $default != null:
return $default(_that.indexField,_that.kind,_that.distance,_that.time,_that.elevation,_that.weather,_that.relativeWind,_that.headwind,_that.relativeWindAngle);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeatherCheckpointDto implements WeatherCheckpointDto {
  const _WeatherCheckpointDto({@JsonKey(name: 'index') required this.indexField, required this.kind, required this.distance, required this.time, this.elevation, this.weather, this.relativeWind, this.headwind, this.relativeWindAngle});
  factory _WeatherCheckpointDto.fromJson(Map<String, dynamic> json) => _$WeatherCheckpointDtoFromJson(json);

@override@JsonKey(name: 'index') final  int indexField;
/// Where the point stands on the leg
@override final  String kind;
/// Distance from the start of the leg's route, metres: its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next. To place the point on the geometry, add up the lengths of the previous tracks: the 4th coordinate of a track geometry restarts at 0 on each track.
@override final  double distance;
/// Estimated passage, from the leg's start time and speed
@override final  String time;
/// Elevation of the point, metres, from the track
@override final  double? elevation;
/// The forecast at the passage. Absent when nothing is in cache for that place yet.
@override final  WeatherConditionsDto? weather;
/// How the rider meets the wind on the stretch that starts here (for the finish, the stretch that ends here). Absent without weather.
@override final  String? relativeWind;
/// Mean head component of the wind on that stretch, km/h, signed: positive against the rider, negative behind
@override final  double? headwind;
/// Direction the wind blows TOWARDS, relative to the direction of travel, degrees clockwise: 0 = from behind (pushing), 90 = from the left, 180 = in the face. Draw the arrow pointing forward, then rotate it by this angle.
@override final  double? relativeWindAngle;

/// Create a copy of WeatherCheckpointDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeatherCheckpointDtoCopyWith<_WeatherCheckpointDto> get copyWith => __$WeatherCheckpointDtoCopyWithImpl<_WeatherCheckpointDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeatherCheckpointDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeatherCheckpointDto&&(identical(other.indexField, indexField) || other.indexField == indexField)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.time, time) || other.time == time)&&(identical(other.elevation, elevation) || other.elevation == elevation)&&(identical(other.weather, weather) || other.weather == weather)&&(identical(other.relativeWind, relativeWind) || other.relativeWind == relativeWind)&&(identical(other.headwind, headwind) || other.headwind == headwind)&&(identical(other.relativeWindAngle, relativeWindAngle) || other.relativeWindAngle == relativeWindAngle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,indexField,kind,distance,time,elevation,weather,relativeWind,headwind,relativeWindAngle);
}

@override
String toString() {
    return 'WeatherCheckpointDto(indexField: $indexField, kind: $kind, distance: $distance, time: $time, elevation: $elevation, weather: $weather, relativeWind: $relativeWind, headwind: $headwind, relativeWindAngle: $relativeWindAngle)';
}


}

/// @nodoc
abstract mixin class _$WeatherCheckpointDtoCopyWith<$Res> implements $WeatherCheckpointDtoCopyWith<$Res> {
  factory _$WeatherCheckpointDtoCopyWith(_WeatherCheckpointDto value, $Res Function(_WeatherCheckpointDto) _then) = __$WeatherCheckpointDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'index') int indexField, String kind, double distance, String time, double? elevation, WeatherConditionsDto? weather, String? relativeWind, double? headwind, double? relativeWindAngle
});


@override $WeatherConditionsDtoCopyWith<$Res>? get weather;

}
/// @nodoc
class __$WeatherCheckpointDtoCopyWithImpl<$Res>
    implements _$WeatherCheckpointDtoCopyWith<$Res> {
  __$WeatherCheckpointDtoCopyWithImpl(this._self, this._then);

  final _WeatherCheckpointDto _self;
  final $Res Function(_WeatherCheckpointDto) _then;

/// Create a copy of WeatherCheckpointDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? indexField = null,Object? kind = null,Object? distance = null,Object? time = null,Object? elevation = freezed,Object? weather = freezed,Object? relativeWind = freezed,Object? headwind = freezed,Object? relativeWindAngle = freezed,}) {
  return _then(_WeatherCheckpointDto(
indexField: null == indexField ? _self.indexField : indexField // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,elevation: freezed == elevation ? _self.elevation : elevation // ignore: cast_nullable_to_non_nullable
as double?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as WeatherConditionsDto?,relativeWind: freezed == relativeWind ? _self.relativeWind : relativeWind // ignore: cast_nullable_to_non_nullable
as String?,headwind: freezed == headwind ? _self.headwind : headwind // ignore: cast_nullable_to_non_nullable
as double?,relativeWindAngle: freezed == relativeWindAngle ? _self.relativeWindAngle : relativeWindAngle // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of WeatherCheckpointDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherConditionsDtoCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $WeatherConditionsDtoCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
  });
}
}

// dart format on
