// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'generated_route_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GeneratedRouteDto {

/// Geometry as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import
 String get polyline;/// Distance in metres
 double get distanceM;/// Share of the distance on the team's roads, short gaps between them included, 0 to 1
 double get teamShare;/// Share of the distance on unpaved roads, 0 to 1
 double get unpavedShare;/// Metres ridden twice (the way to and from the loop), counted once
 double get sharedM;/// Junctions crossed more than once outside the shared part
 int get crossings;/// Map frame of the route
 BoundsDto get bounds;/// Elevation gain in metres. Absent when the profile was not ready in time: the editor computes it
 double? get ascentM;/// Elevation loss in metres. Absent like the gain
 double? get descentM;/// Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply
 double? get bearingDeviationDeg;
/// Create a copy of GeneratedRouteDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeneratedRouteDtoCopyWith<GeneratedRouteDto> get copyWith => _$GeneratedRouteDtoCopyWithImpl<GeneratedRouteDto>(this as GeneratedRouteDto, _$identity);

  /// Serializes this GeneratedRouteDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GeneratedRouteDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeneratedRouteDto&&(identical(other.polyline, _this.polyline) || other.polyline == _this.polyline)&&(identical(other.distanceM, _this.distanceM) || other.distanceM == _this.distanceM)&&(identical(other.teamShare, _this.teamShare) || other.teamShare == _this.teamShare)&&(identical(other.unpavedShare, _this.unpavedShare) || other.unpavedShare == _this.unpavedShare)&&(identical(other.sharedM, _this.sharedM) || other.sharedM == _this.sharedM)&&(identical(other.crossings, _this.crossings) || other.crossings == _this.crossings)&&(identical(other.bounds, _this.bounds) || other.bounds == _this.bounds)&&(identical(other.ascentM, _this.ascentM) || other.ascentM == _this.ascentM)&&(identical(other.descentM, _this.descentM) || other.descentM == _this.descentM)&&(identical(other.bearingDeviationDeg, _this.bearingDeviationDeg) || other.bearingDeviationDeg == _this.bearingDeviationDeg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GeneratedRouteDto;
  return Object.hash(runtimeType,_this.polyline,_this.distanceM,_this.teamShare,_this.unpavedShare,_this.sharedM,_this.crossings,_this.bounds,_this.ascentM,_this.descentM,_this.bearingDeviationDeg);
}

@override
String toString() {
  final _this = this as GeneratedRouteDto;
  return 'GeneratedRouteDto(polyline: ${_this.polyline}, distanceM: ${_this.distanceM}, teamShare: ${_this.teamShare}, unpavedShare: ${_this.unpavedShare}, sharedM: ${_this.sharedM}, crossings: ${_this.crossings}, bounds: ${_this.bounds}, ascentM: ${_this.ascentM}, descentM: ${_this.descentM}, bearingDeviationDeg: ${_this.bearingDeviationDeg})';
}


}

/// @nodoc
abstract mixin class $GeneratedRouteDtoCopyWith<$Res>  {
  factory $GeneratedRouteDtoCopyWith(GeneratedRouteDto value, $Res Function(GeneratedRouteDto) _then) = _$GeneratedRouteDtoCopyWithImpl;
@useResult
$Res call({
 String polyline, double distanceM, double teamShare, double unpavedShare, double sharedM, int crossings, BoundsDto bounds, double? ascentM, double? descentM, double? bearingDeviationDeg
});


$BoundsDtoCopyWith<$Res> get bounds;

}
/// @nodoc
class _$GeneratedRouteDtoCopyWithImpl<$Res>
    implements $GeneratedRouteDtoCopyWith<$Res> {
  _$GeneratedRouteDtoCopyWithImpl(this._self, this._then);

  final GeneratedRouteDto _self;
  final $Res Function(GeneratedRouteDto) _then;

/// Create a copy of GeneratedRouteDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? polyline = null,Object? distanceM = null,Object? teamShare = null,Object? unpavedShare = null,Object? sharedM = null,Object? crossings = null,Object? bounds = null,Object? ascentM = freezed,Object? descentM = freezed,Object? bearingDeviationDeg = freezed,}) {
  return _then(GeneratedRouteDto(
polyline: null == polyline ? _self.polyline : polyline // ignore: cast_nullable_to_non_nullable
as String,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,teamShare: null == teamShare ? _self.teamShare : teamShare // ignore: cast_nullable_to_non_nullable
as double,unpavedShare: null == unpavedShare ? _self.unpavedShare : unpavedShare // ignore: cast_nullable_to_non_nullable
as double,sharedM: null == sharedM ? _self.sharedM : sharedM // ignore: cast_nullable_to_non_nullable
as double,crossings: null == crossings ? _self.crossings : crossings // ignore: cast_nullable_to_non_nullable
as int,bounds: null == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as BoundsDto,ascentM: freezed == ascentM ? _self.ascentM : ascentM // ignore: cast_nullable_to_non_nullable
as double?,descentM: freezed == descentM ? _self.descentM : descentM // ignore: cast_nullable_to_non_nullable
as double?,bearingDeviationDeg: freezed == bearingDeviationDeg ? _self.bearingDeviationDeg : bearingDeviationDeg // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of GeneratedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BoundsDtoCopyWith<$Res> get bounds {
  
  return $BoundsDtoCopyWith<$Res>(_self.bounds, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}
}


/// Adds pattern-matching-related methods to [GeneratedRouteDto].
extension GeneratedRouteDtoPatterns on GeneratedRouteDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeneratedRouteDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeneratedRouteDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeneratedRouteDto value)  $default,){
final _that = this;
switch (_that) {
case _GeneratedRouteDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeneratedRouteDto value)?  $default,){
final _that = this;
switch (_that) {
case _GeneratedRouteDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String polyline,  double distanceM,  double teamShare,  double unpavedShare,  double sharedM,  int crossings,  BoundsDto bounds,  double? ascentM,  double? descentM,  double? bearingDeviationDeg)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeneratedRouteDto() when $default != null:
return $default(_that.polyline,_that.distanceM,_that.teamShare,_that.unpavedShare,_that.sharedM,_that.crossings,_that.bounds,_that.ascentM,_that.descentM,_that.bearingDeviationDeg);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String polyline,  double distanceM,  double teamShare,  double unpavedShare,  double sharedM,  int crossings,  BoundsDto bounds,  double? ascentM,  double? descentM,  double? bearingDeviationDeg)  $default,) {final _that = this;
switch (_that) {
case _GeneratedRouteDto():
return $default(_that.polyline,_that.distanceM,_that.teamShare,_that.unpavedShare,_that.sharedM,_that.crossings,_that.bounds,_that.ascentM,_that.descentM,_that.bearingDeviationDeg);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String polyline,  double distanceM,  double teamShare,  double unpavedShare,  double sharedM,  int crossings,  BoundsDto bounds,  double? ascentM,  double? descentM,  double? bearingDeviationDeg)?  $default,) {final _that = this;
switch (_that) {
case _GeneratedRouteDto() when $default != null:
return $default(_that.polyline,_that.distanceM,_that.teamShare,_that.unpavedShare,_that.sharedM,_that.crossings,_that.bounds,_that.ascentM,_that.descentM,_that.bearingDeviationDeg);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeneratedRouteDto implements GeneratedRouteDto {
  const _GeneratedRouteDto({required this.polyline, required this.distanceM, required this.teamShare, required this.unpavedShare, required this.sharedM, required this.crossings, required this.bounds, this.ascentM, this.descentM, this.bearingDeviationDeg});
  factory _GeneratedRouteDto.fromJson(Map<String, dynamic> json) => _$GeneratedRouteDtoFromJson(json);

/// Geometry as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import
@override final  String polyline;
/// Distance in metres
@override final  double distanceM;
/// Share of the distance on the team's roads, short gaps between them included, 0 to 1
@override final  double teamShare;
/// Share of the distance on unpaved roads, 0 to 1
@override final  double unpavedShare;
/// Metres ridden twice (the way to and from the loop), counted once
@override final  double sharedM;
/// Junctions crossed more than once outside the shared part
@override final  int crossings;
/// Map frame of the route
@override final  BoundsDto bounds;
/// Elevation gain in metres. Absent when the profile was not ready in time: the editor computes it
@override final  double? ascentM;
/// Elevation loss in metres. Absent like the gain
@override final  double? descentM;
/// Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply
@override final  double? bearingDeviationDeg;

/// Create a copy of GeneratedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeneratedRouteDtoCopyWith<_GeneratedRouteDto> get copyWith => __$GeneratedRouteDtoCopyWithImpl<_GeneratedRouteDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeneratedRouteDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeneratedRouteDto&&(identical(other.polyline, polyline) || other.polyline == polyline)&&(identical(other.distanceM, distanceM) || other.distanceM == distanceM)&&(identical(other.teamShare, teamShare) || other.teamShare == teamShare)&&(identical(other.unpavedShare, unpavedShare) || other.unpavedShare == unpavedShare)&&(identical(other.sharedM, sharedM) || other.sharedM == sharedM)&&(identical(other.crossings, crossings) || other.crossings == crossings)&&(identical(other.bounds, bounds) || other.bounds == bounds)&&(identical(other.ascentM, ascentM) || other.ascentM == ascentM)&&(identical(other.descentM, descentM) || other.descentM == descentM)&&(identical(other.bearingDeviationDeg, bearingDeviationDeg) || other.bearingDeviationDeg == bearingDeviationDeg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,polyline,distanceM,teamShare,unpavedShare,sharedM,crossings,bounds,ascentM,descentM,bearingDeviationDeg);
}

@override
String toString() {
    return 'GeneratedRouteDto(polyline: $polyline, distanceM: $distanceM, teamShare: $teamShare, unpavedShare: $unpavedShare, sharedM: $sharedM, crossings: $crossings, bounds: $bounds, ascentM: $ascentM, descentM: $descentM, bearingDeviationDeg: $bearingDeviationDeg)';
}


}

/// @nodoc
abstract mixin class _$GeneratedRouteDtoCopyWith<$Res> implements $GeneratedRouteDtoCopyWith<$Res> {
  factory _$GeneratedRouteDtoCopyWith(_GeneratedRouteDto value, $Res Function(_GeneratedRouteDto) _then) = __$GeneratedRouteDtoCopyWithImpl;
@override @useResult
$Res call({
 String polyline, double distanceM, double teamShare, double unpavedShare, double sharedM, int crossings, BoundsDto bounds, double? ascentM, double? descentM, double? bearingDeviationDeg
});


@override $BoundsDtoCopyWith<$Res> get bounds;

}
/// @nodoc
class __$GeneratedRouteDtoCopyWithImpl<$Res>
    implements _$GeneratedRouteDtoCopyWith<$Res> {
  __$GeneratedRouteDtoCopyWithImpl(this._self, this._then);

  final _GeneratedRouteDto _self;
  final $Res Function(_GeneratedRouteDto) _then;

/// Create a copy of GeneratedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? polyline = null,Object? distanceM = null,Object? teamShare = null,Object? unpavedShare = null,Object? sharedM = null,Object? crossings = null,Object? bounds = null,Object? ascentM = freezed,Object? descentM = freezed,Object? bearingDeviationDeg = freezed,}) {
  return _then(_GeneratedRouteDto(
polyline: null == polyline ? _self.polyline : polyline // ignore: cast_nullable_to_non_nullable
as String,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,teamShare: null == teamShare ? _self.teamShare : teamShare // ignore: cast_nullable_to_non_nullable
as double,unpavedShare: null == unpavedShare ? _self.unpavedShare : unpavedShare // ignore: cast_nullable_to_non_nullable
as double,sharedM: null == sharedM ? _self.sharedM : sharedM // ignore: cast_nullable_to_non_nullable
as double,crossings: null == crossings ? _self.crossings : crossings // ignore: cast_nullable_to_non_nullable
as int,bounds: null == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as BoundsDto,ascentM: freezed == ascentM ? _self.ascentM : ascentM // ignore: cast_nullable_to_non_nullable
as double?,descentM: freezed == descentM ? _self.descentM : descentM // ignore: cast_nullable_to_non_nullable
as double?,bearingDeviationDeg: freezed == bearingDeviationDeg ? _self.bearingDeviationDeg : bearingDeviationDeg // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of GeneratedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BoundsDtoCopyWith<$Res> get bounds {
  
  return $BoundsDtoCopyWith<$Res>(_self.bounds, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}
}

// dart format on
