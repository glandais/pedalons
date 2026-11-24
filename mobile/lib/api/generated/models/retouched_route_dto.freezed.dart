// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'retouched_route_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RetouchedRouteDto {

/// The WHOLE retouched route as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import
 String get polyline;/// Distance in metres
 double get distanceM;/// What changed
 String get kind;/// Share of the original route kept as it was drawn, 0 to 1
 double get keptShare;/// Metres of the kept parts that the engine could not match to its map: there, the route may ride a road twice and nothing was checked
 double get unmatchedM;/// The stretch that changed
 RetouchedSpanDto get changed;/// Map frame of the whole route
 BoundsDto get bounds;/// Elevation gain in metres, measured as the original's (originalAscentM). Absent when the profile was not ready in time
 double? get ascentM;/// Elevation loss in metres. Absent like the gain
 double? get descentM;/// Which choice a MOVE_END route makes. Absent for the others
 String? get variant;/// MOVE_END and TRUNCATE: distance in metres from the asked finish to the last point of the route
 double? get endSnapM;
/// Create a copy of RetouchedRouteDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RetouchedRouteDtoCopyWith<RetouchedRouteDto> get copyWith => _$RetouchedRouteDtoCopyWithImpl<RetouchedRouteDto>(this as RetouchedRouteDto, _$identity);

  /// Serializes this RetouchedRouteDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RetouchedRouteDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RetouchedRouteDto&&(identical(other.polyline, _this.polyline) || other.polyline == _this.polyline)&&(identical(other.distanceM, _this.distanceM) || other.distanceM == _this.distanceM)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.keptShare, _this.keptShare) || other.keptShare == _this.keptShare)&&(identical(other.unmatchedM, _this.unmatchedM) || other.unmatchedM == _this.unmatchedM)&&(identical(other.changed, _this.changed) || other.changed == _this.changed)&&(identical(other.bounds, _this.bounds) || other.bounds == _this.bounds)&&(identical(other.ascentM, _this.ascentM) || other.ascentM == _this.ascentM)&&(identical(other.descentM, _this.descentM) || other.descentM == _this.descentM)&&(identical(other.variant, _this.variant) || other.variant == _this.variant)&&(identical(other.endSnapM, _this.endSnapM) || other.endSnapM == _this.endSnapM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RetouchedRouteDto;
  return Object.hash(runtimeType,_this.polyline,_this.distanceM,_this.kind,_this.keptShare,_this.unmatchedM,_this.changed,_this.bounds,_this.ascentM,_this.descentM,_this.variant,_this.endSnapM);
}

@override
String toString() {
  final _this = this as RetouchedRouteDto;
  return 'RetouchedRouteDto(polyline: ${_this.polyline}, distanceM: ${_this.distanceM}, kind: ${_this.kind}, keptShare: ${_this.keptShare}, unmatchedM: ${_this.unmatchedM}, changed: ${_this.changed}, bounds: ${_this.bounds}, ascentM: ${_this.ascentM}, descentM: ${_this.descentM}, variant: ${_this.variant}, endSnapM: ${_this.endSnapM})';
}


}

/// @nodoc
abstract mixin class $RetouchedRouteDtoCopyWith<$Res>  {
  factory $RetouchedRouteDtoCopyWith(RetouchedRouteDto value, $Res Function(RetouchedRouteDto) _then) = _$RetouchedRouteDtoCopyWithImpl;
@useResult
$Res call({
 String polyline, double distanceM, String kind, double keptShare, double unmatchedM, RetouchedSpanDto changed, BoundsDto bounds, double? ascentM, double? descentM, String? variant, double? endSnapM
});


$RetouchedSpanDtoCopyWith<$Res> get changed;$BoundsDtoCopyWith<$Res> get bounds;

}
/// @nodoc
class _$RetouchedRouteDtoCopyWithImpl<$Res>
    implements $RetouchedRouteDtoCopyWith<$Res> {
  _$RetouchedRouteDtoCopyWithImpl(this._self, this._then);

  final RetouchedRouteDto _self;
  final $Res Function(RetouchedRouteDto) _then;

/// Create a copy of RetouchedRouteDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? polyline = null,Object? distanceM = null,Object? kind = null,Object? keptShare = null,Object? unmatchedM = null,Object? changed = null,Object? bounds = null,Object? ascentM = freezed,Object? descentM = freezed,Object? variant = freezed,Object? endSnapM = freezed,}) {
  return _then(RetouchedRouteDto(
polyline: null == polyline ? _self.polyline : polyline // ignore: cast_nullable_to_non_nullable
as String,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,keptShare: null == keptShare ? _self.keptShare : keptShare // ignore: cast_nullable_to_non_nullable
as double,unmatchedM: null == unmatchedM ? _self.unmatchedM : unmatchedM // ignore: cast_nullable_to_non_nullable
as double,changed: null == changed ? _self.changed : changed // ignore: cast_nullable_to_non_nullable
as RetouchedSpanDto,bounds: null == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as BoundsDto,ascentM: freezed == ascentM ? _self.ascentM : ascentM // ignore: cast_nullable_to_non_nullable
as double?,descentM: freezed == descentM ? _self.descentM : descentM // ignore: cast_nullable_to_non_nullable
as double?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,endSnapM: freezed == endSnapM ? _self.endSnapM : endSnapM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of RetouchedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RetouchedSpanDtoCopyWith<$Res> get changed {
  
  return $RetouchedSpanDtoCopyWith<$Res>(_self.changed, (value) {
    return _then(_self.copyWith(changed: value));
  });
}/// Create a copy of RetouchedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BoundsDtoCopyWith<$Res> get bounds {
  
  return $BoundsDtoCopyWith<$Res>(_self.bounds, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}
}


/// Adds pattern-matching-related methods to [RetouchedRouteDto].
extension RetouchedRouteDtoPatterns on RetouchedRouteDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RetouchedRouteDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RetouchedRouteDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RetouchedRouteDto value)  $default,){
final _that = this;
switch (_that) {
case _RetouchedRouteDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RetouchedRouteDto value)?  $default,){
final _that = this;
switch (_that) {
case _RetouchedRouteDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String polyline,  double distanceM,  String kind,  double keptShare,  double unmatchedM,  RetouchedSpanDto changed,  BoundsDto bounds,  double? ascentM,  double? descentM,  String? variant,  double? endSnapM)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RetouchedRouteDto() when $default != null:
return $default(_that.polyline,_that.distanceM,_that.kind,_that.keptShare,_that.unmatchedM,_that.changed,_that.bounds,_that.ascentM,_that.descentM,_that.variant,_that.endSnapM);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String polyline,  double distanceM,  String kind,  double keptShare,  double unmatchedM,  RetouchedSpanDto changed,  BoundsDto bounds,  double? ascentM,  double? descentM,  String? variant,  double? endSnapM)  $default,) {final _that = this;
switch (_that) {
case _RetouchedRouteDto():
return $default(_that.polyline,_that.distanceM,_that.kind,_that.keptShare,_that.unmatchedM,_that.changed,_that.bounds,_that.ascentM,_that.descentM,_that.variant,_that.endSnapM);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String polyline,  double distanceM,  String kind,  double keptShare,  double unmatchedM,  RetouchedSpanDto changed,  BoundsDto bounds,  double? ascentM,  double? descentM,  String? variant,  double? endSnapM)?  $default,) {final _that = this;
switch (_that) {
case _RetouchedRouteDto() when $default != null:
return $default(_that.polyline,_that.distanceM,_that.kind,_that.keptShare,_that.unmatchedM,_that.changed,_that.bounds,_that.ascentM,_that.descentM,_that.variant,_that.endSnapM);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RetouchedRouteDto implements RetouchedRouteDto {
  const _RetouchedRouteDto({required this.polyline, required this.distanceM, required this.kind, required this.keptShare, required this.unmatchedM, required this.changed, required this.bounds, this.ascentM, this.descentM, this.variant, this.endSnapM});
  factory _RetouchedRouteDto.fromJson(Map<String, dynamic> json) => _$RetouchedRouteDtoFromJson(json);

/// The WHOLE retouched route as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import
@override final  String polyline;
/// Distance in metres
@override final  double distanceM;
/// What changed
@override final  String kind;
/// Share of the original route kept as it was drawn, 0 to 1
@override final  double keptShare;
/// Metres of the kept parts that the engine could not match to its map: there, the route may ride a road twice and nothing was checked
@override final  double unmatchedM;
/// The stretch that changed
@override final  RetouchedSpanDto changed;
/// Map frame of the whole route
@override final  BoundsDto bounds;
/// Elevation gain in metres, measured as the original's (originalAscentM). Absent when the profile was not ready in time
@override final  double? ascentM;
/// Elevation loss in metres. Absent like the gain
@override final  double? descentM;
/// Which choice a MOVE_END route makes. Absent for the others
@override final  String? variant;
/// MOVE_END and TRUNCATE: distance in metres from the asked finish to the last point of the route
@override final  double? endSnapM;

/// Create a copy of RetouchedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RetouchedRouteDtoCopyWith<_RetouchedRouteDto> get copyWith => __$RetouchedRouteDtoCopyWithImpl<_RetouchedRouteDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RetouchedRouteDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RetouchedRouteDto&&(identical(other.polyline, polyline) || other.polyline == polyline)&&(identical(other.distanceM, distanceM) || other.distanceM == distanceM)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.keptShare, keptShare) || other.keptShare == keptShare)&&(identical(other.unmatchedM, unmatchedM) || other.unmatchedM == unmatchedM)&&(identical(other.changed, changed) || other.changed == changed)&&(identical(other.bounds, bounds) || other.bounds == bounds)&&(identical(other.ascentM, ascentM) || other.ascentM == ascentM)&&(identical(other.descentM, descentM) || other.descentM == descentM)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.endSnapM, endSnapM) || other.endSnapM == endSnapM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,polyline,distanceM,kind,keptShare,unmatchedM,changed,bounds,ascentM,descentM,variant,endSnapM);
}

@override
String toString() {
    return 'RetouchedRouteDto(polyline: $polyline, distanceM: $distanceM, kind: $kind, keptShare: $keptShare, unmatchedM: $unmatchedM, changed: $changed, bounds: $bounds, ascentM: $ascentM, descentM: $descentM, variant: $variant, endSnapM: $endSnapM)';
}


}

/// @nodoc
abstract mixin class _$RetouchedRouteDtoCopyWith<$Res> implements $RetouchedRouteDtoCopyWith<$Res> {
  factory _$RetouchedRouteDtoCopyWith(_RetouchedRouteDto value, $Res Function(_RetouchedRouteDto) _then) = __$RetouchedRouteDtoCopyWithImpl;
@override @useResult
$Res call({
 String polyline, double distanceM, String kind, double keptShare, double unmatchedM, RetouchedSpanDto changed, BoundsDto bounds, double? ascentM, double? descentM, String? variant, double? endSnapM
});


@override $RetouchedSpanDtoCopyWith<$Res> get changed;@override $BoundsDtoCopyWith<$Res> get bounds;

}
/// @nodoc
class __$RetouchedRouteDtoCopyWithImpl<$Res>
    implements _$RetouchedRouteDtoCopyWith<$Res> {
  __$RetouchedRouteDtoCopyWithImpl(this._self, this._then);

  final _RetouchedRouteDto _self;
  final $Res Function(_RetouchedRouteDto) _then;

/// Create a copy of RetouchedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? polyline = null,Object? distanceM = null,Object? kind = null,Object? keptShare = null,Object? unmatchedM = null,Object? changed = null,Object? bounds = null,Object? ascentM = freezed,Object? descentM = freezed,Object? variant = freezed,Object? endSnapM = freezed,}) {
  return _then(_RetouchedRouteDto(
polyline: null == polyline ? _self.polyline : polyline // ignore: cast_nullable_to_non_nullable
as String,distanceM: null == distanceM ? _self.distanceM : distanceM // ignore: cast_nullable_to_non_nullable
as double,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,keptShare: null == keptShare ? _self.keptShare : keptShare // ignore: cast_nullable_to_non_nullable
as double,unmatchedM: null == unmatchedM ? _self.unmatchedM : unmatchedM // ignore: cast_nullable_to_non_nullable
as double,changed: null == changed ? _self.changed : changed // ignore: cast_nullable_to_non_nullable
as RetouchedSpanDto,bounds: null == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as BoundsDto,ascentM: freezed == ascentM ? _self.ascentM : ascentM // ignore: cast_nullable_to_non_nullable
as double?,descentM: freezed == descentM ? _self.descentM : descentM // ignore: cast_nullable_to_non_nullable
as double?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,endSnapM: freezed == endSnapM ? _self.endSnapM : endSnapM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of RetouchedRouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RetouchedSpanDtoCopyWith<$Res> get changed {
  
  return $RetouchedSpanDtoCopyWith<$Res>(_self.changed, (value) {
    return _then(_self.copyWith(changed: value));
  });
}/// Create a copy of RetouchedRouteDto
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
