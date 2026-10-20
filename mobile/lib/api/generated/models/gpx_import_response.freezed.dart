// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gpx_import_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GpxImportResponse {

/// Name of the file: its metadata, else its first track, else its file name
 String get name;/// Tracks in the order of the file, 1 to 8
 List<GpxImportTrack> get tracks;/// Number of waypoints of the file (the first 500 are in waypoints)
 int get waypointCount;/// True when the elevations of a track could not all be read from the elevation source and part of them are the file's own
 bool get elevationFallback;/// The waypoints of the file, typed from their symbol, at most 500, in file order: imported, with no identifier and no distance (the server places them when the route is saved)
 List<WaypointDto>? get waypoints;
/// Create a copy of GpxImportResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpxImportResponseCopyWith<GpxImportResponse> get copyWith => _$GpxImportResponseCopyWithImpl<GpxImportResponse>(this as GpxImportResponse, _$identity);

  /// Serializes this GpxImportResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GpxImportResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpxImportResponse&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.tracks, _this.tracks)&&(identical(other.waypointCount, _this.waypointCount) || other.waypointCount == _this.waypointCount)&&(identical(other.elevationFallback, _this.elevationFallback) || other.elevationFallback == _this.elevationFallback)&&const DeepCollectionEquality().equals(other.waypoints, _this.waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GpxImportResponse;
  return Object.hash(runtimeType,_this.name,const DeepCollectionEquality().hash(_this.tracks),_this.waypointCount,_this.elevationFallback,const DeepCollectionEquality().hash(_this.waypoints));
}

@override
String toString() {
  final _this = this as GpxImportResponse;
  return 'GpxImportResponse(name: ${_this.name}, tracks: ${_this.tracks}, waypointCount: ${_this.waypointCount}, elevationFallback: ${_this.elevationFallback}, waypoints: ${_this.waypoints})';
}


}

/// @nodoc
abstract mixin class $GpxImportResponseCopyWith<$Res>  {
  factory $GpxImportResponseCopyWith(GpxImportResponse value, $Res Function(GpxImportResponse) _then) = _$GpxImportResponseCopyWithImpl;
@useResult
$Res call({
 String name, List<GpxImportTrack> tracks, int waypointCount, bool elevationFallback, List<WaypointDto>? waypoints
});




}
/// @nodoc
class _$GpxImportResponseCopyWithImpl<$Res>
    implements $GpxImportResponseCopyWith<$Res> {
  _$GpxImportResponseCopyWithImpl(this._self, this._then);

  final GpxImportResponse _self;
  final $Res Function(GpxImportResponse) _then;

/// Create a copy of GpxImportResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? tracks = null,Object? waypointCount = null,Object? elevationFallback = null,Object? waypoints = freezed,}) {
  return _then(GpxImportResponse(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<GpxImportTrack>,waypointCount: null == waypointCount ? _self.waypointCount : waypointCount // ignore: cast_nullable_to_non_nullable
as int,elevationFallback: null == elevationFallback ? _self.elevationFallback : elevationFallback // ignore: cast_nullable_to_non_nullable
as bool,waypoints: freezed == waypoints ? _self.waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointDto>?,
  ));
}

}


/// Adds pattern-matching-related methods to [GpxImportResponse].
extension GpxImportResponsePatterns on GpxImportResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpxImportResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpxImportResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpxImportResponse value)  $default,){
final _that = this;
switch (_that) {
case _GpxImportResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpxImportResponse value)?  $default,){
final _that = this;
switch (_that) {
case _GpxImportResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  List<GpxImportTrack> tracks,  int waypointCount,  bool elevationFallback,  List<WaypointDto>? waypoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpxImportResponse() when $default != null:
return $default(_that.name,_that.tracks,_that.waypointCount,_that.elevationFallback,_that.waypoints);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  List<GpxImportTrack> tracks,  int waypointCount,  bool elevationFallback,  List<WaypointDto>? waypoints)  $default,) {final _that = this;
switch (_that) {
case _GpxImportResponse():
return $default(_that.name,_that.tracks,_that.waypointCount,_that.elevationFallback,_that.waypoints);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  List<GpxImportTrack> tracks,  int waypointCount,  bool elevationFallback,  List<WaypointDto>? waypoints)?  $default,) {final _that = this;
switch (_that) {
case _GpxImportResponse() when $default != null:
return $default(_that.name,_that.tracks,_that.waypointCount,_that.elevationFallback,_that.waypoints);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpxImportResponse implements GpxImportResponse {
  const _GpxImportResponse({required this.name, required  List<GpxImportTrack> tracks, required this.waypointCount, required this.elevationFallback,  List<WaypointDto>? waypoints}): _tracks = tracks,_waypoints = waypoints;
  factory _GpxImportResponse.fromJson(Map<String, dynamic> json) => _$GpxImportResponseFromJson(json);

/// Name of the file: its metadata, else its first track, else its file name
@override final  String name;
/// Tracks in the order of the file, 1 to 8
 final  List<GpxImportTrack> _tracks;
/// Tracks in the order of the file, 1 to 8
@override List<GpxImportTrack> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}

/// Number of waypoints of the file (the first 500 are in waypoints)
@override final  int waypointCount;
/// True when the elevations of a track could not all be read from the elevation source and part of them are the file's own
@override final  bool elevationFallback;
/// The waypoints of the file, typed from their symbol, at most 500, in file order: imported, with no identifier and no distance (the server places them when the route is saved)
 final  List<WaypointDto>? _waypoints;
/// The waypoints of the file, typed from their symbol, at most 500, in file order: imported, with no identifier and no distance (the server places them when the route is saved)
@override List<WaypointDto>? get waypoints {
  final value = _waypoints;
  if (value == null) return null;
  if (_waypoints is EqualUnmodifiableListView) return _waypoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of GpxImportResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpxImportResponseCopyWith<_GpxImportResponse> get copyWith => __$GpxImportResponseCopyWithImpl<_GpxImportResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpxImportResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpxImportResponse&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.tracks, _tracks)&&(identical(other.waypointCount, waypointCount) || other.waypointCount == waypointCount)&&(identical(other.elevationFallback, elevationFallback) || other.elevationFallback == elevationFallback)&&const DeepCollectionEquality().equals(other.waypoints, _waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_tracks),waypointCount,elevationFallback,const DeepCollectionEquality().hash(_waypoints));
}

@override
String toString() {
    return 'GpxImportResponse(name: $name, tracks: $tracks, waypointCount: $waypointCount, elevationFallback: $elevationFallback, waypoints: $waypoints)';
}


}

/// @nodoc
abstract mixin class _$GpxImportResponseCopyWith<$Res> implements $GpxImportResponseCopyWith<$Res> {
  factory _$GpxImportResponseCopyWith(_GpxImportResponse value, $Res Function(_GpxImportResponse) _then) = __$GpxImportResponseCopyWithImpl;
@override @useResult
$Res call({
 String name, List<GpxImportTrack> tracks, int waypointCount, bool elevationFallback, List<WaypointDto>? waypoints
});




}
/// @nodoc
class __$GpxImportResponseCopyWithImpl<$Res>
    implements _$GpxImportResponseCopyWith<$Res> {
  __$GpxImportResponseCopyWithImpl(this._self, this._then);

  final _GpxImportResponse _self;
  final $Res Function(_GpxImportResponse) _then;

/// Create a copy of GpxImportResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? tracks = null,Object? waypointCount = null,Object? elevationFallback = null,Object? waypoints = freezed,}) {
  return _then(_GpxImportResponse(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tracks: null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<GpxImportTrack>,waypointCount: null == waypointCount ? _self.waypointCount : waypointCount // ignore: cast_nullable_to_non_nullable
as int,elevationFallback: null == elevationFallback ? _self.elevationFallback : elevationFallback // ignore: cast_nullable_to_non_nullable
as bool,waypoints: freezed == waypoints ? _self._waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointDto>?,
  ));
}


}

// dart format on
