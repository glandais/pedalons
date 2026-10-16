// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_weather_summary_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideWeatherSummaryDto {

/// OK, STALE or NOT_YET_AVAILABLE
 String get status;/// For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure
 String? get availableFrom;/// WMO code at the departure hour
 int? get weatherCode;/// weatherCode folded into a condition, same table as WeatherConditionsDto.condition
 String? get condition;/// Whether the departure itself (not the round model hour read for it) is between sunrise and sunset
 bool? get daylight;/// Air temperature at the departure hour, °C
 double? get temperature;/// Lowest temperature over the window, °C
 double? get temperatureMin;/// Highest temperature over the window, °C
 double? get temperatureMax;/// Highest probability of precipitation over the window, %. Absent when the model gives none.
 int? get maxPrecipitationProbability;/// Wind at the departure hour
 WindDto? get wind;/// The first hour of the window with rain likely (50 % or more). Its distance is absent on a ride's summary, present on a trip stage's (the checkpoint's)
 WeatherRainAlertDto? get rainAlert;/// IANA zone the times of this summary (rain alert) are read in, as rendezvous with no zone mention. Set on a trip's card, where it is its next stage's zone — not TripDto.timezone, the first stage's. Absent elsewhere: the owner's timezone (RideDto, TripStageDto) applies.
 String? get timezone;
/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideWeatherSummaryDtoCopyWith<RideWeatherSummaryDto> get copyWith => _$RideWeatherSummaryDtoCopyWithImpl<RideWeatherSummaryDto>(this as RideWeatherSummaryDto, _$identity);

  /// Serializes this RideWeatherSummaryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RideWeatherSummaryDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideWeatherSummaryDto&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.availableFrom, _this.availableFrom) || other.availableFrom == _this.availableFrom)&&(identical(other.weatherCode, _this.weatherCode) || other.weatherCode == _this.weatherCode)&&(identical(other.condition, _this.condition) || other.condition == _this.condition)&&(identical(other.daylight, _this.daylight) || other.daylight == _this.daylight)&&(identical(other.temperature, _this.temperature) || other.temperature == _this.temperature)&&(identical(other.temperatureMin, _this.temperatureMin) || other.temperatureMin == _this.temperatureMin)&&(identical(other.temperatureMax, _this.temperatureMax) || other.temperatureMax == _this.temperatureMax)&&(identical(other.maxPrecipitationProbability, _this.maxPrecipitationProbability) || other.maxPrecipitationProbability == _this.maxPrecipitationProbability)&&(identical(other.wind, _this.wind) || other.wind == _this.wind)&&(identical(other.rainAlert, _this.rainAlert) || other.rainAlert == _this.rainAlert)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RideWeatherSummaryDto;
  return Object.hash(runtimeType,_this.status,_this.availableFrom,_this.weatherCode,_this.condition,_this.daylight,_this.temperature,_this.temperatureMin,_this.temperatureMax,_this.maxPrecipitationProbability,_this.wind,_this.rainAlert,_this.timezone);
}

@override
String toString() {
  final _this = this as RideWeatherSummaryDto;
  return 'RideWeatherSummaryDto(status: ${_this.status}, availableFrom: ${_this.availableFrom}, weatherCode: ${_this.weatherCode}, condition: ${_this.condition}, daylight: ${_this.daylight}, temperature: ${_this.temperature}, temperatureMin: ${_this.temperatureMin}, temperatureMax: ${_this.temperatureMax}, maxPrecipitationProbability: ${_this.maxPrecipitationProbability}, wind: ${_this.wind}, rainAlert: ${_this.rainAlert}, timezone: ${_this.timezone})';
}


}

/// @nodoc
abstract mixin class $RideWeatherSummaryDtoCopyWith<$Res>  {
  factory $RideWeatherSummaryDtoCopyWith(RideWeatherSummaryDto value, $Res Function(RideWeatherSummaryDto) _then) = _$RideWeatherSummaryDtoCopyWithImpl;
@useResult
$Res call({
 String status, String? availableFrom, int? weatherCode, String? condition, bool? daylight, double? temperature, double? temperatureMin, double? temperatureMax, int? maxPrecipitationProbability, WindDto? wind, WeatherRainAlertDto? rainAlert, String? timezone
});


$WindDtoCopyWith<$Res>? get wind;$WeatherRainAlertDtoCopyWith<$Res>? get rainAlert;

}
/// @nodoc
class _$RideWeatherSummaryDtoCopyWithImpl<$Res>
    implements $RideWeatherSummaryDtoCopyWith<$Res> {
  _$RideWeatherSummaryDtoCopyWithImpl(this._self, this._then);

  final RideWeatherSummaryDto _self;
  final $Res Function(RideWeatherSummaryDto) _then;

/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? availableFrom = freezed,Object? weatherCode = freezed,Object? condition = freezed,Object? daylight = freezed,Object? temperature = freezed,Object? temperatureMin = freezed,Object? temperatureMax = freezed,Object? maxPrecipitationProbability = freezed,Object? wind = freezed,Object? rainAlert = freezed,Object? timezone = freezed,}) {
  return _then(RideWeatherSummaryDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,weatherCode: freezed == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as int?,condition: freezed == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String?,daylight: freezed == daylight ? _self.daylight : daylight // ignore: cast_nullable_to_non_nullable
as bool?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,temperatureMin: freezed == temperatureMin ? _self.temperatureMin : temperatureMin // ignore: cast_nullable_to_non_nullable
as double?,temperatureMax: freezed == temperatureMax ? _self.temperatureMax : temperatureMax // ignore: cast_nullable_to_non_nullable
as double?,maxPrecipitationProbability: freezed == maxPrecipitationProbability ? _self.maxPrecipitationProbability : maxPrecipitationProbability // ignore: cast_nullable_to_non_nullable
as int?,wind: freezed == wind ? _self.wind : wind // ignore: cast_nullable_to_non_nullable
as WindDto?,rainAlert: freezed == rainAlert ? _self.rainAlert : rainAlert // ignore: cast_nullable_to_non_nullable
as WeatherRainAlertDto?,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindDtoCopyWith<$Res>? get wind {
    if (_self.wind == null) {
    return null;
  }

  return $WindDtoCopyWith<$Res>(_self.wind!, (value) {
    return _then(_self.copyWith(wind: value));
  });
}/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherRainAlertDtoCopyWith<$Res>? get rainAlert {
    if (_self.rainAlert == null) {
    return null;
  }

  return $WeatherRainAlertDtoCopyWith<$Res>(_self.rainAlert!, (value) {
    return _then(_self.copyWith(rainAlert: value));
  });
}
}


/// Adds pattern-matching-related methods to [RideWeatherSummaryDto].
extension RideWeatherSummaryDtoPatterns on RideWeatherSummaryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideWeatherSummaryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideWeatherSummaryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideWeatherSummaryDto value)  $default,){
final _that = this;
switch (_that) {
case _RideWeatherSummaryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideWeatherSummaryDto value)?  $default,){
final _that = this;
switch (_that) {
case _RideWeatherSummaryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  String? availableFrom,  int? weatherCode,  String? condition,  bool? daylight,  double? temperature,  double? temperatureMin,  double? temperatureMax,  int? maxPrecipitationProbability,  WindDto? wind,  WeatherRainAlertDto? rainAlert,  String? timezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideWeatherSummaryDto() when $default != null:
return $default(_that.status,_that.availableFrom,_that.weatherCode,_that.condition,_that.daylight,_that.temperature,_that.temperatureMin,_that.temperatureMax,_that.maxPrecipitationProbability,_that.wind,_that.rainAlert,_that.timezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  String? availableFrom,  int? weatherCode,  String? condition,  bool? daylight,  double? temperature,  double? temperatureMin,  double? temperatureMax,  int? maxPrecipitationProbability,  WindDto? wind,  WeatherRainAlertDto? rainAlert,  String? timezone)  $default,) {final _that = this;
switch (_that) {
case _RideWeatherSummaryDto():
return $default(_that.status,_that.availableFrom,_that.weatherCode,_that.condition,_that.daylight,_that.temperature,_that.temperatureMin,_that.temperatureMax,_that.maxPrecipitationProbability,_that.wind,_that.rainAlert,_that.timezone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  String? availableFrom,  int? weatherCode,  String? condition,  bool? daylight,  double? temperature,  double? temperatureMin,  double? temperatureMax,  int? maxPrecipitationProbability,  WindDto? wind,  WeatherRainAlertDto? rainAlert,  String? timezone)?  $default,) {final _that = this;
switch (_that) {
case _RideWeatherSummaryDto() when $default != null:
return $default(_that.status,_that.availableFrom,_that.weatherCode,_that.condition,_that.daylight,_that.temperature,_that.temperatureMin,_that.temperatureMax,_that.maxPrecipitationProbability,_that.wind,_that.rainAlert,_that.timezone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideWeatherSummaryDto implements RideWeatherSummaryDto {
  const _RideWeatherSummaryDto({required this.status, this.availableFrom, this.weatherCode, this.condition, this.daylight, this.temperature, this.temperatureMin, this.temperatureMax, this.maxPrecipitationProbability, this.wind, this.rainAlert, this.timezone});
  factory _RideWeatherSummaryDto.fromJson(Map<String, dynamic> json) => _$RideWeatherSummaryDtoFromJson(json);

/// OK, STALE or NOT_YET_AVAILABLE
@override final  String status;
/// For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure
@override final  String? availableFrom;
/// WMO code at the departure hour
@override final  int? weatherCode;
/// weatherCode folded into a condition, same table as WeatherConditionsDto.condition
@override final  String? condition;
/// Whether the departure itself (not the round model hour read for it) is between sunrise and sunset
@override final  bool? daylight;
/// Air temperature at the departure hour, °C
@override final  double? temperature;
/// Lowest temperature over the window, °C
@override final  double? temperatureMin;
/// Highest temperature over the window, °C
@override final  double? temperatureMax;
/// Highest probability of precipitation over the window, %. Absent when the model gives none.
@override final  int? maxPrecipitationProbability;
/// Wind at the departure hour
@override final  WindDto? wind;
/// The first hour of the window with rain likely (50 % or more). Its distance is absent on a ride's summary, present on a trip stage's (the checkpoint's)
@override final  WeatherRainAlertDto? rainAlert;
/// IANA zone the times of this summary (rain alert) are read in, as rendezvous with no zone mention. Set on a trip's card, where it is its next stage's zone — not TripDto.timezone, the first stage's. Absent elsewhere: the owner's timezone (RideDto, TripStageDto) applies.
@override final  String? timezone;

/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideWeatherSummaryDtoCopyWith<_RideWeatherSummaryDto> get copyWith => __$RideWeatherSummaryDtoCopyWithImpl<_RideWeatherSummaryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideWeatherSummaryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideWeatherSummaryDto&&(identical(other.status, status) || other.status == status)&&(identical(other.availableFrom, availableFrom) || other.availableFrom == availableFrom)&&(identical(other.weatherCode, weatherCode) || other.weatherCode == weatherCode)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.daylight, daylight) || other.daylight == daylight)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.temperatureMin, temperatureMin) || other.temperatureMin == temperatureMin)&&(identical(other.temperatureMax, temperatureMax) || other.temperatureMax == temperatureMax)&&(identical(other.maxPrecipitationProbability, maxPrecipitationProbability) || other.maxPrecipitationProbability == maxPrecipitationProbability)&&(identical(other.wind, wind) || other.wind == wind)&&(identical(other.rainAlert, rainAlert) || other.rainAlert == rainAlert)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,availableFrom,weatherCode,condition,daylight,temperature,temperatureMin,temperatureMax,maxPrecipitationProbability,wind,rainAlert,timezone);
}

@override
String toString() {
    return 'RideWeatherSummaryDto(status: $status, availableFrom: $availableFrom, weatherCode: $weatherCode, condition: $condition, daylight: $daylight, temperature: $temperature, temperatureMin: $temperatureMin, temperatureMax: $temperatureMax, maxPrecipitationProbability: $maxPrecipitationProbability, wind: $wind, rainAlert: $rainAlert, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class _$RideWeatherSummaryDtoCopyWith<$Res> implements $RideWeatherSummaryDtoCopyWith<$Res> {
  factory _$RideWeatherSummaryDtoCopyWith(_RideWeatherSummaryDto value, $Res Function(_RideWeatherSummaryDto) _then) = __$RideWeatherSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 String status, String? availableFrom, int? weatherCode, String? condition, bool? daylight, double? temperature, double? temperatureMin, double? temperatureMax, int? maxPrecipitationProbability, WindDto? wind, WeatherRainAlertDto? rainAlert, String? timezone
});


@override $WindDtoCopyWith<$Res>? get wind;@override $WeatherRainAlertDtoCopyWith<$Res>? get rainAlert;

}
/// @nodoc
class __$RideWeatherSummaryDtoCopyWithImpl<$Res>
    implements _$RideWeatherSummaryDtoCopyWith<$Res> {
  __$RideWeatherSummaryDtoCopyWithImpl(this._self, this._then);

  final _RideWeatherSummaryDto _self;
  final $Res Function(_RideWeatherSummaryDto) _then;

/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? availableFrom = freezed,Object? weatherCode = freezed,Object? condition = freezed,Object? daylight = freezed,Object? temperature = freezed,Object? temperatureMin = freezed,Object? temperatureMax = freezed,Object? maxPrecipitationProbability = freezed,Object? wind = freezed,Object? rainAlert = freezed,Object? timezone = freezed,}) {
  return _then(_RideWeatherSummaryDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,weatherCode: freezed == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as int?,condition: freezed == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String?,daylight: freezed == daylight ? _self.daylight : daylight // ignore: cast_nullable_to_non_nullable
as bool?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,temperatureMin: freezed == temperatureMin ? _self.temperatureMin : temperatureMin // ignore: cast_nullable_to_non_nullable
as double?,temperatureMax: freezed == temperatureMax ? _self.temperatureMax : temperatureMax // ignore: cast_nullable_to_non_nullable
as double?,maxPrecipitationProbability: freezed == maxPrecipitationProbability ? _self.maxPrecipitationProbability : maxPrecipitationProbability // ignore: cast_nullable_to_non_nullable
as int?,wind: freezed == wind ? _self.wind : wind // ignore: cast_nullable_to_non_nullable
as WindDto?,rainAlert: freezed == rainAlert ? _self.rainAlert : rainAlert // ignore: cast_nullable_to_non_nullable
as WeatherRainAlertDto?,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindDtoCopyWith<$Res>? get wind {
    if (_self.wind == null) {
    return null;
  }

  return $WindDtoCopyWith<$Res>(_self.wind!, (value) {
    return _then(_self.copyWith(wind: value));
  });
}/// Create a copy of RideWeatherSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherRainAlertDtoCopyWith<$Res>? get rainAlert {
    if (_self.rainAlert == null) {
    return null;
  }

  return $WeatherRainAlertDtoCopyWith<$Res>(_self.rainAlert!, (value) {
    return _then(_self.copyWith(rainAlert: value));
  });
}
}

// dart format on
