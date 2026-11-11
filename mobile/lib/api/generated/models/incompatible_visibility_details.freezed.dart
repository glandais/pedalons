// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'incompatible_visibility_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$IncompatibleVisibilityDetails {

/// Type
 String get type;/// Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved.
 List<IncompatibleRouteDto> get routes;/// Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved.
 List<IncompatibleRouteUsageDto> get usages;
/// Create a copy of IncompatibleVisibilityDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$IncompatibleVisibilityDetailsCopyWith<IncompatibleVisibilityDetails> get copyWith => _$IncompatibleVisibilityDetailsCopyWithImpl<IncompatibleVisibilityDetails>(this as IncompatibleVisibilityDetails, _$identity);

  /// Serializes this IncompatibleVisibilityDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as IncompatibleVisibilityDetails;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IncompatibleVisibilityDetails&&(identical(other.type, _this.type) || other.type == _this.type)&&const DeepCollectionEquality().equals(other.routes, _this.routes)&&const DeepCollectionEquality().equals(other.usages, _this.usages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as IncompatibleVisibilityDetails;
  return Object.hash(runtimeType,_this.type,const DeepCollectionEquality().hash(_this.routes),const DeepCollectionEquality().hash(_this.usages));
}

@override
String toString() {
  final _this = this as IncompatibleVisibilityDetails;
  return 'IncompatibleVisibilityDetails(type: ${_this.type}, routes: ${_this.routes}, usages: ${_this.usages})';
}


}

/// @nodoc
abstract mixin class $IncompatibleVisibilityDetailsCopyWith<$Res>  {
  factory $IncompatibleVisibilityDetailsCopyWith(IncompatibleVisibilityDetails value, $Res Function(IncompatibleVisibilityDetails) _then) = _$IncompatibleVisibilityDetailsCopyWithImpl;
@useResult
$Res call({
 String type, List<IncompatibleRouteDto> routes, List<IncompatibleRouteUsageDto> usages
});




}
/// @nodoc
class _$IncompatibleVisibilityDetailsCopyWithImpl<$Res>
    implements $IncompatibleVisibilityDetailsCopyWith<$Res> {
  _$IncompatibleVisibilityDetailsCopyWithImpl(this._self, this._then);

  final IncompatibleVisibilityDetails _self;
  final $Res Function(IncompatibleVisibilityDetails) _then;

/// Create a copy of IncompatibleVisibilityDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? routes = null,Object? usages = null,}) {
  return _then(IncompatibleVisibilityDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,routes: null == routes ? _self.routes : routes // ignore: cast_nullable_to_non_nullable
as List<IncompatibleRouteDto>,usages: null == usages ? _self.usages : usages // ignore: cast_nullable_to_non_nullable
as List<IncompatibleRouteUsageDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [IncompatibleVisibilityDetails].
extension IncompatibleVisibilityDetailsPatterns on IncompatibleVisibilityDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _IncompatibleVisibilityDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _IncompatibleVisibilityDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _IncompatibleVisibilityDetails value)  $default,){
final _that = this;
switch (_that) {
case _IncompatibleVisibilityDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _IncompatibleVisibilityDetails value)?  $default,){
final _that = this;
switch (_that) {
case _IncompatibleVisibilityDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  List<IncompatibleRouteDto> routes,  List<IncompatibleRouteUsageDto> usages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _IncompatibleVisibilityDetails() when $default != null:
return $default(_that.type,_that.routes,_that.usages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  List<IncompatibleRouteDto> routes,  List<IncompatibleRouteUsageDto> usages)  $default,) {final _that = this;
switch (_that) {
case _IncompatibleVisibilityDetails():
return $default(_that.type,_that.routes,_that.usages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  List<IncompatibleRouteDto> routes,  List<IncompatibleRouteUsageDto> usages)?  $default,) {final _that = this;
switch (_that) {
case _IncompatibleVisibilityDetails() when $default != null:
return $default(_that.type,_that.routes,_that.usages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _IncompatibleVisibilityDetails implements IncompatibleVisibilityDetails {
  const _IncompatibleVisibilityDetails({required this.type, required  List<IncompatibleRouteDto> routes, required  List<IncompatibleRouteUsageDto> usages}): _routes = routes,_usages = usages;
  factory _IncompatibleVisibilityDetails.fromJson(Map<String, dynamic> json) => _$IncompatibleVisibilityDetailsFromJson(json);

/// Type
@override final  String type;
/// Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved.
 final  List<IncompatibleRouteDto> _routes;
/// Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved.
@override List<IncompatibleRouteDto> get routes {
  if (_routes is EqualUnmodifiableListView) return _routes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_routes);
}

/// Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved.
 final  List<IncompatibleRouteUsageDto> _usages;
/// Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved.
@override List<IncompatibleRouteUsageDto> get usages {
  if (_usages is EqualUnmodifiableListView) return _usages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usages);
}


/// Create a copy of IncompatibleVisibilityDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IncompatibleVisibilityDetailsCopyWith<_IncompatibleVisibilityDetails> get copyWith => __$IncompatibleVisibilityDetailsCopyWithImpl<_IncompatibleVisibilityDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$IncompatibleVisibilityDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _IncompatibleVisibilityDetails&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.routes, _routes)&&const DeepCollectionEquality().equals(other.usages, _usages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_routes),const DeepCollectionEquality().hash(_usages));
}

@override
String toString() {
    return 'IncompatibleVisibilityDetails(type: $type, routes: $routes, usages: $usages)';
}


}

/// @nodoc
abstract mixin class _$IncompatibleVisibilityDetailsCopyWith<$Res> implements $IncompatibleVisibilityDetailsCopyWith<$Res> {
  factory _$IncompatibleVisibilityDetailsCopyWith(_IncompatibleVisibilityDetails value, $Res Function(_IncompatibleVisibilityDetails) _then) = __$IncompatibleVisibilityDetailsCopyWithImpl;
@override @useResult
$Res call({
 String type, List<IncompatibleRouteDto> routes, List<IncompatibleRouteUsageDto> usages
});




}
/// @nodoc
class __$IncompatibleVisibilityDetailsCopyWithImpl<$Res>
    implements _$IncompatibleVisibilityDetailsCopyWith<$Res> {
  __$IncompatibleVisibilityDetailsCopyWithImpl(this._self, this._then);

  final _IncompatibleVisibilityDetails _self;
  final $Res Function(_IncompatibleVisibilityDetails) _then;

/// Create a copy of IncompatibleVisibilityDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? routes = null,Object? usages = null,}) {
  return _then(_IncompatibleVisibilityDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,routes: null == routes ? _self._routes : routes // ignore: cast_nullable_to_non_nullable
as List<IncompatibleRouteDto>,usages: null == usages ? _self._usages : usages // ignore: cast_nullable_to_non_nullable
as List<IncompatibleRouteUsageDto>,
  ));
}


}

// dart format on
