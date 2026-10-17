// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gpx_preview_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GpxPreviewDto {

/// Public identifier used in URLs
 String get id;/// Track name
 String get name;/// Distance in meters
 double get distance;/// Total elevation gain in meters
 double get elevationGain;/// Total elevation loss in meters
 double get elevationLoss;/// Elevation gain per kilometer
 double get hilliness;/// Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.
 String get elevationState;/// Whether the current user created this preview
 bool get owned;/// Creation timestamp
 String get createdAt;/// URL to download the analysed GPX file
 String get gpxUrl;/// URL to download the analysed track as a FIT file
 String get fitUrl;/// Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown
 bool get drawn;/// Tracks
 List<TrackDto> get tracks;/// Waypoints
 List<WaypointDto> get waypoints;/// Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;
/// Create a copy of GpxPreviewDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpxPreviewDtoCopyWith<GpxPreviewDto> get copyWith => _$GpxPreviewDtoCopyWithImpl<GpxPreviewDto>(this as GpxPreviewDto, _$identity);

  /// Serializes this GpxPreviewDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GpxPreviewDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpxPreviewDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.elevationLoss, _this.elevationLoss) || other.elevationLoss == _this.elevationLoss)&&(identical(other.hilliness, _this.hilliness) || other.hilliness == _this.hilliness)&&(identical(other.elevationState, _this.elevationState) || other.elevationState == _this.elevationState)&&(identical(other.owned, _this.owned) || other.owned == _this.owned)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.gpxUrl, _this.gpxUrl) || other.gpxUrl == _this.gpxUrl)&&(identical(other.fitUrl, _this.fitUrl) || other.fitUrl == _this.fitUrl)&&(identical(other.drawn, _this.drawn) || other.drawn == _this.drawn)&&const DeepCollectionEquality().equals(other.tracks, _this.tracks)&&const DeepCollectionEquality().equals(other.waypoints, _this.waypoints)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GpxPreviewDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.distance,_this.elevationGain,_this.elevationLoss,_this.hilliness,_this.elevationState,_this.owned,_this.createdAt,_this.gpxUrl,_this.fitUrl,_this.drawn,const DeepCollectionEquality().hash(_this.tracks),const DeepCollectionEquality().hash(_this.waypoints),_this.thumbnailUrl);
}

@override
String toString() {
  final _this = this as GpxPreviewDto;
  return 'GpxPreviewDto(id: ${_this.id}, name: ${_this.name}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, elevationLoss: ${_this.elevationLoss}, hilliness: ${_this.hilliness}, elevationState: ${_this.elevationState}, owned: ${_this.owned}, createdAt: ${_this.createdAt}, gpxUrl: ${_this.gpxUrl}, fitUrl: ${_this.fitUrl}, drawn: ${_this.drawn}, tracks: ${_this.tracks}, waypoints: ${_this.waypoints}, thumbnailUrl: ${_this.thumbnailUrl})';
}


}

/// @nodoc
abstract mixin class $GpxPreviewDtoCopyWith<$Res>  {
  factory $GpxPreviewDtoCopyWith(GpxPreviewDto value, $Res Function(GpxPreviewDto) _then) = _$GpxPreviewDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, double distance, double elevationGain, double elevationLoss, double hilliness, String elevationState, bool owned, String createdAt, String gpxUrl, String fitUrl, bool drawn, List<TrackDto> tracks, List<WaypointDto> waypoints, String? thumbnailUrl
});




}
/// @nodoc
class _$GpxPreviewDtoCopyWithImpl<$Res>
    implements $GpxPreviewDtoCopyWith<$Res> {
  _$GpxPreviewDtoCopyWithImpl(this._self, this._then);

  final GpxPreviewDto _self;
  final $Res Function(GpxPreviewDto) _then;

/// Create a copy of GpxPreviewDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? hilliness = null,Object? elevationState = null,Object? owned = null,Object? createdAt = null,Object? gpxUrl = null,Object? fitUrl = null,Object? drawn = null,Object? tracks = null,Object? waypoints = null,Object? thumbnailUrl = freezed,}) {
  return _then(GpxPreviewDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,elevationLoss: null == elevationLoss ? _self.elevationLoss : elevationLoss // ignore: cast_nullable_to_non_nullable
as double,hilliness: null == hilliness ? _self.hilliness : hilliness // ignore: cast_nullable_to_non_nullable
as double,elevationState: null == elevationState ? _self.elevationState : elevationState // ignore: cast_nullable_to_non_nullable
as String,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,gpxUrl: null == gpxUrl ? _self.gpxUrl : gpxUrl // ignore: cast_nullable_to_non_nullable
as String,fitUrl: null == fitUrl ? _self.fitUrl : fitUrl // ignore: cast_nullable_to_non_nullable
as String,drawn: null == drawn ? _self.drawn : drawn // ignore: cast_nullable_to_non_nullable
as bool,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<TrackDto>,waypoints: null == waypoints ? _self.waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointDto>,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GpxPreviewDto].
extension GpxPreviewDtoPatterns on GpxPreviewDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpxPreviewDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpxPreviewDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpxPreviewDto value)  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpxPreviewDto value)?  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double distance,  double elevationGain,  double elevationLoss,  double hilliness,  String elevationState,  bool owned,  String createdAt,  String gpxUrl,  String fitUrl,  bool drawn,  List<TrackDto> tracks,  List<WaypointDto> waypoints,  String? thumbnailUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpxPreviewDto() when $default != null:
return $default(_that.id,_that.name,_that.distance,_that.elevationGain,_that.elevationLoss,_that.hilliness,_that.elevationState,_that.owned,_that.createdAt,_that.gpxUrl,_that.fitUrl,_that.drawn,_that.tracks,_that.waypoints,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double distance,  double elevationGain,  double elevationLoss,  double hilliness,  String elevationState,  bool owned,  String createdAt,  String gpxUrl,  String fitUrl,  bool drawn,  List<TrackDto> tracks,  List<WaypointDto> waypoints,  String? thumbnailUrl)  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewDto():
return $default(_that.id,_that.name,_that.distance,_that.elevationGain,_that.elevationLoss,_that.hilliness,_that.elevationState,_that.owned,_that.createdAt,_that.gpxUrl,_that.fitUrl,_that.drawn,_that.tracks,_that.waypoints,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double distance,  double elevationGain,  double elevationLoss,  double hilliness,  String elevationState,  bool owned,  String createdAt,  String gpxUrl,  String fitUrl,  bool drawn,  List<TrackDto> tracks,  List<WaypointDto> waypoints,  String? thumbnailUrl)?  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewDto() when $default != null:
return $default(_that.id,_that.name,_that.distance,_that.elevationGain,_that.elevationLoss,_that.hilliness,_that.elevationState,_that.owned,_that.createdAt,_that.gpxUrl,_that.fitUrl,_that.drawn,_that.tracks,_that.waypoints,_that.thumbnailUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpxPreviewDto implements GpxPreviewDto {
  const _GpxPreviewDto({required this.id, required this.name, required this.distance, required this.elevationGain, required this.elevationLoss, required this.hilliness, required this.elevationState, required this.owned, required this.createdAt, required this.gpxUrl, required this.fitUrl, required this.drawn, required  List<TrackDto> tracks, required  List<WaypointDto> waypoints, this.thumbnailUrl}): _tracks = tracks,_waypoints = waypoints;
  factory _GpxPreviewDto.fromJson(Map<String, dynamic> json) => _$GpxPreviewDtoFromJson(json);

/// Public identifier used in URLs
@override final  String id;
/// Track name
@override final  String name;
/// Distance in meters
@override final  double distance;
/// Total elevation gain in meters
@override final  double elevationGain;
/// Total elevation loss in meters
@override final  double elevationLoss;
/// Elevation gain per kilometer
@override final  double hilliness;
/// Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.
@override final  String elevationState;
/// Whether the current user created this preview
@override final  bool owned;
/// Creation timestamp
@override final  String createdAt;
/// URL to download the analysed GPX file
@override final  String gpxUrl;
/// URL to download the analysed track as a FIT file
@override final  String fitUrl;
/// Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown
@override final  bool drawn;
/// Tracks
 final  List<TrackDto> _tracks;
/// Tracks
@override List<TrackDto> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}

/// Waypoints
 final  List<WaypointDto> _waypoints;
/// Waypoints
@override List<WaypointDto> get waypoints {
  if (_waypoints is EqualUnmodifiableListView) return _waypoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_waypoints);
}

/// Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;

/// Create a copy of GpxPreviewDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpxPreviewDtoCopyWith<_GpxPreviewDto> get copyWith => __$GpxPreviewDtoCopyWithImpl<_GpxPreviewDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpxPreviewDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpxPreviewDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.elevationLoss, elevationLoss) || other.elevationLoss == elevationLoss)&&(identical(other.hilliness, hilliness) || other.hilliness == hilliness)&&(identical(other.elevationState, elevationState) || other.elevationState == elevationState)&&(identical(other.owned, owned) || other.owned == owned)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.gpxUrl, gpxUrl) || other.gpxUrl == gpxUrl)&&(identical(other.fitUrl, fitUrl) || other.fitUrl == fitUrl)&&(identical(other.drawn, drawn) || other.drawn == drawn)&&const DeepCollectionEquality().equals(other.tracks, _tracks)&&const DeepCollectionEquality().equals(other.waypoints, _waypoints)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,distance,elevationGain,elevationLoss,hilliness,elevationState,owned,createdAt,gpxUrl,fitUrl,drawn,const DeepCollectionEquality().hash(_tracks),const DeepCollectionEquality().hash(_waypoints),thumbnailUrl);
}

@override
String toString() {
    return 'GpxPreviewDto(id: $id, name: $name, distance: $distance, elevationGain: $elevationGain, elevationLoss: $elevationLoss, hilliness: $hilliness, elevationState: $elevationState, owned: $owned, createdAt: $createdAt, gpxUrl: $gpxUrl, fitUrl: $fitUrl, drawn: $drawn, tracks: $tracks, waypoints: $waypoints, thumbnailUrl: $thumbnailUrl)';
}


}

/// @nodoc
abstract mixin class _$GpxPreviewDtoCopyWith<$Res> implements $GpxPreviewDtoCopyWith<$Res> {
  factory _$GpxPreviewDtoCopyWith(_GpxPreviewDto value, $Res Function(_GpxPreviewDto) _then) = __$GpxPreviewDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double distance, double elevationGain, double elevationLoss, double hilliness, String elevationState, bool owned, String createdAt, String gpxUrl, String fitUrl, bool drawn, List<TrackDto> tracks, List<WaypointDto> waypoints, String? thumbnailUrl
});




}
/// @nodoc
class __$GpxPreviewDtoCopyWithImpl<$Res>
    implements _$GpxPreviewDtoCopyWith<$Res> {
  __$GpxPreviewDtoCopyWithImpl(this._self, this._then);

  final _GpxPreviewDto _self;
  final $Res Function(_GpxPreviewDto) _then;

/// Create a copy of GpxPreviewDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? hilliness = null,Object? elevationState = null,Object? owned = null,Object? createdAt = null,Object? gpxUrl = null,Object? fitUrl = null,Object? drawn = null,Object? tracks = null,Object? waypoints = null,Object? thumbnailUrl = freezed,}) {
  return _then(_GpxPreviewDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,elevationLoss: null == elevationLoss ? _self.elevationLoss : elevationLoss // ignore: cast_nullable_to_non_nullable
as double,hilliness: null == hilliness ? _self.hilliness : hilliness // ignore: cast_nullable_to_non_nullable
as double,elevationState: null == elevationState ? _self.elevationState : elevationState // ignore: cast_nullable_to_non_nullable
as String,owned: null == owned ? _self.owned : owned // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,gpxUrl: null == gpxUrl ? _self.gpxUrl : gpxUrl // ignore: cast_nullable_to_non_nullable
as String,fitUrl: null == fitUrl ? _self.fitUrl : fitUrl // ignore: cast_nullable_to_non_nullable
as String,drawn: null == drawn ? _self.drawn : drawn // ignore: cast_nullable_to_non_nullable
as bool,tracks: null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<TrackDto>,waypoints: null == waypoints ? _self._waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointDto>,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
