// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gpx_preview_summary_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GpxPreviewSummaryDto {

/// Public identifier used in URLs
 String get id;/// Track name
 String get name;/// Distance in meters
 double get distance;/// Total elevation gain in meters
 double get elevationGain;/// Total elevation loss in meters
 double get elevationLoss;/// Elevation gain per kilometer
 double get hilliness;/// Creation timestamp
 String get createdAt;/// Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone
 String? get departureTime;/// IANA time zone of the first point of the track, the one the departure was entered in
 String? get departureTimezone;
/// Create a copy of GpxPreviewSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpxPreviewSummaryDtoCopyWith<GpxPreviewSummaryDto> get copyWith => _$GpxPreviewSummaryDtoCopyWithImpl<GpxPreviewSummaryDto>(this as GpxPreviewSummaryDto, _$identity);

  /// Serializes this GpxPreviewSummaryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GpxPreviewSummaryDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpxPreviewSummaryDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.elevationLoss, _this.elevationLoss) || other.elevationLoss == _this.elevationLoss)&&(identical(other.hilliness, _this.hilliness) || other.hilliness == _this.hilliness)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.departureTime, _this.departureTime) || other.departureTime == _this.departureTime)&&(identical(other.departureTimezone, _this.departureTimezone) || other.departureTimezone == _this.departureTimezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GpxPreviewSummaryDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.distance,_this.elevationGain,_this.elevationLoss,_this.hilliness,_this.createdAt,_this.departureTime,_this.departureTimezone);
}

@override
String toString() {
  final _this = this as GpxPreviewSummaryDto;
  return 'GpxPreviewSummaryDto(id: ${_this.id}, name: ${_this.name}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, elevationLoss: ${_this.elevationLoss}, hilliness: ${_this.hilliness}, createdAt: ${_this.createdAt}, departureTime: ${_this.departureTime}, departureTimezone: ${_this.departureTimezone})';
}


}

/// @nodoc
abstract mixin class $GpxPreviewSummaryDtoCopyWith<$Res>  {
  factory $GpxPreviewSummaryDtoCopyWith(GpxPreviewSummaryDto value, $Res Function(GpxPreviewSummaryDto) _then) = _$GpxPreviewSummaryDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, double distance, double elevationGain, double elevationLoss, double hilliness, String createdAt, String? departureTime, String? departureTimezone
});




}
/// @nodoc
class _$GpxPreviewSummaryDtoCopyWithImpl<$Res>
    implements $GpxPreviewSummaryDtoCopyWith<$Res> {
  _$GpxPreviewSummaryDtoCopyWithImpl(this._self, this._then);

  final GpxPreviewSummaryDto _self;
  final $Res Function(GpxPreviewSummaryDto) _then;

/// Create a copy of GpxPreviewSummaryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? hilliness = null,Object? createdAt = null,Object? departureTime = freezed,Object? departureTimezone = freezed,}) {
  return _then(GpxPreviewSummaryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,elevationLoss: null == elevationLoss ? _self.elevationLoss : elevationLoss // ignore: cast_nullable_to_non_nullable
as double,hilliness: null == hilliness ? _self.hilliness : hilliness // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,departureTime: freezed == departureTime ? _self.departureTime : departureTime // ignore: cast_nullable_to_non_nullable
as String?,departureTimezone: freezed == departureTimezone ? _self.departureTimezone : departureTimezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GpxPreviewSummaryDto].
extension GpxPreviewSummaryDtoPatterns on GpxPreviewSummaryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpxPreviewSummaryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpxPreviewSummaryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpxPreviewSummaryDto value)  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewSummaryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpxPreviewSummaryDto value)?  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewSummaryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double distance,  double elevationGain,  double elevationLoss,  double hilliness,  String createdAt,  String? departureTime,  String? departureTimezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpxPreviewSummaryDto() when $default != null:
return $default(_that.id,_that.name,_that.distance,_that.elevationGain,_that.elevationLoss,_that.hilliness,_that.createdAt,_that.departureTime,_that.departureTimezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double distance,  double elevationGain,  double elevationLoss,  double hilliness,  String createdAt,  String? departureTime,  String? departureTimezone)  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewSummaryDto():
return $default(_that.id,_that.name,_that.distance,_that.elevationGain,_that.elevationLoss,_that.hilliness,_that.createdAt,_that.departureTime,_that.departureTimezone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double distance,  double elevationGain,  double elevationLoss,  double hilliness,  String createdAt,  String? departureTime,  String? departureTimezone)?  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewSummaryDto() when $default != null:
return $default(_that.id,_that.name,_that.distance,_that.elevationGain,_that.elevationLoss,_that.hilliness,_that.createdAt,_that.departureTime,_that.departureTimezone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpxPreviewSummaryDto implements GpxPreviewSummaryDto {
  const _GpxPreviewSummaryDto({required this.id, required this.name, required this.distance, required this.elevationGain, required this.elevationLoss, required this.hilliness, required this.createdAt, this.departureTime, this.departureTimezone});
  factory _GpxPreviewSummaryDto.fromJson(Map<String, dynamic> json) => _$GpxPreviewSummaryDtoFromJson(json);

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
/// Creation timestamp
@override final  String createdAt;
/// Departure instant, when the person gave a date. The wall time at the start of the track is this instant in departureTimezone. Present together with departureTimezone
@override final  String? departureTime;
/// IANA time zone of the first point of the track, the one the departure was entered in
@override final  String? departureTimezone;

/// Create a copy of GpxPreviewSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpxPreviewSummaryDtoCopyWith<_GpxPreviewSummaryDto> get copyWith => __$GpxPreviewSummaryDtoCopyWithImpl<_GpxPreviewSummaryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpxPreviewSummaryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpxPreviewSummaryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.elevationLoss, elevationLoss) || other.elevationLoss == elevationLoss)&&(identical(other.hilliness, hilliness) || other.hilliness == hilliness)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.departureTime, departureTime) || other.departureTime == departureTime)&&(identical(other.departureTimezone, departureTimezone) || other.departureTimezone == departureTimezone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,distance,elevationGain,elevationLoss,hilliness,createdAt,departureTime,departureTimezone);
}

@override
String toString() {
    return 'GpxPreviewSummaryDto(id: $id, name: $name, distance: $distance, elevationGain: $elevationGain, elevationLoss: $elevationLoss, hilliness: $hilliness, createdAt: $createdAt, departureTime: $departureTime, departureTimezone: $departureTimezone)';
}


}

/// @nodoc
abstract mixin class _$GpxPreviewSummaryDtoCopyWith<$Res> implements $GpxPreviewSummaryDtoCopyWith<$Res> {
  factory _$GpxPreviewSummaryDtoCopyWith(_GpxPreviewSummaryDto value, $Res Function(_GpxPreviewSummaryDto) _then) = __$GpxPreviewSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double distance, double elevationGain, double elevationLoss, double hilliness, String createdAt, String? departureTime, String? departureTimezone
});




}
/// @nodoc
class __$GpxPreviewSummaryDtoCopyWithImpl<$Res>
    implements _$GpxPreviewSummaryDtoCopyWith<$Res> {
  __$GpxPreviewSummaryDtoCopyWithImpl(this._self, this._then);

  final _GpxPreviewSummaryDto _self;
  final $Res Function(_GpxPreviewSummaryDto) _then;

/// Create a copy of GpxPreviewSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? hilliness = null,Object? createdAt = null,Object? departureTime = freezed,Object? departureTimezone = freezed,}) {
  return _then(_GpxPreviewSummaryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,elevationLoss: null == elevationLoss ? _self.elevationLoss : elevationLoss // ignore: cast_nullable_to_non_nullable
as double,hilliness: null == hilliness ? _self.hilliness : hilliness // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,departureTime: freezed == departureTime ? _self.departureTime : departureTime // ignore: cast_nullable_to_non_nullable
as String?,departureTimezone: freezed == departureTimezone ? _self.departureTimezone : departureTimezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
