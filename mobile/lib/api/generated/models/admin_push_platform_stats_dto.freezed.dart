// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_push_platform_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminPushPlatformStatsDto {

/// The platform (ANDROID, IOS…)
 String get platform;/// Devices registered
 int get devices;/// Accounts with at least one device
 int get users;/// Devices seen during the last 7 days
 int get seenLast7Days;
/// Create a copy of AdminPushPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminPushPlatformStatsDtoCopyWith<AdminPushPlatformStatsDto> get copyWith => _$AdminPushPlatformStatsDtoCopyWithImpl<AdminPushPlatformStatsDto>(this as AdminPushPlatformStatsDto, _$identity);

  /// Serializes this AdminPushPlatformStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminPushPlatformStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminPushPlatformStatsDto&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.devices, _this.devices) || other.devices == _this.devices)&&(identical(other.users, _this.users) || other.users == _this.users)&&(identical(other.seenLast7Days, _this.seenLast7Days) || other.seenLast7Days == _this.seenLast7Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminPushPlatformStatsDto;
  return Object.hash(runtimeType,_this.platform,_this.devices,_this.users,_this.seenLast7Days);
}

@override
String toString() {
  final _this = this as AdminPushPlatformStatsDto;
  return 'AdminPushPlatformStatsDto(platform: ${_this.platform}, devices: ${_this.devices}, users: ${_this.users}, seenLast7Days: ${_this.seenLast7Days})';
}


}

/// @nodoc
abstract mixin class $AdminPushPlatformStatsDtoCopyWith<$Res>  {
  factory $AdminPushPlatformStatsDtoCopyWith(AdminPushPlatformStatsDto value, $Res Function(AdminPushPlatformStatsDto) _then) = _$AdminPushPlatformStatsDtoCopyWithImpl;
@useResult
$Res call({
 String platform, int devices, int users, int seenLast7Days
});




}
/// @nodoc
class _$AdminPushPlatformStatsDtoCopyWithImpl<$Res>
    implements $AdminPushPlatformStatsDtoCopyWith<$Res> {
  _$AdminPushPlatformStatsDtoCopyWithImpl(this._self, this._then);

  final AdminPushPlatformStatsDto _self;
  final $Res Function(AdminPushPlatformStatsDto) _then;

/// Create a copy of AdminPushPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? platform = null,Object? devices = null,Object? users = null,Object? seenLast7Days = null,}) {
  return _then(AdminPushPlatformStatsDto(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as int,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as int,seenLast7Days: null == seenLast7Days ? _self.seenLast7Days : seenLast7Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminPushPlatformStatsDto].
extension AdminPushPlatformStatsDtoPatterns on AdminPushPlatformStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminPushPlatformStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminPushPlatformStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminPushPlatformStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminPushPlatformStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminPushPlatformStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminPushPlatformStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String platform,  int devices,  int users,  int seenLast7Days)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminPushPlatformStatsDto() when $default != null:
return $default(_that.platform,_that.devices,_that.users,_that.seenLast7Days);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String platform,  int devices,  int users,  int seenLast7Days)  $default,) {final _that = this;
switch (_that) {
case _AdminPushPlatformStatsDto():
return $default(_that.platform,_that.devices,_that.users,_that.seenLast7Days);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String platform,  int devices,  int users,  int seenLast7Days)?  $default,) {final _that = this;
switch (_that) {
case _AdminPushPlatformStatsDto() when $default != null:
return $default(_that.platform,_that.devices,_that.users,_that.seenLast7Days);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminPushPlatformStatsDto implements AdminPushPlatformStatsDto {
  const _AdminPushPlatformStatsDto({required this.platform, required this.devices, required this.users, required this.seenLast7Days});
  factory _AdminPushPlatformStatsDto.fromJson(Map<String, dynamic> json) => _$AdminPushPlatformStatsDtoFromJson(json);

/// The platform (ANDROID, IOS…)
@override final  String platform;
/// Devices registered
@override final  int devices;
/// Accounts with at least one device
@override final  int users;
/// Devices seen during the last 7 days
@override final  int seenLast7Days;

/// Create a copy of AdminPushPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminPushPlatformStatsDtoCopyWith<_AdminPushPlatformStatsDto> get copyWith => __$AdminPushPlatformStatsDtoCopyWithImpl<_AdminPushPlatformStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminPushPlatformStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminPushPlatformStatsDto&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.devices, devices) || other.devices == devices)&&(identical(other.users, users) || other.users == users)&&(identical(other.seenLast7Days, seenLast7Days) || other.seenLast7Days == seenLast7Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,platform,devices,users,seenLast7Days);
}

@override
String toString() {
    return 'AdminPushPlatformStatsDto(platform: $platform, devices: $devices, users: $users, seenLast7Days: $seenLast7Days)';
}


}

/// @nodoc
abstract mixin class _$AdminPushPlatformStatsDtoCopyWith<$Res> implements $AdminPushPlatformStatsDtoCopyWith<$Res> {
  factory _$AdminPushPlatformStatsDtoCopyWith(_AdminPushPlatformStatsDto value, $Res Function(_AdminPushPlatformStatsDto) _then) = __$AdminPushPlatformStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 String platform, int devices, int users, int seenLast7Days
});




}
/// @nodoc
class __$AdminPushPlatformStatsDtoCopyWithImpl<$Res>
    implements _$AdminPushPlatformStatsDtoCopyWith<$Res> {
  __$AdminPushPlatformStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminPushPlatformStatsDto _self;
  final $Res Function(_AdminPushPlatformStatsDto) _then;

/// Create a copy of AdminPushPlatformStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? platform = null,Object? devices = null,Object? users = null,Object? seenLast7Days = null,}) {
  return _then(_AdminPushPlatformStatsDto(
platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as int,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as int,seenLast7Days: null == seenLast7Days ? _self.seenLast7Days : seenLast7Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
