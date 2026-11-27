// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_month_count_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminMonthCountDto {

/// Calendar month, YYYY-MM (UTC)
 String get month;/// How many
 int get count;
/// Create a copy of AdminMonthCountDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminMonthCountDtoCopyWith<AdminMonthCountDto> get copyWith => _$AdminMonthCountDtoCopyWithImpl<AdminMonthCountDto>(this as AdminMonthCountDto, _$identity);

  /// Serializes this AdminMonthCountDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminMonthCountDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminMonthCountDto&&(identical(other.month, _this.month) || other.month == _this.month)&&(identical(other.count, _this.count) || other.count == _this.count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminMonthCountDto;
  return Object.hash(runtimeType,_this.month,_this.count);
}

@override
String toString() {
  final _this = this as AdminMonthCountDto;
  return 'AdminMonthCountDto(month: ${_this.month}, count: ${_this.count})';
}


}

/// @nodoc
abstract mixin class $AdminMonthCountDtoCopyWith<$Res>  {
  factory $AdminMonthCountDtoCopyWith(AdminMonthCountDto value, $Res Function(AdminMonthCountDto) _then) = _$AdminMonthCountDtoCopyWithImpl;
@useResult
$Res call({
 String month, int count
});




}
/// @nodoc
class _$AdminMonthCountDtoCopyWithImpl<$Res>
    implements $AdminMonthCountDtoCopyWith<$Res> {
  _$AdminMonthCountDtoCopyWithImpl(this._self, this._then);

  final AdminMonthCountDto _self;
  final $Res Function(AdminMonthCountDto) _then;

/// Create a copy of AdminMonthCountDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? month = null,Object? count = null,}) {
  return _then(AdminMonthCountDto(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminMonthCountDto].
extension AdminMonthCountDtoPatterns on AdminMonthCountDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminMonthCountDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminMonthCountDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminMonthCountDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminMonthCountDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminMonthCountDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminMonthCountDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String month,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminMonthCountDto() when $default != null:
return $default(_that.month,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String month,  int count)  $default,) {final _that = this;
switch (_that) {
case _AdminMonthCountDto():
return $default(_that.month,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String month,  int count)?  $default,) {final _that = this;
switch (_that) {
case _AdminMonthCountDto() when $default != null:
return $default(_that.month,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminMonthCountDto implements AdminMonthCountDto {
  const _AdminMonthCountDto({required this.month, required this.count});
  factory _AdminMonthCountDto.fromJson(Map<String, dynamic> json) => _$AdminMonthCountDtoFromJson(json);

/// Calendar month, YYYY-MM (UTC)
@override final  String month;
/// How many
@override final  int count;

/// Create a copy of AdminMonthCountDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminMonthCountDtoCopyWith<_AdminMonthCountDto> get copyWith => __$AdminMonthCountDtoCopyWithImpl<_AdminMonthCountDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminMonthCountDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminMonthCountDto&&(identical(other.month, month) || other.month == month)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,month,count);
}

@override
String toString() {
    return 'AdminMonthCountDto(month: $month, count: $count)';
}


}

/// @nodoc
abstract mixin class _$AdminMonthCountDtoCopyWith<$Res> implements $AdminMonthCountDtoCopyWith<$Res> {
  factory _$AdminMonthCountDtoCopyWith(_AdminMonthCountDto value, $Res Function(_AdminMonthCountDto) _then) = __$AdminMonthCountDtoCopyWithImpl;
@override @useResult
$Res call({
 String month, int count
});




}
/// @nodoc
class __$AdminMonthCountDtoCopyWithImpl<$Res>
    implements _$AdminMonthCountDtoCopyWith<$Res> {
  __$AdminMonthCountDtoCopyWithImpl(this._self, this._then);

  final _AdminMonthCountDto _self;
  final $Res Function(_AdminMonthCountDto) _then;

/// Create a copy of AdminMonthCountDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? month = null,Object? count = null,}) {
  return _then(_AdminMonthCountDto(
month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
