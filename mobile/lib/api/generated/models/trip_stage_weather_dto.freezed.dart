// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_stage_weather_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TripStageWeatherDto {

/// The stage's route, at its estimated passages (stage speed, else 25 km/h)
 WeatherLegDto get leg;/// The weather when the stage leaves, at its first forecast point: conditions, sunrise and sunset, as RideWeatherDto.departure for a ride. OUT_OF_RANGE once the stage has left, NO_LOCATION without a route, NOT_YET_AVAILABLE beyond the horizon.
 DepartureWeatherDto get departure;/// The stage (TSID), as TripStageDto.id. Absent for the single leg of a trip without stages, which rides the trip's own route at its own time.
 String? get stageId;/// The stage's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert. Present when leg.status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only).
 RideWeatherSummaryDto? get summary;
/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripStageWeatherDtoCopyWith<TripStageWeatherDto> get copyWith => _$TripStageWeatherDtoCopyWithImpl<TripStageWeatherDto>(this as TripStageWeatherDto, _$identity);

  /// Serializes this TripStageWeatherDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TripStageWeatherDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripStageWeatherDto&&(identical(other.leg, _this.leg) || other.leg == _this.leg)&&(identical(other.departure, _this.departure) || other.departure == _this.departure)&&(identical(other.stageId, _this.stageId) || other.stageId == _this.stageId)&&(identical(other.summary, _this.summary) || other.summary == _this.summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TripStageWeatherDto;
  return Object.hash(runtimeType,_this.leg,_this.departure,_this.stageId,_this.summary);
}

@override
String toString() {
  final _this = this as TripStageWeatherDto;
  return 'TripStageWeatherDto(leg: ${_this.leg}, departure: ${_this.departure}, stageId: ${_this.stageId}, summary: ${_this.summary})';
}


}

/// @nodoc
abstract mixin class $TripStageWeatherDtoCopyWith<$Res>  {
  factory $TripStageWeatherDtoCopyWith(TripStageWeatherDto value, $Res Function(TripStageWeatherDto) _then) = _$TripStageWeatherDtoCopyWithImpl;
@useResult
$Res call({
 WeatherLegDto leg, DepartureWeatherDto departure, String? stageId, RideWeatherSummaryDto? summary
});


$WeatherLegDtoCopyWith<$Res> get leg;$DepartureWeatherDtoCopyWith<$Res> get departure;$RideWeatherSummaryDtoCopyWith<$Res>? get summary;

}
/// @nodoc
class _$TripStageWeatherDtoCopyWithImpl<$Res>
    implements $TripStageWeatherDtoCopyWith<$Res> {
  _$TripStageWeatherDtoCopyWithImpl(this._self, this._then);

  final TripStageWeatherDto _self;
  final $Res Function(TripStageWeatherDto) _then;

/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? leg = null,Object? departure = null,Object? stageId = freezed,Object? summary = freezed,}) {
  return _then(TripStageWeatherDto(
leg: null == leg ? _self.leg : leg // ignore: cast_nullable_to_non_nullable
as WeatherLegDto,departure: null == departure ? _self.departure : departure // ignore: cast_nullable_to_non_nullable
as DepartureWeatherDto,stageId: freezed == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,
  ));
}
/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherLegDtoCopyWith<$Res> get leg {
  
  return $WeatherLegDtoCopyWith<$Res>(_self.leg, (value) {
    return _then(_self.copyWith(leg: value));
  });
}/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DepartureWeatherDtoCopyWith<$Res> get departure {
  
  return $DepartureWeatherDtoCopyWith<$Res>(_self.departure, (value) {
    return _then(_self.copyWith(departure: value));
  });
}/// Create a copy of TripStageWeatherDto
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
}
}


/// Adds pattern-matching-related methods to [TripStageWeatherDto].
extension TripStageWeatherDtoPatterns on TripStageWeatherDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripStageWeatherDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripStageWeatherDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripStageWeatherDto value)  $default,){
final _that = this;
switch (_that) {
case _TripStageWeatherDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripStageWeatherDto value)?  $default,){
final _that = this;
switch (_that) {
case _TripStageWeatherDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WeatherLegDto leg,  DepartureWeatherDto departure,  String? stageId,  RideWeatherSummaryDto? summary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripStageWeatherDto() when $default != null:
return $default(_that.leg,_that.departure,_that.stageId,_that.summary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WeatherLegDto leg,  DepartureWeatherDto departure,  String? stageId,  RideWeatherSummaryDto? summary)  $default,) {final _that = this;
switch (_that) {
case _TripStageWeatherDto():
return $default(_that.leg,_that.departure,_that.stageId,_that.summary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WeatherLegDto leg,  DepartureWeatherDto departure,  String? stageId,  RideWeatherSummaryDto? summary)?  $default,) {final _that = this;
switch (_that) {
case _TripStageWeatherDto() when $default != null:
return $default(_that.leg,_that.departure,_that.stageId,_that.summary);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripStageWeatherDto implements TripStageWeatherDto {
  const _TripStageWeatherDto({required this.leg, required this.departure, this.stageId, this.summary});
  factory _TripStageWeatherDto.fromJson(Map<String, dynamic> json) => _$TripStageWeatherDtoFromJson(json);

/// The stage's route, at its estimated passages (stage speed, else 25 km/h)
@override final  WeatherLegDto leg;
/// The weather when the stage leaves, at its first forecast point: conditions, sunrise and sunset, as RideWeatherDto.departure for a ride. OUT_OF_RANGE once the stage has left, NO_LOCATION without a route, NOT_YET_AVAILABLE beyond the horizon.
@override final  DepartureWeatherDto departure;
/// The stage (TSID), as TripStageDto.id. Absent for the single leg of a trip without stages, which rides the trip's own route at its own time.
@override final  String? stageId;
/// The stage's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert. Present when leg.status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only).
@override final  RideWeatherSummaryDto? summary;

/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripStageWeatherDtoCopyWith<_TripStageWeatherDto> get copyWith => __$TripStageWeatherDtoCopyWithImpl<_TripStageWeatherDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripStageWeatherDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripStageWeatherDto&&(identical(other.leg, leg) || other.leg == leg)&&(identical(other.departure, departure) || other.departure == departure)&&(identical(other.stageId, stageId) || other.stageId == stageId)&&(identical(other.summary, summary) || other.summary == summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,leg,departure,stageId,summary);
}

@override
String toString() {
    return 'TripStageWeatherDto(leg: $leg, departure: $departure, stageId: $stageId, summary: $summary)';
}


}

/// @nodoc
abstract mixin class _$TripStageWeatherDtoCopyWith<$Res> implements $TripStageWeatherDtoCopyWith<$Res> {
  factory _$TripStageWeatherDtoCopyWith(_TripStageWeatherDto value, $Res Function(_TripStageWeatherDto) _then) = __$TripStageWeatherDtoCopyWithImpl;
@override @useResult
$Res call({
 WeatherLegDto leg, DepartureWeatherDto departure, String? stageId, RideWeatherSummaryDto? summary
});


@override $WeatherLegDtoCopyWith<$Res> get leg;@override $DepartureWeatherDtoCopyWith<$Res> get departure;@override $RideWeatherSummaryDtoCopyWith<$Res>? get summary;

}
/// @nodoc
class __$TripStageWeatherDtoCopyWithImpl<$Res>
    implements _$TripStageWeatherDtoCopyWith<$Res> {
  __$TripStageWeatherDtoCopyWithImpl(this._self, this._then);

  final _TripStageWeatherDto _self;
  final $Res Function(_TripStageWeatherDto) _then;

/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? leg = null,Object? departure = null,Object? stageId = freezed,Object? summary = freezed,}) {
  return _then(_TripStageWeatherDto(
leg: null == leg ? _self.leg : leg // ignore: cast_nullable_to_non_nullable
as WeatherLegDto,departure: null == departure ? _self.departure : departure // ignore: cast_nullable_to_non_nullable
as DepartureWeatherDto,stageId: freezed == stageId ? _self.stageId : stageId // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,
  ));
}

/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherLegDtoCopyWith<$Res> get leg {
  
  return $WeatherLegDtoCopyWith<$Res>(_self.leg, (value) {
    return _then(_self.copyWith(leg: value));
  });
}/// Create a copy of TripStageWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DepartureWeatherDtoCopyWith<$Res> get departure {
  
  return $DepartureWeatherDtoCopyWith<$Res>(_self.departure, (value) {
    return _then(_self.copyWith(departure: value));
  });
}/// Create a copy of TripStageWeatherDto
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
}
}

// dart format on
