// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_retouch_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteRetouchResponse {

/// The operation answered
 String get operation;/// Length of the original route's raw track in metres, the engine's own
 double get originalDistanceM;/// One to three proposals, best first
 List<RetouchedRouteDto> get candidates;/// Elevation gain of the original track, computed in the same batch as the proposals' so that before and after compare like with like
 double? get originalAscentM;/// Elevation loss of the original track
 double? get originalDescentM;/// RESIZE: the total distance asked, in metres
 double? get targetDistanceM;/// When the team's roads were last prepared for the generator. Absent when the request did not use them (discovery)
 String? get networkPreparedAt;
/// Create a copy of RouteRetouchResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteRetouchResponseCopyWith<RouteRetouchResponse> get copyWith => _$RouteRetouchResponseCopyWithImpl<RouteRetouchResponse>(this as RouteRetouchResponse, _$identity);

  /// Serializes this RouteRetouchResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteRetouchResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteRetouchResponse&&(identical(other.operation, _this.operation) || other.operation == _this.operation)&&(identical(other.originalDistanceM, _this.originalDistanceM) || other.originalDistanceM == _this.originalDistanceM)&&const DeepCollectionEquality().equals(other.candidates, _this.candidates)&&(identical(other.originalAscentM, _this.originalAscentM) || other.originalAscentM == _this.originalAscentM)&&(identical(other.originalDescentM, _this.originalDescentM) || other.originalDescentM == _this.originalDescentM)&&(identical(other.targetDistanceM, _this.targetDistanceM) || other.targetDistanceM == _this.targetDistanceM)&&(identical(other.networkPreparedAt, _this.networkPreparedAt) || other.networkPreparedAt == _this.networkPreparedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteRetouchResponse;
  return Object.hash(runtimeType,_this.operation,_this.originalDistanceM,const DeepCollectionEquality().hash(_this.candidates),_this.originalAscentM,_this.originalDescentM,_this.targetDistanceM,_this.networkPreparedAt);
}

@override
String toString() {
  final _this = this as RouteRetouchResponse;
  return 'RouteRetouchResponse(operation: ${_this.operation}, originalDistanceM: ${_this.originalDistanceM}, candidates: ${_this.candidates}, originalAscentM: ${_this.originalAscentM}, originalDescentM: ${_this.originalDescentM}, targetDistanceM: ${_this.targetDistanceM}, networkPreparedAt: ${_this.networkPreparedAt})';
}


}

/// @nodoc
abstract mixin class $RouteRetouchResponseCopyWith<$Res>  {
  factory $RouteRetouchResponseCopyWith(RouteRetouchResponse value, $Res Function(RouteRetouchResponse) _then) = _$RouteRetouchResponseCopyWithImpl;
@useResult
$Res call({
 String operation, double originalDistanceM, List<RetouchedRouteDto> candidates, double? originalAscentM, double? originalDescentM, double? targetDistanceM, String? networkPreparedAt
});




}
/// @nodoc
class _$RouteRetouchResponseCopyWithImpl<$Res>
    implements $RouteRetouchResponseCopyWith<$Res> {
  _$RouteRetouchResponseCopyWithImpl(this._self, this._then);

  final RouteRetouchResponse _self;
  final $Res Function(RouteRetouchResponse) _then;

/// Create a copy of RouteRetouchResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? operation = null,Object? originalDistanceM = null,Object? candidates = null,Object? originalAscentM = freezed,Object? originalDescentM = freezed,Object? targetDistanceM = freezed,Object? networkPreparedAt = freezed,}) {
  return _then(RouteRetouchResponse(
operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as String,originalDistanceM: null == originalDistanceM ? _self.originalDistanceM : originalDistanceM // ignore: cast_nullable_to_non_nullable
as double,candidates: null == candidates ? _self.candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<RetouchedRouteDto>,originalAscentM: freezed == originalAscentM ? _self.originalAscentM : originalAscentM // ignore: cast_nullable_to_non_nullable
as double?,originalDescentM: freezed == originalDescentM ? _self.originalDescentM : originalDescentM // ignore: cast_nullable_to_non_nullable
as double?,targetDistanceM: freezed == targetDistanceM ? _self.targetDistanceM : targetDistanceM // ignore: cast_nullable_to_non_nullable
as double?,networkPreparedAt: freezed == networkPreparedAt ? _self.networkPreparedAt : networkPreparedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteRetouchResponse].
extension RouteRetouchResponsePatterns on RouteRetouchResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteRetouchResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteRetouchResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteRetouchResponse value)  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteRetouchResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String operation,  double originalDistanceM,  List<RetouchedRouteDto> candidates,  double? originalAscentM,  double? originalDescentM,  double? targetDistanceM,  String? networkPreparedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteRetouchResponse() when $default != null:
return $default(_that.operation,_that.originalDistanceM,_that.candidates,_that.originalAscentM,_that.originalDescentM,_that.targetDistanceM,_that.networkPreparedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String operation,  double originalDistanceM,  List<RetouchedRouteDto> candidates,  double? originalAscentM,  double? originalDescentM,  double? targetDistanceM,  String? networkPreparedAt)  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchResponse():
return $default(_that.operation,_that.originalDistanceM,_that.candidates,_that.originalAscentM,_that.originalDescentM,_that.targetDistanceM,_that.networkPreparedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String operation,  double originalDistanceM,  List<RetouchedRouteDto> candidates,  double? originalAscentM,  double? originalDescentM,  double? targetDistanceM,  String? networkPreparedAt)?  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchResponse() when $default != null:
return $default(_that.operation,_that.originalDistanceM,_that.candidates,_that.originalAscentM,_that.originalDescentM,_that.targetDistanceM,_that.networkPreparedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteRetouchResponse implements RouteRetouchResponse {
  const _RouteRetouchResponse({required this.operation, required this.originalDistanceM, required  List<RetouchedRouteDto> candidates, this.originalAscentM, this.originalDescentM, this.targetDistanceM, this.networkPreparedAt}): _candidates = candidates;
  factory _RouteRetouchResponse.fromJson(Map<String, dynamic> json) => _$RouteRetouchResponseFromJson(json);

/// The operation answered
@override final  String operation;
/// Length of the original route's raw track in metres, the engine's own
@override final  double originalDistanceM;
/// One to three proposals, best first
 final  List<RetouchedRouteDto> _candidates;
/// One to three proposals, best first
@override List<RetouchedRouteDto> get candidates {
  if (_candidates is EqualUnmodifiableListView) return _candidates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_candidates);
}

/// Elevation gain of the original track, computed in the same batch as the proposals' so that before and after compare like with like
@override final  double? originalAscentM;
/// Elevation loss of the original track
@override final  double? originalDescentM;
/// RESIZE: the total distance asked, in metres
@override final  double? targetDistanceM;
/// When the team's roads were last prepared for the generator. Absent when the request did not use them (discovery)
@override final  String? networkPreparedAt;

/// Create a copy of RouteRetouchResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteRetouchResponseCopyWith<_RouteRetouchResponse> get copyWith => __$RouteRetouchResponseCopyWithImpl<_RouteRetouchResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteRetouchResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteRetouchResponse&&(identical(other.operation, operation) || other.operation == operation)&&(identical(other.originalDistanceM, originalDistanceM) || other.originalDistanceM == originalDistanceM)&&const DeepCollectionEquality().equals(other.candidates, _candidates)&&(identical(other.originalAscentM, originalAscentM) || other.originalAscentM == originalAscentM)&&(identical(other.originalDescentM, originalDescentM) || other.originalDescentM == originalDescentM)&&(identical(other.targetDistanceM, targetDistanceM) || other.targetDistanceM == targetDistanceM)&&(identical(other.networkPreparedAt, networkPreparedAt) || other.networkPreparedAt == networkPreparedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,operation,originalDistanceM,const DeepCollectionEquality().hash(_candidates),originalAscentM,originalDescentM,targetDistanceM,networkPreparedAt);
}

@override
String toString() {
    return 'RouteRetouchResponse(operation: $operation, originalDistanceM: $originalDistanceM, candidates: $candidates, originalAscentM: $originalAscentM, originalDescentM: $originalDescentM, targetDistanceM: $targetDistanceM, networkPreparedAt: $networkPreparedAt)';
}


}

/// @nodoc
abstract mixin class _$RouteRetouchResponseCopyWith<$Res> implements $RouteRetouchResponseCopyWith<$Res> {
  factory _$RouteRetouchResponseCopyWith(_RouteRetouchResponse value, $Res Function(_RouteRetouchResponse) _then) = __$RouteRetouchResponseCopyWithImpl;
@override @useResult
$Res call({
 String operation, double originalDistanceM, List<RetouchedRouteDto> candidates, double? originalAscentM, double? originalDescentM, double? targetDistanceM, String? networkPreparedAt
});




}
/// @nodoc
class __$RouteRetouchResponseCopyWithImpl<$Res>
    implements _$RouteRetouchResponseCopyWith<$Res> {
  __$RouteRetouchResponseCopyWithImpl(this._self, this._then);

  final _RouteRetouchResponse _self;
  final $Res Function(_RouteRetouchResponse) _then;

/// Create a copy of RouteRetouchResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? operation = null,Object? originalDistanceM = null,Object? candidates = null,Object? originalAscentM = freezed,Object? originalDescentM = freezed,Object? targetDistanceM = freezed,Object? networkPreparedAt = freezed,}) {
  return _then(_RouteRetouchResponse(
operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as String,originalDistanceM: null == originalDistanceM ? _self.originalDistanceM : originalDistanceM // ignore: cast_nullable_to_non_nullable
as double,candidates: null == candidates ? _self._candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<RetouchedRouteDto>,originalAscentM: freezed == originalAscentM ? _self.originalAscentM : originalAscentM // ignore: cast_nullable_to_non_nullable
as double?,originalDescentM: freezed == originalDescentM ? _self.originalDescentM : originalDescentM // ignore: cast_nullable_to_non_nullable
as double?,targetDistanceM: freezed == targetDistanceM ? _self.targetDistanceM : targetDistanceM // ignore: cast_nullable_to_non_nullable
as double?,networkPreparedAt: freezed == networkPreparedAt ? _self.networkPreparedAt : networkPreparedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
