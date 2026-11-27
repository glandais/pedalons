// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_team_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminTeamStatsDto {

/// Teams that are not deleted
 int get active;/// Teams deleted
 int get deleted;/// Active teams per plan (FREE, UNLOCKED…)
 List<AdminKeyCountDto> get byTier;/// Memberships per role (MEMBER, ORGANIZER, ADMIN), active teams and accounts that are not deleted
 List<AdminKeyCountDto> get membershipsByRole;/// Accounts that are not deleted per number of active teams they belong to: keys "0", "1", "2", "3+"
 List<AdminKeyCountDto> get usersByTeamCount;
/// Create a copy of AdminTeamStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminTeamStatsDtoCopyWith<AdminTeamStatsDto> get copyWith => _$AdminTeamStatsDtoCopyWithImpl<AdminTeamStatsDto>(this as AdminTeamStatsDto, _$identity);

  /// Serializes this AdminTeamStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminTeamStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminTeamStatsDto&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&const DeepCollectionEquality().equals(other.byTier, _this.byTier)&&const DeepCollectionEquality().equals(other.membershipsByRole, _this.membershipsByRole)&&const DeepCollectionEquality().equals(other.usersByTeamCount, _this.usersByTeamCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminTeamStatsDto;
  return Object.hash(runtimeType,_this.active,_this.deleted,const DeepCollectionEquality().hash(_this.byTier),const DeepCollectionEquality().hash(_this.membershipsByRole),const DeepCollectionEquality().hash(_this.usersByTeamCount));
}

@override
String toString() {
  final _this = this as AdminTeamStatsDto;
  return 'AdminTeamStatsDto(active: ${_this.active}, deleted: ${_this.deleted}, byTier: ${_this.byTier}, membershipsByRole: ${_this.membershipsByRole}, usersByTeamCount: ${_this.usersByTeamCount})';
}


}

/// @nodoc
abstract mixin class $AdminTeamStatsDtoCopyWith<$Res>  {
  factory $AdminTeamStatsDtoCopyWith(AdminTeamStatsDto value, $Res Function(AdminTeamStatsDto) _then) = _$AdminTeamStatsDtoCopyWithImpl;
@useResult
$Res call({
 int active, int deleted, List<AdminKeyCountDto> byTier, List<AdminKeyCountDto> membershipsByRole, List<AdminKeyCountDto> usersByTeamCount
});




}
/// @nodoc
class _$AdminTeamStatsDtoCopyWithImpl<$Res>
    implements $AdminTeamStatsDtoCopyWith<$Res> {
  _$AdminTeamStatsDtoCopyWithImpl(this._self, this._then);

  final AdminTeamStatsDto _self;
  final $Res Function(AdminTeamStatsDto) _then;

/// Create a copy of AdminTeamStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? active = null,Object? deleted = null,Object? byTier = null,Object? membershipsByRole = null,Object? usersByTeamCount = null,}) {
  return _then(AdminTeamStatsDto(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as int,byTier: null == byTier ? _self.byTier : byTier // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,membershipsByRole: null == membershipsByRole ? _self.membershipsByRole : membershipsByRole // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,usersByTeamCount: null == usersByTeamCount ? _self.usersByTeamCount : usersByTeamCount // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminTeamStatsDto].
extension AdminTeamStatsDtoPatterns on AdminTeamStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminTeamStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminTeamStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminTeamStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminTeamStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminTeamStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminTeamStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int active,  int deleted,  List<AdminKeyCountDto> byTier,  List<AdminKeyCountDto> membershipsByRole,  List<AdminKeyCountDto> usersByTeamCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminTeamStatsDto() when $default != null:
return $default(_that.active,_that.deleted,_that.byTier,_that.membershipsByRole,_that.usersByTeamCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int active,  int deleted,  List<AdminKeyCountDto> byTier,  List<AdminKeyCountDto> membershipsByRole,  List<AdminKeyCountDto> usersByTeamCount)  $default,) {final _that = this;
switch (_that) {
case _AdminTeamStatsDto():
return $default(_that.active,_that.deleted,_that.byTier,_that.membershipsByRole,_that.usersByTeamCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int active,  int deleted,  List<AdminKeyCountDto> byTier,  List<AdminKeyCountDto> membershipsByRole,  List<AdminKeyCountDto> usersByTeamCount)?  $default,) {final _that = this;
switch (_that) {
case _AdminTeamStatsDto() when $default != null:
return $default(_that.active,_that.deleted,_that.byTier,_that.membershipsByRole,_that.usersByTeamCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminTeamStatsDto implements AdminTeamStatsDto {
  const _AdminTeamStatsDto({required this.active, required this.deleted, required  List<AdminKeyCountDto> byTier, required  List<AdminKeyCountDto> membershipsByRole, required  List<AdminKeyCountDto> usersByTeamCount}): _byTier = byTier,_membershipsByRole = membershipsByRole,_usersByTeamCount = usersByTeamCount;
  factory _AdminTeamStatsDto.fromJson(Map<String, dynamic> json) => _$AdminTeamStatsDtoFromJson(json);

/// Teams that are not deleted
@override final  int active;
/// Teams deleted
@override final  int deleted;
/// Active teams per plan (FREE, UNLOCKED…)
 final  List<AdminKeyCountDto> _byTier;
/// Active teams per plan (FREE, UNLOCKED…)
@override List<AdminKeyCountDto> get byTier {
  if (_byTier is EqualUnmodifiableListView) return _byTier;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_byTier);
}

/// Memberships per role (MEMBER, ORGANIZER, ADMIN), active teams and accounts that are not deleted
 final  List<AdminKeyCountDto> _membershipsByRole;
/// Memberships per role (MEMBER, ORGANIZER, ADMIN), active teams and accounts that are not deleted
@override List<AdminKeyCountDto> get membershipsByRole {
  if (_membershipsByRole is EqualUnmodifiableListView) return _membershipsByRole;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_membershipsByRole);
}

/// Accounts that are not deleted per number of active teams they belong to: keys "0", "1", "2", "3+"
 final  List<AdminKeyCountDto> _usersByTeamCount;
/// Accounts that are not deleted per number of active teams they belong to: keys "0", "1", "2", "3+"
@override List<AdminKeyCountDto> get usersByTeamCount {
  if (_usersByTeamCount is EqualUnmodifiableListView) return _usersByTeamCount;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usersByTeamCount);
}


/// Create a copy of AdminTeamStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminTeamStatsDtoCopyWith<_AdminTeamStatsDto> get copyWith => __$AdminTeamStatsDtoCopyWithImpl<_AdminTeamStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminTeamStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminTeamStatsDto&&(identical(other.active, active) || other.active == active)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&const DeepCollectionEquality().equals(other.byTier, _byTier)&&const DeepCollectionEquality().equals(other.membershipsByRole, _membershipsByRole)&&const DeepCollectionEquality().equals(other.usersByTeamCount, _usersByTeamCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,active,deleted,const DeepCollectionEquality().hash(_byTier),const DeepCollectionEquality().hash(_membershipsByRole),const DeepCollectionEquality().hash(_usersByTeamCount));
}

@override
String toString() {
    return 'AdminTeamStatsDto(active: $active, deleted: $deleted, byTier: $byTier, membershipsByRole: $membershipsByRole, usersByTeamCount: $usersByTeamCount)';
}


}

/// @nodoc
abstract mixin class _$AdminTeamStatsDtoCopyWith<$Res> implements $AdminTeamStatsDtoCopyWith<$Res> {
  factory _$AdminTeamStatsDtoCopyWith(_AdminTeamStatsDto value, $Res Function(_AdminTeamStatsDto) _then) = __$AdminTeamStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 int active, int deleted, List<AdminKeyCountDto> byTier, List<AdminKeyCountDto> membershipsByRole, List<AdminKeyCountDto> usersByTeamCount
});




}
/// @nodoc
class __$AdminTeamStatsDtoCopyWithImpl<$Res>
    implements _$AdminTeamStatsDtoCopyWith<$Res> {
  __$AdminTeamStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminTeamStatsDto _self;
  final $Res Function(_AdminTeamStatsDto) _then;

/// Create a copy of AdminTeamStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? active = null,Object? deleted = null,Object? byTier = null,Object? membershipsByRole = null,Object? usersByTeamCount = null,}) {
  return _then(_AdminTeamStatsDto(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as int,byTier: null == byTier ? _self._byTier : byTier // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,membershipsByRole: null == membershipsByRole ? _self._membershipsByRole : membershipsByRole // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,usersByTeamCount: null == usersByTeamCount ? _self._usersByTeamCount : usersByTeamCount // ignore: cast_nullable_to_non_nullable
as List<AdminKeyCountDto>,
  ));
}


}

// dart format on
