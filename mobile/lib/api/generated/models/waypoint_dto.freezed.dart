// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'waypoint_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WaypointDto {

 GeoJsonPoint get geometry;/// Name, possibly empty
 String get name;/// What the waypoint is
 String get type;/// Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's
 String get origin;/// Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet
 String? get id;/// Free text, at most 500 characters
 String? get description;/// Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track
 double? get distance;
/// Create a copy of WaypointDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WaypointDtoCopyWith<WaypointDto> get copyWith => _$WaypointDtoCopyWithImpl<WaypointDto>(this as WaypointDto, _$identity);

  /// Serializes this WaypointDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WaypointDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WaypointDto&&(identical(other.geometry, _this.geometry) || other.geometry == _this.geometry)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.origin, _this.origin) || other.origin == _this.origin)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.distance, _this.distance) || other.distance == _this.distance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WaypointDto;
  return Object.hash(runtimeType,_this.geometry,_this.name,_this.type,_this.origin,_this.id,_this.description,_this.distance);
}

@override
String toString() {
  final _this = this as WaypointDto;
  return 'WaypointDto(geometry: ${_this.geometry}, name: ${_this.name}, type: ${_this.type}, origin: ${_this.origin}, id: ${_this.id}, description: ${_this.description}, distance: ${_this.distance})';
}


}

/// @nodoc
abstract mixin class $WaypointDtoCopyWith<$Res>  {
  factory $WaypointDtoCopyWith(WaypointDto value, $Res Function(WaypointDto) _then) = _$WaypointDtoCopyWithImpl;
@useResult
$Res call({
 GeoJsonPoint geometry, String name, String type, String origin, String? id, String? description, double? distance
});


$GeoJsonPointCopyWith<$Res> get geometry;

}
/// @nodoc
class _$WaypointDtoCopyWithImpl<$Res>
    implements $WaypointDtoCopyWith<$Res> {
  _$WaypointDtoCopyWithImpl(this._self, this._then);

  final WaypointDto _self;
  final $Res Function(WaypointDto) _then;

/// Create a copy of WaypointDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? geometry = null,Object? name = null,Object? type = null,Object? origin = null,Object? id = freezed,Object? description = freezed,Object? distance = freezed,}) {
  return _then(WaypointDto(
geometry: null == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as GeoJsonPoint,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of WaypointDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonPointCopyWith<$Res> get geometry {
  
  return $GeoJsonPointCopyWith<$Res>(_self.geometry, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}
}


/// Adds pattern-matching-related methods to [WaypointDto].
extension WaypointDtoPatterns on WaypointDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WaypointDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WaypointDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WaypointDto value)  $default,){
final _that = this;
switch (_that) {
case _WaypointDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WaypointDto value)?  $default,){
final _that = this;
switch (_that) {
case _WaypointDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoJsonPoint geometry,  String name,  String type,  String origin,  String? id,  String? description,  double? distance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WaypointDto() when $default != null:
return $default(_that.geometry,_that.name,_that.type,_that.origin,_that.id,_that.description,_that.distance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoJsonPoint geometry,  String name,  String type,  String origin,  String? id,  String? description,  double? distance)  $default,) {final _that = this;
switch (_that) {
case _WaypointDto():
return $default(_that.geometry,_that.name,_that.type,_that.origin,_that.id,_that.description,_that.distance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoJsonPoint geometry,  String name,  String type,  String origin,  String? id,  String? description,  double? distance)?  $default,) {final _that = this;
switch (_that) {
case _WaypointDto() when $default != null:
return $default(_that.geometry,_that.name,_that.type,_that.origin,_that.id,_that.description,_that.distance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WaypointDto implements WaypointDto {
  const _WaypointDto({required this.geometry, required this.name, required this.type, required this.origin, this.id, this.description, this.distance});
  factory _WaypointDto.fromJson(Map<String, dynamic> json) => _$WaypointDtoFromJson(json);

@override final  GeoJsonPoint geometry;
/// Name, possibly empty
@override final  String name;
/// What the waypoint is
@override final  String type;
/// Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's
@override final  String origin;
/// Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet
@override final  String? id;
/// Free text, at most 500 characters
@override final  String? description;
/// Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track
@override final  double? distance;

/// Create a copy of WaypointDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WaypointDtoCopyWith<_WaypointDto> get copyWith => __$WaypointDtoCopyWithImpl<_WaypointDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WaypointDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WaypointDto&&(identical(other.geometry, geometry) || other.geometry == geometry)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.distance, distance) || other.distance == distance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,geometry,name,type,origin,id,description,distance);
}

@override
String toString() {
    return 'WaypointDto(geometry: $geometry, name: $name, type: $type, origin: $origin, id: $id, description: $description, distance: $distance)';
}


}

/// @nodoc
abstract mixin class _$WaypointDtoCopyWith<$Res> implements $WaypointDtoCopyWith<$Res> {
  factory _$WaypointDtoCopyWith(_WaypointDto value, $Res Function(_WaypointDto) _then) = __$WaypointDtoCopyWithImpl;
@override @useResult
$Res call({
 GeoJsonPoint geometry, String name, String type, String origin, String? id, String? description, double? distance
});


@override $GeoJsonPointCopyWith<$Res> get geometry;

}
/// @nodoc
class __$WaypointDtoCopyWithImpl<$Res>
    implements _$WaypointDtoCopyWith<$Res> {
  __$WaypointDtoCopyWithImpl(this._self, this._then);

  final _WaypointDto _self;
  final $Res Function(_WaypointDto) _then;

/// Create a copy of WaypointDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? geometry = null,Object? name = null,Object? type = null,Object? origin = null,Object? id = freezed,Object? description = freezed,Object? distance = freezed,}) {
  return _then(_WaypointDto(
geometry: null == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as GeoJsonPoint,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of WaypointDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonPointCopyWith<$Res> get geometry {
  
  return $GeoJsonPointCopyWith<$Res>(_self.geometry, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}
}

// dart format on
