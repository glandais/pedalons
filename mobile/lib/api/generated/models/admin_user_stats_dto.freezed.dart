// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_user_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminUserStatsDto {

/// Accounts that are not deleted
 int get total;/// Accounts deleted
 int get deleted;/// Accounts whose e-mail address is verified
 int get emailVerified;/// Accounts that accepted the terms
 int get termsAccepted;/// Platform administrators
 int get platformAdmins;/// Accounts with an avatar
 int get withAvatar;/// Accounts that never signed in
 int get neverLoggedIn;/// Accounts that signed in during the last 7 days
 int get activeLast7Days;/// Accounts that signed in during the last 30 days
 int get activeLast30Days;/// Accounts that signed in during the last 90 days
 int get activeLast90Days;
/// Create a copy of AdminUserStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminUserStatsDtoCopyWith<AdminUserStatsDto> get copyWith => _$AdminUserStatsDtoCopyWithImpl<AdminUserStatsDto>(this as AdminUserStatsDto, _$identity);

  /// Serializes this AdminUserStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminUserStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminUserStatsDto&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.emailVerified, _this.emailVerified) || other.emailVerified == _this.emailVerified)&&(identical(other.termsAccepted, _this.termsAccepted) || other.termsAccepted == _this.termsAccepted)&&(identical(other.platformAdmins, _this.platformAdmins) || other.platformAdmins == _this.platformAdmins)&&(identical(other.withAvatar, _this.withAvatar) || other.withAvatar == _this.withAvatar)&&(identical(other.neverLoggedIn, _this.neverLoggedIn) || other.neverLoggedIn == _this.neverLoggedIn)&&(identical(other.activeLast7Days, _this.activeLast7Days) || other.activeLast7Days == _this.activeLast7Days)&&(identical(other.activeLast30Days, _this.activeLast30Days) || other.activeLast30Days == _this.activeLast30Days)&&(identical(other.activeLast90Days, _this.activeLast90Days) || other.activeLast90Days == _this.activeLast90Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminUserStatsDto;
  return Object.hash(runtimeType,_this.total,_this.deleted,_this.emailVerified,_this.termsAccepted,_this.platformAdmins,_this.withAvatar,_this.neverLoggedIn,_this.activeLast7Days,_this.activeLast30Days,_this.activeLast90Days);
}

@override
String toString() {
  final _this = this as AdminUserStatsDto;
  return 'AdminUserStatsDto(total: ${_this.total}, deleted: ${_this.deleted}, emailVerified: ${_this.emailVerified}, termsAccepted: ${_this.termsAccepted}, platformAdmins: ${_this.platformAdmins}, withAvatar: ${_this.withAvatar}, neverLoggedIn: ${_this.neverLoggedIn}, activeLast7Days: ${_this.activeLast7Days}, activeLast30Days: ${_this.activeLast30Days}, activeLast90Days: ${_this.activeLast90Days})';
}


}

/// @nodoc
abstract mixin class $AdminUserStatsDtoCopyWith<$Res>  {
  factory $AdminUserStatsDtoCopyWith(AdminUserStatsDto value, $Res Function(AdminUserStatsDto) _then) = _$AdminUserStatsDtoCopyWithImpl;
@useResult
$Res call({
 int total, int deleted, int emailVerified, int termsAccepted, int platformAdmins, int withAvatar, int neverLoggedIn, int activeLast7Days, int activeLast30Days, int activeLast90Days
});




}
/// @nodoc
class _$AdminUserStatsDtoCopyWithImpl<$Res>
    implements $AdminUserStatsDtoCopyWith<$Res> {
  _$AdminUserStatsDtoCopyWithImpl(this._self, this._then);

  final AdminUserStatsDto _self;
  final $Res Function(AdminUserStatsDto) _then;

/// Create a copy of AdminUserStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? deleted = null,Object? emailVerified = null,Object? termsAccepted = null,Object? platformAdmins = null,Object? withAvatar = null,Object? neverLoggedIn = null,Object? activeLast7Days = null,Object? activeLast30Days = null,Object? activeLast90Days = null,}) {
  return _then(AdminUserStatsDto(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as int,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as int,termsAccepted: null == termsAccepted ? _self.termsAccepted : termsAccepted // ignore: cast_nullable_to_non_nullable
as int,platformAdmins: null == platformAdmins ? _self.platformAdmins : platformAdmins // ignore: cast_nullable_to_non_nullable
as int,withAvatar: null == withAvatar ? _self.withAvatar : withAvatar // ignore: cast_nullable_to_non_nullable
as int,neverLoggedIn: null == neverLoggedIn ? _self.neverLoggedIn : neverLoggedIn // ignore: cast_nullable_to_non_nullable
as int,activeLast7Days: null == activeLast7Days ? _self.activeLast7Days : activeLast7Days // ignore: cast_nullable_to_non_nullable
as int,activeLast30Days: null == activeLast30Days ? _self.activeLast30Days : activeLast30Days // ignore: cast_nullable_to_non_nullable
as int,activeLast90Days: null == activeLast90Days ? _self.activeLast90Days : activeLast90Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminUserStatsDto].
extension AdminUserStatsDtoPatterns on AdminUserStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminUserStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminUserStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminUserStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminUserStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminUserStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminUserStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int deleted,  int emailVerified,  int termsAccepted,  int platformAdmins,  int withAvatar,  int neverLoggedIn,  int activeLast7Days,  int activeLast30Days,  int activeLast90Days)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminUserStatsDto() when $default != null:
return $default(_that.total,_that.deleted,_that.emailVerified,_that.termsAccepted,_that.platformAdmins,_that.withAvatar,_that.neverLoggedIn,_that.activeLast7Days,_that.activeLast30Days,_that.activeLast90Days);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int deleted,  int emailVerified,  int termsAccepted,  int platformAdmins,  int withAvatar,  int neverLoggedIn,  int activeLast7Days,  int activeLast30Days,  int activeLast90Days)  $default,) {final _that = this;
switch (_that) {
case _AdminUserStatsDto():
return $default(_that.total,_that.deleted,_that.emailVerified,_that.termsAccepted,_that.platformAdmins,_that.withAvatar,_that.neverLoggedIn,_that.activeLast7Days,_that.activeLast30Days,_that.activeLast90Days);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int deleted,  int emailVerified,  int termsAccepted,  int platformAdmins,  int withAvatar,  int neverLoggedIn,  int activeLast7Days,  int activeLast30Days,  int activeLast90Days)?  $default,) {final _that = this;
switch (_that) {
case _AdminUserStatsDto() when $default != null:
return $default(_that.total,_that.deleted,_that.emailVerified,_that.termsAccepted,_that.platformAdmins,_that.withAvatar,_that.neverLoggedIn,_that.activeLast7Days,_that.activeLast30Days,_that.activeLast90Days);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminUserStatsDto implements AdminUserStatsDto {
  const _AdminUserStatsDto({required this.total, required this.deleted, required this.emailVerified, required this.termsAccepted, required this.platformAdmins, required this.withAvatar, required this.neverLoggedIn, required this.activeLast7Days, required this.activeLast30Days, required this.activeLast90Days});
  factory _AdminUserStatsDto.fromJson(Map<String, dynamic> json) => _$AdminUserStatsDtoFromJson(json);

/// Accounts that are not deleted
@override final  int total;
/// Accounts deleted
@override final  int deleted;
/// Accounts whose e-mail address is verified
@override final  int emailVerified;
/// Accounts that accepted the terms
@override final  int termsAccepted;
/// Platform administrators
@override final  int platformAdmins;
/// Accounts with an avatar
@override final  int withAvatar;
/// Accounts that never signed in
@override final  int neverLoggedIn;
/// Accounts that signed in during the last 7 days
@override final  int activeLast7Days;
/// Accounts that signed in during the last 30 days
@override final  int activeLast30Days;
/// Accounts that signed in during the last 90 days
@override final  int activeLast90Days;

/// Create a copy of AdminUserStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminUserStatsDtoCopyWith<_AdminUserStatsDto> get copyWith => __$AdminUserStatsDtoCopyWithImpl<_AdminUserStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminUserStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminUserStatsDto&&(identical(other.total, total) || other.total == total)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.termsAccepted, termsAccepted) || other.termsAccepted == termsAccepted)&&(identical(other.platformAdmins, platformAdmins) || other.platformAdmins == platformAdmins)&&(identical(other.withAvatar, withAvatar) || other.withAvatar == withAvatar)&&(identical(other.neverLoggedIn, neverLoggedIn) || other.neverLoggedIn == neverLoggedIn)&&(identical(other.activeLast7Days, activeLast7Days) || other.activeLast7Days == activeLast7Days)&&(identical(other.activeLast30Days, activeLast30Days) || other.activeLast30Days == activeLast30Days)&&(identical(other.activeLast90Days, activeLast90Days) || other.activeLast90Days == activeLast90Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,total,deleted,emailVerified,termsAccepted,platformAdmins,withAvatar,neverLoggedIn,activeLast7Days,activeLast30Days,activeLast90Days);
}

@override
String toString() {
    return 'AdminUserStatsDto(total: $total, deleted: $deleted, emailVerified: $emailVerified, termsAccepted: $termsAccepted, platformAdmins: $platformAdmins, withAvatar: $withAvatar, neverLoggedIn: $neverLoggedIn, activeLast7Days: $activeLast7Days, activeLast30Days: $activeLast30Days, activeLast90Days: $activeLast90Days)';
}


}

/// @nodoc
abstract mixin class _$AdminUserStatsDtoCopyWith<$Res> implements $AdminUserStatsDtoCopyWith<$Res> {
  factory _$AdminUserStatsDtoCopyWith(_AdminUserStatsDto value, $Res Function(_AdminUserStatsDto) _then) = __$AdminUserStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 int total, int deleted, int emailVerified, int termsAccepted, int platformAdmins, int withAvatar, int neverLoggedIn, int activeLast7Days, int activeLast30Days, int activeLast90Days
});




}
/// @nodoc
class __$AdminUserStatsDtoCopyWithImpl<$Res>
    implements _$AdminUserStatsDtoCopyWith<$Res> {
  __$AdminUserStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminUserStatsDto _self;
  final $Res Function(_AdminUserStatsDto) _then;

/// Create a copy of AdminUserStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? deleted = null,Object? emailVerified = null,Object? termsAccepted = null,Object? platformAdmins = null,Object? withAvatar = null,Object? neverLoggedIn = null,Object? activeLast7Days = null,Object? activeLast30Days = null,Object? activeLast90Days = null,}) {
  return _then(_AdminUserStatsDto(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as int,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as int,termsAccepted: null == termsAccepted ? _self.termsAccepted : termsAccepted // ignore: cast_nullable_to_non_nullable
as int,platformAdmins: null == platformAdmins ? _self.platformAdmins : platformAdmins // ignore: cast_nullable_to_non_nullable
as int,withAvatar: null == withAvatar ? _self.withAvatar : withAvatar // ignore: cast_nullable_to_non_nullable
as int,neverLoggedIn: null == neverLoggedIn ? _self.neverLoggedIn : neverLoggedIn // ignore: cast_nullable_to_non_nullable
as int,activeLast7Days: null == activeLast7Days ? _self.activeLast7Days : activeLast7Days // ignore: cast_nullable_to_non_nullable
as int,activeLast30Days: null == activeLast30Days ? _self.activeLast30Days : activeLast30Days // ignore: cast_nullable_to_non_nullable
as int,activeLast90Days: null == activeLast90Days ? _self.activeLast90Days : activeLast90Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
