// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_registered_stage_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceRegisteredStageDto {

/// Team slug
 String get teamSlug;/// Trip slug
 String get tripSlug;/// Trip name
 String get tripName;/// Stage name
 String get stageName;/// Slug of the route to load: the stage's own route, never the trip's (a stage without a route is left out)
 String get routeSlug;/// Route name
 String get routeName;/// Distance in meters
 double get distance;/// Elevation gain in meters
 double get elevationGain;/// When the stage leaves, as an absolute instant (UTC)
 String get startDateTime;/// IANA time zone of the stage (e.g. Europe/Paris)
 String get timezone;/// Where the route stands at each of the user's GPS services that hold it, as DeviceRegisteredGroupDto.syncStatuses
 List<DeviceRouteSyncStatusDto> get syncStatuses;/// Name of the place the stage leaves from, when it has one
 String? get startPlaceName;/// Name of the place the stage ends at, when it has one
 String? get endPlaceName;
/// Create a copy of DeviceRegisteredStageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRegisteredStageDtoCopyWith<DeviceRegisteredStageDto> get copyWith => _$DeviceRegisteredStageDtoCopyWithImpl<DeviceRegisteredStageDto>(this as DeviceRegisteredStageDto, _$identity);

  /// Serializes this DeviceRegisteredStageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRegisteredStageDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRegisteredStageDto&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.tripSlug, _this.tripSlug) || other.tripSlug == _this.tripSlug)&&(identical(other.tripName, _this.tripName) || other.tripName == _this.tripName)&&(identical(other.stageName, _this.stageName) || other.stageName == _this.stageName)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.routeName, _this.routeName) || other.routeName == _this.routeName)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.startDateTime, _this.startDateTime) || other.startDateTime == _this.startDateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&const DeepCollectionEquality().equals(other.syncStatuses, _this.syncStatuses)&&(identical(other.startPlaceName, _this.startPlaceName) || other.startPlaceName == _this.startPlaceName)&&(identical(other.endPlaceName, _this.endPlaceName) || other.endPlaceName == _this.endPlaceName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRegisteredStageDto;
  return Object.hash(runtimeType,_this.teamSlug,_this.tripSlug,_this.tripName,_this.stageName,_this.routeSlug,_this.routeName,_this.distance,_this.elevationGain,_this.startDateTime,_this.timezone,const DeepCollectionEquality().hash(_this.syncStatuses),_this.startPlaceName,_this.endPlaceName);
}

@override
String toString() {
  final _this = this as DeviceRegisteredStageDto;
  return 'DeviceRegisteredStageDto(teamSlug: ${_this.teamSlug}, tripSlug: ${_this.tripSlug}, tripName: ${_this.tripName}, stageName: ${_this.stageName}, routeSlug: ${_this.routeSlug}, routeName: ${_this.routeName}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, startDateTime: ${_this.startDateTime}, timezone: ${_this.timezone}, syncStatuses: ${_this.syncStatuses}, startPlaceName: ${_this.startPlaceName}, endPlaceName: ${_this.endPlaceName})';
}


}

/// @nodoc
abstract mixin class $DeviceRegisteredStageDtoCopyWith<$Res>  {
  factory $DeviceRegisteredStageDtoCopyWith(DeviceRegisteredStageDto value, $Res Function(DeviceRegisteredStageDto) _then) = _$DeviceRegisteredStageDtoCopyWithImpl;
@useResult
$Res call({
 String teamSlug, String tripSlug, String tripName, String stageName, String routeSlug, String routeName, double distance, double elevationGain, String startDateTime, String timezone, List<DeviceRouteSyncStatusDto> syncStatuses, String? startPlaceName, String? endPlaceName
});




}
/// @nodoc
class _$DeviceRegisteredStageDtoCopyWithImpl<$Res>
    implements $DeviceRegisteredStageDtoCopyWith<$Res> {
  _$DeviceRegisteredStageDtoCopyWithImpl(this._self, this._then);

  final DeviceRegisteredStageDto _self;
  final $Res Function(DeviceRegisteredStageDto) _then;

/// Create a copy of DeviceRegisteredStageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? teamSlug = null,Object? tripSlug = null,Object? tripName = null,Object? stageName = null,Object? routeSlug = null,Object? routeName = null,Object? distance = null,Object? elevationGain = null,Object? startDateTime = null,Object? timezone = null,Object? syncStatuses = null,Object? startPlaceName = freezed,Object? endPlaceName = freezed,}) {
  return _then(DeviceRegisteredStageDto(
teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,tripSlug: null == tripSlug ? _self.tripSlug : tripSlug // ignore: cast_nullable_to_non_nullable
as String,tripName: null == tripName ? _self.tripName : tripName // ignore: cast_nullable_to_non_nullable
as String,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,routeSlug: null == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,startDateTime: null == startDateTime ? _self.startDateTime : startDateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,syncStatuses: null == syncStatuses ? _self.syncStatuses : syncStatuses // ignore: cast_nullable_to_non_nullable
as List<DeviceRouteSyncStatusDto>,startPlaceName: freezed == startPlaceName ? _self.startPlaceName : startPlaceName // ignore: cast_nullable_to_non_nullable
as String?,endPlaceName: freezed == endPlaceName ? _self.endPlaceName : endPlaceName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRegisteredStageDto].
extension DeviceRegisteredStageDtoPatterns on DeviceRegisteredStageDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRegisteredStageDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRegisteredStageDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRegisteredStageDto value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRegisteredStageDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRegisteredStageDto value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRegisteredStageDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String teamSlug,  String tripSlug,  String tripName,  String stageName,  String routeSlug,  String routeName,  double distance,  double elevationGain,  String startDateTime,  String timezone,  List<DeviceRouteSyncStatusDto> syncStatuses,  String? startPlaceName,  String? endPlaceName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRegisteredStageDto() when $default != null:
return $default(_that.teamSlug,_that.tripSlug,_that.tripName,_that.stageName,_that.routeSlug,_that.routeName,_that.distance,_that.elevationGain,_that.startDateTime,_that.timezone,_that.syncStatuses,_that.startPlaceName,_that.endPlaceName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String teamSlug,  String tripSlug,  String tripName,  String stageName,  String routeSlug,  String routeName,  double distance,  double elevationGain,  String startDateTime,  String timezone,  List<DeviceRouteSyncStatusDto> syncStatuses,  String? startPlaceName,  String? endPlaceName)  $default,) {final _that = this;
switch (_that) {
case _DeviceRegisteredStageDto():
return $default(_that.teamSlug,_that.tripSlug,_that.tripName,_that.stageName,_that.routeSlug,_that.routeName,_that.distance,_that.elevationGain,_that.startDateTime,_that.timezone,_that.syncStatuses,_that.startPlaceName,_that.endPlaceName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String teamSlug,  String tripSlug,  String tripName,  String stageName,  String routeSlug,  String routeName,  double distance,  double elevationGain,  String startDateTime,  String timezone,  List<DeviceRouteSyncStatusDto> syncStatuses,  String? startPlaceName,  String? endPlaceName)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRegisteredStageDto() when $default != null:
return $default(_that.teamSlug,_that.tripSlug,_that.tripName,_that.stageName,_that.routeSlug,_that.routeName,_that.distance,_that.elevationGain,_that.startDateTime,_that.timezone,_that.syncStatuses,_that.startPlaceName,_that.endPlaceName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRegisteredStageDto implements DeviceRegisteredStageDto {
  const _DeviceRegisteredStageDto({required this.teamSlug, required this.tripSlug, required this.tripName, required this.stageName, required this.routeSlug, required this.routeName, required this.distance, required this.elevationGain, required this.startDateTime, required this.timezone, required  List<DeviceRouteSyncStatusDto> syncStatuses, this.startPlaceName, this.endPlaceName}): _syncStatuses = syncStatuses;
  factory _DeviceRegisteredStageDto.fromJson(Map<String, dynamic> json) => _$DeviceRegisteredStageDtoFromJson(json);

/// Team slug
@override final  String teamSlug;
/// Trip slug
@override final  String tripSlug;
/// Trip name
@override final  String tripName;
/// Stage name
@override final  String stageName;
/// Slug of the route to load: the stage's own route, never the trip's (a stage without a route is left out)
@override final  String routeSlug;
/// Route name
@override final  String routeName;
/// Distance in meters
@override final  double distance;
/// Elevation gain in meters
@override final  double elevationGain;
/// When the stage leaves, as an absolute instant (UTC)
@override final  String startDateTime;
/// IANA time zone of the stage (e.g. Europe/Paris)
@override final  String timezone;
/// Where the route stands at each of the user's GPS services that hold it, as DeviceRegisteredGroupDto.syncStatuses
 final  List<DeviceRouteSyncStatusDto> _syncStatuses;
/// Where the route stands at each of the user's GPS services that hold it, as DeviceRegisteredGroupDto.syncStatuses
@override List<DeviceRouteSyncStatusDto> get syncStatuses {
  if (_syncStatuses is EqualUnmodifiableListView) return _syncStatuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_syncStatuses);
}

/// Name of the place the stage leaves from, when it has one
@override final  String? startPlaceName;
/// Name of the place the stage ends at, when it has one
@override final  String? endPlaceName;

/// Create a copy of DeviceRegisteredStageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRegisteredStageDtoCopyWith<_DeviceRegisteredStageDto> get copyWith => __$DeviceRegisteredStageDtoCopyWithImpl<_DeviceRegisteredStageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRegisteredStageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRegisteredStageDto&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.tripSlug, tripSlug) || other.tripSlug == tripSlug)&&(identical(other.tripName, tripName) || other.tripName == tripName)&&(identical(other.stageName, stageName) || other.stageName == stageName)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.routeName, routeName) || other.routeName == routeName)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.startDateTime, startDateTime) || other.startDateTime == startDateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&const DeepCollectionEquality().equals(other.syncStatuses, _syncStatuses)&&(identical(other.startPlaceName, startPlaceName) || other.startPlaceName == startPlaceName)&&(identical(other.endPlaceName, endPlaceName) || other.endPlaceName == endPlaceName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,teamSlug,tripSlug,tripName,stageName,routeSlug,routeName,distance,elevationGain,startDateTime,timezone,const DeepCollectionEquality().hash(_syncStatuses),startPlaceName,endPlaceName);
}

@override
String toString() {
    return 'DeviceRegisteredStageDto(teamSlug: $teamSlug, tripSlug: $tripSlug, tripName: $tripName, stageName: $stageName, routeSlug: $routeSlug, routeName: $routeName, distance: $distance, elevationGain: $elevationGain, startDateTime: $startDateTime, timezone: $timezone, syncStatuses: $syncStatuses, startPlaceName: $startPlaceName, endPlaceName: $endPlaceName)';
}


}

/// @nodoc
abstract mixin class _$DeviceRegisteredStageDtoCopyWith<$Res> implements $DeviceRegisteredStageDtoCopyWith<$Res> {
  factory _$DeviceRegisteredStageDtoCopyWith(_DeviceRegisteredStageDto value, $Res Function(_DeviceRegisteredStageDto) _then) = __$DeviceRegisteredStageDtoCopyWithImpl;
@override @useResult
$Res call({
 String teamSlug, String tripSlug, String tripName, String stageName, String routeSlug, String routeName, double distance, double elevationGain, String startDateTime, String timezone, List<DeviceRouteSyncStatusDto> syncStatuses, String? startPlaceName, String? endPlaceName
});




}
/// @nodoc
class __$DeviceRegisteredStageDtoCopyWithImpl<$Res>
    implements _$DeviceRegisteredStageDtoCopyWith<$Res> {
  __$DeviceRegisteredStageDtoCopyWithImpl(this._self, this._then);

  final _DeviceRegisteredStageDto _self;
  final $Res Function(_DeviceRegisteredStageDto) _then;

/// Create a copy of DeviceRegisteredStageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? teamSlug = null,Object? tripSlug = null,Object? tripName = null,Object? stageName = null,Object? routeSlug = null,Object? routeName = null,Object? distance = null,Object? elevationGain = null,Object? startDateTime = null,Object? timezone = null,Object? syncStatuses = null,Object? startPlaceName = freezed,Object? endPlaceName = freezed,}) {
  return _then(_DeviceRegisteredStageDto(
teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,tripSlug: null == tripSlug ? _self.tripSlug : tripSlug // ignore: cast_nullable_to_non_nullable
as String,tripName: null == tripName ? _self.tripName : tripName // ignore: cast_nullable_to_non_nullable
as String,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,routeSlug: null == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String,routeName: null == routeName ? _self.routeName : routeName // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,startDateTime: null == startDateTime ? _self.startDateTime : startDateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,syncStatuses: null == syncStatuses ? _self._syncStatuses : syncStatuses // ignore: cast_nullable_to_non_nullable
as List<DeviceRouteSyncStatusDto>,startPlaceName: freezed == startPlaceName ? _self.startPlaceName : startPlaceName // ignore: cast_nullable_to_non_nullable
as String?,endPlaceName: freezed == endPlaceName ? _self.endPlaceName : endPlaceName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
