// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_generator_network_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGeneratorNetworkDto {

/// Length of the whole network of the team
 double get totalLengthM;/// Routes the network is made of
 int get routeCount;/// Routes whose roads are still being analysed and are not in the network yet
 int get pendingRouteCount;/// Routes ticked "ne pas utiliser pour générer des parcours"
 int get excludedRouteCount;/// True when pendingRouteCount is above zero: the network may still grow
 bool get incomplete;/// Length of the road the search can reach around the start and the end. Absent when no route was generated
 double? get lengthM;
/// Create a copy of RouteGeneratorNetworkDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGeneratorNetworkDtoCopyWith<RouteGeneratorNetworkDto> get copyWith => _$RouteGeneratorNetworkDtoCopyWithImpl<RouteGeneratorNetworkDto>(this as RouteGeneratorNetworkDto, _$identity);

  /// Serializes this RouteGeneratorNetworkDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGeneratorNetworkDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGeneratorNetworkDto&&(identical(other.totalLengthM, _this.totalLengthM) || other.totalLengthM == _this.totalLengthM)&&(identical(other.routeCount, _this.routeCount) || other.routeCount == _this.routeCount)&&(identical(other.pendingRouteCount, _this.pendingRouteCount) || other.pendingRouteCount == _this.pendingRouteCount)&&(identical(other.excludedRouteCount, _this.excludedRouteCount) || other.excludedRouteCount == _this.excludedRouteCount)&&(identical(other.incomplete, _this.incomplete) || other.incomplete == _this.incomplete)&&(identical(other.lengthM, _this.lengthM) || other.lengthM == _this.lengthM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGeneratorNetworkDto;
  return Object.hash(runtimeType,_this.totalLengthM,_this.routeCount,_this.pendingRouteCount,_this.excludedRouteCount,_this.incomplete,_this.lengthM);
}

@override
String toString() {
  final _this = this as RouteGeneratorNetworkDto;
  return 'RouteGeneratorNetworkDto(totalLengthM: ${_this.totalLengthM}, routeCount: ${_this.routeCount}, pendingRouteCount: ${_this.pendingRouteCount}, excludedRouteCount: ${_this.excludedRouteCount}, incomplete: ${_this.incomplete}, lengthM: ${_this.lengthM})';
}


}

/// @nodoc
abstract mixin class $RouteGeneratorNetworkDtoCopyWith<$Res>  {
  factory $RouteGeneratorNetworkDtoCopyWith(RouteGeneratorNetworkDto value, $Res Function(RouteGeneratorNetworkDto) _then) = _$RouteGeneratorNetworkDtoCopyWithImpl;
@useResult
$Res call({
 double totalLengthM, int routeCount, int pendingRouteCount, int excludedRouteCount, bool incomplete, double? lengthM
});




}
/// @nodoc
class _$RouteGeneratorNetworkDtoCopyWithImpl<$Res>
    implements $RouteGeneratorNetworkDtoCopyWith<$Res> {
  _$RouteGeneratorNetworkDtoCopyWithImpl(this._self, this._then);

  final RouteGeneratorNetworkDto _self;
  final $Res Function(RouteGeneratorNetworkDto) _then;

/// Create a copy of RouteGeneratorNetworkDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalLengthM = null,Object? routeCount = null,Object? pendingRouteCount = null,Object? excludedRouteCount = null,Object? incomplete = null,Object? lengthM = freezed,}) {
  return _then(RouteGeneratorNetworkDto(
totalLengthM: null == totalLengthM ? _self.totalLengthM : totalLengthM // ignore: cast_nullable_to_non_nullable
as double,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,pendingRouteCount: null == pendingRouteCount ? _self.pendingRouteCount : pendingRouteCount // ignore: cast_nullable_to_non_nullable
as int,excludedRouteCount: null == excludedRouteCount ? _self.excludedRouteCount : excludedRouteCount // ignore: cast_nullable_to_non_nullable
as int,incomplete: null == incomplete ? _self.incomplete : incomplete // ignore: cast_nullable_to_non_nullable
as bool,lengthM: freezed == lengthM ? _self.lengthM : lengthM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteGeneratorNetworkDto].
extension RouteGeneratorNetworkDtoPatterns on RouteGeneratorNetworkDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGeneratorNetworkDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGeneratorNetworkDto value)  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGeneratorNetworkDto value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double totalLengthM,  int routeCount,  int pendingRouteCount,  int excludedRouteCount,  bool incomplete,  double? lengthM)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDto() when $default != null:
return $default(_that.totalLengthM,_that.routeCount,_that.pendingRouteCount,_that.excludedRouteCount,_that.incomplete,_that.lengthM);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double totalLengthM,  int routeCount,  int pendingRouteCount,  int excludedRouteCount,  bool incomplete,  double? lengthM)  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDto():
return $default(_that.totalLengthM,_that.routeCount,_that.pendingRouteCount,_that.excludedRouteCount,_that.incomplete,_that.lengthM);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double totalLengthM,  int routeCount,  int pendingRouteCount,  int excludedRouteCount,  bool incomplete,  double? lengthM)?  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDto() when $default != null:
return $default(_that.totalLengthM,_that.routeCount,_that.pendingRouteCount,_that.excludedRouteCount,_that.incomplete,_that.lengthM);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGeneratorNetworkDto implements RouteGeneratorNetworkDto {
  const _RouteGeneratorNetworkDto({required this.totalLengthM, required this.routeCount, required this.pendingRouteCount, required this.excludedRouteCount, required this.incomplete, this.lengthM});
  factory _RouteGeneratorNetworkDto.fromJson(Map<String, dynamic> json) => _$RouteGeneratorNetworkDtoFromJson(json);

/// Length of the whole network of the team
@override final  double totalLengthM;
/// Routes the network is made of
@override final  int routeCount;
/// Routes whose roads are still being analysed and are not in the network yet
@override final  int pendingRouteCount;
/// Routes ticked "ne pas utiliser pour générer des parcours"
@override final  int excludedRouteCount;
/// True when pendingRouteCount is above zero: the network may still grow
@override final  bool incomplete;
/// Length of the road the search can reach around the start and the end. Absent when no route was generated
@override final  double? lengthM;

/// Create a copy of RouteGeneratorNetworkDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGeneratorNetworkDtoCopyWith<_RouteGeneratorNetworkDto> get copyWith => __$RouteGeneratorNetworkDtoCopyWithImpl<_RouteGeneratorNetworkDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGeneratorNetworkDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGeneratorNetworkDto&&(identical(other.totalLengthM, totalLengthM) || other.totalLengthM == totalLengthM)&&(identical(other.routeCount, routeCount) || other.routeCount == routeCount)&&(identical(other.pendingRouteCount, pendingRouteCount) || other.pendingRouteCount == pendingRouteCount)&&(identical(other.excludedRouteCount, excludedRouteCount) || other.excludedRouteCount == excludedRouteCount)&&(identical(other.incomplete, incomplete) || other.incomplete == incomplete)&&(identical(other.lengthM, lengthM) || other.lengthM == lengthM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,totalLengthM,routeCount,pendingRouteCount,excludedRouteCount,incomplete,lengthM);
}

@override
String toString() {
    return 'RouteGeneratorNetworkDto(totalLengthM: $totalLengthM, routeCount: $routeCount, pendingRouteCount: $pendingRouteCount, excludedRouteCount: $excludedRouteCount, incomplete: $incomplete, lengthM: $lengthM)';
}


}

/// @nodoc
abstract mixin class _$RouteGeneratorNetworkDtoCopyWith<$Res> implements $RouteGeneratorNetworkDtoCopyWith<$Res> {
  factory _$RouteGeneratorNetworkDtoCopyWith(_RouteGeneratorNetworkDto value, $Res Function(_RouteGeneratorNetworkDto) _then) = __$RouteGeneratorNetworkDtoCopyWithImpl;
@override @useResult
$Res call({
 double totalLengthM, int routeCount, int pendingRouteCount, int excludedRouteCount, bool incomplete, double? lengthM
});




}
/// @nodoc
class __$RouteGeneratorNetworkDtoCopyWithImpl<$Res>
    implements _$RouteGeneratorNetworkDtoCopyWith<$Res> {
  __$RouteGeneratorNetworkDtoCopyWithImpl(this._self, this._then);

  final _RouteGeneratorNetworkDto _self;
  final $Res Function(_RouteGeneratorNetworkDto) _then;

/// Create a copy of RouteGeneratorNetworkDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalLengthM = null,Object? routeCount = null,Object? pendingRouteCount = null,Object? excludedRouteCount = null,Object? incomplete = null,Object? lengthM = freezed,}) {
  return _then(_RouteGeneratorNetworkDto(
totalLengthM: null == totalLengthM ? _self.totalLengthM : totalLengthM // ignore: cast_nullable_to_non_nullable
as double,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,pendingRouteCount: null == pendingRouteCount ? _self.pendingRouteCount : pendingRouteCount // ignore: cast_nullable_to_non_nullable
as int,excludedRouteCount: null == excludedRouteCount ? _self.excludedRouteCount : excludedRouteCount // ignore: cast_nullable_to_non_nullable
as int,incomplete: null == incomplete ? _self.incomplete : incomplete // ignore: cast_nullable_to_non_nullable
as bool,lengthM: freezed == lengthM ? _self.lengthM : lengthM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
