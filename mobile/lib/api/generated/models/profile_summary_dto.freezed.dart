// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_summary_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProfileSummaryDto {

/// The user's teams on this site, in name order, each with the user's role in it
 List<ProfileTeamDto> get teams;/// Number of passkeys registered on the account
 int get passkeyCount;/// Devices (Karoo, Garmin) paired with the account, newest first — the same rows as GET /api/users/me/devices
 List<PairedDeviceDto> get pairedDevices;/// Number of live accounts the user blocked
 int get blockedUserCount;/// Where the user's notifications go
 ProfileNotificationSummaryDto get notifications;
/// Create a copy of ProfileSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileSummaryDtoCopyWith<ProfileSummaryDto> get copyWith => _$ProfileSummaryDtoCopyWithImpl<ProfileSummaryDto>(this as ProfileSummaryDto, _$identity);

  /// Serializes this ProfileSummaryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileSummaryDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileSummaryDto&&const DeepCollectionEquality().equals(other.teams, _this.teams)&&(identical(other.passkeyCount, _this.passkeyCount) || other.passkeyCount == _this.passkeyCount)&&const DeepCollectionEquality().equals(other.pairedDevices, _this.pairedDevices)&&(identical(other.blockedUserCount, _this.blockedUserCount) || other.blockedUserCount == _this.blockedUserCount)&&(identical(other.notifications, _this.notifications) || other.notifications == _this.notifications));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileSummaryDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.teams),_this.passkeyCount,const DeepCollectionEquality().hash(_this.pairedDevices),_this.blockedUserCount,_this.notifications);
}

@override
String toString() {
  final _this = this as ProfileSummaryDto;
  return 'ProfileSummaryDto(teams: ${_this.teams}, passkeyCount: ${_this.passkeyCount}, pairedDevices: ${_this.pairedDevices}, blockedUserCount: ${_this.blockedUserCount}, notifications: ${_this.notifications})';
}


}

/// @nodoc
abstract mixin class $ProfileSummaryDtoCopyWith<$Res>  {
  factory $ProfileSummaryDtoCopyWith(ProfileSummaryDto value, $Res Function(ProfileSummaryDto) _then) = _$ProfileSummaryDtoCopyWithImpl;
@useResult
$Res call({
 List<ProfileTeamDto> teams, int passkeyCount, List<PairedDeviceDto> pairedDevices, int blockedUserCount, ProfileNotificationSummaryDto notifications
});


$ProfileNotificationSummaryDtoCopyWith<$Res> get notifications;

}
/// @nodoc
class _$ProfileSummaryDtoCopyWithImpl<$Res>
    implements $ProfileSummaryDtoCopyWith<$Res> {
  _$ProfileSummaryDtoCopyWithImpl(this._self, this._then);

  final ProfileSummaryDto _self;
  final $Res Function(ProfileSummaryDto) _then;

/// Create a copy of ProfileSummaryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? teams = null,Object? passkeyCount = null,Object? pairedDevices = null,Object? blockedUserCount = null,Object? notifications = null,}) {
  return _then(ProfileSummaryDto(
teams: null == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as List<ProfileTeamDto>,passkeyCount: null == passkeyCount ? _self.passkeyCount : passkeyCount // ignore: cast_nullable_to_non_nullable
as int,pairedDevices: null == pairedDevices ? _self.pairedDevices : pairedDevices // ignore: cast_nullable_to_non_nullable
as List<PairedDeviceDto>,blockedUserCount: null == blockedUserCount ? _self.blockedUserCount : blockedUserCount // ignore: cast_nullable_to_non_nullable
as int,notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as ProfileNotificationSummaryDto,
  ));
}
/// Create a copy of ProfileSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileNotificationSummaryDtoCopyWith<$Res> get notifications {
  
  return $ProfileNotificationSummaryDtoCopyWith<$Res>(_self.notifications, (value) {
    return _then(_self.copyWith(notifications: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileSummaryDto].
extension ProfileSummaryDtoPatterns on ProfileSummaryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileSummaryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileSummaryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileSummaryDto value)  $default,){
final _that = this;
switch (_that) {
case _ProfileSummaryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileSummaryDto value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileSummaryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ProfileTeamDto> teams,  int passkeyCount,  List<PairedDeviceDto> pairedDevices,  int blockedUserCount,  ProfileNotificationSummaryDto notifications)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileSummaryDto() when $default != null:
return $default(_that.teams,_that.passkeyCount,_that.pairedDevices,_that.blockedUserCount,_that.notifications);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ProfileTeamDto> teams,  int passkeyCount,  List<PairedDeviceDto> pairedDevices,  int blockedUserCount,  ProfileNotificationSummaryDto notifications)  $default,) {final _that = this;
switch (_that) {
case _ProfileSummaryDto():
return $default(_that.teams,_that.passkeyCount,_that.pairedDevices,_that.blockedUserCount,_that.notifications);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ProfileTeamDto> teams,  int passkeyCount,  List<PairedDeviceDto> pairedDevices,  int blockedUserCount,  ProfileNotificationSummaryDto notifications)?  $default,) {final _that = this;
switch (_that) {
case _ProfileSummaryDto() when $default != null:
return $default(_that.teams,_that.passkeyCount,_that.pairedDevices,_that.blockedUserCount,_that.notifications);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileSummaryDto implements ProfileSummaryDto {
  const _ProfileSummaryDto({required  List<ProfileTeamDto> teams, required this.passkeyCount, required  List<PairedDeviceDto> pairedDevices, required this.blockedUserCount, required this.notifications}): _teams = teams,_pairedDevices = pairedDevices;
  factory _ProfileSummaryDto.fromJson(Map<String, dynamic> json) => _$ProfileSummaryDtoFromJson(json);

/// The user's teams on this site, in name order, each with the user's role in it
 final  List<ProfileTeamDto> _teams;
/// The user's teams on this site, in name order, each with the user's role in it
@override List<ProfileTeamDto> get teams {
  if (_teams is EqualUnmodifiableListView) return _teams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_teams);
}

/// Number of passkeys registered on the account
@override final  int passkeyCount;
/// Devices (Karoo, Garmin) paired with the account, newest first — the same rows as GET /api/users/me/devices
 final  List<PairedDeviceDto> _pairedDevices;
/// Devices (Karoo, Garmin) paired with the account, newest first — the same rows as GET /api/users/me/devices
@override List<PairedDeviceDto> get pairedDevices {
  if (_pairedDevices is EqualUnmodifiableListView) return _pairedDevices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pairedDevices);
}

/// Number of live accounts the user blocked
@override final  int blockedUserCount;
/// Where the user's notifications go
@override final  ProfileNotificationSummaryDto notifications;

/// Create a copy of ProfileSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileSummaryDtoCopyWith<_ProfileSummaryDto> get copyWith => __$ProfileSummaryDtoCopyWithImpl<_ProfileSummaryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileSummaryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileSummaryDto&&const DeepCollectionEquality().equals(other.teams, _teams)&&(identical(other.passkeyCount, passkeyCount) || other.passkeyCount == passkeyCount)&&const DeepCollectionEquality().equals(other.pairedDevices, _pairedDevices)&&(identical(other.blockedUserCount, blockedUserCount) || other.blockedUserCount == blockedUserCount)&&(identical(other.notifications, notifications) || other.notifications == notifications));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_teams),passkeyCount,const DeepCollectionEquality().hash(_pairedDevices),blockedUserCount,notifications);
}

@override
String toString() {
    return 'ProfileSummaryDto(teams: $teams, passkeyCount: $passkeyCount, pairedDevices: $pairedDevices, blockedUserCount: $blockedUserCount, notifications: $notifications)';
}


}

/// @nodoc
abstract mixin class _$ProfileSummaryDtoCopyWith<$Res> implements $ProfileSummaryDtoCopyWith<$Res> {
  factory _$ProfileSummaryDtoCopyWith(_ProfileSummaryDto value, $Res Function(_ProfileSummaryDto) _then) = __$ProfileSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 List<ProfileTeamDto> teams, int passkeyCount, List<PairedDeviceDto> pairedDevices, int blockedUserCount, ProfileNotificationSummaryDto notifications
});


@override $ProfileNotificationSummaryDtoCopyWith<$Res> get notifications;

}
/// @nodoc
class __$ProfileSummaryDtoCopyWithImpl<$Res>
    implements _$ProfileSummaryDtoCopyWith<$Res> {
  __$ProfileSummaryDtoCopyWithImpl(this._self, this._then);

  final _ProfileSummaryDto _self;
  final $Res Function(_ProfileSummaryDto) _then;

/// Create a copy of ProfileSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? teams = null,Object? passkeyCount = null,Object? pairedDevices = null,Object? blockedUserCount = null,Object? notifications = null,}) {
  return _then(_ProfileSummaryDto(
teams: null == teams ? _self._teams : teams // ignore: cast_nullable_to_non_nullable
as List<ProfileTeamDto>,passkeyCount: null == passkeyCount ? _self.passkeyCount : passkeyCount // ignore: cast_nullable_to_non_nullable
as int,pairedDevices: null == pairedDevices ? _self._pairedDevices : pairedDevices // ignore: cast_nullable_to_non_nullable
as List<PairedDeviceDto>,blockedUserCount: null == blockedUserCount ? _self.blockedUserCount : blockedUserCount // ignore: cast_nullable_to_non_nullable
as int,notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as ProfileNotificationSummaryDto,
  ));
}

/// Create a copy of ProfileSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProfileNotificationSummaryDtoCopyWith<$Res> get notifications {
  
  return $ProfileNotificationSummaryDtoCopyWith<$Res>(_self.notifications, (value) {
    return _then(_self.copyWith(notifications: value));
  });
}
}

// dart format on
