// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_generator_network_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGeneratorNetworkDetails {

/// Type
 String get type;/// Routes the network is made of
 int get routeCount;/// Routes whose roads are still being analysed and are not in the network yet
 int get pendingRouteCount;/// Routes ticked "ne pas utiliser pour générer des parcours"
 int get excludedRouteCount;/// Length of the whole network of the team, in metres
 double get totalLengthM;/// True when pendingRouteCount is above zero: the network may still grow
 bool get incomplete;
/// Create a copy of RouteGeneratorNetworkDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGeneratorNetworkDetailsCopyWith<RouteGeneratorNetworkDetails> get copyWith => _$RouteGeneratorNetworkDetailsCopyWithImpl<RouteGeneratorNetworkDetails>(this as RouteGeneratorNetworkDetails, _$identity);

  /// Serializes this RouteGeneratorNetworkDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGeneratorNetworkDetails;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGeneratorNetworkDetails&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.routeCount, _this.routeCount) || other.routeCount == _this.routeCount)&&(identical(other.pendingRouteCount, _this.pendingRouteCount) || other.pendingRouteCount == _this.pendingRouteCount)&&(identical(other.excludedRouteCount, _this.excludedRouteCount) || other.excludedRouteCount == _this.excludedRouteCount)&&(identical(other.totalLengthM, _this.totalLengthM) || other.totalLengthM == _this.totalLengthM)&&(identical(other.incomplete, _this.incomplete) || other.incomplete == _this.incomplete));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGeneratorNetworkDetails;
  return Object.hash(runtimeType,_this.type,_this.routeCount,_this.pendingRouteCount,_this.excludedRouteCount,_this.totalLengthM,_this.incomplete);
}

@override
String toString() {
  final _this = this as RouteGeneratorNetworkDetails;
  return 'RouteGeneratorNetworkDetails(type: ${_this.type}, routeCount: ${_this.routeCount}, pendingRouteCount: ${_this.pendingRouteCount}, excludedRouteCount: ${_this.excludedRouteCount}, totalLengthM: ${_this.totalLengthM}, incomplete: ${_this.incomplete})';
}


}

/// @nodoc
abstract mixin class $RouteGeneratorNetworkDetailsCopyWith<$Res>  {
  factory $RouteGeneratorNetworkDetailsCopyWith(RouteGeneratorNetworkDetails value, $Res Function(RouteGeneratorNetworkDetails) _then) = _$RouteGeneratorNetworkDetailsCopyWithImpl;
@useResult
$Res call({
 String type, int routeCount, int pendingRouteCount, int excludedRouteCount, double totalLengthM, bool incomplete
});




}
/// @nodoc
class _$RouteGeneratorNetworkDetailsCopyWithImpl<$Res>
    implements $RouteGeneratorNetworkDetailsCopyWith<$Res> {
  _$RouteGeneratorNetworkDetailsCopyWithImpl(this._self, this._then);

  final RouteGeneratorNetworkDetails _self;
  final $Res Function(RouteGeneratorNetworkDetails) _then;

/// Create a copy of RouteGeneratorNetworkDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? routeCount = null,Object? pendingRouteCount = null,Object? excludedRouteCount = null,Object? totalLengthM = null,Object? incomplete = null,}) {
  return _then(RouteGeneratorNetworkDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,pendingRouteCount: null == pendingRouteCount ? _self.pendingRouteCount : pendingRouteCount // ignore: cast_nullable_to_non_nullable
as int,excludedRouteCount: null == excludedRouteCount ? _self.excludedRouteCount : excludedRouteCount // ignore: cast_nullable_to_non_nullable
as int,totalLengthM: null == totalLengthM ? _self.totalLengthM : totalLengthM // ignore: cast_nullable_to_non_nullable
as double,incomplete: null == incomplete ? _self.incomplete : incomplete // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteGeneratorNetworkDetails].
extension RouteGeneratorNetworkDetailsPatterns on RouteGeneratorNetworkDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGeneratorNetworkDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGeneratorNetworkDetails value)  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGeneratorNetworkDetails value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  int routeCount,  int pendingRouteCount,  int excludedRouteCount,  double totalLengthM,  bool incomplete)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDetails() when $default != null:
return $default(_that.type,_that.routeCount,_that.pendingRouteCount,_that.excludedRouteCount,_that.totalLengthM,_that.incomplete);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  int routeCount,  int pendingRouteCount,  int excludedRouteCount,  double totalLengthM,  bool incomplete)  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDetails():
return $default(_that.type,_that.routeCount,_that.pendingRouteCount,_that.excludedRouteCount,_that.totalLengthM,_that.incomplete);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  int routeCount,  int pendingRouteCount,  int excludedRouteCount,  double totalLengthM,  bool incomplete)?  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorNetworkDetails() when $default != null:
return $default(_that.type,_that.routeCount,_that.pendingRouteCount,_that.excludedRouteCount,_that.totalLengthM,_that.incomplete);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGeneratorNetworkDetails implements RouteGeneratorNetworkDetails {
  const _RouteGeneratorNetworkDetails({required this.type, required this.routeCount, required this.pendingRouteCount, required this.excludedRouteCount, required this.totalLengthM, required this.incomplete});
  factory _RouteGeneratorNetworkDetails.fromJson(Map<String, dynamic> json) => _$RouteGeneratorNetworkDetailsFromJson(json);

/// Type
@override final  String type;
/// Routes the network is made of
@override final  int routeCount;
/// Routes whose roads are still being analysed and are not in the network yet
@override final  int pendingRouteCount;
/// Routes ticked "ne pas utiliser pour générer des parcours"
@override final  int excludedRouteCount;
/// Length of the whole network of the team, in metres
@override final  double totalLengthM;
/// True when pendingRouteCount is above zero: the network may still grow
@override final  bool incomplete;

/// Create a copy of RouteGeneratorNetworkDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGeneratorNetworkDetailsCopyWith<_RouteGeneratorNetworkDetails> get copyWith => __$RouteGeneratorNetworkDetailsCopyWithImpl<_RouteGeneratorNetworkDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGeneratorNetworkDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGeneratorNetworkDetails&&(identical(other.type, type) || other.type == type)&&(identical(other.routeCount, routeCount) || other.routeCount == routeCount)&&(identical(other.pendingRouteCount, pendingRouteCount) || other.pendingRouteCount == pendingRouteCount)&&(identical(other.excludedRouteCount, excludedRouteCount) || other.excludedRouteCount == excludedRouteCount)&&(identical(other.totalLengthM, totalLengthM) || other.totalLengthM == totalLengthM)&&(identical(other.incomplete, incomplete) || other.incomplete == incomplete));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,routeCount,pendingRouteCount,excludedRouteCount,totalLengthM,incomplete);
}

@override
String toString() {
    return 'RouteGeneratorNetworkDetails(type: $type, routeCount: $routeCount, pendingRouteCount: $pendingRouteCount, excludedRouteCount: $excludedRouteCount, totalLengthM: $totalLengthM, incomplete: $incomplete)';
}


}

/// @nodoc
abstract mixin class _$RouteGeneratorNetworkDetailsCopyWith<$Res> implements $RouteGeneratorNetworkDetailsCopyWith<$Res> {
  factory _$RouteGeneratorNetworkDetailsCopyWith(_RouteGeneratorNetworkDetails value, $Res Function(_RouteGeneratorNetworkDetails) _then) = __$RouteGeneratorNetworkDetailsCopyWithImpl;
@override @useResult
$Res call({
 String type, int routeCount, int pendingRouteCount, int excludedRouteCount, double totalLengthM, bool incomplete
});




}
/// @nodoc
class __$RouteGeneratorNetworkDetailsCopyWithImpl<$Res>
    implements _$RouteGeneratorNetworkDetailsCopyWith<$Res> {
  __$RouteGeneratorNetworkDetailsCopyWithImpl(this._self, this._then);

  final _RouteGeneratorNetworkDetails _self;
  final $Res Function(_RouteGeneratorNetworkDetails) _then;

/// Create a copy of RouteGeneratorNetworkDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? routeCount = null,Object? pendingRouteCount = null,Object? excludedRouteCount = null,Object? totalLengthM = null,Object? incomplete = null,}) {
  return _then(_RouteGeneratorNetworkDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,pendingRouteCount: null == pendingRouteCount ? _self.pendingRouteCount : pendingRouteCount // ignore: cast_nullable_to_non_nullable
as int,excludedRouteCount: null == excludedRouteCount ? _self.excludedRouteCount : excludedRouteCount // ignore: cast_nullable_to_non_nullable
as int,totalLengthM: null == totalLengthM ? _self.totalLengthM : totalLengthM // ignore: cast_nullable_to_non_nullable
as double,incomplete: null == incomplete ? _self.incomplete : incomplete // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
