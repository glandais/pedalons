// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'router_engines_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouterEnginesResponse {

/// The engines the planner can ask for a leg. STADIA is always there, with every profile; PEDALONS only when the service behind it is configured and says it is ready
 List<RouterEngineOffer> get engines;
/// Create a copy of RouterEnginesResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouterEnginesResponseCopyWith<RouterEnginesResponse> get copyWith => _$RouterEnginesResponseCopyWithImpl<RouterEnginesResponse>(this as RouterEnginesResponse, _$identity);

  /// Serializes this RouterEnginesResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouterEnginesResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouterEnginesResponse&&const DeepCollectionEquality().equals(other.engines, _this.engines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouterEnginesResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.engines));
}

@override
String toString() {
  final _this = this as RouterEnginesResponse;
  return 'RouterEnginesResponse(engines: ${_this.engines})';
}


}

/// @nodoc
abstract mixin class $RouterEnginesResponseCopyWith<$Res>  {
  factory $RouterEnginesResponseCopyWith(RouterEnginesResponse value, $Res Function(RouterEnginesResponse) _then) = _$RouterEnginesResponseCopyWithImpl;
@useResult
$Res call({
 List<RouterEngineOffer> engines
});




}
/// @nodoc
class _$RouterEnginesResponseCopyWithImpl<$Res>
    implements $RouterEnginesResponseCopyWith<$Res> {
  _$RouterEnginesResponseCopyWithImpl(this._self, this._then);

  final RouterEnginesResponse _self;
  final $Res Function(RouterEnginesResponse) _then;

/// Create a copy of RouterEnginesResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? engines = null,}) {
  return _then(RouterEnginesResponse(
engines: null == engines ? _self.engines : engines // ignore: cast_nullable_to_non_nullable
as List<RouterEngineOffer>,
  ));
}

}


/// Adds pattern-matching-related methods to [RouterEnginesResponse].
extension RouterEnginesResponsePatterns on RouterEnginesResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouterEnginesResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouterEnginesResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouterEnginesResponse value)  $default,){
final _that = this;
switch (_that) {
case _RouterEnginesResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouterEnginesResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RouterEnginesResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<RouterEngineOffer> engines)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouterEnginesResponse() when $default != null:
return $default(_that.engines);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<RouterEngineOffer> engines)  $default,) {final _that = this;
switch (_that) {
case _RouterEnginesResponse():
return $default(_that.engines);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<RouterEngineOffer> engines)?  $default,) {final _that = this;
switch (_that) {
case _RouterEnginesResponse() when $default != null:
return $default(_that.engines);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouterEnginesResponse implements RouterEnginesResponse {
  const _RouterEnginesResponse({required  List<RouterEngineOffer> engines}): _engines = engines;
  factory _RouterEnginesResponse.fromJson(Map<String, dynamic> json) => _$RouterEnginesResponseFromJson(json);

/// The engines the planner can ask for a leg. STADIA is always there, with every profile; PEDALONS only when the service behind it is configured and says it is ready
 final  List<RouterEngineOffer> _engines;
/// The engines the planner can ask for a leg. STADIA is always there, with every profile; PEDALONS only when the service behind it is configured and says it is ready
@override List<RouterEngineOffer> get engines {
  if (_engines is EqualUnmodifiableListView) return _engines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_engines);
}


/// Create a copy of RouterEnginesResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouterEnginesResponseCopyWith<_RouterEnginesResponse> get copyWith => __$RouterEnginesResponseCopyWithImpl<_RouterEnginesResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouterEnginesResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouterEnginesResponse&&const DeepCollectionEquality().equals(other.engines, _engines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_engines));
}

@override
String toString() {
    return 'RouterEnginesResponse(engines: $engines)';
}


}

/// @nodoc
abstract mixin class _$RouterEnginesResponseCopyWith<$Res> implements $RouterEnginesResponseCopyWith<$Res> {
  factory _$RouterEnginesResponseCopyWith(_RouterEnginesResponse value, $Res Function(_RouterEnginesResponse) _then) = __$RouterEnginesResponseCopyWithImpl;
@override @useResult
$Res call({
 List<RouterEngineOffer> engines
});




}
/// @nodoc
class __$RouterEnginesResponseCopyWithImpl<$Res>
    implements _$RouterEnginesResponseCopyWith<$Res> {
  __$RouterEnginesResponseCopyWithImpl(this._self, this._then);

  final _RouterEnginesResponse _self;
  final $Res Function(_RouterEnginesResponse) _then;

/// Create a copy of RouterEnginesResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? engines = null,}) {
  return _then(_RouterEnginesResponse(
engines: null == engines ? _self._engines : engines // ignore: cast_nullable_to_non_nullable
as List<RouterEngineOffer>,
  ));
}


}

// dart format on
