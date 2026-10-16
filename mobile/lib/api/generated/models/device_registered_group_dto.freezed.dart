// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_registered_group_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceRegisteredGroupDto {

/// Team slug
 String get teamSlug;/// Ride slug
 String get rideSlug;/// Ride name
 String get rideName;/// Name of the group the user is registered in
 String get groupName;/// Slug of the route to load: the group's own route, or the ride's when the group has none
 String get routeSlug;/// Route name
 String get routeName;/// Distance in meters
 double get distance;/// Elevation gain in meters
 double get elevationGain;/// When the group leaves, as an absolute instant (UTC): the group's startAt, the ride's own start when the group has no time. Devices render it in their own zone.
 String get startDateTime;/// IANA time zone of the ride (e.g. Europe/Paris)
 String get timezone;
/// Create a copy of DeviceRegisteredGroupDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRegisteredGroupDtoCopyWith<DeviceRegisteredGroupDto> get copyWith => _$DeviceRegisteredGroupDtoCopyWithImpl<DeviceRegisteredGroupDto>(this as DeviceRegisteredGroupDto, _$identity);

  /// Serializes this DeviceRegisteredGroupDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRegisteredGroupDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRegisteredGroupDto&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.rideSlug, _this.rideSlug) || other.rideSlug == _this.rideSlug)&&(identical(other.rideName, _this.rideName) || other.rideName == _this.rideName)&&(identical(other.groupName, _this.groupName) || other.groupName == _this.groupName)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.routeName, _this.routeName) || other.routeName == _this.routeName)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.startDateTime, _this.startDateTime) || other.startDateTime == _this.startDateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRegisteredGroupDto;
  return Object.hash(runtimeType,_this.teamSlug,_this.rideSlug,_this.rideName,_this.groupName,_this.routeSlug,_this.routeName,_this.distance,_this.elevationGain,_this.startDateTime,_this.timezone);
}

@override
String toString() {
  final _this = this as DeviceRegisteredGroupDto;
  return 'DeviceRegisteredGroupDto(teamSlug: ${_this.teamSlug}, rideSlug: ${_this.rideSlug}, rideName: ${_this.rideName}, groupName: ${_this.groupName}, routeSlug: ${_this.routeSlug}, routeName: ${_this.routeName}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, startDateTime: ${_this.startDateTime}, timezone: ${_this.timezone})';
}


}

/// @nodoc
abstract mixin class $DeviceRegisteredGroupDtoCopyWith<$Res>  {
  factory $DeviceRegisteredGroupDtoCopyWith(DeviceRegisteredGroupDto value, $Res Function(DeviceRegisteredGroupDto) _then) = _$DeviceRegisteredGroupDtoCopyWithImpl;
@useResult
$Res call({
 String teamSlug, String rideSlug, String rideName, String groupName, String routeSlug, String routeName, double distance, double elevationGain, String startDateTime, String timezone
});




}
/// @nodoc
class _$DeviceRegisteredGroupDtoCopyWithImpl<$Res>
    implements $DeviceRegisteredGroupDtoCopyWith<$Res> {
  _$DeviceRegisteredGroupDtoCopyWithImpl(this._self, this._then);

  final DeviceRegisteredGroupDto _self;
  final $Res Function(DeviceRegisteredGroupDto) _then;

/// Create a copy of DeviceRegisteredGroupDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? teamSlug = null,Object? rideSlug = null,Object? rideName = null,Object? groupName = null,Object? routeSlug = null,Object? routeName = null,Object? distance = null,Object? elevationGain = null,Object? startDateTime = null,Object? timezone = null,}) {
  return _then(DeviceRegisteredGroupDto(
teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,rideSlug: null == rideSlug ? _self.rideSlug : rideSlug // ignore: cast_nullable_to_non_nullable
as String,rideName: null == rideName ? _self.rideName : rideName // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,routeSlug: null == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,startDateTime: null == startDateTime ? _self.startDateTime : startDateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRegisteredGroupDto].
extension DeviceRegisteredGroupDtoPatterns on DeviceRegisteredGroupDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRegisteredGroupDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRegisteredGroupDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRegisteredGroupDto value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRegisteredGroupDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRegisteredGroupDto value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRegisteredGroupDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String teamSlug,  String rideSlug,  String rideName,  String groupName,  String routeSlug,  String routeName,  double distance,  double elevationGain,  String startDateTime,  String timezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRegisteredGroupDto() when $default != null:
return $default(_that.teamSlug,_that.rideSlug,_that.rideName,_that.groupName,_that.routeSlug,_that.routeName,_that.distance,_that.elevationGain,_that.startDateTime,_that.timezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String teamSlug,  String rideSlug,  String rideName,  String groupName,  String routeSlug,  String routeName,  double distance,  double elevationGain,  String startDateTime,  String timezone)  $default,) {final _that = this;
switch (_that) {
case _DeviceRegisteredGroupDto():
return $default(_that.teamSlug,_that.rideSlug,_that.rideName,_that.groupName,_that.routeSlug,_that.routeName,_that.distance,_that.elevationGain,_that.startDateTime,_that.timezone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String teamSlug,  String rideSlug,  String rideName,  String groupName,  String routeSlug,  String routeName,  double distance,  double elevationGain,  String startDateTime,  String timezone)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRegisteredGroupDto() when $default != null:
return $default(_that.teamSlug,_that.rideSlug,_that.rideName,_that.groupName,_that.routeSlug,_that.routeName,_that.distance,_that.elevationGain,_that.startDateTime,_that.timezone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRegisteredGroupDto implements DeviceRegisteredGroupDto {
  const _DeviceRegisteredGroupDto({required this.teamSlug, required this.rideSlug, required this.rideName, required this.groupName, required this.routeSlug, required this.routeName, required this.distance, required this.elevationGain, required this.startDateTime, required this.timezone});
  factory _DeviceRegisteredGroupDto.fromJson(Map<String, dynamic> json) => _$DeviceRegisteredGroupDtoFromJson(json);

/// Team slug
@override final  String teamSlug;
/// Ride slug
@override final  String rideSlug;
/// Ride name
@override final  String rideName;
/// Name of the group the user is registered in
@override final  String groupName;
/// Slug of the route to load: the group's own route, or the ride's when the group has none
@override final  String routeSlug;
/// Route name
@override final  String routeName;
/// Distance in meters
@override final  double distance;
/// Elevation gain in meters
@override final  double elevationGain;
/// When the group leaves, as an absolute instant (UTC): the group's startAt, the ride's own start when the group has no time. Devices render it in their own zone.
@override final  String startDateTime;
/// IANA time zone of the ride (e.g. Europe/Paris)
@override final  String timezone;

/// Create a copy of DeviceRegisteredGroupDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRegisteredGroupDtoCopyWith<_DeviceRegisteredGroupDto> get copyWith => __$DeviceRegisteredGroupDtoCopyWithImpl<_DeviceRegisteredGroupDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRegisteredGroupDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRegisteredGroupDto&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.rideSlug, rideSlug) || other.rideSlug == rideSlug)&&(identical(other.rideName, rideName) || other.rideName == rideName)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.startDateTime, startDateTime) || other.startDateTime == startDateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,teamSlug,rideSlug,rideName,groupName,routeSlug,routeName,distance,elevationGain,startDateTime,timezone);
}

@override
String toString() {
    return 'DeviceRegisteredGroupDto(teamSlug: $teamSlug, rideSlug: $rideSlug, rideName: $rideName, groupName: $groupName, routeSlug: $routeSlug, routeName: $routeName, distance: $distance, elevationGain: $elevationGain, startDateTime: $startDateTime, timezone: $timezone)';
}


}

/// @nodoc
abstract mixin class _$DeviceRegisteredGroupDtoCopyWith<$Res> implements $DeviceRegisteredGroupDtoCopyWith<$Res> {
  factory _$DeviceRegisteredGroupDtoCopyWith(_DeviceRegisteredGroupDto value, $Res Function(_DeviceRegisteredGroupDto) _then) = __$DeviceRegisteredGroupDtoCopyWithImpl;
@override @useResult
$Res call({
 String teamSlug, String rideSlug, String rideName, String groupName, String routeSlug, String routeName, double distance, double elevationGain, String startDateTime, String timezone
});




}
/// @nodoc
class __$DeviceRegisteredGroupDtoCopyWithImpl<$Res>
    implements _$DeviceRegisteredGroupDtoCopyWith<$Res> {
  __$DeviceRegisteredGroupDtoCopyWithImpl(this._self, this._then);

  final _DeviceRegisteredGroupDto _self;
  final $Res Function(_DeviceRegisteredGroupDto) _then;

/// Create a copy of DeviceRegisteredGroupDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? teamSlug = null,Object? rideSlug = null,Object? rideName = null,Object? groupName = null,Object? routeSlug = null,Object? routeName = null,Object? distance = null,Object? elevationGain = null,Object? startDateTime = null,Object? timezone = null,}) {
  return _then(_DeviceRegisteredGroupDto(
teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,rideSlug: null == rideSlug ? _self.rideSlug : rideSlug // ignore: cast_nullable_to_non_nullable
as String,rideName: null == rideName ? _self.rideName : rideName // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,routeSlug: null == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,startDateTime: null == startDateTime ? _self.startDateTime : startDateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
