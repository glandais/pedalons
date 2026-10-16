// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gps_auto_sync_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GpsAutoSyncRequest {

/// true to send the routes of the user's upcoming rides to this service automatically; false to stop, which also removes from the service the upcoming routes the sync sent
 bool get enabled;
/// Create a copy of GpsAutoSyncRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpsAutoSyncRequestCopyWith<GpsAutoSyncRequest> get copyWith => _$GpsAutoSyncRequestCopyWithImpl<GpsAutoSyncRequest>(this as GpsAutoSyncRequest, _$identity);

  /// Serializes this GpsAutoSyncRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GpsAutoSyncRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpsAutoSyncRequest&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GpsAutoSyncRequest;
  return Object.hash(runtimeType,_this.enabled);
}

@override
String toString() {
  final _this = this as GpsAutoSyncRequest;
  return 'GpsAutoSyncRequest(enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $GpsAutoSyncRequestCopyWith<$Res>  {
  factory $GpsAutoSyncRequestCopyWith(GpsAutoSyncRequest value, $Res Function(GpsAutoSyncRequest) _then) = _$GpsAutoSyncRequestCopyWithImpl;
@useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class _$GpsAutoSyncRequestCopyWithImpl<$Res>
    implements $GpsAutoSyncRequestCopyWith<$Res> {
  _$GpsAutoSyncRequestCopyWithImpl(this._self, this._then);

  final GpsAutoSyncRequest _self;
  final $Res Function(GpsAutoSyncRequest) _then;

/// Create a copy of GpsAutoSyncRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,}) {
  return _then(GpsAutoSyncRequest(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GpsAutoSyncRequest].
extension GpsAutoSyncRequestPatterns on GpsAutoSyncRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpsAutoSyncRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpsAutoSyncRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpsAutoSyncRequest value)  $default,){
final _that = this;
switch (_that) {
case _GpsAutoSyncRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpsAutoSyncRequest value)?  $default,){
final _that = this;
switch (_that) {
case _GpsAutoSyncRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpsAutoSyncRequest() when $default != null:
return $default(_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled)  $default,) {final _that = this;
switch (_that) {
case _GpsAutoSyncRequest():
return $default(_that.enabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _GpsAutoSyncRequest() when $default != null:
return $default(_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpsAutoSyncRequest implements GpsAutoSyncRequest {
  const _GpsAutoSyncRequest({required this.enabled});
  factory _GpsAutoSyncRequest.fromJson(Map<String, dynamic> json) => _$GpsAutoSyncRequestFromJson(json);

/// true to send the routes of the user's upcoming rides to this service automatically; false to stop, which also removes from the service the upcoming routes the sync sent
@override final  bool enabled;

/// Create a copy of GpsAutoSyncRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpsAutoSyncRequestCopyWith<_GpsAutoSyncRequest> get copyWith => __$GpsAutoSyncRequestCopyWithImpl<_GpsAutoSyncRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpsAutoSyncRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpsAutoSyncRequest&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,enabled);
}

@override
String toString() {
    return 'GpsAutoSyncRequest(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$GpsAutoSyncRequestCopyWith<$Res> implements $GpsAutoSyncRequestCopyWith<$Res> {
  factory _$GpsAutoSyncRequestCopyWith(_GpsAutoSyncRequest value, $Res Function(_GpsAutoSyncRequest) _then) = __$GpsAutoSyncRequestCopyWithImpl;
@override @useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class __$GpsAutoSyncRequestCopyWithImpl<$Res>
    implements _$GpsAutoSyncRequestCopyWith<$Res> {
  __$GpsAutoSyncRequestCopyWithImpl(this._self, this._then);

  final _GpsAutoSyncRequest _self;
  final $Res Function(_GpsAutoSyncRequest) _then;

/// Create a copy of GpsAutoSyncRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(_GpsAutoSyncRequest(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
