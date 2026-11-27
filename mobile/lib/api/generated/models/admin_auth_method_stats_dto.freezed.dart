// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_auth_method_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminAuthMethodStatsDto {

/// A password and no passkey
 int get passwordOnly;/// A passkey and no password
 int get passkeyOnly;/// A password and a passkey
 int get passwordAndPasskey;/// Neither: one-time code sent by e-mail only
 int get neither;
/// Create a copy of AdminAuthMethodStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminAuthMethodStatsDtoCopyWith<AdminAuthMethodStatsDto> get copyWith => _$AdminAuthMethodStatsDtoCopyWithImpl<AdminAuthMethodStatsDto>(this as AdminAuthMethodStatsDto, _$identity);

  /// Serializes this AdminAuthMethodStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminAuthMethodStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminAuthMethodStatsDto&&(identical(other.passwordOnly, _this.passwordOnly) || other.passwordOnly == _this.passwordOnly)&&(identical(other.passkeyOnly, _this.passkeyOnly) || other.passkeyOnly == _this.passkeyOnly)&&(identical(other.passwordAndPasskey, _this.passwordAndPasskey) || other.passwordAndPasskey == _this.passwordAndPasskey)&&(identical(other.neither, _this.neither) || other.neither == _this.neither));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminAuthMethodStatsDto;
  return Object.hash(runtimeType,_this.passwordOnly,_this.passkeyOnly,_this.passwordAndPasskey,_this.neither);
}

@override
String toString() {
  final _this = this as AdminAuthMethodStatsDto;
  return 'AdminAuthMethodStatsDto(passwordOnly: ${_this.passwordOnly}, passkeyOnly: ${_this.passkeyOnly}, passwordAndPasskey: ${_this.passwordAndPasskey}, neither: ${_this.neither})';
}


}

/// @nodoc
abstract mixin class $AdminAuthMethodStatsDtoCopyWith<$Res>  {
  factory $AdminAuthMethodStatsDtoCopyWith(AdminAuthMethodStatsDto value, $Res Function(AdminAuthMethodStatsDto) _then) = _$AdminAuthMethodStatsDtoCopyWithImpl;
@useResult
$Res call({
 int passwordOnly, int passkeyOnly, int passwordAndPasskey, int neither
});




}
/// @nodoc
class _$AdminAuthMethodStatsDtoCopyWithImpl<$Res>
    implements $AdminAuthMethodStatsDtoCopyWith<$Res> {
  _$AdminAuthMethodStatsDtoCopyWithImpl(this._self, this._then);

  final AdminAuthMethodStatsDto _self;
  final $Res Function(AdminAuthMethodStatsDto) _then;

/// Create a copy of AdminAuthMethodStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? passwordOnly = null,Object? passkeyOnly = null,Object? passwordAndPasskey = null,Object? neither = null,}) {
  return _then(AdminAuthMethodStatsDto(
passwordOnly: null == passwordOnly ? _self.passwordOnly : passwordOnly // ignore: cast_nullable_to_non_nullable
as int,passkeyOnly: null == passkeyOnly ? _self.passkeyOnly : passkeyOnly // ignore: cast_nullable_to_non_nullable
as int,passwordAndPasskey: null == passwordAndPasskey ? _self.passwordAndPasskey : passwordAndPasskey // ignore: cast_nullable_to_non_nullable
as int,neither: null == neither ? _self.neither : neither // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminAuthMethodStatsDto].
extension AdminAuthMethodStatsDtoPatterns on AdminAuthMethodStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminAuthMethodStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminAuthMethodStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminAuthMethodStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminAuthMethodStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminAuthMethodStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminAuthMethodStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int passwordOnly,  int passkeyOnly,  int passwordAndPasskey,  int neither)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminAuthMethodStatsDto() when $default != null:
return $default(_that.passwordOnly,_that.passkeyOnly,_that.passwordAndPasskey,_that.neither);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int passwordOnly,  int passkeyOnly,  int passwordAndPasskey,  int neither)  $default,) {final _that = this;
switch (_that) {
case _AdminAuthMethodStatsDto():
return $default(_that.passwordOnly,_that.passkeyOnly,_that.passwordAndPasskey,_that.neither);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int passwordOnly,  int passkeyOnly,  int passwordAndPasskey,  int neither)?  $default,) {final _that = this;
switch (_that) {
case _AdminAuthMethodStatsDto() when $default != null:
return $default(_that.passwordOnly,_that.passkeyOnly,_that.passwordAndPasskey,_that.neither);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminAuthMethodStatsDto implements AdminAuthMethodStatsDto {
  const _AdminAuthMethodStatsDto({required this.passwordOnly, required this.passkeyOnly, required this.passwordAndPasskey, required this.neither});
  factory _AdminAuthMethodStatsDto.fromJson(Map<String, dynamic> json) => _$AdminAuthMethodStatsDtoFromJson(json);

/// A password and no passkey
@override final  int passwordOnly;
/// A passkey and no password
@override final  int passkeyOnly;
/// A password and a passkey
@override final  int passwordAndPasskey;
/// Neither: one-time code sent by e-mail only
@override final  int neither;

/// Create a copy of AdminAuthMethodStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminAuthMethodStatsDtoCopyWith<_AdminAuthMethodStatsDto> get copyWith => __$AdminAuthMethodStatsDtoCopyWithImpl<_AdminAuthMethodStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminAuthMethodStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminAuthMethodStatsDto&&(identical(other.passwordOnly, passwordOnly) || other.passwordOnly == passwordOnly)&&(identical(other.passkeyOnly, passkeyOnly) || other.passkeyOnly == passkeyOnly)&&(identical(other.passwordAndPasskey, passwordAndPasskey) || other.passwordAndPasskey == passwordAndPasskey)&&(identical(other.neither, neither) || other.neither == neither));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,passwordOnly,passkeyOnly,passwordAndPasskey,neither);
}

@override
String toString() {
    return 'AdminAuthMethodStatsDto(passwordOnly: $passwordOnly, passkeyOnly: $passkeyOnly, passwordAndPasskey: $passwordAndPasskey, neither: $neither)';
}


}

/// @nodoc
abstract mixin class _$AdminAuthMethodStatsDtoCopyWith<$Res> implements $AdminAuthMethodStatsDtoCopyWith<$Res> {
  factory _$AdminAuthMethodStatsDtoCopyWith(_AdminAuthMethodStatsDto value, $Res Function(_AdminAuthMethodStatsDto) _then) = __$AdminAuthMethodStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 int passwordOnly, int passkeyOnly, int passwordAndPasskey, int neither
});




}
/// @nodoc
class __$AdminAuthMethodStatsDtoCopyWithImpl<$Res>
    implements _$AdminAuthMethodStatsDtoCopyWith<$Res> {
  __$AdminAuthMethodStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminAuthMethodStatsDto _self;
  final $Res Function(_AdminAuthMethodStatsDto) _then;

/// Create a copy of AdminAuthMethodStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? passwordOnly = null,Object? passkeyOnly = null,Object? passwordAndPasskey = null,Object? neither = null,}) {
  return _then(_AdminAuthMethodStatsDto(
passwordOnly: null == passwordOnly ? _self.passwordOnly : passwordOnly // ignore: cast_nullable_to_non_nullable
as int,passkeyOnly: null == passkeyOnly ? _self.passkeyOnly : passkeyOnly // ignore: cast_nullable_to_non_nullable
as int,passwordAndPasskey: null == passwordAndPasskey ? _self.passwordAndPasskey : passwordAndPasskey // ignore: cast_nullable_to_non_nullable
as int,neither: null == neither ? _self.neither : neither // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
