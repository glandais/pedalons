// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_weather_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideWeatherDto {

/// Overall state. OK and STALE (shown, flagged as old) carry the forecast; NOT_YET_AVAILABLE comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION is worth a word to the organisers only; OUT_OF_RANGE (over — its last group back, the ride's estimated end —, cancelled) shows nothing. A ride that has left but whose groups are still out, or still to leave, keeps its forecast.
 String get status;/// The meeting point when the ride leaves (its dateTime). Each leg carries its own, at the group's start.
 DepartureWeatherDto get departure;/// One per group, in group order; a single one without groupId for a ride without groups. Empty for OUT_OF_RANGE, NO_LOCATION and NOT_YET_AVAILABLE.
 List<WeatherLegDto> get legs;/// The credit the forecast's licence asks for
 WeatherAttributionDto get attribution;/// For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure
 String? get availableFrom;/// The oldest fetch among the forecasts read
 String? get fetchedAt;
/// Create a copy of RideWeatherDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideWeatherDtoCopyWith<RideWeatherDto> get copyWith => _$RideWeatherDtoCopyWithImpl<RideWeatherDto>(this as RideWeatherDto, _$identity);

  /// Serializes this RideWeatherDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RideWeatherDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideWeatherDto&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.departure, _this.departure) || other.departure == _this.departure)&&const DeepCollectionEquality().equals(other.legs, _this.legs)&&(identical(other.attribution, _this.attribution) || other.attribution == _this.attribution)&&(identical(other.availableFrom, _this.availableFrom) || other.availableFrom == _this.availableFrom)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RideWeatherDto;
  return Object.hash(runtimeType,_this.status,_this.departure,const DeepCollectionEquality().hash(_this.legs),_this.attribution,_this.availableFrom,_this.fetchedAt);
}

@override
String toString() {
  final _this = this as RideWeatherDto;
  return 'RideWeatherDto(status: ${_this.status}, departure: ${_this.departure}, legs: ${_this.legs}, attribution: ${_this.attribution}, availableFrom: ${_this.availableFrom}, fetchedAt: ${_this.fetchedAt})';
}


}

/// @nodoc
abstract mixin class $RideWeatherDtoCopyWith<$Res>  {
  factory $RideWeatherDtoCopyWith(RideWeatherDto value, $Res Function(RideWeatherDto) _then) = _$RideWeatherDtoCopyWithImpl;
@useResult
$Res call({
 String status, DepartureWeatherDto departure, List<WeatherLegDto> legs, WeatherAttributionDto attribution, String? availableFrom, String? fetchedAt
});


$DepartureWeatherDtoCopyWith<$Res> get departure;$WeatherAttributionDtoCopyWith<$Res> get attribution;

}
/// @nodoc
class _$RideWeatherDtoCopyWithImpl<$Res>
    implements $RideWeatherDtoCopyWith<$Res> {
  _$RideWeatherDtoCopyWithImpl(this._self, this._then);

  final RideWeatherDto _self;
  final $Res Function(RideWeatherDto) _then;

/// Create a copy of RideWeatherDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? departure = null,Object? legs = null,Object? attribution = null,Object? availableFrom = freezed,Object? fetchedAt = freezed,}) {
  return _then(RideWeatherDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,departure: null == departure ? _self.departure : departure // ignore: cast_nullable_to_non_nullable
as DepartureWeatherDto,legs: null == legs ? _self.legs : legs // ignore: cast_nullable_to_non_nullable
as List<WeatherLegDto>,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as WeatherAttributionDto,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of RideWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DepartureWeatherDtoCopyWith<$Res> get departure {
  
  return $DepartureWeatherDtoCopyWith<$Res>(_self.departure, (value) {
    return _then(_self.copyWith(departure: value));
  });
}/// Create a copy of RideWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherAttributionDtoCopyWith<$Res> get attribution {
  
  return $WeatherAttributionDtoCopyWith<$Res>(_self.attribution, (value) {
    return _then(_self.copyWith(attribution: value));
  });
}
}


/// Adds pattern-matching-related methods to [RideWeatherDto].
extension RideWeatherDtoPatterns on RideWeatherDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideWeatherDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideWeatherDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideWeatherDto value)  $default,){
final _that = this;
switch (_that) {
case _RideWeatherDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideWeatherDto value)?  $default,){
final _that = this;
switch (_that) {
case _RideWeatherDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  DepartureWeatherDto departure,  List<WeatherLegDto> legs,  WeatherAttributionDto attribution,  String? availableFrom,  String? fetchedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideWeatherDto() when $default != null:
return $default(_that.status,_that.departure,_that.legs,_that.attribution,_that.availableFrom,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  DepartureWeatherDto departure,  List<WeatherLegDto> legs,  WeatherAttributionDto attribution,  String? availableFrom,  String? fetchedAt)  $default,) {final _that = this;
switch (_that) {
case _RideWeatherDto():
return $default(_that.status,_that.departure,_that.legs,_that.attribution,_that.availableFrom,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  DepartureWeatherDto departure,  List<WeatherLegDto> legs,  WeatherAttributionDto attribution,  String? availableFrom,  String? fetchedAt)?  $default,) {final _that = this;
switch (_that) {
case _RideWeatherDto() when $default != null:
return $default(_that.status,_that.departure,_that.legs,_that.attribution,_that.availableFrom,_that.fetchedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideWeatherDto implements RideWeatherDto {
  const _RideWeatherDto({required this.status, required this.departure, required  List<WeatherLegDto> legs, required this.attribution, this.availableFrom, this.fetchedAt}): _legs = legs;
  factory _RideWeatherDto.fromJson(Map<String, dynamic> json) => _$RideWeatherDtoFromJson(json);

/// Overall state. OK and STALE (shown, flagged as old) carry the forecast; NOT_YET_AVAILABLE comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION is worth a word to the organisers only; OUT_OF_RANGE (over — its last group back, the ride's estimated end —, cancelled) shows nothing. A ride that has left but whose groups are still out, or still to leave, keeps its forecast.
@override final  String status;
/// The meeting point when the ride leaves (its dateTime). Each leg carries its own, at the group's start.
@override final  DepartureWeatherDto departure;
/// One per group, in group order; a single one without groupId for a ride without groups. Empty for OUT_OF_RANGE, NO_LOCATION and NOT_YET_AVAILABLE.
 final  List<WeatherLegDto> _legs;
/// One per group, in group order; a single one without groupId for a ride without groups. Empty for OUT_OF_RANGE, NO_LOCATION and NOT_YET_AVAILABLE.
@override List<WeatherLegDto> get legs {
  if (_legs is EqualUnmodifiableListView) return _legs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_legs);
}

/// The credit the forecast's licence asks for
@override final  WeatherAttributionDto attribution;
/// For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure
@override final  String? availableFrom;
/// The oldest fetch among the forecasts read
@override final  String? fetchedAt;

/// Create a copy of RideWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideWeatherDtoCopyWith<_RideWeatherDto> get copyWith => __$RideWeatherDtoCopyWithImpl<_RideWeatherDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideWeatherDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideWeatherDto&&(identical(other.status, status) || other.status == status)&&(identical(other.departure, departure) || other.departure == departure)&&const DeepCollectionEquality().equals(other.legs, _legs)&&(identical(other.attribution, attribution) || other.attribution == attribution)&&(identical(other.availableFrom, availableFrom) || other.availableFrom == availableFrom)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,departure,const DeepCollectionEquality().hash(_legs),attribution,availableFrom,fetchedAt);
}

@override
String toString() {
    return 'RideWeatherDto(status: $status, departure: $departure, legs: $legs, attribution: $attribution, availableFrom: $availableFrom, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class _$RideWeatherDtoCopyWith<$Res> implements $RideWeatherDtoCopyWith<$Res> {
  factory _$RideWeatherDtoCopyWith(_RideWeatherDto value, $Res Function(_RideWeatherDto) _then) = __$RideWeatherDtoCopyWithImpl;
@override @useResult
$Res call({
 String status, DepartureWeatherDto departure, List<WeatherLegDto> legs, WeatherAttributionDto attribution, String? availableFrom, String? fetchedAt
});


@override $DepartureWeatherDtoCopyWith<$Res> get departure;@override $WeatherAttributionDtoCopyWith<$Res> get attribution;

}
/// @nodoc
class __$RideWeatherDtoCopyWithImpl<$Res>
    implements _$RideWeatherDtoCopyWith<$Res> {
  __$RideWeatherDtoCopyWithImpl(this._self, this._then);

  final _RideWeatherDto _self;
  final $Res Function(_RideWeatherDto) _then;

/// Create a copy of RideWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? departure = null,Object? legs = null,Object? attribution = null,Object? availableFrom = freezed,Object? fetchedAt = freezed,}) {
  return _then(_RideWeatherDto(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,departure: null == departure ? _self.departure : departure // ignore: cast_nullable_to_non_nullable
as DepartureWeatherDto,legs: null == legs ? _self._legs : legs // ignore: cast_nullable_to_non_nullable
as List<WeatherLegDto>,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as WeatherAttributionDto,availableFrom: freezed == availableFrom ? _self.availableFrom : availableFrom // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of RideWeatherDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DepartureWeatherDtoCopyWith<$Res> get departure {
  
  return $DepartureWeatherDtoCopyWith<$Res>(_self.departure, (value) {
    return _then(_self.copyWith(departure: value));
  });
}/// Create a copy of RideWeatherDto
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
