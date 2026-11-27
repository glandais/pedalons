// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_key_count_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminKeyCountDto {

/// What is counted
 String get key;/// How many
 int get count;
/// Create a copy of AdminKeyCountDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminKeyCountDtoCopyWith<AdminKeyCountDto> get copyWith => _$AdminKeyCountDtoCopyWithImpl<AdminKeyCountDto>(this as AdminKeyCountDto, _$identity);

  /// Serializes this AdminKeyCountDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminKeyCountDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminKeyCountDto&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.count, _this.count) || other.count == _this.count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminKeyCountDto;
  return Object.hash(runtimeType,_this.key,_this.count);
}

@override
String toString() {
  final _this = this as AdminKeyCountDto;
  return 'AdminKeyCountDto(key: ${_this.key}, count: ${_this.count})';
}


}

/// @nodoc
abstract mixin class $AdminKeyCountDtoCopyWith<$Res>  {
  factory $AdminKeyCountDtoCopyWith(AdminKeyCountDto value, $Res Function(AdminKeyCountDto) _then) = _$AdminKeyCountDtoCopyWithImpl;
@useResult
$Res call({
 String key, int count
});




}
/// @nodoc
class _$AdminKeyCountDtoCopyWithImpl<$Res>
    implements $AdminKeyCountDtoCopyWith<$Res> {
  _$AdminKeyCountDtoCopyWithImpl(this._self, this._then);

  final AdminKeyCountDto _self;
  final $Res Function(AdminKeyCountDto) _then;

/// Create a copy of AdminKeyCountDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? count = null,}) {
  return _then(AdminKeyCountDto(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminKeyCountDto].
extension AdminKeyCountDtoPatterns on AdminKeyCountDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminKeyCountDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminKeyCountDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminKeyCountDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminKeyCountDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminKeyCountDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminKeyCountDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminKeyCountDto() when $default != null:
return $default(_that.key,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  int count)  $default,) {final _that = this;
switch (_that) {
case _AdminKeyCountDto():
return $default(_that.key,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  int count)?  $default,) {final _that = this;
switch (_that) {
case _AdminKeyCountDto() when $default != null:
return $default(_that.key,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminKeyCountDto implements AdminKeyCountDto {
  const _AdminKeyCountDto({required this.key, required this.count});
  factory _AdminKeyCountDto.fromJson(Map<String, dynamic> json) => _$AdminKeyCountDtoFromJson(json);

/// What is counted
@override final  String key;
/// How many
@override final  int count;

/// Create a copy of AdminKeyCountDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminKeyCountDtoCopyWith<_AdminKeyCountDto> get copyWith => __$AdminKeyCountDtoCopyWithImpl<_AdminKeyCountDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminKeyCountDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminKeyCountDto&&(identical(other.key, key) || other.key == key)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,key,count);
}

@override
String toString() {
    return 'AdminKeyCountDto(key: $key, count: $count)';
}


}

/// @nodoc
abstract mixin class _$AdminKeyCountDtoCopyWith<$Res> implements $AdminKeyCountDtoCopyWith<$Res> {
  factory _$AdminKeyCountDtoCopyWith(_AdminKeyCountDto value, $Res Function(_AdminKeyCountDto) _then) = __$AdminKeyCountDtoCopyWithImpl;
@override @useResult
$Res call({
 String key, int count
});




}
/// @nodoc
class __$AdminKeyCountDtoCopyWithImpl<$Res>
    implements _$AdminKeyCountDtoCopyWith<$Res> {
  __$AdminKeyCountDtoCopyWithImpl(this._self, this._then);

  final _AdminKeyCountDto _self;
  final $Res Function(_AdminKeyCountDto) _then;

/// Create a copy of AdminKeyCountDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? count = null,}) {
  return _then(_AdminKeyCountDto(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
