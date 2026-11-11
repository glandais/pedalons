// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'incompatible_route_usage_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IncompatibleRouteUsageDto {

/// RIDE or TRIP
 String get type;/// Ride or trip URL slug, in the route's team
 String get slug;/// Ride or trip name
 String get name;/// Its visibility: PUBLIC or PUBLIC_UNLISTED
 String get visibility;
/// Create a copy of IncompatibleRouteUsageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IncompatibleRouteUsageDtoCopyWith<IncompatibleRouteUsageDto> get copyWith => _$IncompatibleRouteUsageDtoCopyWithImpl<IncompatibleRouteUsageDto>(this as IncompatibleRouteUsageDto, _$identity);

  /// Serializes this IncompatibleRouteUsageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IncompatibleRouteUsageDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IncompatibleRouteUsageDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IncompatibleRouteUsageDto;
  return Object.hash(runtimeType,_this.type,_this.slug,_this.name,_this.visibility);
}

@override
String toString() {
  final _this = this as IncompatibleRouteUsageDto;
  return 'IncompatibleRouteUsageDto(type: ${_this.type}, slug: ${_this.slug}, name: ${_this.name}, visibility: ${_this.visibility})';
}


}

/// @nodoc
abstract mixin class $IncompatibleRouteUsageDtoCopyWith<$Res>  {
  factory $IncompatibleRouteUsageDtoCopyWith(IncompatibleRouteUsageDto value, $Res Function(IncompatibleRouteUsageDto) _then) = _$IncompatibleRouteUsageDtoCopyWithImpl;
@useResult
$Res call({
 String type, String slug, String name, String visibility
});




}
/// @nodoc
class _$IncompatibleRouteUsageDtoCopyWithImpl<$Res>
    implements $IncompatibleRouteUsageDtoCopyWith<$Res> {
  _$IncompatibleRouteUsageDtoCopyWithImpl(this._self, this._then);

  final IncompatibleRouteUsageDto _self;
  final $Res Function(IncompatibleRouteUsageDto) _then;

/// Create a copy of IncompatibleRouteUsageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? slug = null,Object? name = null,Object? visibility = null,}) {
  return _then(IncompatibleRouteUsageDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [IncompatibleRouteUsageDto].
extension IncompatibleRouteUsageDtoPatterns on IncompatibleRouteUsageDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IncompatibleRouteUsageDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IncompatibleRouteUsageDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IncompatibleRouteUsageDto value)  $default,){
final _that = this;
switch (_that) {
case _IncompatibleRouteUsageDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IncompatibleRouteUsageDto value)?  $default,){
final _that = this;
switch (_that) {
case _IncompatibleRouteUsageDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String slug,  String name,  String visibility)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IncompatibleRouteUsageDto() when $default != null:
return $default(_that.type,_that.slug,_that.name,_that.visibility);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String slug,  String name,  String visibility)  $default,) {final _that = this;
switch (_that) {
case _IncompatibleRouteUsageDto():
return $default(_that.type,_that.slug,_that.name,_that.visibility);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String slug,  String name,  String visibility)?  $default,) {final _that = this;
switch (_that) {
case _IncompatibleRouteUsageDto() when $default != null:
return $default(_that.type,_that.slug,_that.name,_that.visibility);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IncompatibleRouteUsageDto implements IncompatibleRouteUsageDto {
  const _IncompatibleRouteUsageDto({required this.type, required this.slug, required this.name, required this.visibility});
  factory _IncompatibleRouteUsageDto.fromJson(Map<String, dynamic> json) => _$IncompatibleRouteUsageDtoFromJson(json);

/// RIDE or TRIP
@override final  String type;
/// Ride or trip URL slug, in the route's team
@override final  String slug;
/// Ride or trip name
@override final  String name;
/// Its visibility: PUBLIC or PUBLIC_UNLISTED
@override final  String visibility;

/// Create a copy of IncompatibleRouteUsageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IncompatibleRouteUsageDtoCopyWith<_IncompatibleRouteUsageDto> get copyWith => __$IncompatibleRouteUsageDtoCopyWithImpl<_IncompatibleRouteUsageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IncompatibleRouteUsageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IncompatibleRouteUsageDto&&(identical(other.type, type) || other.type == type)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.visibility, visibility) || other.visibility == visibility));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,slug,name,visibility);
}

@override
String toString() {
    return 'IncompatibleRouteUsageDto(type: $type, slug: $slug, name: $name, visibility: $visibility)';
}


}

/// @nodoc
abstract mixin class _$IncompatibleRouteUsageDtoCopyWith<$Res> implements $IncompatibleRouteUsageDtoCopyWith<$Res> {
  factory _$IncompatibleRouteUsageDtoCopyWith(_IncompatibleRouteUsageDto value, $Res Function(_IncompatibleRouteUsageDto) _then) = __$IncompatibleRouteUsageDtoCopyWithImpl;
@override @useResult
$Res call({
 String type, String slug, String name, String visibility
});




}
/// @nodoc
class __$IncompatibleRouteUsageDtoCopyWithImpl<$Res>
    implements _$IncompatibleRouteUsageDtoCopyWith<$Res> {
  __$IncompatibleRouteUsageDtoCopyWithImpl(this._self, this._then);

  final _IncompatibleRouteUsageDto _self;
  final $Res Function(_IncompatibleRouteUsageDto) _then;

/// Create a copy of IncompatibleRouteUsageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? slug = null,Object? name = null,Object? visibility = null,}) {
  return _then(_IncompatibleRouteUsageDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
