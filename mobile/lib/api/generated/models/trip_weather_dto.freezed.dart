// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_weather_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TripWeatherDto {

/// Overall state, over the stages not over yet. OK and STALE (shown, flagged as old) carry a forecast for at least one stage; NOT_YET_AVAILABLE (every stage with a route is beyond the horizon) comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION (no stage not over yet has a route) is worth a word to the organisers only; OUT_OF_RANGE (finished, cancelled, draft) shows nothing. Each stage also has its own, in its leg.
 String get status;/// One per live stage, in stage order (as TripDto.stages), stages already over (their estimated end passed) included with leg.status OUT_OF_RANGE; a stage under way keeps its forecast; a single one without stageId for a trip without stages. Empty when the trip is not published.
 List<TripStageWeatherDto> get stages;/// The credit the forecast's licence asks for
 WeatherAttributionDto get attribution;/// For NOT_YET_AVAILABLE: when the first forecast opens, seven days before the first stage with a route leaves
 String? get availableFrom;/// The oldest fetch among the forecasts read
 String? get fetchedAt;
/// Create a copy of TripWeatherDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripWeatherDtoCopyWith<TripWeatherDto> get copyWith => _$TripWeatherDtoCopyWithImpl<TripWeatherDto>(this as TripWeatherDto, _$identity);

  /// Serializes this TripWeatherDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TripWeatherDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripWeatherDto&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.stages, _this.stages)&&(identical(other.attribution, _this.attribution) || other.attribution == _this.attribution)&&(identical(other.availableFrom, _this.availableFrom) || other.availableFrom == _this.availableFrom)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TripWeatherDto;
  return Object.hash(runtimeType,_this.status,const DeepCollectionEquality().hash(_this.stages),_this.attribution,_this.availableFrom,_this.fetchedAt);
}

@override
String toString() {
  final _this = this as TripWeatherDto;
  return 'TripWeatherDto(status: ${_this.status}, stages: ${_this.stages}, attribution: ${_this.attribution}, availableFrom: ${_this.availableFrom}, fetchedAt: ${_this.fetchedAt})';
}


}

/// @nodoc
abstract mixin class $TripWeatherDtoCopyWith<$Res>  {
  factory $TripWeatherDtoCopyWith(TripWeatherDto value, $Res Function(TripWeatherDto) _then) = _$TripWeatherDtoCopyWithImpl;
@useResult
$Res call({
 String status, List<TripStageWeatherDto> stages, WeatherAttributionDto attribution, String? availableFrom, String? fetchedAt
});


$WeatherAttributionDtoCopyWith<$Res> get attribution;

}
/// @nodoc
class _$TripWeatherDtoCopyWithImpl<$Res>
    implements $TripWeatherDtoCopyWith<$Res> {
  _$TripWeatherDtoCopyWithImpl(this._self, this._then);

  final TripWeatherDto _self;
  final $Res Function(TripWeatherDto) _then;

/// Create a copy of TripWeatherDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? stages = null,Object? attribution = null,Object? availableFrom = freezed,Object? fetchedAt = freezed,}) {
  return _then(TripWeatherDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,stages: null == stages ? _self.stages : stages // ignore: cast_nullable_to_non_nullable
as List<TripStageWeatherDto>,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as WeatherAttributionDto,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of TripWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherAttributionDtoCopyWith<$Res> get attribution {
  
  return $WeatherAttributionDtoCopyWith<$Res>(_self.attribution, (value) {
    return _then(_self.copyWith(attribution: value));
  });
}
}


/// Adds pattern-matching-related methods to [TripWeatherDto].
extension TripWeatherDtoPatterns on TripWeatherDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripWeatherDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripWeatherDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripWeatherDto value)  $default,){
final _that = this;
switch (_that) {
case _TripWeatherDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripWeatherDto value)?  $default,){
final _that = this;
switch (_that) {
case _TripWeatherDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  List<TripStageWeatherDto> stages,  WeatherAttributionDto attribution,  String? availableFrom,  String? fetchedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripWeatherDto() when $default != null:
return $default(_that.status,_that.stages,_that.attribution,_that.availableFrom,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  List<TripStageWeatherDto> stages,  WeatherAttributionDto attribution,  String? availableFrom,  String? fetchedAt)  $default,) {final _that = this;
switch (_that) {
case _TripWeatherDto():
return $default(_that.status,_that.stages,_that.attribution,_that.availableFrom,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  List<TripStageWeatherDto> stages,  WeatherAttributionDto attribution,  String? availableFrom,  String? fetchedAt)?  $default,) {final _that = this;
switch (_that) {
case _TripWeatherDto() when $default != null:
return $default(_that.status,_that.stages,_that.attribution,_that.availableFrom,_that.fetchedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripWeatherDto implements TripWeatherDto {
  const _TripWeatherDto({required this.status, required  List<TripStageWeatherDto> stages, required this.attribution, this.availableFrom, this.fetchedAt}): _stages = stages;
  factory _TripWeatherDto.fromJson(Map<String, dynamic> json) => _$TripWeatherDtoFromJson(json);

/// Overall state, over the stages not over yet. OK and STALE (shown, flagged as old) carry a forecast for at least one stage; NOT_YET_AVAILABLE (every stage with a route is beyond the horizon) comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION (no stage not over yet has a route) is worth a word to the organisers only; OUT_OF_RANGE (finished, cancelled, draft) shows nothing. Each stage also has its own, in its leg.
@override final  String status;
/// One per live stage, in stage order (as TripDto.stages), stages already over (their estimated end passed) included with leg.status OUT_OF_RANGE; a stage under way keeps its forecast; a single one without stageId for a trip without stages. Empty when the trip is not published.
 final  List<TripStageWeatherDto> _stages;
/// One per live stage, in stage order (as TripDto.stages), stages already over (their estimated end passed) included with leg.status OUT_OF_RANGE; a stage under way keeps its forecast; a single one without stageId for a trip without stages. Empty when the trip is not published.
@override List<TripStageWeatherDto> get stages {
  if (_stages is EqualUnmodifiableListView) return _stages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stages);
}

/// The credit the forecast's licence asks for
@override final  WeatherAttributionDto attribution;
/// For NOT_YET_AVAILABLE: when the first forecast opens, seven days before the first stage with a route leaves
@override final  String? availableFrom;
/// The oldest fetch among the forecasts read
@override final  String? fetchedAt;

/// Create a copy of TripWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripWeatherDtoCopyWith<_TripWeatherDto> get copyWith => __$TripWeatherDtoCopyWithImpl<_TripWeatherDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripWeatherDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripWeatherDto&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.stages, _stages)&&(identical(other.attribution, attribution) || other.attribution == attribution)&&(identical(other.availableFrom, availableFrom) || other.availableFrom == availableFrom)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_stages),attribution,availableFrom,fetchedAt);
}

@override
String toString() {
    return 'TripWeatherDto(status: $status, stages: $stages, attribution: $attribution, availableFrom: $availableFrom, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class _$TripWeatherDtoCopyWith<$Res> implements $TripWeatherDtoCopyWith<$Res> {
  factory _$TripWeatherDtoCopyWith(_TripWeatherDto value, $Res Function(_TripWeatherDto) _then) = __$TripWeatherDtoCopyWithImpl;
@override @useResult
$Res call({
 String status, List<TripStageWeatherDto> stages, WeatherAttributionDto attribution, String? availableFrom, String? fetchedAt
});


@override $WeatherAttributionDtoCopyWith<$Res> get attribution;

}
/// @nodoc
class __$TripWeatherDtoCopyWithImpl<$Res>
    implements _$TripWeatherDtoCopyWith<$Res> {
  __$TripWeatherDtoCopyWithImpl(this._self, this._then);

  final _TripWeatherDto _self;
  final $Res Function(_TripWeatherDto) _then;

/// Create a copy of TripWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? stages = null,Object? attribution = null,Object? availableFrom = freezed,Object? fetchedAt = freezed,}) {
  return _then(_TripWeatherDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,stages: null == stages ? _self._stages : stages // ignore: cast_nullable_to_non_nullable
as List<TripStageWeatherDto>,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as WeatherAttributionDto,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of TripWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherAttributionDtoCopyWith<$Res> get attribution {
  
  return $WeatherAttributionDtoCopyWith<$Res>(_self.attribution, (value) {
    return _then(_self.copyWith(attribution: value));
  });
}
}

// dart format on
