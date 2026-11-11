// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'incompatible_route_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IncompatibleRouteDto {

/// Route URL slug
 String get slug;/// Route name
 String get name;/// The route's visibility today (TEAM)
 String get visibility;/// The visibility the route takes when the same request is replayed with alignVisibility = true: always PUBLIC_UNLISTED, even under a PUBLIC ride or trip — a route never becomes PUBLIC without an explicit decision.
 String get proposedVisibility;
/// Create a copy of IncompatibleRouteDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IncompatibleRouteDtoCopyWith<IncompatibleRouteDto> get copyWith => _$IncompatibleRouteDtoCopyWithImpl<IncompatibleRouteDto>(this as IncompatibleRouteDto, _$identity);

  /// Serializes this IncompatibleRouteDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IncompatibleRouteDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IncompatibleRouteDto&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.proposedVisibility, _this.proposedVisibility) || other.proposedVisibility == _this.proposedVisibility));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IncompatibleRouteDto;
  return Object.hash(runtimeType,_this.slug,_this.name,_this.visibility,_this.proposedVisibility);
}

@override
String toString() {
  final _this = this as IncompatibleRouteDto;
  return 'IncompatibleRouteDto(slug: ${_this.slug}, name: ${_this.name}, visibility: ${_this.visibility}, proposedVisibility: ${_this.proposedVisibility})';
}


}

/// @nodoc
abstract mixin class $IncompatibleRouteDtoCopyWith<$Res>  {
  factory $IncompatibleRouteDtoCopyWith(IncompatibleRouteDto value, $Res Function(IncompatibleRouteDto) _then) = _$IncompatibleRouteDtoCopyWithImpl;
@useResult
$Res call({
 String slug, String name, String visibility, String proposedVisibility
});




}
/// @nodoc
class _$IncompatibleRouteDtoCopyWithImpl<$Res>
    implements $IncompatibleRouteDtoCopyWith<$Res> {
  _$IncompatibleRouteDtoCopyWithImpl(this._self, this._then);

  final IncompatibleRouteDto _self;
  final $Res Function(IncompatibleRouteDto) _then;

/// Create a copy of IncompatibleRouteDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slug = null,Object? name = null,Object? visibility = null,Object? proposedVisibility = null,}) {
  return _then(IncompatibleRouteDto(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,proposedVisibility: null == proposedVisibility ? _self.proposedVisibility : proposedVisibility // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [IncompatibleRouteDto].
extension IncompatibleRouteDtoPatterns on IncompatibleRouteDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IncompatibleRouteDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IncompatibleRouteDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IncompatibleRouteDto value)  $default,){
final _that = this;
switch (_that) {
case _IncompatibleRouteDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IncompatibleRouteDto value)?  $default,){
final _that = this;
switch (_that) {
case _IncompatibleRouteDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String slug,  String name,  String visibility,  String proposedVisibility)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IncompatibleRouteDto() when $default != null:
return $default(_that.slug,_that.name,_that.visibility,_that.proposedVisibility);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String slug,  String name,  String visibility,  String proposedVisibility)  $default,) {final _that = this;
switch (_that) {
case _IncompatibleRouteDto():
return $default(_that.slug,_that.name,_that.visibility,_that.proposedVisibility);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String slug,  String name,  String visibility,  String proposedVisibility)?  $default,) {final _that = this;
switch (_that) {
case _IncompatibleRouteDto() when $default != null:
return $default(_that.slug,_that.name,_that.visibility,_that.proposedVisibility);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IncompatibleRouteDto implements IncompatibleRouteDto {
  const _IncompatibleRouteDto({required this.slug, required this.name, required this.visibility, required this.proposedVisibility});
  factory _IncompatibleRouteDto.fromJson(Map<String, dynamic> json) => _$IncompatibleRouteDtoFromJson(json);

/// Route URL slug
@override final  String slug;
/// Route name
@override final  String name;
/// The route's visibility today (TEAM)
@override final  String visibility;
/// The visibility the route takes when the same request is replayed with alignVisibility = true: always PUBLIC_UNLISTED, even under a PUBLIC ride or trip — a route never becomes PUBLIC without an explicit decision.
@override final  String proposedVisibility;

/// Create a copy of IncompatibleRouteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IncompatibleRouteDtoCopyWith<_IncompatibleRouteDto> get copyWith => __$IncompatibleRouteDtoCopyWithImpl<_IncompatibleRouteDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IncompatibleRouteDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IncompatibleRouteDto&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.proposedVisibility, proposedVisibility) || other.proposedVisibility == proposedVisibility));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,slug,name,visibility,proposedVisibility);
}

@override
String toString() {
    return 'IncompatibleRouteDto(slug: $slug, name: $name, visibility: $visibility, proposedVisibility: $proposedVisibility)';
}


}

/// @nodoc
abstract mixin class _$IncompatibleRouteDtoCopyWith<$Res> implements $IncompatibleRouteDtoCopyWith<$Res> {
  factory _$IncompatibleRouteDtoCopyWith(_IncompatibleRouteDto value, $Res Function(_IncompatibleRouteDto) _then) = __$IncompatibleRouteDtoCopyWithImpl;
@override @useResult
$Res call({
 String slug, String name, String visibility, String proposedVisibility
});




}
/// @nodoc
class __$IncompatibleRouteDtoCopyWithImpl<$Res>
    implements _$IncompatibleRouteDtoCopyWith<$Res> {
  __$IncompatibleRouteDtoCopyWithImpl(this._self, this._then);

  final _IncompatibleRouteDto _self;
  final $Res Function(_IncompatibleRouteDto) _then;

/// Create a copy of IncompatibleRouteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? name = null,Object? visibility = null,Object? proposedVisibility = null,}) {
  return _then(_IncompatibleRouteDto(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,proposedVisibility: null == proposedVisibility ? _self.proposedVisibility : proposedVisibility // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
