// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_config_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnalyticsConfigDto {

/// Same-origin path the site sends a page view to (for example /count), without the query string.
 String get countPath;
/// Create a copy of AnalyticsConfigDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalyticsConfigDtoCopyWith<AnalyticsConfigDto> get copyWith => _$AnalyticsConfigDtoCopyWithImpl<AnalyticsConfigDto>(this as AnalyticsConfigDto, _$identity);

  /// Serializes this AnalyticsConfigDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AnalyticsConfigDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalyticsConfigDto&&(identical(other.countPath, _this.countPath) || other.countPath == _this.countPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AnalyticsConfigDto;
  return Object.hash(runtimeType,_this.countPath);
}

@override
String toString() {
  final _this = this as AnalyticsConfigDto;
  return 'AnalyticsConfigDto(countPath: ${_this.countPath})';
}


}

/// @nodoc
abstract mixin class $AnalyticsConfigDtoCopyWith<$Res>  {
  factory $AnalyticsConfigDtoCopyWith(AnalyticsConfigDto value, $Res Function(AnalyticsConfigDto) _then) = _$AnalyticsConfigDtoCopyWithImpl;
@useResult
$Res call({
 String countPath
});




}
/// @nodoc
class _$AnalyticsConfigDtoCopyWithImpl<$Res>
    implements $AnalyticsConfigDtoCopyWith<$Res> {
  _$AnalyticsConfigDtoCopyWithImpl(this._self, this._then);

  final AnalyticsConfigDto _self;
  final $Res Function(AnalyticsConfigDto) _then;

/// Create a copy of AnalyticsConfigDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? countPath = null,}) {
  return _then(AnalyticsConfigDto(
countPath: null == countPath ? _self.countPath : countPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AnalyticsConfigDto].
extension AnalyticsConfigDtoPatterns on AnalyticsConfigDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnalyticsConfigDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnalyticsConfigDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnalyticsConfigDto value)  $default,){
final _that = this;
switch (_that) {
case _AnalyticsConfigDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnalyticsConfigDto value)?  $default,){
final _that = this;
switch (_that) {
case _AnalyticsConfigDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String countPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnalyticsConfigDto() when $default != null:
return $default(_that.countPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String countPath)  $default,) {final _that = this;
switch (_that) {
case _AnalyticsConfigDto():
return $default(_that.countPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String countPath)?  $default,) {final _that = this;
switch (_that) {
case _AnalyticsConfigDto() when $default != null:
return $default(_that.countPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnalyticsConfigDto implements AnalyticsConfigDto {
  const _AnalyticsConfigDto({required this.countPath});
  factory _AnalyticsConfigDto.fromJson(Map<String, dynamic> json) => _$AnalyticsConfigDtoFromJson(json);

/// Same-origin path the site sends a page view to (for example /count), without the query string.
@override final  String countPath;

/// Create a copy of AnalyticsConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnalyticsConfigDtoCopyWith<_AnalyticsConfigDto> get copyWith => __$AnalyticsConfigDtoCopyWithImpl<_AnalyticsConfigDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnalyticsConfigDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnalyticsConfigDto&&(identical(other.countPath, countPath) || other.countPath == countPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,countPath);
}

@override
String toString() {
    return 'AnalyticsConfigDto(countPath: $countPath)';
}


}

/// @nodoc
abstract mixin class _$AnalyticsConfigDtoCopyWith<$Res> implements $AnalyticsConfigDtoCopyWith<$Res> {
  factory _$AnalyticsConfigDtoCopyWith(_AnalyticsConfigDto value, $Res Function(_AnalyticsConfigDto) _then) = __$AnalyticsConfigDtoCopyWithImpl;
@override @useResult
$Res call({
 String countPath
});




}
/// @nodoc
class __$AnalyticsConfigDtoCopyWithImpl<$Res>
    implements _$AnalyticsConfigDtoCopyWith<$Res> {
  __$AnalyticsConfigDtoCopyWithImpl(this._self, this._then);

  final _AnalyticsConfigDto _self;
  final $Res Function(_AnalyticsConfigDto) _then;

/// Create a copy of AnalyticsConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? countPath = null,}) {
  return _then(_AnalyticsConfigDto(
countPath: null == countPath ? _self.countPath : countPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
