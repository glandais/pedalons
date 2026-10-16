// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weather_conditions_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WeatherConditionsDto {

/// The forecast hour used: the one nearest the moment asked about
 String get time;/// WMO weather interpretation code, as the model gives it. condition is its folding; a client reads condition, this is for the curious.
 int get weatherCode;/// weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR; 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55 DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73, 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other OVERCAST. A client meeting a value it does not know shows a plain cloud.
 String get condition;/// Whether the moment asked about (the departure, the checkpoint's passage) falls between sunrise and sunset at that place — not time, the round model hour. Picks the day or night icon
 bool get daylight;/// Air temperature at 2 m, °C
 double get temperature;/// Felt temperature (wind chill, humidity), °C
 double get apparentTemperature;/// Precipitation over the hour (rain, showers, snow), mm
 double get precipitation;/// Wind of that hour
 WindDto get wind;/// Probability of precipitation, % (0–100). Absent when the model gives none.
 int? get precipitationProbability;
/// Create a copy of WeatherConditionsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherConditionsDtoCopyWith<WeatherConditionsDto> get copyWith => _$WeatherConditionsDtoCopyWithImpl<WeatherConditionsDto>(this as WeatherConditionsDto, _$identity);

  /// Serializes this WeatherConditionsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WeatherConditionsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherConditionsDto&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.weatherCode, _this.weatherCode) || other.weatherCode == _this.weatherCode)&&(identical(other.condition, _this.condition) || other.condition == _this.condition)&&(identical(other.daylight, _this.daylight) || other.daylight == _this.daylight)&&(identical(other.temperature, _this.temperature) || other.temperature == _this.temperature)&&(identical(other.apparentTemperature, _this.apparentTemperature) || other.apparentTemperature == _this.apparentTemperature)&&(identical(other.precipitation, _this.precipitation) || other.precipitation == _this.precipitation)&&(identical(other.wind, _this.wind) || other.wind == _this.wind)&&(identical(other.precipitationProbability, _this.precipitationProbability) || other.precipitationProbability == _this.precipitationProbability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WeatherConditionsDto;
  return Object.hash(runtimeType,_this.time,_this.weatherCode,_this.condition,_this.daylight,_this.temperature,_this.apparentTemperature,_this.precipitation,_this.wind,_this.precipitationProbability);
}

@override
String toString() {
  final _this = this as WeatherConditionsDto;
  return 'WeatherConditionsDto(time: ${_this.time}, weatherCode: ${_this.weatherCode}, condition: ${_this.condition}, daylight: ${_this.daylight}, temperature: ${_this.temperature}, apparentTemperature: ${_this.apparentTemperature}, precipitation: ${_this.precipitation}, wind: ${_this.wind}, precipitationProbability: ${_this.precipitationProbability})';
}


}

/// @nodoc
abstract mixin class $WeatherConditionsDtoCopyWith<$Res>  {
  factory $WeatherConditionsDtoCopyWith(WeatherConditionsDto value, $Res Function(WeatherConditionsDto) _then) = _$WeatherConditionsDtoCopyWithImpl;
@useResult
$Res call({
 String time, int weatherCode, String condition, bool daylight, double temperature, double apparentTemperature, double precipitation, WindDto wind, int? precipitationProbability
});


$WindDtoCopyWith<$Res> get wind;

}
/// @nodoc
class _$WeatherConditionsDtoCopyWithImpl<$Res>
    implements $WeatherConditionsDtoCopyWith<$Res> {
  _$WeatherConditionsDtoCopyWithImpl(this._self, this._then);

  final WeatherConditionsDto _self;
  final $Res Function(WeatherConditionsDto) _then;

/// Create a copy of WeatherConditionsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? time = null,Object? weatherCode = null,Object? condition = null,Object? daylight = null,Object? temperature = null,Object? apparentTemperature = null,Object? precipitation = null,Object? wind = null,Object? precipitationProbability = freezed,}) {
  return _then(WeatherConditionsDto(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,weatherCode: null == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as int,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,daylight: null == daylight ? _self.daylight : daylight // ignore: cast_nullable_to_non_nullable
as bool,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,apparentTemperature: null == apparentTemperature ? _self.apparentTemperature : apparentTemperature // ignore: cast_nullable_to_non_nullable
as double,precipitation: null == precipitation ? _self.precipitation : precipitation // ignore: cast_nullable_to_non_nullable
as double,wind: null == wind ? _self.wind : wind // ignore: cast_nullable_to_non_nullable
as WindDto,precipitationProbability: freezed == precipitationProbability ? _self.precipitationProbability : precipitationProbability // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of WeatherConditionsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindDtoCopyWith<$Res> get wind {
  
  return $WindDtoCopyWith<$Res>(_self.wind, (value) {
    return _then(_self.copyWith(wind: value));
  });
}
}


/// Adds pattern-matching-related methods to [WeatherConditionsDto].
extension WeatherConditionsDtoPatterns on WeatherConditionsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeatherConditionsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeatherConditionsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeatherConditionsDto value)  $default,){
final _that = this;
switch (_that) {
case _WeatherConditionsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeatherConditionsDto value)?  $default,){
final _that = this;
switch (_that) {
case _WeatherConditionsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String time,  int weatherCode,  String condition,  bool daylight,  double temperature,  double apparentTemperature,  double precipitation,  WindDto wind,  int? precipitationProbability)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeatherConditionsDto() when $default != null:
return $default(_that.time,_that.weatherCode,_that.condition,_that.daylight,_that.temperature,_that.apparentTemperature,_that.precipitation,_that.wind,_that.precipitationProbability);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String time,  int weatherCode,  String condition,  bool daylight,  double temperature,  double apparentTemperature,  double precipitation,  WindDto wind,  int? precipitationProbability)  $default,) {final _that = this;
switch (_that) {
case _WeatherConditionsDto():
return $default(_that.time,_that.weatherCode,_that.condition,_that.daylight,_that.temperature,_that.apparentTemperature,_that.precipitation,_that.wind,_that.precipitationProbability);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String time,  int weatherCode,  String condition,  bool daylight,  double temperature,  double apparentTemperature,  double precipitation,  WindDto wind,  int? precipitationProbability)?  $default,) {final _that = this;
switch (_that) {
case _WeatherConditionsDto() when $default != null:
return $default(_that.time,_that.weatherCode,_that.condition,_that.daylight,_that.temperature,_that.apparentTemperature,_that.precipitation,_that.wind,_that.precipitationProbability);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeatherConditionsDto implements WeatherConditionsDto {
  const _WeatherConditionsDto({required this.time, required this.weatherCode, required this.condition, required this.daylight, required this.temperature, required this.apparentTemperature, required this.precipitation, required this.wind, this.precipitationProbability});
  factory _WeatherConditionsDto.fromJson(Map<String, dynamic> json) => _$WeatherConditionsDtoFromJson(json);

/// The forecast hour used: the one nearest the moment asked about
@override final  String time;
/// WMO weather interpretation code, as the model gives it. condition is its folding; a client reads condition, this is for the curious.
@override final  int weatherCode;
/// weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR; 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55 DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73, 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other OVERCAST. A client meeting a value it does not know shows a plain cloud.
@override final  String condition;
/// Whether the moment asked about (the departure, the checkpoint's passage) falls between sunrise and sunset at that place — not time, the round model hour. Picks the day or night icon
@override final  bool daylight;
/// Air temperature at 2 m, °C
@override final  double temperature;
/// Felt temperature (wind chill, humidity), °C
@override final  double apparentTemperature;
/// Precipitation over the hour (rain, showers, snow), mm
@override final  double precipitation;
/// Wind of that hour
@override final  WindDto wind;
/// Probability of precipitation, % (0–100). Absent when the model gives none.
@override final  int? precipitationProbability;

/// Create a copy of WeatherConditionsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeatherConditionsDtoCopyWith<_WeatherConditionsDto> get copyWith => __$WeatherConditionsDtoCopyWithImpl<_WeatherConditionsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeatherConditionsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeatherConditionsDto&&(identical(other.time, time) || other.time == time)&&(identical(other.weatherCode, weatherCode) || other.weatherCode == weatherCode)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.daylight, daylight) || other.daylight == daylight)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.apparentTemperature, apparentTemperature) || other.apparentTemperature == apparentTemperature)&&(identical(other.precipitation, precipitation) || other.precipitation == precipitation)&&(identical(other.wind, wind) || other.wind == wind)&&(identical(other.precipitationProbability, precipitationProbability) || other.precipitationProbability == precipitationProbability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,time,weatherCode,condition,daylight,temperature,apparentTemperature,precipitation,wind,precipitationProbability);
}

@override
String toString() {
    return 'WeatherConditionsDto(time: $time, weatherCode: $weatherCode, condition: $condition, daylight: $daylight, temperature: $temperature, apparentTemperature: $apparentTemperature, precipitation: $precipitation, wind: $wind, precipitationProbability: $precipitationProbability)';
}


}

/// @nodoc
abstract mixin class _$WeatherConditionsDtoCopyWith<$Res> implements $WeatherConditionsDtoCopyWith<$Res> {
  factory _$WeatherConditionsDtoCopyWith(_WeatherConditionsDto value, $Res Function(_WeatherConditionsDto) _then) = __$WeatherConditionsDtoCopyWithImpl;
@override @useResult
$Res call({
 String time, int weatherCode, String condition, bool daylight, double temperature, double apparentTemperature, double precipitation, WindDto wind, int? precipitationProbability
});


@override $WindDtoCopyWith<$Res> get wind;

}
/// @nodoc
class __$WeatherConditionsDtoCopyWithImpl<$Res>
    implements _$WeatherConditionsDtoCopyWith<$Res> {
  __$WeatherConditionsDtoCopyWithImpl(this._self, this._then);

  final _WeatherConditionsDto _self;
  final $Res Function(_WeatherConditionsDto) _then;

/// Create a copy of WeatherConditionsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? time = null,Object? weatherCode = null,Object? condition = null,Object? daylight = null,Object? temperature = null,Object? apparentTemperature = null,Object? precipitation = null,Object? wind = null,Object? precipitationProbability = freezed,}) {
  return _then(_WeatherConditionsDto(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,weatherCode: null == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as int,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,daylight: null == daylight ? _self.daylight : daylight // ignore: cast_nullable_to_non_nullable
as bool,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,apparentTemperature: null == apparentTemperature ? _self.apparentTemperature : apparentTemperature // ignore: cast_nullable_to_non_nullable
as double,precipitation: null == precipitation ? _self.precipitation : precipitation // ignore: cast_nullable_to_non_nullable
as double,wind: null == wind ? _self.wind : wind // ignore: cast_nullable_to_non_nullable
as WindDto,precipitationProbability: freezed == precipitationProbability ? _self.precipitationProbability : precipitationProbability // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of WeatherConditionsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindDtoCopyWith<$Res> get wind {
  
  return $WindDtoCopyWith<$Res>(_self.wind, (value) {
    return _then(_self.copyWith(wind: value));
  });
}
}

// dart format on
