// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_platform_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminPlatformStatsDto {

/// When the figures were computed
 String get generatedAt; AdminUserStatsDto get users; AdminAuthMethodStatsDto get authMethods; AdminPasskeyStatsDto get passkeys;/// Accounts created per calendar month (UTC), the last 12 months, the current one included, oldest first, months without any included
 List<AdminMonthCountDto> get signupsByMonth; AdminTeamStatsDto get teams; List<AdminGpsServiceStatsDto> get gpsServices;/// Accounts with a connection to any GPS service
 int get usersWithGpsService; List<AdminPushPlatformStatsDto> get pushDevices;/// Distinct accounts per kind of client among the sessions used during the last 30 days. Keys: MOBILE_APP (the Pédalons app), OAUTH (a third-party application authorised through OAuth), the lowercase device client of a paired device (garmin, karoo), WEB_MOBILE (a browser on a phone or tablet), WEB_DESKTOP (any other browser). An account counts once per kind, so the total can exceed the number of accounts.
 List<AdminKeyCountDto> get clientsLast30Days; AdminCalendarStatsDto get calendarFeeds;/// The domain the figures are limited to; absent: all domains
 String? get domainId;
/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminPlatformStatsDtoCopyWith<AdminPlatformStatsDto> get copyWith => _$AdminPlatformStatsDtoCopyWithImpl<AdminPlatformStatsDto>(this as AdminPlatformStatsDto, _$identity);

  /// Serializes this AdminPlatformStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminPlatformStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminPlatformStatsDto&&(identical(other.generatedAt, _this.generatedAt) || other.generatedAt == _this.generatedAt)&&(identical(other.users, _this.users) || other.users == _this.users)&&(identical(other.authMethods, _this.authMethods) || other.authMethods == _this.authMethods)&&(identical(other.passkeys, _this.passkeys) || other.passkeys == _this.passkeys)&&const DeepCollectionEquality().equals(other.signupsByMonth, _this.signupsByMonth)&&(identical(other.teams, _this.teams) || other.teams == _this.teams)&&const DeepCollectionEquality().equals(other.gpsServices, _this.gpsServices)&&(identical(other.usersWithGpsService, _this.usersWithGpsService) || other.usersWithGpsService == _this.usersWithGpsService)&&const DeepCollectionEquality().equals(other.pushDevices, _this.pushDevices)&&const DeepCollectionEquality().equals(other.clientsLast30Days, _this.clientsLast30Days)&&(identical(other.calendarFeeds, _this.calendarFeeds) || other.calendarFeeds == _this.calendarFeeds)&&(identical(other.domainId, _this.domainId) || other.domainId == _this.domainId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminPlatformStatsDto;
  return Object.hash(runtimeType,_this.generatedAt,_this.users,_this.authMethods,_this.passkeys,const DeepCollectionEquality().hash(_this.signupsByMonth),_this.teams,const DeepCollectionEquality().hash(_this.gpsServices),_this.usersWithGpsService,const DeepCollectionEquality().hash(_this.pushDevices),const DeepCollectionEquality().hash(_this.clientsLast30Days),_this.calendarFeeds,_this.domainId);
}

@override
String toString() {
  final _this = this as AdminPlatformStatsDto;
  return 'AdminPlatformStatsDto(generatedAt: ${_this.generatedAt}, users: ${_this.users}, authMethods: ${_this.authMethods}, passkeys: ${_this.passkeys}, signupsByMonth: ${_this.signupsByMonth}, teams: ${_this.teams}, gpsServices: ${_this.gpsServices}, usersWithGpsService: ${_this.usersWithGpsService}, pushDevices: ${_this.pushDevices}, clientsLast30Days: ${_this.clientsLast30Days}, calendarFeeds: ${_this.calendarFeeds}, domainId: ${_this.domainId})';
}


}

/// @nodoc
abstract mixin class $AdminPlatformStatsDtoCopyWith<$Res>  {
  factory $AdminPlatformStatsDtoCopyWith(AdminPlatformStatsDto value, $Res Function(AdminPlatformStatsDto) _then) = _$AdminPlatformStatsDtoCopyWithImpl;
@useResult
$Res call({
 String generatedAt, AdminUserStatsDto users, AdminAuthMethodStatsDto authMethods, AdminPasskeyStatsDto passkeys, List<AdminMonthCountDto> signupsByMonth, AdminTeamStatsDto teams, List<AdminGpsServiceStatsDto> gpsServices, int usersWithGpsService, List<AdminPushPlatformStatsDto> pushDevices, List<AdminKeyCountDto> clientsLast30Days, AdminCalendarStatsDto calendarFeeds, String? domainId
});


$AdminUserStatsDtoCopyWith<$Res> get users;$AdminAuthMethodStatsDtoCopyWith<$Res> get authMethods;$AdminPasskeyStatsDtoCopyWith<$Res> get passkeys;$AdminTeamStatsDtoCopyWith<$Res> get teams;$AdminCalendarStatsDtoCopyWith<$Res> get calendarFeeds;

}
/// @nodoc
class _$AdminPlatformStatsDtoCopyWithImpl<$Res>
    implements $AdminPlatformStatsDtoCopyWith<$Res> {
  _$AdminPlatformStatsDtoCopyWithImpl(this._self, this._then);

  final AdminPlatformStatsDto _self;
  final $Res Function(AdminPlatformStatsDto) _then;

/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generatedAt = null,Object? users = null,Object? authMethods = null,Object? passkeys = null,Object? signupsByMonth = null,Object? teams = null,Object? gpsServices = null,Object? usersWithGpsService = null,Object? pushDevices = null,Object? clientsLast30Days = null,Object? calendarFeeds = null,Object? domainId = freezed,}) {
  return _then(AdminPlatformStatsDto(
generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as String,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as AdminUserStatsDto,authMethods: null == authMethods ? _self.authMethods : authMethods // ignore: cast_nullable_to_non_nullable
as AdminAuthMethodStatsDto,passkeys: null == passkeys ? _self.passkeys : passkeys // ignore: cast_nullable_to_non_nullable
as AdminPasskeyStatsDto,signupsByMonth: null == signupsByMonth ? _self.signupsByMonth : signupsByMonth // ignore: cast_nullable_to_non_nullable
as List<AdminMonthCountDto>,teams: null == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as AdminTeamStatsDto,gpsServices: null == gpsServices ? _self.gpsServices : gpsServices // ignore: cast_nullable_to_non_nullable
as List<AdminGpsServiceStatsDto>,usersWithGpsService: null == usersWithGpsService ? _self.usersWithGpsService : usersWithGpsService // ignore: cast_nullable_to_non_nullable
as int,pushDevices: null == pushDevices ? _self.pushDevices : pushDevices // ignore: cast_nullable_to_non_nullable
as List<AdminPushPlatformStatsDto>,clientsLast30Days: null == clientsLast30Days ? _self.clientsLast30Days : clientsLast30Days // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,calendarFeeds: null == calendarFeeds ? _self.calendarFeeds : calendarFeeds // ignore: cast_nullable_to_non_nullable
as AdminCalendarStatsDto,domainId: freezed == domainId ? _self.domainId : domainId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminUserStatsDtoCopyWith<$Res> get users {
  
  return $AdminUserStatsDtoCopyWith<$Res>(_self.users, (value) {
    return _then(_self.copyWith(users: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminAuthMethodStatsDtoCopyWith<$Res> get authMethods {
  
  return $AdminAuthMethodStatsDtoCopyWith<$Res>(_self.authMethods, (value) {
    return _then(_self.copyWith(authMethods: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminPasskeyStatsDtoCopyWith<$Res> get passkeys {
  
  return $AdminPasskeyStatsDtoCopyWith<$Res>(_self.passkeys, (value) {
    return _then(_self.copyWith(passkeys: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminTeamStatsDtoCopyWith<$Res> get teams {
  
  return $AdminTeamStatsDtoCopyWith<$Res>(_self.teams, (value) {
    return _then(_self.copyWith(teams: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminCalendarStatsDtoCopyWith<$Res> get calendarFeeds {
  
  return $AdminCalendarStatsDtoCopyWith<$Res>(_self.calendarFeeds, (value) {
    return _then(_self.copyWith(calendarFeeds: value));
  });
}
}


/// Adds pattern-matching-related methods to [AdminPlatformStatsDto].
extension AdminPlatformStatsDtoPatterns on AdminPlatformStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminPlatformStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminPlatformStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminPlatformStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminPlatformStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminPlatformStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminPlatformStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String generatedAt,  AdminUserStatsDto users,  AdminAuthMethodStatsDto authMethods,  AdminPasskeyStatsDto passkeys,  List<AdminMonthCountDto> signupsByMonth,  AdminTeamStatsDto teams,  List<AdminGpsServiceStatsDto> gpsServices,  int usersWithGpsService,  List<AdminPushPlatformStatsDto> pushDevices,  List<AdminKeyCountDto> clientsLast30Days,  AdminCalendarStatsDto calendarFeeds,  String? domainId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminPlatformStatsDto() when $default != null:
return $default(_that.generatedAt,_that.users,_that.authMethods,_that.passkeys,_that.signupsByMonth,_that.teams,_that.gpsServices,_that.usersWithGpsService,_that.pushDevices,_that.clientsLast30Days,_that.calendarFeeds,_that.domainId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String generatedAt,  AdminUserStatsDto users,  AdminAuthMethodStatsDto authMethods,  AdminPasskeyStatsDto passkeys,  List<AdminMonthCountDto> signupsByMonth,  AdminTeamStatsDto teams,  List<AdminGpsServiceStatsDto> gpsServices,  int usersWithGpsService,  List<AdminPushPlatformStatsDto> pushDevices,  List<AdminKeyCountDto> clientsLast30Days,  AdminCalendarStatsDto calendarFeeds,  String? domainId)  $default,) {final _that = this;
switch (_that) {
case _AdminPlatformStatsDto():
return $default(_that.generatedAt,_that.users,_that.authMethods,_that.passkeys,_that.signupsByMonth,_that.teams,_that.gpsServices,_that.usersWithGpsService,_that.pushDevices,_that.clientsLast30Days,_that.calendarFeeds,_that.domainId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String generatedAt,  AdminUserStatsDto users,  AdminAuthMethodStatsDto authMethods,  AdminPasskeyStatsDto passkeys,  List<AdminMonthCountDto> signupsByMonth,  AdminTeamStatsDto teams,  List<AdminGpsServiceStatsDto> gpsServices,  int usersWithGpsService,  List<AdminPushPlatformStatsDto> pushDevices,  List<AdminKeyCountDto> clientsLast30Days,  AdminCalendarStatsDto calendarFeeds,  String? domainId)?  $default,) {final _that = this;
switch (_that) {
case _AdminPlatformStatsDto() when $default != null:
return $default(_that.generatedAt,_that.users,_that.authMethods,_that.passkeys,_that.signupsByMonth,_that.teams,_that.gpsServices,_that.usersWithGpsService,_that.pushDevices,_that.clientsLast30Days,_that.calendarFeeds,_that.domainId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminPlatformStatsDto implements AdminPlatformStatsDto {
  const _AdminPlatformStatsDto({required this.generatedAt, required this.users, required this.authMethods, required this.passkeys, required  List<AdminMonthCountDto> signupsByMonth, required this.teams, required  List<AdminGpsServiceStatsDto> gpsServices, required this.usersWithGpsService, required  List<AdminPushPlatformStatsDto> pushDevices, required  List<AdminKeyCountDto> clientsLast30Days, required this.calendarFeeds, this.domainId}): _signupsByMonth = signupsByMonth,_gpsServices = gpsServices,_pushDevices = pushDevices,_clientsLast30Days = clientsLast30Days;
  factory _AdminPlatformStatsDto.fromJson(Map<String, dynamic> json) => _$AdminPlatformStatsDtoFromJson(json);

/// When the figures were computed
@override final  String generatedAt;
@override final  AdminUserStatsDto users;
@override final  AdminAuthMethodStatsDto authMethods;
@override final  AdminPasskeyStatsDto passkeys;
/// Accounts created per calendar month (UTC), the last 12 months, the current one included, oldest first, months without any included
 final  List<AdminMonthCountDto> _signupsByMonth;
/// Accounts created per calendar month (UTC), the last 12 months, the current one included, oldest first, months without any included
@override List<AdminMonthCountDto> get signupsByMonth {
  if (_signupsByMonth is EqualUnmodifiableListView) return _signupsByMonth;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_signupsByMonth);
}

@override final  AdminTeamStatsDto teams;
 final  List<AdminGpsServiceStatsDto> _gpsServices;
@override List<AdminGpsServiceStatsDto> get gpsServices {
  if (_gpsServices is EqualUnmodifiableListView) return _gpsServices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gpsServices);
}

/// Accounts with a connection to any GPS service
@override final  int usersWithGpsService;
 final  List<AdminPushPlatformStatsDto> _pushDevices;
@override List<AdminPushPlatformStatsDto> get pushDevices {
  if (_pushDevices is EqualUnmodifiableListView) return _pushDevices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pushDevices);
}

/// Distinct accounts per kind of client among the sessions used during the last 30 days. Keys: MOBILE_APP (the Pédalons app), OAUTH (a third-party application authorised through OAuth), the lowercase device client of a paired device (garmin, karoo), WEB_MOBILE (a browser on a phone or tablet), WEB_DESKTOP (any other browser). An account counts once per kind, so the total can exceed the number of accounts.
 final  List<AdminKeyCountDto> _clientsLast30Days;
/// Distinct accounts per kind of client among the sessions used during the last 30 days. Keys: MOBILE_APP (the Pédalons app), OAUTH (a third-party application authorised through OAuth), the lowercase device client of a paired device (garmin, karoo), WEB_MOBILE (a browser on a phone or tablet), WEB_DESKTOP (any other browser). An account counts once per kind, so the total can exceed the number of accounts.
@override List<AdminKeyCountDto> get clientsLast30Days {
  if (_clientsLast30Days is EqualUnmodifiableListView) return _clientsLast30Days;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clientsLast30Days);
}

@override final  AdminCalendarStatsDto calendarFeeds;
/// The domain the figures are limited to; absent: all domains
@override final  String? domainId;

/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminPlatformStatsDtoCopyWith<_AdminPlatformStatsDto> get copyWith => __$AdminPlatformStatsDtoCopyWithImpl<_AdminPlatformStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminPlatformStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminPlatformStatsDto&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.users, users) || other.users == users)&&(identical(other.authMethods, authMethods) || other.authMethods == authMethods)&&(identical(other.passkeys, passkeys) || other.passkeys == passkeys)&&const DeepCollectionEquality().equals(other.signupsByMonth, _signupsByMonth)&&(identical(other.teams, teams) || other.teams == teams)&&const DeepCollectionEquality().equals(other.gpsServices, _gpsServices)&&(identical(other.usersWithGpsService, usersWithGpsService) || other.usersWithGpsService == usersWithGpsService)&&const DeepCollectionEquality().equals(other.pushDevices, _pushDevices)&&const DeepCollectionEquality().equals(other.clientsLast30Days, _clientsLast30Days)&&(identical(other.calendarFeeds, calendarFeeds) || other.calendarFeeds == calendarFeeds)&&(identical(other.domainId, domainId) || other.domainId == domainId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,generatedAt,users,authMethods,passkeys,const DeepCollectionEquality().hash(_signupsByMonth),teams,const DeepCollectionEquality().hash(_gpsServices),usersWithGpsService,const DeepCollectionEquality().hash(_pushDevices),const DeepCollectionEquality().hash(_clientsLast30Days),calendarFeeds,domainId);
}

@override
String toString() {
    return 'AdminPlatformStatsDto(generatedAt: $generatedAt, users: $users, authMethods: $authMethods, passkeys: $passkeys, signupsByMonth: $signupsByMonth, teams: $teams, gpsServices: $gpsServices, usersWithGpsService: $usersWithGpsService, pushDevices: $pushDevices, clientsLast30Days: $clientsLast30Days, calendarFeeds: $calendarFeeds, domainId: $domainId)';
}


}

/// @nodoc
abstract mixin class _$AdminPlatformStatsDtoCopyWith<$Res> implements $AdminPlatformStatsDtoCopyWith<$Res> {
  factory _$AdminPlatformStatsDtoCopyWith(_AdminPlatformStatsDto value, $Res Function(_AdminPlatformStatsDto) _then) = __$AdminPlatformStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 String generatedAt, AdminUserStatsDto users, AdminAuthMethodStatsDto authMethods, AdminPasskeyStatsDto passkeys, List<AdminMonthCountDto> signupsByMonth, AdminTeamStatsDto teams, List<AdminGpsServiceStatsDto> gpsServices, int usersWithGpsService, List<AdminPushPlatformStatsDto> pushDevices, List<AdminKeyCountDto> clientsLast30Days, AdminCalendarStatsDto calendarFeeds, String? domainId
});


@override $AdminUserStatsDtoCopyWith<$Res> get users;@override $AdminAuthMethodStatsDtoCopyWith<$Res> get authMethods;@override $AdminPasskeyStatsDtoCopyWith<$Res> get passkeys;@override $AdminTeamStatsDtoCopyWith<$Res> get teams;@override $AdminCalendarStatsDtoCopyWith<$Res> get calendarFeeds;

}
/// @nodoc
class __$AdminPlatformStatsDtoCopyWithImpl<$Res>
    implements _$AdminPlatformStatsDtoCopyWith<$Res> {
  __$AdminPlatformStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminPlatformStatsDto _self;
  final $Res Function(_AdminPlatformStatsDto) _then;

/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generatedAt = null,Object? users = null,Object? authMethods = null,Object? passkeys = null,Object? signupsByMonth = null,Object? teams = null,Object? gpsServices = null,Object? usersWithGpsService = null,Object? pushDevices = null,Object? clientsLast30Days = null,Object? calendarFeeds = null,Object? domainId = freezed,}) {
  return _then(_AdminPlatformStatsDto(
generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as String,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as AdminUserStatsDto,authMethods: null == authMethods ? _self.authMethods : authMethods // ignore: cast_nullable_to_non_nullable
as AdminAuthMethodStatsDto,passkeys: null == passkeys ? _self.passkeys : passkeys // ignore: cast_nullable_to_non_nullable
as AdminPasskeyStatsDto,signupsByMonth: null == signupsByMonth ? _self._signupsByMonth : signupsByMonth // ignore: cast_nullable_to_non_nullable
as List<AdminMonthCountDto>,teams: null == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as AdminTeamStatsDto,gpsServices: null == gpsServices ? _self._gpsServices : gpsServices // ignore: cast_nullable_to_non_nullable
as List<AdminGpsServiceStatsDto>,usersWithGpsService: null == usersWithGpsService ? _self.usersWithGpsService : usersWithGpsService // ignore: cast_nullable_to_non_nullable
as int,pushDevices: null == pushDevices ? _self._pushDevices : pushDevices // ignore: cast_nullable_to_non_nullable
as List<AdminPushPlatformStatsDto>,clientsLast30Days: null == clientsLast30Days ? _self._clientsLast30Days : clientsLast30Days // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,calendarFeeds: null == calendarFeeds ? _self.calendarFeeds : calendarFeeds // ignore: cast_nullable_to_non_nullable
as AdminCalendarStatsDto,domainId: freezed == domainId ? _self.domainId : domainId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminUserStatsDtoCopyWith<$Res> get users {
  
  return $AdminUserStatsDtoCopyWith<$Res>(_self.users, (value) {
    return _then(_self.copyWith(users: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminAuthMethodStatsDtoCopyWith<$Res> get authMethods {
  
  return $AdminAuthMethodStatsDtoCopyWith<$Res>(_self.authMethods, (value) {
    return _then(_self.copyWith(authMethods: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminPasskeyStatsDtoCopyWith<$Res> get passkeys {
  
  return $AdminPasskeyStatsDtoCopyWith<$Res>(_self.passkeys, (value) {
    return _then(_self.copyWith(passkeys: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminTeamStatsDtoCopyWith<$Res> get teams {
  
  return $AdminTeamStatsDtoCopyWith<$Res>(_self.teams, (value) {
    return _then(_self.copyWith(teams: value));
  });
}/// Create a copy of AdminPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdminCalendarStatsDtoCopyWith<$Res> get calendarFeeds {
  
  return $AdminCalendarStatsDtoCopyWith<$Res>(_self.calendarFeeds, (value) {
    return _then(_self.copyWith(calendarFeeds: value));
  });
}
}

// dart format on
