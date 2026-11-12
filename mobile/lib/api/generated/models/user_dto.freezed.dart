// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserDto {

/// User ID (TSID)
 String get id;/// User email address
 String get email;/// User display name
 String get displayName;/// Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.
 bool get contactableByMembers;/// Whether the account's email has been verified
 bool get emailVerified;/// Where the user's personal route planner quota stands this month: the saves of a track drawn on the map in the GPX tools (docs/LEDGER_*.md BILL-10). limit is null — unlimited — for a member of an unlocked team of this site. Clients show no counter; they close « create a route » in the GPX tools when used >= limit already.
 PlannerQuotaDto get plannerQuota;/// User avatar URL
 String? get avatarUrl;/// Account creation timestamp
 String? get createdAt;/// Preferred unit system (metric or imperial)
 String? get unitSystem;/// Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.
 String? get theme;/// Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.
 String? get language;/// Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser.
 String? get timezone;/// Platform role (null if regular user)
 String? get platformRole;/// Connected GPS services
 List<GpsServiceConnectionDto>? get connectedServices;
/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserDtoCopyWith<UserDto> get copyWith => _$UserDtoCopyWithImpl<UserDto>(this as UserDto, _$identity);

  /// Serializes this UserDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.contactableByMembers, _this.contactableByMembers) || other.contactableByMembers == _this.contactableByMembers)&&(identical(other.emailVerified, _this.emailVerified) || other.emailVerified == _this.emailVerified)&&(identical(other.plannerQuota, _this.plannerQuota) || other.plannerQuota == _this.plannerQuota)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.unitSystem, _this.unitSystem) || other.unitSystem == _this.unitSystem)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.platformRole, _this.platformRole) || other.platformRole == _this.platformRole)&&const DeepCollectionEquality().equals(other.connectedServices, _this.connectedServices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserDto;
  return Object.hash(runtimeType,_this.id,_this.email,_this.displayName,_this.contactableByMembers,_this.emailVerified,_this.plannerQuota,_this.avatarUrl,_this.createdAt,_this.unitSystem,_this.theme,_this.language,_this.timezone,_this.platformRole,const DeepCollectionEquality().hash(_this.connectedServices));
}

@override
String toString() {
  final _this = this as UserDto;
  return 'UserDto(id: ${_this.id}, email: ${_this.email}, displayName: ${_this.displayName}, contactableByMembers: ${_this.contactableByMembers}, emailVerified: ${_this.emailVerified}, plannerQuota: ${_this.plannerQuota}, avatarUrl: ${_this.avatarUrl}, createdAt: ${_this.createdAt}, unitSystem: ${_this.unitSystem}, theme: ${_this.theme}, language: ${_this.language}, timezone: ${_this.timezone}, platformRole: ${_this.platformRole}, connectedServices: ${_this.connectedServices})';
}


}

/// @nodoc
abstract mixin class $UserDtoCopyWith<$Res>  {
  factory $UserDtoCopyWith(UserDto value, $Res Function(UserDto) _then) = _$UserDtoCopyWithImpl;
@useResult
$Res call({
 String id, String email, String displayName, bool contactableByMembers, bool emailVerified, PlannerQuotaDto plannerQuota, String? avatarUrl, String? createdAt, String? unitSystem, String? theme, String? language, String? timezone, String? platformRole, List<GpsServiceConnectionDto>? connectedServices
});


$PlannerQuotaDtoCopyWith<$Res> get plannerQuota;

}
/// @nodoc
class _$UserDtoCopyWithImpl<$Res>
    implements $UserDtoCopyWith<$Res> {
  _$UserDtoCopyWithImpl(this._self, this._then);

  final UserDto _self;
  final $Res Function(UserDto) _then;

/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? displayName = null,Object? contactableByMembers = null,Object? emailVerified = null,Object? plannerQuota = null,Object? avatarUrl = freezed,Object? createdAt = freezed,Object? unitSystem = freezed,Object? theme = freezed,Object? language = freezed,Object? timezone = freezed,Object? platformRole = freezed,Object? connectedServices = freezed,}) {
  return _then(UserDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,contactableByMembers: null == contactableByMembers ? _self.contactableByMembers : contactableByMembers // ignore: cast_nullable_to_non_nullable
as bool,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,plannerQuota: null == plannerQuota ? _self.plannerQuota : plannerQuota // ignore: cast_nullable_to_non_nullable
as PlannerQuotaDto,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,unitSystem: freezed == unitSystem ? _self.unitSystem : unitSystem // ignore: cast_nullable_to_non_nullable
as String?,theme: freezed == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,platformRole: freezed == platformRole ? _self.platformRole : platformRole // ignore: cast_nullable_to_non_nullable
as String?,connectedServices: freezed == connectedServices ? _self.connectedServices : connectedServices // ignore: cast_nullable_to_non_nullable
as List<GpsServiceConnectionDto>?,
  ));
}
/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerQuotaDtoCopyWith<$Res> get plannerQuota {
  
  return $PlannerQuotaDtoCopyWith<$Res>(_self.plannerQuota, (value) {
    return _then(_self.copyWith(plannerQuota: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserDto].
extension UserDtoPatterns on UserDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserDto value)  $default,){
final _that = this;
switch (_that) {
case _UserDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  String displayName,  bool contactableByMembers,  bool emailVerified,  PlannerQuotaDto plannerQuota,  String? avatarUrl,  String? createdAt,  String? unitSystem,  String? theme,  String? language,  String? timezone,  String? platformRole,  List<GpsServiceConnectionDto>? connectedServices)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserDto() when $default != null:
return $default(_that.id,_that.email,_that.displayName,_that.contactableByMembers,_that.emailVerified,_that.plannerQuota,_that.avatarUrl,_that.createdAt,_that.unitSystem,_that.theme,_that.language,_that.timezone,_that.platformRole,_that.connectedServices);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  String displayName,  bool contactableByMembers,  bool emailVerified,  PlannerQuotaDto plannerQuota,  String? avatarUrl,  String? createdAt,  String? unitSystem,  String? theme,  String? language,  String? timezone,  String? platformRole,  List<GpsServiceConnectionDto>? connectedServices)  $default,) {final _that = this;
switch (_that) {
case _UserDto():
return $default(_that.id,_that.email,_that.displayName,_that.contactableByMembers,_that.emailVerified,_that.plannerQuota,_that.avatarUrl,_that.createdAt,_that.unitSystem,_that.theme,_that.language,_that.timezone,_that.platformRole,_that.connectedServices);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  String displayName,  bool contactableByMembers,  bool emailVerified,  PlannerQuotaDto plannerQuota,  String? avatarUrl,  String? createdAt,  String? unitSystem,  String? theme,  String? language,  String? timezone,  String? platformRole,  List<GpsServiceConnectionDto>? connectedServices)?  $default,) {final _that = this;
switch (_that) {
case _UserDto() when $default != null:
return $default(_that.id,_that.email,_that.displayName,_that.contactableByMembers,_that.emailVerified,_that.plannerQuota,_that.avatarUrl,_that.createdAt,_that.unitSystem,_that.theme,_that.language,_that.timezone,_that.platformRole,_that.connectedServices);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserDto implements UserDto {
  const _UserDto({required this.id, required this.email, required this.displayName, required this.contactableByMembers, required this.emailVerified, required this.plannerQuota, this.avatarUrl, this.createdAt, this.unitSystem, this.theme, this.language, this.timezone, this.platformRole,  List<GpsServiceConnectionDto>? connectedServices}): _connectedServices = connectedServices;
  factory _UserDto.fromJson(Map<String, dynamic> json) => _$UserDtoFromJson(json);

/// User ID (TSID)
@override final  String id;
/// User email address
@override final  String email;
/// User display name
@override final  String displayName;
/// Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.
@override final  bool contactableByMembers;
/// Whether the account's email has been verified
@override final  bool emailVerified;
/// Where the user's personal route planner quota stands this month: the saves of a track drawn on the map in the GPX tools (docs/LEDGER_*.md BILL-10). limit is null — unlimited — for a member of an unlocked team of this site. Clients show no counter; they close « create a route » in the GPX tools when used >= limit already.
@override final  PlannerQuotaDto plannerQuota;
/// User avatar URL
@override final  String? avatarUrl;
/// Account creation timestamp
@override final  String? createdAt;
/// Preferred unit system (metric or imperial)
@override final  String? unitSystem;
/// Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.
@override final  String? theme;
/// Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.
@override final  String? language;
/// Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser.
@override final  String? timezone;
/// Platform role (null if regular user)
@override final  String? platformRole;
/// Connected GPS services
 final  List<GpsServiceConnectionDto>? _connectedServices;
/// Connected GPS services
@override List<GpsServiceConnectionDto>? get connectedServices {
  final value = _connectedServices;
  if (value == null) return null;
  if (_connectedServices is EqualUnmodifiableListView) return _connectedServices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserDtoCopyWith<_UserDto> get copyWith => __$UserDtoCopyWithImpl<_UserDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserDto&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.contactableByMembers, contactableByMembers) || other.contactableByMembers == contactableByMembers)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.plannerQuota, plannerQuota) || other.plannerQuota == plannerQuota)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.unitSystem, unitSystem) || other.unitSystem == unitSystem)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.language, language) || other.language == language)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.platformRole, platformRole) || other.platformRole == platformRole)&&const DeepCollectionEquality().equals(other.connectedServices, _connectedServices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,email,displayName,contactableByMembers,emailVerified,plannerQuota,avatarUrl,createdAt,unitSystem,theme,language,timezone,platformRole,const DeepCollectionEquality().hash(_connectedServices));
}

@override
String toString() {
    return 'UserDto(id: $id, email: $email, displayName: $displayName, contactableByMembers: $contactableByMembers, emailVerified: $emailVerified, plannerQuota: $plannerQuota, avatarUrl: $avatarUrl, createdAt: $createdAt, unitSystem: $unitSystem, theme: $theme, language: $language, timezone: $timezone, platformRole: $platformRole, connectedServices: $connectedServices)';
}


}

/// @nodoc
abstract mixin class _$UserDtoCopyWith<$Res> implements $UserDtoCopyWith<$Res> {
  factory _$UserDtoCopyWith(_UserDto value, $Res Function(_UserDto) _then) = __$UserDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, String displayName, bool contactableByMembers, bool emailVerified, PlannerQuotaDto plannerQuota, String? avatarUrl, String? createdAt, String? unitSystem, String? theme, String? language, String? timezone, String? platformRole, List<GpsServiceConnectionDto>? connectedServices
});


@override $PlannerQuotaDtoCopyWith<$Res> get plannerQuota;

}
/// @nodoc
class __$UserDtoCopyWithImpl<$Res>
    implements _$UserDtoCopyWith<$Res> {
  __$UserDtoCopyWithImpl(this._self, this._then);

  final _UserDto _self;
  final $Res Function(_UserDto) _then;

/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? displayName = null,Object? contactableByMembers = null,Object? emailVerified = null,Object? plannerQuota = null,Object? avatarUrl = freezed,Object? createdAt = freezed,Object? unitSystem = freezed,Object? theme = freezed,Object? language = freezed,Object? timezone = freezed,Object? platformRole = freezed,Object? connectedServices = freezed,}) {
  return _then(_UserDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,contactableByMembers: null == contactableByMembers ? _self.contactableByMembers : contactableByMembers // ignore: cast_nullable_to_non_nullable
as bool,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,plannerQuota: null == plannerQuota ? _self.plannerQuota : plannerQuota // ignore: cast_nullable_to_non_nullable
as PlannerQuotaDto,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,unitSystem: freezed == unitSystem ? _self.unitSystem : unitSystem // ignore: cast_nullable_to_non_nullable
as String?,theme: freezed == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,platformRole: freezed == platformRole ? _self.platformRole : platformRole // ignore: cast_nullable_to_non_nullable
as String?,connectedServices: freezed == connectedServices ? _self._connectedServices : connectedServices // ignore: cast_nullable_to_non_nullable
as List<GpsServiceConnectionDto>?,
  ));
}

/// Create a copy of UserDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerQuotaDtoCopyWith<$Res> get plannerQuota {
  
  return $PlannerQuotaDtoCopyWith<$Res>(_self.plannerQuota, (value) {
    return _then(_self.copyWith(plannerQuota: value));
  });
}
}

// dart format on
