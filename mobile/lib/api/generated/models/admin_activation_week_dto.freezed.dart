// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_activation_week_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminActivationWeekDto {

/// Domain ID (TSID)
 String get domainId;/// Domain name
 String get domainName;/// Monday of the sign-up week (ISO week, UTC)
 String get weekStart;/// Whether every account of the week has had its 7 days: the counts of a week that is not complete can still grow
 bool get complete;/// Accounts created that week, deleted ones left out
 int get signedUp;/// Of those, accounts whose address is verified
 int get verified;/// Of those, accounts that joined a team (or created one) within 7 days of their creation, and still belong to it
 int get joinedTeam;/// Of those, accounts that signed up to a ride within 7 days of their creation, and are still signed up
 int get joinedRide;
/// Create a copy of AdminActivationWeekDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminActivationWeekDtoCopyWith<AdminActivationWeekDto> get copyWith => _$AdminActivationWeekDtoCopyWithImpl<AdminActivationWeekDto>(this as AdminActivationWeekDto, _$identity);

  /// Serializes this AdminActivationWeekDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminActivationWeekDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminActivationWeekDto&&(identical(other.domainId, _this.domainId) || other.domainId == _this.domainId)&&(identical(other.domainName, _this.domainName) || other.domainName == _this.domainName)&&(identical(other.weekStart, _this.weekStart) || other.weekStart == _this.weekStart)&&(identical(other.complete, _this.complete) || other.complete == _this.complete)&&(identical(other.signedUp, _this.signedUp) || other.signedUp == _this.signedUp)&&(identical(other.verified, _this.verified) || other.verified == _this.verified)&&(identical(other.joinedTeam, _this.joinedTeam) || other.joinedTeam == _this.joinedTeam)&&(identical(other.joinedRide, _this.joinedRide) || other.joinedRide == _this.joinedRide));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminActivationWeekDto;
  return Object.hash(runtimeType,_this.domainId,_this.domainName,_this.weekStart,_this.complete,_this.signedUp,_this.verified,_this.joinedTeam,_this.joinedRide);
}

@override
String toString() {
  final _this = this as AdminActivationWeekDto;
  return 'AdminActivationWeekDto(domainId: ${_this.domainId}, domainName: ${_this.domainName}, weekStart: ${_this.weekStart}, complete: ${_this.complete}, signedUp: ${_this.signedUp}, verified: ${_this.verified}, joinedTeam: ${_this.joinedTeam}, joinedRide: ${_this.joinedRide})';
}


}

/// @nodoc
abstract mixin class $AdminActivationWeekDtoCopyWith<$Res>  {
  factory $AdminActivationWeekDtoCopyWith(AdminActivationWeekDto value, $Res Function(AdminActivationWeekDto) _then) = _$AdminActivationWeekDtoCopyWithImpl;
@useResult
$Res call({
 String domainId, String domainName, String weekStart, bool complete, int signedUp, int verified, int joinedTeam, int joinedRide
});




}
/// @nodoc
class _$AdminActivationWeekDtoCopyWithImpl<$Res>
    implements $AdminActivationWeekDtoCopyWith<$Res> {
  _$AdminActivationWeekDtoCopyWithImpl(this._self, this._then);

  final AdminActivationWeekDto _self;
  final $Res Function(AdminActivationWeekDto) _then;

/// Create a copy of AdminActivationWeekDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? domainId = null,Object? domainName = null,Object? weekStart = null,Object? complete = null,Object? signedUp = null,Object? verified = null,Object? joinedTeam = null,Object? joinedRide = null,}) {
  return _then(AdminActivationWeekDto(
domainId: null == domainId ? _self.domainId : domainId // ignore: cast_nullable_to_non_nullable
as String,domainName: null == domainName ? _self.domainName : domainName // ignore: cast_nullable_to_non_nullable
as String,weekStart: null == weekStart ? _self.weekStart : weekStart // ignore: cast_nullable_to_non_nullable
as String,complete: null == complete ? _self.complete : complete // ignore: cast_nullable_to_non_nullable
as bool,signedUp: null == signedUp ? _self.signedUp : signedUp // ignore: cast_nullable_to_non_nullable
as int,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as int,joinedTeam: null == joinedTeam ? _self.joinedTeam : joinedTeam // ignore: cast_nullable_to_non_nullable
as int,joinedRide: null == joinedRide ? _self.joinedRide : joinedRide // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminActivationWeekDto].
extension AdminActivationWeekDtoPatterns on AdminActivationWeekDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminActivationWeekDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminActivationWeekDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminActivationWeekDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminActivationWeekDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminActivationWeekDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminActivationWeekDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String domainId,  String domainName,  String weekStart,  bool complete,  int signedUp,  int verified,  int joinedTeam,  int joinedRide)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminActivationWeekDto() when $default != null:
return $default(_that.domainId,_that.domainName,_that.weekStart,_that.complete,_that.signedUp,_that.verified,_that.joinedTeam,_that.joinedRide);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String domainId,  String domainName,  String weekStart,  bool complete,  int signedUp,  int verified,  int joinedTeam,  int joinedRide)  $default,) {final _that = this;
switch (_that) {
case _AdminActivationWeekDto():
return $default(_that.domainId,_that.domainName,_that.weekStart,_that.complete,_that.signedUp,_that.verified,_that.joinedTeam,_that.joinedRide);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String domainId,  String domainName,  String weekStart,  bool complete,  int signedUp,  int verified,  int joinedTeam,  int joinedRide)?  $default,) {final _that = this;
switch (_that) {
case _AdminActivationWeekDto() when $default != null:
return $default(_that.domainId,_that.domainName,_that.weekStart,_that.complete,_that.signedUp,_that.verified,_that.joinedTeam,_that.joinedRide);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminActivationWeekDto implements AdminActivationWeekDto {
  const _AdminActivationWeekDto({required this.domainId, required this.domainName, required this.weekStart, required this.complete, required this.signedUp, required this.verified, required this.joinedTeam, required this.joinedRide});
  factory _AdminActivationWeekDto.fromJson(Map<String, dynamic> json) => _$AdminActivationWeekDtoFromJson(json);

/// Domain ID (TSID)
@override final  String domainId;
/// Domain name
@override final  String domainName;
/// Monday of the sign-up week (ISO week, UTC)
@override final  String weekStart;
/// Whether every account of the week has had its 7 days: the counts of a week that is not complete can still grow
@override final  bool complete;
/// Accounts created that week, deleted ones left out
@override final  int signedUp;
/// Of those, accounts whose address is verified
@override final  int verified;
/// Of those, accounts that joined a team (or created one) within 7 days of their creation, and still belong to it
@override final  int joinedTeam;
/// Of those, accounts that signed up to a ride within 7 days of their creation, and are still signed up
@override final  int joinedRide;

/// Create a copy of AdminActivationWeekDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminActivationWeekDtoCopyWith<_AdminActivationWeekDto> get copyWith => __$AdminActivationWeekDtoCopyWithImpl<_AdminActivationWeekDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminActivationWeekDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminActivationWeekDto&&(identical(other.domainId, domainId) || other.domainId == domainId)&&(identical(other.domainName, domainName) || other.domainName == domainName)&&(identical(other.weekStart, weekStart) || other.weekStart == weekStart)&&(identical(other.complete, complete) || other.complete == complete)&&(identical(other.signedUp, signedUp) || other.signedUp == signedUp)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.joinedTeam, joinedTeam) || other.joinedTeam == joinedTeam)&&(identical(other.joinedRide, joinedRide) || other.joinedRide == joinedRide));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,domainId,domainName,weekStart,complete,signedUp,verified,joinedTeam,joinedRide);
}

@override
String toString() {
    return 'AdminActivationWeekDto(domainId: $domainId, domainName: $domainName, weekStart: $weekStart, complete: $complete, signedUp: $signedUp, verified: $verified, joinedTeam: $joinedTeam, joinedRide: $joinedRide)';
}


}

/// @nodoc
abstract mixin class _$AdminActivationWeekDtoCopyWith<$Res> implements $AdminActivationWeekDtoCopyWith<$Res> {
  factory _$AdminActivationWeekDtoCopyWith(_AdminActivationWeekDto value, $Res Function(_AdminActivationWeekDto) _then) = __$AdminActivationWeekDtoCopyWithImpl;
@override @useResult
$Res call({
 String domainId, String domainName, String weekStart, bool complete, int signedUp, int verified, int joinedTeam, int joinedRide
});




}
/// @nodoc
class __$AdminActivationWeekDtoCopyWithImpl<$Res>
    implements _$AdminActivationWeekDtoCopyWith<$Res> {
  __$AdminActivationWeekDtoCopyWithImpl(this._self, this._then);

  final _AdminActivationWeekDto _self;
  final $Res Function(_AdminActivationWeekDto) _then;

/// Create a copy of AdminActivationWeekDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? domainId = null,Object? domainName = null,Object? weekStart = null,Object? complete = null,Object? signedUp = null,Object? verified = null,Object? joinedTeam = null,Object? joinedRide = null,}) {
  return _then(_AdminActivationWeekDto(
domainId: null == domainId ? _self.domainId : domainId // ignore: cast_nullable_to_non_nullable
as String,domainName: null == domainName ? _self.domainName : domainName // ignore: cast_nullable_to_non_nullable
as String,weekStart: null == weekStart ? _self.weekStart : weekStart // ignore: cast_nullable_to_non_nullable
as String,complete: null == complete ? _self.complete : complete // ignore: cast_nullable_to_non_nullable
as bool,signedUp: null == signedUp ? _self.signedUp : signedUp // ignore: cast_nullable_to_non_nullable
as int,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as int,joinedTeam: null == joinedTeam ? _self.joinedTeam : joinedTeam // ignore: cast_nullable_to_non_nullable
as int,joinedRide: null == joinedRide ? _self.joinedRide : joinedRide // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
