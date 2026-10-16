// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_routes_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceRoutesResponse {

/// Upcoming rides with route entries
 List<DeviceRideDto> get rides;/// Latest standalone routes
 List<DeviceRouteDto> get routes;/// Upcoming ride groups the user is registered in (from 12 hours ago to 7 days ahead), earliest first, each with the route to load
 List<DeviceRegisteredGroupDto> get registeredGroups;
/// Create a copy of DeviceRoutesResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRoutesResponseCopyWith<DeviceRoutesResponse> get copyWith => _$DeviceRoutesResponseCopyWithImpl<DeviceRoutesResponse>(this as DeviceRoutesResponse, _$identity);

  /// Serializes this DeviceRoutesResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRoutesResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRoutesResponse&&const DeepCollectionEquality().equals(other.rides, _this.rides)&&const DeepCollectionEquality().equals(other.routes, _this.routes)&&const DeepCollectionEquality().equals(other.registeredGroups, _this.registeredGroups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRoutesResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.rides),const DeepCollectionEquality().hash(_this.routes),const DeepCollectionEquality().hash(_this.registeredGroups));
}

@override
String toString() {
  final _this = this as DeviceRoutesResponse;
  return 'DeviceRoutesResponse(rides: ${_this.rides}, routes: ${_this.routes}, registeredGroups: ${_this.registeredGroups})';
}


}

/// @nodoc
abstract mixin class $DeviceRoutesResponseCopyWith<$Res>  {
  factory $DeviceRoutesResponseCopyWith(DeviceRoutesResponse value, $Res Function(DeviceRoutesResponse) _then) = _$DeviceRoutesResponseCopyWithImpl;
@useResult
$Res call({
 List<DeviceRideDto> rides, List<DeviceRouteDto> routes, List<DeviceRegisteredGroupDto> registeredGroups
});




}
/// @nodoc
class _$DeviceRoutesResponseCopyWithImpl<$Res>
    implements $DeviceRoutesResponseCopyWith<$Res> {
  _$DeviceRoutesResponseCopyWithImpl(this._self, this._then);

  final DeviceRoutesResponse _self;
  final $Res Function(DeviceRoutesResponse) _then;

/// Create a copy of DeviceRoutesResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rides = null,Object? routes = null,Object? registeredGroups = null,}) {
  return _then(DeviceRoutesResponse(
rides: null == rides ? _self.rides : rides // ignore: cast_nullable_to_non_nullable
as List<DeviceRideDto>,routes: null == routes ? _self.routes : routes // ignore: cast_nullable_to_non_nullable
as List<DeviceRouteDto>,registeredGroups: null == registeredGroups ? _self.registeredGroups : registeredGroups // ignore: cast_nullable_to_non_nullable
as List<DeviceRegisteredGroupDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRoutesResponse].
extension DeviceRoutesResponsePatterns on DeviceRoutesResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRoutesResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRoutesResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRoutesResponse value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRoutesResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRoutesResponse value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRoutesResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DeviceRideDto> rides,  List<DeviceRouteDto> routes,  List<DeviceRegisteredGroupDto> registeredGroups)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRoutesResponse() when $default != null:
return $default(_that.rides,_that.routes,_that.registeredGroups);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DeviceRideDto> rides,  List<DeviceRouteDto> routes,  List<DeviceRegisteredGroupDto> registeredGroups)  $default,) {final _that = this;
switch (_that) {
case _DeviceRoutesResponse():
return $default(_that.rides,_that.routes,_that.registeredGroups);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DeviceRideDto> rides,  List<DeviceRouteDto> routes,  List<DeviceRegisteredGroupDto> registeredGroups)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRoutesResponse() when $default != null:
return $default(_that.rides,_that.routes,_that.registeredGroups);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRoutesResponse implements DeviceRoutesResponse {
  const _DeviceRoutesResponse({required  List<DeviceRideDto> rides, required  List<DeviceRouteDto> routes, required  List<DeviceRegisteredGroupDto> registeredGroups}): _rides = rides,_routes = routes,_registeredGroups = registeredGroups;
  factory _DeviceRoutesResponse.fromJson(Map<String, dynamic> json) => _$DeviceRoutesResponseFromJson(json);

/// Upcoming rides with route entries
 final  List<DeviceRideDto> _rides;
/// Upcoming rides with route entries
@override List<DeviceRideDto> get rides {
  if (_rides is EqualUnmodifiableListView) return _rides;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rides);
}

/// Latest standalone routes
 final  List<DeviceRouteDto> _routes;
/// Latest standalone routes
@override List<DeviceRouteDto> get routes {
  if (_routes is EqualUnmodifiableListView) return _routes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_routes);
}

/// Upcoming ride groups the user is registered in (from 12 hours ago to 7 days ahead), earliest first, each with the route to load
 final  List<DeviceRegisteredGroupDto> _registeredGroups;
/// Upcoming ride groups the user is registered in (from 12 hours ago to 7 days ahead), earliest first, each with the route to load
@override List<DeviceRegisteredGroupDto> get registeredGroups {
  if (_registeredGroups is EqualUnmodifiableListView) return _registeredGroups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_registeredGroups);
}


/// Create a copy of DeviceRoutesResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRoutesResponseCopyWith<_DeviceRoutesResponse> get copyWith => __$DeviceRoutesResponseCopyWithImpl<_DeviceRoutesResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRoutesResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRoutesResponse&&const DeepCollectionEquality().equals(other.rides, _rides)&&const DeepCollectionEquality().equals(other.routes, _routes)&&const DeepCollectionEquality().equals(other.registeredGroups, _registeredGroups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_rides),const DeepCollectionEquality().hash(_routes),const DeepCollectionEquality().hash(_registeredGroups));
}

@override
String toString() {
    return 'DeviceRoutesResponse(rides: $rides, routes: $routes, registeredGroups: $registeredGroups)';
}


}

/// @nodoc
abstract mixin class _$DeviceRoutesResponseCopyWith<$Res> implements $DeviceRoutesResponseCopyWith<$Res> {
  factory _$DeviceRoutesResponseCopyWith(_DeviceRoutesResponse value, $Res Function(_DeviceRoutesResponse) _then) = __$DeviceRoutesResponseCopyWithImpl;
@override @useResult
$Res call({
 List<DeviceRideDto> rides, List<DeviceRouteDto> routes, List<DeviceRegisteredGroupDto> registeredGroups
});




}
/// @nodoc
class __$DeviceRoutesResponseCopyWithImpl<$Res>
    implements _$DeviceRoutesResponseCopyWith<$Res> {
  __$DeviceRoutesResponseCopyWithImpl(this._self, this._then);

  final _DeviceRoutesResponse _self;
  final $Res Function(_DeviceRoutesResponse) _then;

/// Create a copy of DeviceRoutesResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rides = null,Object? routes = null,Object? registeredGroups = null,}) {
  return _then(_DeviceRoutesResponse(
rides: null == rides ? _self._rides : rides // ignore: cast_nullable_to_non_nullable
as List<DeviceRideDto>,routes: null == routes ? _self._routes : routes // ignore: cast_nullable_to_non_nullable
as List<DeviceRouteDto>,registeredGroups: null == registeredGroups ? _self._registeredGroups : registeredGroups // ignore: cast_nullable_to_non_nullable
as List<DeviceRegisteredGroupDto>,
  ));
}


}

// dart format on
