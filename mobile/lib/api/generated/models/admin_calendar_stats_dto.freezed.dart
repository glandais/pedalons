// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_calendar_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminCalendarStatsDto {

/// Feeds created
 int get tokens;/// Feeds fetched at least once
 int get usedEver;/// Feeds fetched during the last 7 days
 int get usedLast7Days;
/// Create a copy of AdminCalendarStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminCalendarStatsDtoCopyWith<AdminCalendarStatsDto> get copyWith => _$AdminCalendarStatsDtoCopyWithImpl<AdminCalendarStatsDto>(this as AdminCalendarStatsDto, _$identity);

  /// Serializes this AdminCalendarStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminCalendarStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminCalendarStatsDto&&(identical(other.tokens, _this.tokens) || other.tokens == _this.tokens)&&(identical(other.usedEver, _this.usedEver) || other.usedEver == _this.usedEver)&&(identical(other.usedLast7Days, _this.usedLast7Days) || other.usedLast7Days == _this.usedLast7Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminCalendarStatsDto;
  return Object.hash(runtimeType,_this.tokens,_this.usedEver,_this.usedLast7Days);
}

@override
String toString() {
  final _this = this as AdminCalendarStatsDto;
  return 'AdminCalendarStatsDto(tokens: ${_this.tokens}, usedEver: ${_this.usedEver}, usedLast7Days: ${_this.usedLast7Days})';
}


}

/// @nodoc
abstract mixin class $AdminCalendarStatsDtoCopyWith<$Res>  {
  factory $AdminCalendarStatsDtoCopyWith(AdminCalendarStatsDto value, $Res Function(AdminCalendarStatsDto) _then) = _$AdminCalendarStatsDtoCopyWithImpl;
@useResult
$Res call({
 int tokens, int usedEver, int usedLast7Days
});




}
/// @nodoc
class _$AdminCalendarStatsDtoCopyWithImpl<$Res>
    implements $AdminCalendarStatsDtoCopyWith<$Res> {
  _$AdminCalendarStatsDtoCopyWithImpl(this._self, this._then);

  final AdminCalendarStatsDto _self;
  final $Res Function(AdminCalendarStatsDto) _then;

/// Create a copy of AdminCalendarStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tokens = null,Object? usedEver = null,Object? usedLast7Days = null,}) {
  return _then(AdminCalendarStatsDto(
tokens: null == tokens ? _self.tokens : tokens // ignore: cast_nullable_to_non_nullable
as int,usedEver: null == usedEver ? _self.usedEver : usedEver // ignore: cast_nullable_to_non_nullable
as int,usedLast7Days: null == usedLast7Days ? _self.usedLast7Days : usedLast7Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminCalendarStatsDto].
extension AdminCalendarStatsDtoPatterns on AdminCalendarStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminCalendarStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminCalendarStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminCalendarStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminCalendarStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminCalendarStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminCalendarStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int tokens,  int usedEver,  int usedLast7Days)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminCalendarStatsDto() when $default != null:
return $default(_that.tokens,_that.usedEver,_that.usedLast7Days);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int tokens,  int usedEver,  int usedLast7Days)  $default,) {final _that = this;
switch (_that) {
case _AdminCalendarStatsDto():
return $default(_that.tokens,_that.usedEver,_that.usedLast7Days);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int tokens,  int usedEver,  int usedLast7Days)?  $default,) {final _that = this;
switch (_that) {
case _AdminCalendarStatsDto() when $default != null:
return $default(_that.tokens,_that.usedEver,_that.usedLast7Days);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminCalendarStatsDto implements AdminCalendarStatsDto {
  const _AdminCalendarStatsDto({required this.tokens, required this.usedEver, required this.usedLast7Days});
  factory _AdminCalendarStatsDto.fromJson(Map<String, dynamic> json) => _$AdminCalendarStatsDtoFromJson(json);

/// Feeds created
@override final  int tokens;
/// Feeds fetched at least once
@override final  int usedEver;
/// Feeds fetched during the last 7 days
@override final  int usedLast7Days;

/// Create a copy of AdminCalendarStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminCalendarStatsDtoCopyWith<_AdminCalendarStatsDto> get copyWith => __$AdminCalendarStatsDtoCopyWithImpl<_AdminCalendarStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminCalendarStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminCalendarStatsDto&&(identical(other.tokens, tokens) || other.tokens == tokens)&&(identical(other.usedEver, usedEver) || other.usedEver == usedEver)&&(identical(other.usedLast7Days, usedLast7Days) || other.usedLast7Days == usedLast7Days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,tokens,usedEver,usedLast7Days);
}

@override
String toString() {
    return 'AdminCalendarStatsDto(tokens: $tokens, usedEver: $usedEver, usedLast7Days: $usedLast7Days)';
}


}

/// @nodoc
abstract mixin class _$AdminCalendarStatsDtoCopyWith<$Res> implements $AdminCalendarStatsDtoCopyWith<$Res> {
  factory _$AdminCalendarStatsDtoCopyWith(_AdminCalendarStatsDto value, $Res Function(_AdminCalendarStatsDto) _then) = __$AdminCalendarStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 int tokens, int usedEver, int usedLast7Days
});




}
/// @nodoc
class __$AdminCalendarStatsDtoCopyWithImpl<$Res>
    implements _$AdminCalendarStatsDtoCopyWith<$Res> {
  __$AdminCalendarStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminCalendarStatsDto _self;
  final $Res Function(_AdminCalendarStatsDto) _then;

/// Create a copy of AdminCalendarStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tokens = null,Object? usedEver = null,Object? usedLast7Days = null,}) {
  return _then(_AdminCalendarStatsDto(
tokens: null == tokens ? _self.tokens : tokens // ignore: cast_nullable_to_non_nullable
as int,usedEver: null == usedEver ? _self.usedEver : usedEver // ignore: cast_nullable_to_non_nullable
as int,usedLast7Days: null == usedLast7Days ? _self.usedLast7Days : usedLast7Days // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
