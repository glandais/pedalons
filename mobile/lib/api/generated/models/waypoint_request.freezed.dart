// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'waypoint_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WaypointRequest {

/// Where the waypoint is
 GeoPoint get position;/// What the waypoint is
 String get type;/// Name, possibly empty (the type's label then shows on a device). The editor limits it to 40 characters; the API accepts what an import can bring, up to 250
 String get name;/// Identifier of an existing waypoint, as returned by the API: it keeps its origin. Omitted or unknown: a new waypoint. Malformed or repeated: 400
 String? get id;/// Free text, at most 500 characters
 String? get description;/// The distance in metres the editor shows the waypoint at. Only used to pick which passage of a route that goes by twice the waypoint belongs to: the server recomputes the distance itself
 double? get distance;/// Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists: it keeps its own
 String? get origin;
/// Create a copy of WaypointRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WaypointRequestCopyWith<WaypointRequest> get copyWith => _$WaypointRequestCopyWithImpl<WaypointRequest>(this as WaypointRequest, _$identity);

  /// Serializes this WaypointRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WaypointRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WaypointRequest&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.origin, _this.origin) || other.origin == _this.origin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WaypointRequest;
  return Object.hash(runtimeType,_this.position,_this.type,_this.name,_this.id,_this.description,_this.distance,_this.origin);
}

@override
String toString() {
  final _this = this as WaypointRequest;
  return 'WaypointRequest(position: ${_this.position}, type: ${_this.type}, name: ${_this.name}, id: ${_this.id}, description: ${_this.description}, distance: ${_this.distance}, origin: ${_this.origin})';
}


}

/// @nodoc
abstract mixin class $WaypointRequestCopyWith<$Res>  {
  factory $WaypointRequestCopyWith(WaypointRequest value, $Res Function(WaypointRequest) _then) = _$WaypointRequestCopyWithImpl;
@useResult
$Res call({
 GeoPoint position, String type, String name, String? id, String? description, double? distance, String? origin
});


$GeoPointCopyWith<$Res> get position;

}
/// @nodoc
class _$WaypointRequestCopyWithImpl<$Res>
    implements $WaypointRequestCopyWith<$Res> {
  _$WaypointRequestCopyWithImpl(this._self, this._then);

  final WaypointRequest _self;
  final $Res Function(WaypointRequest) _then;

/// Create a copy of WaypointRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? position = null,Object? type = null,Object? name = null,Object? id = freezed,Object? description = freezed,Object? distance = freezed,Object? origin = freezed,}) {
  return _then(WaypointRequest(
position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as GeoPoint,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of WaypointRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get position {
  
  return $GeoPointCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}
}


/// Adds pattern-matching-related methods to [WaypointRequest].
extension WaypointRequestPatterns on WaypointRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WaypointRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WaypointRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WaypointRequest value)  $default,){
final _that = this;
switch (_that) {
case _WaypointRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WaypointRequest value)?  $default,){
final _that = this;
switch (_that) {
case _WaypointRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoPoint position,  String type,  String name,  String? id,  String? description,  double? distance,  String? origin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WaypointRequest() when $default != null:
return $default(_that.position,_that.type,_that.name,_that.id,_that.description,_that.distance,_that.origin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoPoint position,  String type,  String name,  String? id,  String? description,  double? distance,  String? origin)  $default,) {final _that = this;
switch (_that) {
case _WaypointRequest():
return $default(_that.position,_that.type,_that.name,_that.id,_that.description,_that.distance,_that.origin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoPoint position,  String type,  String name,  String? id,  String? description,  double? distance,  String? origin)?  $default,) {final _that = this;
switch (_that) {
case _WaypointRequest() when $default != null:
return $default(_that.position,_that.type,_that.name,_that.id,_that.description,_that.distance,_that.origin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WaypointRequest implements WaypointRequest {
  const _WaypointRequest({required this.position, required this.type, required this.name, this.id, this.description, this.distance, this.origin});
  factory _WaypointRequest.fromJson(Map<String, dynamic> json) => _$WaypointRequestFromJson(json);

/// Where the waypoint is
@override final  GeoPoint position;
/// What the waypoint is
@override final  String type;
/// Name, possibly empty (the type's label then shows on a device). The editor limits it to 40 characters; the API accepts what an import can bring, up to 250
@override final  String name;
/// Identifier of an existing waypoint, as returned by the API: it keeps its origin. Omitted or unknown: a new waypoint. Malformed or repeated: 400
@override final  String? id;
/// Free text, at most 500 characters
@override final  String? description;
/// The distance in metres the editor shows the waypoint at. Only used to pick which passage of a route that goes by twice the waypoint belongs to: the server recomputes the distance itself
@override final  double? distance;
/// Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists: it keeps its own
@override final  String? origin;

/// Create a copy of WaypointRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WaypointRequestCopyWith<_WaypointRequest> get copyWith => __$WaypointRequestCopyWithImpl<_WaypointRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WaypointRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WaypointRequest&&(identical(other.position, position) || other.position == position)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.origin, origin) || other.origin == origin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,position,type,name,id,description,distance,origin);
}

@override
String toString() {
    return 'WaypointRequest(position: $position, type: $type, name: $name, id: $id, description: $description, distance: $distance, origin: $origin)';
}


}

/// @nodoc
abstract mixin class _$WaypointRequestCopyWith<$Res> implements $WaypointRequestCopyWith<$Res> {
  factory _$WaypointRequestCopyWith(_WaypointRequest value, $Res Function(_WaypointRequest) _then) = __$WaypointRequestCopyWithImpl;
@override @useResult
$Res call({
 GeoPoint position, String type, String name, String? id, String? description, double? distance, String? origin
});


@override $GeoPointCopyWith<$Res> get position;

}
/// @nodoc
class __$WaypointRequestCopyWithImpl<$Res>
    implements _$WaypointRequestCopyWith<$Res> {
  __$WaypointRequestCopyWithImpl(this._self, this._then);

  final _WaypointRequest _self;
  final $Res Function(_WaypointRequest) _then;

/// Create a copy of WaypointRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? position = null,Object? type = null,Object? name = null,Object? id = freezed,Object? description = freezed,Object? distance = freezed,Object? origin = freezed,}) {
  return _then(_WaypointRequest(
position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as GeoPoint,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of WaypointRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get position {
  
  return $GeoPointCopyWith<$Res>(_self.position, (value) {
    return _then(_self.copyWith(position: value));
  });
}
}

// dart format on
