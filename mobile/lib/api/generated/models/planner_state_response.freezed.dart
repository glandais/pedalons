// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planner_state_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannerStateResponse {

/// The state; absent when there is none to read back
 PlannerState? get state;
/// Create a copy of PlannerStateResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannerStateResponseCopyWith<PlannerStateResponse> get copyWith => _$PlannerStateResponseCopyWithImpl<PlannerStateResponse>(this as PlannerStateResponse, _$identity);

  /// Serializes this PlannerStateResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlannerStateResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannerStateResponse&&(identical(other.state, _this.state) || other.state == _this.state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlannerStateResponse;
  return Object.hash(runtimeType,_this.state);
}

@override
String toString() {
  final _this = this as PlannerStateResponse;
  return 'PlannerStateResponse(state: ${_this.state})';
}


}

/// @nodoc
abstract mixin class $PlannerStateResponseCopyWith<$Res>  {
  factory $PlannerStateResponseCopyWith(PlannerStateResponse value, $Res Function(PlannerStateResponse) _then) = _$PlannerStateResponseCopyWithImpl;
@useResult
$Res call({
 PlannerState? state
});


$PlannerStateCopyWith<$Res>? get state;

}
/// @nodoc
class _$PlannerStateResponseCopyWithImpl<$Res>
    implements $PlannerStateResponseCopyWith<$Res> {
  _$PlannerStateResponseCopyWithImpl(this._self, this._then);

  final PlannerStateResponse _self;
  final $Res Function(PlannerStateResponse) _then;

/// Create a copy of PlannerStateResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = freezed,}) {
  return _then(PlannerStateResponse(
state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PlannerState?,
  ));
}
/// Create a copy of PlannerStateResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $PlannerStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlannerStateResponse].
extension PlannerStateResponsePatterns on PlannerStateResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannerStateResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannerStateResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannerStateResponse value)  $default,){
final _that = this;
switch (_that) {
case _PlannerStateResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannerStateResponse value)?  $default,){
final _that = this;
switch (_that) {
case _PlannerStateResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PlannerState? state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannerStateResponse() when $default != null:
return $default(_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PlannerState? state)  $default,) {final _that = this;
switch (_that) {
case _PlannerStateResponse():
return $default(_that.state);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PlannerState? state)?  $default,) {final _that = this;
switch (_that) {
case _PlannerStateResponse() when $default != null:
return $default(_that.state);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannerStateResponse implements PlannerStateResponse {
  const _PlannerStateResponse({this.state});
  factory _PlannerStateResponse.fromJson(Map<String, dynamic> json) => _$PlannerStateResponseFromJson(json);

/// The state; absent when there is none to read back
@override final  PlannerState? state;

/// Create a copy of PlannerStateResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannerStateResponseCopyWith<_PlannerStateResponse> get copyWith => __$PlannerStateResponseCopyWithImpl<_PlannerStateResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannerStateResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannerStateResponse&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,state);
}

@override
String toString() {
    return 'PlannerStateResponse(state: $state)';
}


}

/// @nodoc
abstract mixin class _$PlannerStateResponseCopyWith<$Res> implements $PlannerStateResponseCopyWith<$Res> {
  factory _$PlannerStateResponseCopyWith(_PlannerStateResponse value, $Res Function(_PlannerStateResponse) _then) = __$PlannerStateResponseCopyWithImpl;
@override @useResult
$Res call({
 PlannerState? state
});


@override $PlannerStateCopyWith<$Res>? get state;

}
/// @nodoc
class __$PlannerStateResponseCopyWithImpl<$Res>
    implements _$PlannerStateResponseCopyWith<$Res> {
  __$PlannerStateResponseCopyWithImpl(this._self, this._then);

  final _PlannerStateResponse _self;
  final $Res Function(_PlannerStateResponse) _then;

/// Create a copy of PlannerStateResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = freezed,}) {
  return _then(_PlannerStateResponse(
state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PlannerState?,
  ));
}

/// Create a copy of PlannerStateResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerStateCopyWith<$Res>? get state {
    if (_self.state == null) {
    return null;
  }

  return $PlannerStateCopyWith<$Res>(_self.state!, (value) {
    return _then(_self.copyWith(state: value));
  });
}
}

// dart format on
