// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_group_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideGroupDto {

/// Group ID (TSID)
 String get id;/// Group name
 String get name;/// When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own.
 String get startAt;/// Current number of participants
 int get countParticipants;/// The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.
 List<PublicUserDto> get participants;/// Sort order
 int get sortOrder;/// Whether the current user is registered in THIS group. False if anonymous.
 bool get registered;/// Whether the group has reached maxParticipants. False when maxParticipants is not set.
 bool get full;/// Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time.
 String? get time;/// Route slug
 String? get routeSlug;/// Average speed in km/h
 double? get averageSpeed;/// Maximum participants
 int? get maxParticipants;/// Distance in meters of the group route, if it has one
 double? get distance;/// Total elevation gain in meters of the group route, if it has one
 double? get elevationGain;/// The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride.
 PublicUserDto? get leader;/// Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailLightUrl;/// Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailDarkUrl;/// The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;
/// Create a copy of RideGroupDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideGroupDtoCopyWith<RideGroupDto> get copyWith => _$RideGroupDtoCopyWithImpl<RideGroupDto>(this as RideGroupDto, _$identity);

  /// Serializes this RideGroupDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RideGroupDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideGroupDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.startAt, _this.startAt) || other.startAt == _this.startAt)&&(identical(other.countParticipants, _this.countParticipants) || other.countParticipants == _this.countParticipants)&&const DeepCollectionEquality().equals(other.participants, _this.participants)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.registered, _this.registered) || other.registered == _this.registered)&&(identical(other.full, _this.full) || other.full == _this.full)&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.averageSpeed, _this.averageSpeed) || other.averageSpeed == _this.averageSpeed)&&(identical(other.maxParticipants, _this.maxParticipants) || other.maxParticipants == _this.maxParticipants)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.leader, _this.leader) || other.leader == _this.leader)&&(identical(other.thumbnailLightUrl, _this.thumbnailLightUrl) || other.thumbnailLightUrl == _this.thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, _this.thumbnailDarkUrl) || other.thumbnailDarkUrl == _this.thumbnailDarkUrl)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RideGroupDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.startAt,_this.countParticipants,const DeepCollectionEquality().hash(_this.participants),_this.sortOrder,_this.registered,_this.full,_this.time,_this.routeSlug,_this.averageSpeed,_this.maxParticipants,_this.distance,_this.elevationGain,_this.leader,_this.thumbnailLightUrl,_this.thumbnailDarkUrl,_this.thumbnailUrl);
}

@override
String toString() {
  final _this = this as RideGroupDto;
  return 'RideGroupDto(id: ${_this.id}, name: ${_this.name}, startAt: ${_this.startAt}, countParticipants: ${_this.countParticipants}, participants: ${_this.participants}, sortOrder: ${_this.sortOrder}, registered: ${_this.registered}, full: ${_this.full}, time: ${_this.time}, routeSlug: ${_this.routeSlug}, averageSpeed: ${_this.averageSpeed}, maxParticipants: ${_this.maxParticipants}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, leader: ${_this.leader}, thumbnailLightUrl: ${_this.thumbnailLightUrl}, thumbnailDarkUrl: ${_this.thumbnailDarkUrl}, thumbnailUrl: ${_this.thumbnailUrl})';
}


}

/// @nodoc
abstract mixin class $RideGroupDtoCopyWith<$Res>  {
  factory $RideGroupDtoCopyWith(RideGroupDto value, $Res Function(RideGroupDto) _then) = _$RideGroupDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String startAt, int countParticipants, List<PublicUserDto> participants, int sortOrder, bool registered, bool full, String? time, String? routeSlug, double? averageSpeed, int? maxParticipants, double? distance, double? elevationGain, PublicUserDto? leader, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl
});


$PublicUserDtoCopyWith<$Res>? get leader;

}
/// @nodoc
class _$RideGroupDtoCopyWithImpl<$Res>
    implements $RideGroupDtoCopyWith<$Res> {
  _$RideGroupDtoCopyWithImpl(this._self, this._then);

  final RideGroupDto _self;
  final $Res Function(RideGroupDto) _then;

/// Create a copy of RideGroupDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? startAt = null,Object? countParticipants = null,Object? participants = null,Object? sortOrder = null,Object? registered = null,Object? full = null,Object? time = freezed,Object? routeSlug = freezed,Object? averageSpeed = freezed,Object? maxParticipants = freezed,Object? distance = freezed,Object? elevationGain = freezed,Object? leader = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,}) {
  return _then(RideGroupDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as String,countParticipants: null == countParticipants ? _self.countParticipants : countParticipants // ignore: cast_nullable_to_non_nullable
as int,participants: null == participants ? _self.participants : participants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,full: null == full ? _self.full : full // ignore: cast_nullable_to_non_nullable
as bool,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,averageSpeed: freezed == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,leader: freezed == leader ? _self.leader : leader // ignore: cast_nullable_to_non_nullable
as PublicUserDto?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of RideGroupDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicUserDtoCopyWith<$Res>? get leader {
    if (_self.leader == null) {
    return null;
  }

  return $PublicUserDtoCopyWith<$Res>(_self.leader!, (value) {
    return _then(_self.copyWith(leader: value));
  });
}
}


/// Adds pattern-matching-related methods to [RideGroupDto].
extension RideGroupDtoPatterns on RideGroupDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideGroupDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideGroupDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideGroupDto value)  $default,){
final _that = this;
switch (_that) {
case _RideGroupDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideGroupDto value)?  $default,){
final _that = this;
switch (_that) {
case _RideGroupDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String startAt,  int countParticipants,  List<PublicUserDto> participants,  int sortOrder,  bool registered,  bool full,  String? time,  String? routeSlug,  double? averageSpeed,  int? maxParticipants,  double? distance,  double? elevationGain,  PublicUserDto? leader,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideGroupDto() when $default != null:
return $default(_that.id,_that.name,_that.startAt,_that.countParticipants,_that.participants,_that.sortOrder,_that.registered,_that.full,_that.time,_that.routeSlug,_that.averageSpeed,_that.maxParticipants,_that.distance,_that.elevationGain,_that.leader,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String startAt,  int countParticipants,  List<PublicUserDto> participants,  int sortOrder,  bool registered,  bool full,  String? time,  String? routeSlug,  double? averageSpeed,  int? maxParticipants,  double? distance,  double? elevationGain,  PublicUserDto? leader,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl)  $default,) {final _that = this;
switch (_that) {
case _RideGroupDto():
return $default(_that.id,_that.name,_that.startAt,_that.countParticipants,_that.participants,_that.sortOrder,_that.registered,_that.full,_that.time,_that.routeSlug,_that.averageSpeed,_that.maxParticipants,_that.distance,_that.elevationGain,_that.leader,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String startAt,  int countParticipants,  List<PublicUserDto> participants,  int sortOrder,  bool registered,  bool full,  String? time,  String? routeSlug,  double? averageSpeed,  int? maxParticipants,  double? distance,  double? elevationGain,  PublicUserDto? leader,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl)?  $default,) {final _that = this;
switch (_that) {
case _RideGroupDto() when $default != null:
return $default(_that.id,_that.name,_that.startAt,_that.countParticipants,_that.participants,_that.sortOrder,_that.registered,_that.full,_that.time,_that.routeSlug,_that.averageSpeed,_that.maxParticipants,_that.distance,_that.elevationGain,_that.leader,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideGroupDto implements RideGroupDto {
  const _RideGroupDto({required this.id, required this.name, required this.startAt, required this.countParticipants, required  List<PublicUserDto> participants, required this.sortOrder, required this.registered, required this.full, this.time, this.routeSlug, this.averageSpeed, this.maxParticipants, this.distance, this.elevationGain, this.leader, this.thumbnailLightUrl, this.thumbnailDarkUrl, this.thumbnailUrl}): _participants = participants;
  factory _RideGroupDto.fromJson(Map<String, dynamic> json) => _$RideGroupDtoFromJson(json);

/// Group ID (TSID)
@override final  String id;
/// Group name
@override final  String name;
/// When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own.
@override final  String startAt;
/// Current number of participants
@override final  int countParticipants;
/// The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.
 final  List<PublicUserDto> _participants;
/// The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.
@override List<PublicUserDto> get participants {
  if (_participants is EqualUnmodifiableListView) return _participants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participants);
}

/// Sort order
@override final  int sortOrder;
/// Whether the current user is registered in THIS group. False if anonymous.
@override final  bool registered;
/// Whether the group has reached maxParticipants. False when maxParticipants is not set.
@override final  bool full;
/// Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time.
@override final  String? time;
/// Route slug
@override final  String? routeSlug;
/// Average speed in km/h
@override final  double? averageSpeed;
/// Maximum participants
@override final  int? maxParticipants;
/// Distance in meters of the group route, if it has one
@override final  double? distance;
/// Total elevation gain in meters of the group route, if it has one
@override final  double? elevationGain;
/// The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride.
@override final  PublicUserDto? leader;
/// Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailLightUrl;
/// Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailDarkUrl;
/// The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;

/// Create a copy of RideGroupDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideGroupDtoCopyWith<_RideGroupDto> get copyWith => __$RideGroupDtoCopyWithImpl<_RideGroupDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideGroupDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideGroupDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.startAt, startAt) || other.startAt == startAt)&&(identical(other.countParticipants, countParticipants) || other.countParticipants == countParticipants)&&const DeepCollectionEquality().equals(other.participants, _participants)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.registered, registered) || other.registered == registered)&&(identical(other.full, full) || other.full == full)&&(identical(other.time, time) || other.time == time)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.averageSpeed, averageSpeed) || other.averageSpeed == averageSpeed)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.leader, leader) || other.leader == leader)&&(identical(other.thumbnailLightUrl, thumbnailLightUrl) || other.thumbnailLightUrl == thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, thumbnailDarkUrl) || other.thumbnailDarkUrl == thumbnailDarkUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,startAt,countParticipants,const DeepCollectionEquality().hash(_participants),sortOrder,registered,full,time,routeSlug,averageSpeed,maxParticipants,distance,elevationGain,leader,thumbnailLightUrl,thumbnailDarkUrl,thumbnailUrl);
}

@override
String toString() {
    return 'RideGroupDto(id: $id, name: $name, startAt: $startAt, countParticipants: $countParticipants, participants: $participants, sortOrder: $sortOrder, registered: $registered, full: $full, time: $time, routeSlug: $routeSlug, averageSpeed: $averageSpeed, maxParticipants: $maxParticipants, distance: $distance, elevationGain: $elevationGain, leader: $leader, thumbnailLightUrl: $thumbnailLightUrl, thumbnailDarkUrl: $thumbnailDarkUrl, thumbnailUrl: $thumbnailUrl)';
}


}

/// @nodoc
abstract mixin class _$RideGroupDtoCopyWith<$Res> implements $RideGroupDtoCopyWith<$Res> {
  factory _$RideGroupDtoCopyWith(_RideGroupDto value, $Res Function(_RideGroupDto) _then) = __$RideGroupDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String startAt, int countParticipants, List<PublicUserDto> participants, int sortOrder, bool registered, bool full, String? time, String? routeSlug, double? averageSpeed, int? maxParticipants, double? distance, double? elevationGain, PublicUserDto? leader, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl
});


@override $PublicUserDtoCopyWith<$Res>? get leader;

}
/// @nodoc
class __$RideGroupDtoCopyWithImpl<$Res>
    implements _$RideGroupDtoCopyWith<$Res> {
  __$RideGroupDtoCopyWithImpl(this._self, this._then);

  final _RideGroupDto _self;
  final $Res Function(_RideGroupDto) _then;

/// Create a copy of RideGroupDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? startAt = null,Object? countParticipants = null,Object? participants = null,Object? sortOrder = null,Object? registered = null,Object? full = null,Object? time = freezed,Object? routeSlug = freezed,Object? averageSpeed = freezed,Object? maxParticipants = freezed,Object? distance = freezed,Object? elevationGain = freezed,Object? leader = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,}) {
  return _then(_RideGroupDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startAt: null == startAt ? _self.startAt : startAt // ignore: cast_nullable_to_non_nullable
as String,countParticipants: null == countParticipants ? _self.countParticipants : countParticipants // ignore: cast_nullable_to_non_nullable
as int,participants: null == participants ? _self._participants : participants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,full: null == full ? _self.full : full // ignore: cast_nullable_to_non_nullable
as bool,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,averageSpeed: freezed == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,leader: freezed == leader ? _self.leader : leader // ignore: cast_nullable_to_non_nullable
as PublicUserDto?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of RideGroupDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicUserDtoCopyWith<$Res>? get leader {
    if (_self.leader == null) {
    return null;
  }

  return $PublicUserDtoCopyWith<$Res>(_self.leader!, (value) {
    return _then(_self.copyWith(leader: value));
  });
}
}

// dart format on
