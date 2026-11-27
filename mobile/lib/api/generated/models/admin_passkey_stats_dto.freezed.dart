// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_passkey_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminPasskeyStatsDto {

/// Passkeys registered
 int get total;/// Passkeys used during the last 30 days
 int get usedLast30Days;
/// Create a copy of AdminPasskeyStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminPasskeyStatsDtoCopyWith<AdminPasskeyStatsDto> get copyWith => _$AdminPasskeyStatsDtoCopyWithImpl<AdminPasskeyStatsDto>(this as AdminPasskeyStatsDto, _$identity);

  /// Serializes this AdminPasskeyStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminPasskeyStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminPasskeyStatsDto&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.usedLast30Days, _this.usedLast30Days) || other.usedLast30Days == _this.usedLast30Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminPasskeyStatsDto;
  return Object.hash(runtimeType,_this.total,_this.usedLast30Days);
}

@override
String toString() {
  final _this = this as AdminPasskeyStatsDto;
  return 'AdminPasskeyStatsDto(total: ${_this.total}, usedLast30Days: ${_this.usedLast30Days})';
}


}

/// @nodoc
abstract mixin class $AdminPasskeyStatsDtoCopyWith<$Res>  {
  factory $AdminPasskeyStatsDtoCopyWith(AdminPasskeyStatsDto value, $Res Function(AdminPasskeyStatsDto) _then) = _$AdminPasskeyStatsDtoCopyWithImpl;
@useResult
$Res call({
 int total, int usedLast30Days
});




}
/// @nodoc
class _$AdminPasskeyStatsDtoCopyWithImpl<$Res>
    implements $AdminPasskeyStatsDtoCopyWith<$Res> {
  _$AdminPasskeyStatsDtoCopyWithImpl(this._self, this._then);

  final AdminPasskeyStatsDto _self;
  final $Res Function(AdminPasskeyStatsDto) _then;

/// Create a copy of AdminPasskeyStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? usedLast30Days = null,}) {
  return _then(AdminPasskeyStatsDto(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,usedLast30Days: null == usedLast30Days ? _self.usedLast30Days : usedLast30Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminPasskeyStatsDto].
extension AdminPasskeyStatsDtoPatterns on AdminPasskeyStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminPasskeyStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminPasskeyStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminPasskeyStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminPasskeyStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminPasskeyStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminPasskeyStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int total,  int usedLast30Days)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminPasskeyStatsDto() when $default != null:
return $default(_that.total,_that.usedLast30Days);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int total,  int usedLast30Days)  $default,) {final _that = this;
switch (_that) {
case _AdminPasskeyStatsDto():
return $default(_that.total,_that.usedLast30Days);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int total,  int usedLast30Days)?  $default,) {final _that = this;
switch (_that) {
case _AdminPasskeyStatsDto() when $default != null:
return $default(_that.total,_that.usedLast30Days);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminPasskeyStatsDto implements AdminPasskeyStatsDto {
  const _AdminPasskeyStatsDto({required this.total, required this.usedLast30Days});
  factory _AdminPasskeyStatsDto.fromJson(Map<String, dynamic> json) => _$AdminPasskeyStatsDtoFromJson(json);

/// Passkeys registered
@override final  int total;
/// Passkeys used during the last 30 days
@override final  int usedLast30Days;

/// Create a copy of AdminPasskeyStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminPasskeyStatsDtoCopyWith<_AdminPasskeyStatsDto> get copyWith => __$AdminPasskeyStatsDtoCopyWithImpl<_AdminPasskeyStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminPasskeyStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminPasskeyStatsDto&&(identical(other.total, total) || other.total == total)&&(identical(other.usedLast30Days, usedLast30Days) || other.usedLast30Days == usedLast30Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,total,usedLast30Days);
}

@override
String toString() {
    return 'AdminPasskeyStatsDto(total: $total, usedLast30Days: $usedLast30Days)';
}


}

/// @nodoc
abstract mixin class _$AdminPasskeyStatsDtoCopyWith<$Res> implements $AdminPasskeyStatsDtoCopyWith<$Res> {
  factory _$AdminPasskeyStatsDtoCopyWith(_AdminPasskeyStatsDto value, $Res Function(_AdminPasskeyStatsDto) _then) = __$AdminPasskeyStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 int total, int usedLast30Days
});




}
/// @nodoc
class __$AdminPasskeyStatsDtoCopyWithImpl<$Res>
    implements _$AdminPasskeyStatsDtoCopyWith<$Res> {
  __$AdminPasskeyStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminPasskeyStatsDto _self;
  final $Res Function(_AdminPasskeyStatsDto) _then;

/// Create a copy of AdminPasskeyStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? usedLast30Days = null,}) {
  return _then(_AdminPasskeyStatsDto(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,usedLast30Days: null == usedLast30Days ? _self.usedLast30Days : usedLast30Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
