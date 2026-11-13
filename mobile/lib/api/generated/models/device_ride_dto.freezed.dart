// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_ride_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceRideDto {

/// Team slug
 String get teamSlug;/// Ride slug
 String get rideSlug;/// Ride name
 String get rideName;/// IANA zone of the ride, as RideDto.timezone: the Karoo renders the starts in it, the Garmin app ignores it and renders in its own zone
 String get timezone;/// Route entries for this ride
 List<DeviceRideEntryDto> get entries;/// Start date/time
 String? get startDateTime;
/// Create a copy of DeviceRideDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRideDtoCopyWith<DeviceRideDto> get copyWith => _$DeviceRideDtoCopyWithImpl<DeviceRideDto>(this as DeviceRideDto, _$identity);

  /// Serializes this DeviceRideDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRideDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRideDto&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.rideSlug, _this.rideSlug) || other.rideSlug == _this.rideSlug)&&(identical(other.rideName, _this.rideName) || other.rideName == _this.rideName)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&const DeepCollectionEquality().equals(other.entries, _this.entries)&&(identical(other.startDateTime, _this.startDateTime) || other.startDateTime == _this.startDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRideDto;
  return Object.hash(runtimeType,_this.teamSlug,_this.rideSlug,_this.rideName,_this.timezone,const DeepCollectionEquality().hash(_this.entries),_this.startDateTime);
}

@override
String toString() {
  final _this = this as DeviceRideDto;
  return 'DeviceRideDto(teamSlug: ${_this.teamSlug}, rideSlug: ${_this.rideSlug}, rideName: ${_this.rideName}, timezone: ${_this.timezone}, entries: ${_this.entries}, startDateTime: ${_this.startDateTime})';
}


}

/// @nodoc
abstract mixin class $DeviceRideDtoCopyWith<$Res>  {
  factory $DeviceRideDtoCopyWith(DeviceRideDto value, $Res Function(DeviceRideDto) _then) = _$DeviceRideDtoCopyWithImpl;
@useResult
$Res call({
 String teamSlug, String rideSlug, String rideName, String timezone, List<DeviceRideEntryDto> entries, String? startDateTime
});




}
/// @nodoc
class _$DeviceRideDtoCopyWithImpl<$Res>
    implements $DeviceRideDtoCopyWith<$Res> {
  _$DeviceRideDtoCopyWithImpl(this._self, this._then);

  final DeviceRideDto _self;
  final $Res Function(DeviceRideDto) _then;

/// Create a copy of DeviceRideDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? teamSlug = null,Object? rideSlug = null,Object? rideName = null,Object? timezone = null,Object? entries = null,Object? startDateTime = freezed,}) {
  return _then(DeviceRideDto(
teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,rideSlug: null == rideSlug ? _self.rideSlug : rideSlug // ignore: cast_nullable_to_non_nullable
as String,rideName: null == rideName ? _self.rideName : rideName // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<DeviceRideEntryDto>,startDateTime: freezed == startDateTime ? _self.startDateTime : startDateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRideDto].
extension DeviceRideDtoPatterns on DeviceRideDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRideDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRideDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRideDto value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRideDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRideDto value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRideDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String teamSlug,  String rideSlug,  String rideName,  String timezone,  List<DeviceRideEntryDto> entries,  String? startDateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRideDto() when $default != null:
return $default(_that.teamSlug,_that.rideSlug,_that.rideName,_that.timezone,_that.entries,_that.startDateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String teamSlug,  String rideSlug,  String rideName,  String timezone,  List<DeviceRideEntryDto> entries,  String? startDateTime)  $default,) {final _that = this;
switch (_that) {
case _DeviceRideDto():
return $default(_that.teamSlug,_that.rideSlug,_that.rideName,_that.timezone,_that.entries,_that.startDateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String teamSlug,  String rideSlug,  String rideName,  String timezone,  List<DeviceRideEntryDto> entries,  String? startDateTime)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRideDto() when $default != null:
return $default(_that.teamSlug,_that.rideSlug,_that.rideName,_that.timezone,_that.entries,_that.startDateTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRideDto implements DeviceRideDto {
  const _DeviceRideDto({required this.teamSlug, required this.rideSlug, required this.rideName, required this.timezone, required  List<DeviceRideEntryDto> entries, this.startDateTime}): _entries = entries;
  factory _DeviceRideDto.fromJson(Map<String, dynamic> json) => _$DeviceRideDtoFromJson(json);

/// Team slug
@override final  String teamSlug;
/// Ride slug
@override final  String rideSlug;
/// Ride name
@override final  String rideName;
/// IANA zone of the ride, as RideDto.timezone: the Karoo renders the starts in it, the Garmin app ignores it and renders in its own zone
@override final  String timezone;
/// Route entries for this ride
 final  List<DeviceRideEntryDto> _entries;
/// Route entries for this ride
@override List<DeviceRideEntryDto> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

/// Start date/time
@override final  String? startDateTime;

/// Create a copy of DeviceRideDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRideDtoCopyWith<_DeviceRideDto> get copyWith => __$DeviceRideDtoCopyWithImpl<_DeviceRideDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRideDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRideDto&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.rideSlug, rideSlug) || other.rideSlug == rideSlug)&&(identical(other.rideName, rideName) || other.rideName == rideName)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&const DeepCollectionEquality().equals(other.entries, _entries)&&(identical(other.startDateTime, startDateTime) || other.startDateTime == startDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,teamSlug,rideSlug,rideName,timezone,const DeepCollectionEquality().hash(_entries),startDateTime);
}

@override
String toString() {
    return 'DeviceRideDto(teamSlug: $teamSlug, rideSlug: $rideSlug, rideName: $rideName, timezone: $timezone, entries: $entries, startDateTime: $startDateTime)';
}


}

/// @nodoc
abstract mixin class _$DeviceRideDtoCopyWith<$Res> implements $DeviceRideDtoCopyWith<$Res> {
  factory _$DeviceRideDtoCopyWith(_DeviceRideDto value, $Res Function(_DeviceRideDto) _then) = __$DeviceRideDtoCopyWithImpl;
@override @useResult
$Res call({
 String teamSlug, String rideSlug, String rideName, String timezone, List<DeviceRideEntryDto> entries, String? startDateTime
});




}
/// @nodoc
class __$DeviceRideDtoCopyWithImpl<$Res>
    implements _$DeviceRideDtoCopyWith<$Res> {
  __$DeviceRideDtoCopyWithImpl(this._self, this._then);

  final _DeviceRideDto _self;
  final $Res Function(_DeviceRideDto) _then;

/// Create a copy of DeviceRideDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? teamSlug = null,Object? rideSlug = null,Object? rideName = null,Object? timezone = null,Object? entries = null,Object? startDateTime = freezed,}) {
  return _then(_DeviceRideDto(
teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,rideSlug: null == rideSlug ? _self.rideSlug : rideSlug // ignore: cast_nullable_to_non_nullable
as String,rideName: null == rideName ? _self.rideName : rideName // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<DeviceRideEntryDto>,startDateTime: freezed == startDateTime ? _self.startDateTime : startDateTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
