// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weather_leg_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WeatherLegDto {

/// State of this leg's forecast. NO_LOCATION when the leg has no route to sample: then no checkpoint, no segment. NOT_YET_AVAILABLE when it leaves beyond the seven-day horizon: checkpoints and times without weather, and availableFrom. OUT_OF_RANGE for a trip stage already over (its estimated end passed): nothing to show.
 String get status;/// When the leg leaves
 String get startTime;/// Speed used for the passages, km/h
 double get averageSpeed;/// Whether averageSpeed is the 25 km/h default, the group or stage having none — to be said on screen
 bool get speedIsDefault;/// Length of the leg's route, metres
 double get distance;/// Estimated arrival
 String get arrivalTime;/// Forecast points, start to finish
 List<WeatherCheckpointDto> get checkpoints;/// The wind stretch by stretch, from one checkpoint to the next
 List<WindSegmentDto> get segments;/// Distance ridden against, across and with the wind
 WindExposureDto get windExposure;/// The ride group (TSID). Absent for a ride without groups — the leg rides the ride's own route — and for a trip's legs, which TripStageWeatherDto.stageId names.
 String? get groupId;/// For NOT_YET_AVAILABLE: when this leg's forecast opens, seven days before it leaves
 String? get availableFrom;/// The oldest fetch among the forecasts this leg reads
 String? get fetchedAt;/// The leg's dominant wind: circular mean of the directions, mean speed, highest gust
 WindDto? get prevailingWind;/// The first checkpoint where rain becomes likely, if any
 WeatherRainAlertDto? get rainAlert;/// The leg's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert — as TripStageWeatherDto.summary for a stage. Present when status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only).
 RideWeatherSummaryDto? get summary;/// For a ride's leg: the weather at the ride's meeting point when this group leaves (startTime), sunrise and sunset included — RideWeatherDto.departure is the same at the ride's own time. Same states: conditions for OK and STALE only, UNAVAILABLE when the cache has no hour near the group's start, NOT_YET_AVAILABLE when the group leaves beyond the horizon. Absent on a trip's legs, whose departure TripStageWeatherDto.departure carries.
 DepartureWeatherDto? get departure;
/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherLegDtoCopyWith<WeatherLegDto> get copyWith => _$WeatherLegDtoCopyWithImpl<WeatherLegDto>(this as WeatherLegDto, _$identity);

  /// Serializes this WeatherLegDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WeatherLegDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherLegDto&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.startTime, _this.startTime) || other.startTime == _this.startTime)&&(identical(other.averageSpeed, _this.averageSpeed) || other.averageSpeed == _this.averageSpeed)&&(identical(other.speedIsDefault, _this.speedIsDefault) || other.speedIsDefault == _this.speedIsDefault)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.arrivalTime, _this.arrivalTime) || other.arrivalTime == _this.arrivalTime)&&const DeepCollectionEquality().equals(other.checkpoints, _this.checkpoints)&&const DeepCollectionEquality().equals(other.segments, _this.segments)&&(identical(other.windExposure, _this.windExposure) || other.windExposure == _this.windExposure)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.availableFrom, _this.availableFrom) || other.availableFrom == _this.availableFrom)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt)&&(identical(other.prevailingWind, _this.prevailingWind) || other.prevailingWind == _this.prevailingWind)&&(identical(other.rainAlert, _this.rainAlert) || other.rainAlert == _this.rainAlert)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.departure, _this.departure) || other.departure == _this.departure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WeatherLegDto;
  return Object.hash(runtimeType,_this.status,_this.startTime,_this.averageSpeed,_this.speedIsDefault,_this.distance,_this.arrivalTime,const DeepCollectionEquality().hash(_this.checkpoints),const DeepCollectionEquality().hash(_this.segments),_this.windExposure,_this.groupId,_this.availableFrom,_this.fetchedAt,_this.prevailingWind,_this.rainAlert,_this.summary,_this.departure);
}

@override
String toString() {
  final _this = this as WeatherLegDto;
  return 'WeatherLegDto(status: ${_this.status}, startTime: ${_this.startTime}, averageSpeed: ${_this.averageSpeed}, speedIsDefault: ${_this.speedIsDefault}, distance: ${_this.distance}, arrivalTime: ${_this.arrivalTime}, checkpoints: ${_this.checkpoints}, segments: ${_this.segments}, windExposure: ${_this.windExposure}, groupId: ${_this.groupId}, availableFrom: ${_this.availableFrom}, fetchedAt: ${_this.fetchedAt}, prevailingWind: ${_this.prevailingWind}, rainAlert: ${_this.rainAlert}, summary: ${_this.summary}, departure: ${_this.departure})';
}


}

/// @nodoc
abstract mixin class $WeatherLegDtoCopyWith<$Res>  {
  factory $WeatherLegDtoCopyWith(WeatherLegDto value, $Res Function(WeatherLegDto) _then) = _$WeatherLegDtoCopyWithImpl;
@useResult
$Res call({
 String status, String startTime, double averageSpeed, bool speedIsDefault, double distance, String arrivalTime, List<WeatherCheckpointDto> checkpoints, List<WindSegmentDto> segments, WindExposureDto windExposure, String? groupId, String? availableFrom, String? fetchedAt, WindDto? prevailingWind, WeatherRainAlertDto? rainAlert, RideWeatherSummaryDto? summary, DepartureWeatherDto? departure
});


$WindExposureDtoCopyWith<$Res> get windExposure;$WindDtoCopyWith<$Res>? get prevailingWind;$WeatherRainAlertDtoCopyWith<$Res>? get rainAlert;$RideWeatherSummaryDtoCopyWith<$Res>? get summary;$DepartureWeatherDtoCopyWith<$Res>? get departure;

}
/// @nodoc
class _$WeatherLegDtoCopyWithImpl<$Res>
    implements $WeatherLegDtoCopyWith<$Res> {
  _$WeatherLegDtoCopyWithImpl(this._self, this._then);

  final WeatherLegDto _self;
  final $Res Function(WeatherLegDto) _then;

/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? startTime = null,Object? averageSpeed = null,Object? speedIsDefault = null,Object? distance = null,Object? arrivalTime = null,Object? checkpoints = null,Object? segments = null,Object? windExposure = null,Object? groupId = freezed,Object? availableFrom = freezed,Object? fetchedAt = freezed,Object? prevailingWind = freezed,Object? rainAlert = freezed,Object? summary = freezed,Object? departure = freezed,}) {
  return _then(WeatherLegDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,averageSpeed: null == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double,speedIsDefault: null == speedIsDefault ? _self.speedIsDefault : speedIsDefault // ignore: cast_nullable_to_non_nullable
as bool,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,arrivalTime: null == arrivalTime ? _self.arrivalTime : arrivalTime // ignore: cast_nullable_to_non_nullable
as String,checkpoints: null == checkpoints ? _self.checkpoints : checkpoints // ignore: cast_nullable_to_non_nullable
as List<WeatherCheckpointDto>,segments: null == segments ? _self.segments : segments // ignore: cast_nullable_to_non_nullable
as List<WindSegmentDto>,windExposure: null == windExposure ? _self.windExposure : windExposure // ignore: cast_nullable_to_non_nullable
as WindExposureDto,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as String?,prevailingWind: freezed == prevailingWind ? _self.prevailingWind : prevailingWind // ignore: cast_nullable_to_non_nullable
as WindDto?,rainAlert: freezed == rainAlert ? _self.rainAlert : rainAlert // ignore: cast_nullable_to_non_nullable
as WeatherRainAlertDto?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,departure: freezed == departure ? _self.departure : departure // ignore: cast_nullable_to_non_nullable
as DepartureWeatherDto?,
  ));
}
/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindExposureDtoCopyWith<$Res> get windExposure {
  
  return $WindExposureDtoCopyWith<$Res>(_self.windExposure, (value) {
    return _then(_self.copyWith(windExposure: value));
  });
}/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindDtoCopyWith<$Res>? get prevailingWind {
    if (_self.prevailingWind == null) {
    return null;
  }

  return $WindDtoCopyWith<$Res>(_self.prevailingWind!, (value) {
    return _then(_self.copyWith(prevailingWind: value));
  });
}/// Create a copy of WeatherLegDto
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
}/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RideWeatherSummaryDtoCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $RideWeatherSummaryDtoCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DepartureWeatherDtoCopyWith<$Res>? get departure {
    if (_self.departure == null) {
    return null;
  }

  return $DepartureWeatherDtoCopyWith<$Res>(_self.departure!, (value) {
    return _then(_self.copyWith(departure: value));
  });
}
}


/// Adds pattern-matching-related methods to [WeatherLegDto].
extension WeatherLegDtoPatterns on WeatherLegDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeatherLegDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeatherLegDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeatherLegDto value)  $default,){
final _that = this;
switch (_that) {
case _WeatherLegDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeatherLegDto value)?  $default,){
final _that = this;
switch (_that) {
case _WeatherLegDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  String startTime,  double averageSpeed,  bool speedIsDefault,  double distance,  String arrivalTime,  List<WeatherCheckpointDto> checkpoints,  List<WindSegmentDto> segments,  WindExposureDto windExposure,  String? groupId,  String? availableFrom,  String? fetchedAt,  WindDto? prevailingWind,  WeatherRainAlertDto? rainAlert,  RideWeatherSummaryDto? summary,  DepartureWeatherDto? departure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeatherLegDto() when $default != null:
return $default(_that.status,_that.startTime,_that.averageSpeed,_that.speedIsDefault,_that.distance,_that.arrivalTime,_that.checkpoints,_that.segments,_that.windExposure,_that.groupId,_that.availableFrom,_that.fetchedAt,_that.prevailingWind,_that.rainAlert,_that.summary,_that.departure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  String startTime,  double averageSpeed,  bool speedIsDefault,  double distance,  String arrivalTime,  List<WeatherCheckpointDto> checkpoints,  List<WindSegmentDto> segments,  WindExposureDto windExposure,  String? groupId,  String? availableFrom,  String? fetchedAt,  WindDto? prevailingWind,  WeatherRainAlertDto? rainAlert,  RideWeatherSummaryDto? summary,  DepartureWeatherDto? departure)  $default,) {final _that = this;
switch (_that) {
case _WeatherLegDto():
return $default(_that.status,_that.startTime,_that.averageSpeed,_that.speedIsDefault,_that.distance,_that.arrivalTime,_that.checkpoints,_that.segments,_that.windExposure,_that.groupId,_that.availableFrom,_that.fetchedAt,_that.prevailingWind,_that.rainAlert,_that.summary,_that.departure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  String startTime,  double averageSpeed,  bool speedIsDefault,  double distance,  String arrivalTime,  List<WeatherCheckpointDto> checkpoints,  List<WindSegmentDto> segments,  WindExposureDto windExposure,  String? groupId,  String? availableFrom,  String? fetchedAt,  WindDto? prevailingWind,  WeatherRainAlertDto? rainAlert,  RideWeatherSummaryDto? summary,  DepartureWeatherDto? departure)?  $default,) {final _that = this;
switch (_that) {
case _WeatherLegDto() when $default != null:
return $default(_that.status,_that.startTime,_that.averageSpeed,_that.speedIsDefault,_that.distance,_that.arrivalTime,_that.checkpoints,_that.segments,_that.windExposure,_that.groupId,_that.availableFrom,_that.fetchedAt,_that.prevailingWind,_that.rainAlert,_that.summary,_that.departure);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeatherLegDto implements WeatherLegDto {
  const _WeatherLegDto({required this.status, required this.startTime, required this.averageSpeed, required this.speedIsDefault, required this.distance, required this.arrivalTime, required  List<WeatherCheckpointDto> checkpoints, required  List<WindSegmentDto> segments, required this.windExposure, this.groupId, this.availableFrom, this.fetchedAt, this.prevailingWind, this.rainAlert, this.summary, this.departure}): _checkpoints = checkpoints,_segments = segments;
  factory _WeatherLegDto.fromJson(Map<String, dynamic> json) => _$WeatherLegDtoFromJson(json);

/// State of this leg's forecast. NO_LOCATION when the leg has no route to sample: then no checkpoint, no segment. NOT_YET_AVAILABLE when it leaves beyond the seven-day horizon: checkpoints and times without weather, and availableFrom. OUT_OF_RANGE for a trip stage already over (its estimated end passed): nothing to show.
@override final  String status;
/// When the leg leaves
@override final  String startTime;
/// Speed used for the passages, km/h
@override final  double averageSpeed;
/// Whether averageSpeed is the 25 km/h default, the group or stage having none — to be said on screen
@override final  bool speedIsDefault;
/// Length of the leg's route, metres
@override final  double distance;
/// Estimated arrival
@override final  String arrivalTime;
/// Forecast points, start to finish
 final  List<WeatherCheckpointDto> _checkpoints;
/// Forecast points, start to finish
@override List<WeatherCheckpointDto> get checkpoints {
  if (_checkpoints is EqualUnmodifiableListView) return _checkpoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_checkpoints);
}

/// The wind stretch by stretch, from one checkpoint to the next
 final  List<WindSegmentDto> _segments;
/// The wind stretch by stretch, from one checkpoint to the next
@override List<WindSegmentDto> get segments {
  if (_segments is EqualUnmodifiableListView) return _segments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_segments);
}

/// Distance ridden against, across and with the wind
@override final  WindExposureDto windExposure;
/// The ride group (TSID). Absent for a ride without groups — the leg rides the ride's own route — and for a trip's legs, which TripStageWeatherDto.stageId names.
@override final  String? groupId;
/// For NOT_YET_AVAILABLE: when this leg's forecast opens, seven days before it leaves
@override final  String? availableFrom;
/// The oldest fetch among the forecasts this leg reads
@override final  String? fetchedAt;
/// The leg's dominant wind: circular mean of the directions, mean speed, highest gust
@override final  WindDto? prevailingWind;
/// The first checkpoint where rain becomes likely, if any
@override final  WeatherRainAlertDto? rainAlert;
/// The leg's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert — as TripStageWeatherDto.summary for a stage. Present when status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only).
@override final  RideWeatherSummaryDto? summary;
/// For a ride's leg: the weather at the ride's meeting point when this group leaves (startTime), sunrise and sunset included — RideWeatherDto.departure is the same at the ride's own time. Same states: conditions for OK and STALE only, UNAVAILABLE when the cache has no hour near the group's start, NOT_YET_AVAILABLE when the group leaves beyond the horizon. Absent on a trip's legs, whose departure TripStageWeatherDto.departure carries.
@override final  DepartureWeatherDto? departure;

/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeatherLegDtoCopyWith<_WeatherLegDto> get copyWith => __$WeatherLegDtoCopyWithImpl<_WeatherLegDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeatherLegDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeatherLegDto&&(identical(other.status, status) || other.status == status)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.averageSpeed, averageSpeed) || other.averageSpeed == averageSpeed)&&(identical(other.speedIsDefault, speedIsDefault) || other.speedIsDefault == speedIsDefault)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.arrivalTime, arrivalTime) || other.arrivalTime == arrivalTime)&&const DeepCollectionEquality().equals(other.checkpoints, _checkpoints)&&const DeepCollectionEquality().equals(other.segments, _segments)&&(identical(other.windExposure, windExposure) || other.windExposure == windExposure)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.availableFrom, availableFrom) || other.availableFrom == availableFrom)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt)&&(identical(other.prevailingWind, prevailingWind) || other.prevailingWind == prevailingWind)&&(identical(other.rainAlert, rainAlert) || other.rainAlert == rainAlert)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.departure, departure) || other.departure == departure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,startTime,averageSpeed,speedIsDefault,distance,arrivalTime,const DeepCollectionEquality().hash(_checkpoints),const DeepCollectionEquality().hash(_segments),windExposure,groupId,availableFrom,fetchedAt,prevailingWind,rainAlert,summary,departure);
}

@override
String toString() {
    return 'WeatherLegDto(status: $status, startTime: $startTime, averageSpeed: $averageSpeed, speedIsDefault: $speedIsDefault, distance: $distance, arrivalTime: $arrivalTime, checkpoints: $checkpoints, segments: $segments, windExposure: $windExposure, groupId: $groupId, availableFrom: $availableFrom, fetchedAt: $fetchedAt, prevailingWind: $prevailingWind, rainAlert: $rainAlert, summary: $summary, departure: $departure)';
}


}

/// @nodoc
abstract mixin class _$WeatherLegDtoCopyWith<$Res> implements $WeatherLegDtoCopyWith<$Res> {
  factory _$WeatherLegDtoCopyWith(_WeatherLegDto value, $Res Function(_WeatherLegDto) _then) = __$WeatherLegDtoCopyWithImpl;
@override @useResult
$Res call({
 String status, String startTime, double averageSpeed, bool speedIsDefault, double distance, String arrivalTime, List<WeatherCheckpointDto> checkpoints, List<WindSegmentDto> segments, WindExposureDto windExposure, String? groupId, String? availableFrom, String? fetchedAt, WindDto? prevailingWind, WeatherRainAlertDto? rainAlert, RideWeatherSummaryDto? summary, DepartureWeatherDto? departure
});


@override $WindExposureDtoCopyWith<$Res> get windExposure;@override $WindDtoCopyWith<$Res>? get prevailingWind;@override $WeatherRainAlertDtoCopyWith<$Res>? get rainAlert;@override $RideWeatherSummaryDtoCopyWith<$Res>? get summary;@override $DepartureWeatherDtoCopyWith<$Res>? get departure;

}
/// @nodoc
class __$WeatherLegDtoCopyWithImpl<$Res>
    implements _$WeatherLegDtoCopyWith<$Res> {
  __$WeatherLegDtoCopyWithImpl(this._self, this._then);

  final _WeatherLegDto _self;
  final $Res Function(_WeatherLegDto) _then;

/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? startTime = null,Object? averageSpeed = null,Object? speedIsDefault = null,Object? distance = null,Object? arrivalTime = null,Object? checkpoints = null,Object? segments = null,Object? windExposure = null,Object? groupId = freezed,Object? availableFrom = freezed,Object? fetchedAt = freezed,Object? prevailingWind = freezed,Object? rainAlert = freezed,Object? summary = freezed,Object? departure = freezed,}) {
  return _then(_WeatherLegDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,averageSpeed: null == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double,speedIsDefault: null == speedIsDefault ? _self.speedIsDefault : speedIsDefault // ignore: cast_nullable_to_non_nullable
as bool,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,arrivalTime: null == arrivalTime ? _self.arrivalTime : arrivalTime // ignore: cast_nullable_to_non_nullable
as String,checkpoints: null == checkpoints ? _self._checkpoints : checkpoints // ignore: cast_nullable_to_non_nullable
as List<WeatherCheckpointDto>,segments: null == segments ? _self._segments : segments // ignore: cast_nullable_to_non_nullable
as List<WindSegmentDto>,windExposure: null == windExposure ? _self.windExposure : windExposure // ignore: cast_nullable_to_non_nullable
as WindExposureDto,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as String?,prevailingWind: freezed == prevailingWind ? _self.prevailingWind : prevailingWind // ignore: cast_nullable_to_non_nullable
as WindDto?,rainAlert: freezed == rainAlert ? _self.rainAlert : rainAlert // ignore: cast_nullable_to_non_nullable
as WeatherRainAlertDto?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,departure: freezed == departure ? _self.departure : departure // ignore: cast_nullable_to_non_nullable
as DepartureWeatherDto?,
  ));
}

/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindExposureDtoCopyWith<$Res> get windExposure {
  
  return $WindExposureDtoCopyWith<$Res>(_self.windExposure, (value) {
    return _then(_self.copyWith(windExposure: value));
  });
}/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WindDtoCopyWith<$Res>? get prevailingWind {
    if (_self.prevailingWind == null) {
    return null;
  }

  return $WindDtoCopyWith<$Res>(_self.prevailingWind!, (value) {
    return _then(_self.copyWith(prevailingWind: value));
  });
}/// Create a copy of WeatherLegDto
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
}/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RideWeatherSummaryDtoCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $RideWeatherSummaryDtoCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of WeatherLegDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DepartureWeatherDtoCopyWith<$Res>? get departure {
    if (_self.departure == null) {
    return null;
  }

  return $DepartureWeatherDtoCopyWith<$Res>(_self.departure!, (value) {
    return _then(_self.copyWith(departure: value));
  });
}
}

// dart format on
