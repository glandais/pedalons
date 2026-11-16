// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_generator_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGeneratorResponse {

/// One to three routes, best first, different from each other
 List<GeneratedRouteDto> get candidates;/// True when part of the area around the start leaves the region the generator covers: proposals are rarer there
 bool get partialCoverage;/// When the team's roads were last prepared for the generator (the night before at best). Absent when the request did not use them (discovery)
 String? get networkPreparedAt;
/// Create a copy of RouteGeneratorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGeneratorResponseCopyWith<RouteGeneratorResponse> get copyWith => _$RouteGeneratorResponseCopyWithImpl<RouteGeneratorResponse>(this as RouteGeneratorResponse, _$identity);

  /// Serializes this RouteGeneratorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGeneratorResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGeneratorResponse&&const DeepCollectionEquality().equals(other.candidates, _this.candidates)&&(identical(other.partialCoverage, _this.partialCoverage) || other.partialCoverage == _this.partialCoverage)&&(identical(other.networkPreparedAt, _this.networkPreparedAt) || other.networkPreparedAt == _this.networkPreparedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGeneratorResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.candidates),_this.partialCoverage,_this.networkPreparedAt);
}

@override
String toString() {
  final _this = this as RouteGeneratorResponse;
  return 'RouteGeneratorResponse(candidates: ${_this.candidates}, partialCoverage: ${_this.partialCoverage}, networkPreparedAt: ${_this.networkPreparedAt})';
}


}

/// @nodoc
abstract mixin class $RouteGeneratorResponseCopyWith<$Res>  {
  factory $RouteGeneratorResponseCopyWith(RouteGeneratorResponse value, $Res Function(RouteGeneratorResponse) _then) = _$RouteGeneratorResponseCopyWithImpl;
@useResult
$Res call({
 List<GeneratedRouteDto> candidates, bool partialCoverage, String? networkPreparedAt
});




}
/// @nodoc
class _$RouteGeneratorResponseCopyWithImpl<$Res>
    implements $RouteGeneratorResponseCopyWith<$Res> {
  _$RouteGeneratorResponseCopyWithImpl(this._self, this._then);

  final RouteGeneratorResponse _self;
  final $Res Function(RouteGeneratorResponse) _then;

/// Create a copy of RouteGeneratorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? candidates = null,Object? partialCoverage = null,Object? networkPreparedAt = freezed,}) {
  return _then(RouteGeneratorResponse(
candidates: null == candidates ? _self.candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<GeneratedRouteDto>,partialCoverage: null == partialCoverage ? _self.partialCoverage : partialCoverage // ignore: cast_nullable_to_non_nullable
as bool,networkPreparedAt: freezed == networkPreparedAt ? _self.networkPreparedAt : networkPreparedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteGeneratorResponse].
extension RouteGeneratorResponsePatterns on RouteGeneratorResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGeneratorResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGeneratorResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGeneratorResponse value)  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGeneratorResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GeneratedRouteDto> candidates,  bool partialCoverage,  String? networkPreparedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGeneratorResponse() when $default != null:
return $default(_that.candidates,_that.partialCoverage,_that.networkPreparedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GeneratedRouteDto> candidates,  bool partialCoverage,  String? networkPreparedAt)  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorResponse():
return $default(_that.candidates,_that.partialCoverage,_that.networkPreparedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GeneratedRouteDto> candidates,  bool partialCoverage,  String? networkPreparedAt)?  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorResponse() when $default != null:
return $default(_that.candidates,_that.partialCoverage,_that.networkPreparedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGeneratorResponse implements RouteGeneratorResponse {
  const _RouteGeneratorResponse({required  List<GeneratedRouteDto> candidates, required this.partialCoverage, this.networkPreparedAt}): _candidates = candidates;
  factory _RouteGeneratorResponse.fromJson(Map<String, dynamic> json) => _$RouteGeneratorResponseFromJson(json);

/// One to three routes, best first, different from each other
 final  List<GeneratedRouteDto> _candidates;
/// One to three routes, best first, different from each other
@override List<GeneratedRouteDto> get candidates {
  if (_candidates is EqualUnmodifiableListView) return _candidates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_candidates);
}

/// True when part of the area around the start leaves the region the generator covers: proposals are rarer there
@override final  bool partialCoverage;
/// When the team's roads were last prepared for the generator (the night before at best). Absent when the request did not use them (discovery)
@override final  String? networkPreparedAt;

/// Create a copy of RouteGeneratorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGeneratorResponseCopyWith<_RouteGeneratorResponse> get copyWith => __$RouteGeneratorResponseCopyWithImpl<_RouteGeneratorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGeneratorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGeneratorResponse&&const DeepCollectionEquality().equals(other.candidates, _candidates)&&(identical(other.partialCoverage, partialCoverage) || other.partialCoverage == partialCoverage)&&(identical(other.networkPreparedAt, networkPreparedAt) || other.networkPreparedAt == networkPreparedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_candidates),partialCoverage,networkPreparedAt);
}

@override
String toString() {
    return 'RouteGeneratorResponse(candidates: $candidates, partialCoverage: $partialCoverage, networkPreparedAt: $networkPreparedAt)';
}


}

/// @nodoc
abstract mixin class _$RouteGeneratorResponseCopyWith<$Res> implements $RouteGeneratorResponseCopyWith<$Res> {
  factory _$RouteGeneratorResponseCopyWith(_RouteGeneratorResponse value, $Res Function(_RouteGeneratorResponse) _then) = __$RouteGeneratorResponseCopyWithImpl;
@override @useResult
$Res call({
 List<GeneratedRouteDto> candidates, bool partialCoverage, String? networkPreparedAt
});




}
/// @nodoc
class __$RouteGeneratorResponseCopyWithImpl<$Res>
    implements _$RouteGeneratorResponseCopyWith<$Res> {
  __$RouteGeneratorResponseCopyWithImpl(this._self, this._then);

  final _RouteGeneratorResponse _self;
  final $Res Function(_RouteGeneratorResponse) _then;

/// Create a copy of RouteGeneratorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? candidates = null,Object? partialCoverage = null,Object? networkPreparedAt = freezed,}) {
  return _then(_RouteGeneratorResponse(
candidates: null == candidates ? _self._candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<GeneratedRouteDto>,partialCoverage: null == partialCoverage ? _self.partialCoverage : partialCoverage // ignore: cast_nullable_to_non_nullable
as bool,networkPreparedAt: freezed == networkPreparedAt ? _self.networkPreparedAt : networkPreparedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
