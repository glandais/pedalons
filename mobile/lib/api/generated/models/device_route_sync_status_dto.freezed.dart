// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_route_sync_status_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceRouteSyncStatusDto {

/// GPS service
 String get serviceType;/// SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed
 String get state;
/// Create a copy of DeviceRouteSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceRouteSyncStatusDtoCopyWith<DeviceRouteSyncStatusDto> get copyWith => _$DeviceRouteSyncStatusDtoCopyWithImpl<DeviceRouteSyncStatusDto>(this as DeviceRouteSyncStatusDto, _$identity);

  /// Serializes this DeviceRouteSyncStatusDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeviceRouteSyncStatusDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceRouteSyncStatusDto&&(identical(other.serviceType, _this.serviceType) || other.serviceType == _this.serviceType)&&(identical(other.state, _this.state) || other.state == _this.state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeviceRouteSyncStatusDto;
  return Object.hash(runtimeType,_this.serviceType,_this.state);
}

@override
String toString() {
  final _this = this as DeviceRouteSyncStatusDto;
  return 'DeviceRouteSyncStatusDto(serviceType: ${_this.serviceType}, state: ${_this.state})';
}


}

/// @nodoc
abstract mixin class $DeviceRouteSyncStatusDtoCopyWith<$Res>  {
  factory $DeviceRouteSyncStatusDtoCopyWith(DeviceRouteSyncStatusDto value, $Res Function(DeviceRouteSyncStatusDto) _then) = _$DeviceRouteSyncStatusDtoCopyWithImpl;
@useResult
$Res call({
 String serviceType, String state
});




}
/// @nodoc
class _$DeviceRouteSyncStatusDtoCopyWithImpl<$Res>
    implements $DeviceRouteSyncStatusDtoCopyWith<$Res> {
  _$DeviceRouteSyncStatusDtoCopyWithImpl(this._self, this._then);

  final DeviceRouteSyncStatusDto _self;
  final $Res Function(DeviceRouteSyncStatusDto) _then;

/// Create a copy of DeviceRouteSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serviceType = null,Object? state = null,}) {
  return _then(DeviceRouteSyncStatusDto(
serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceRouteSyncStatusDto].
extension DeviceRouteSyncStatusDtoPatterns on DeviceRouteSyncStatusDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceRouteSyncStatusDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceRouteSyncStatusDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceRouteSyncStatusDto value)  $default,){
final _that = this;
switch (_that) {
case _DeviceRouteSyncStatusDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceRouteSyncStatusDto value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceRouteSyncStatusDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serviceType,  String state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceRouteSyncStatusDto() when $default != null:
return $default(_that.serviceType,_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serviceType,  String state)  $default,) {final _that = this;
switch (_that) {
case _DeviceRouteSyncStatusDto():
return $default(_that.serviceType,_that.state);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serviceType,  String state)?  $default,) {final _that = this;
switch (_that) {
case _DeviceRouteSyncStatusDto() when $default != null:
return $default(_that.serviceType,_that.state);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceRouteSyncStatusDto implements DeviceRouteSyncStatusDto {
  const _DeviceRouteSyncStatusDto({required this.serviceType, required this.state});
  factory _DeviceRouteSyncStatusDto.fromJson(Map<String, dynamic> json) => _$DeviceRouteSyncStatusDtoFromJson(json);

/// GPS service
@override final  String serviceType;
/// SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed
@override final  String state;

/// Create a copy of DeviceRouteSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceRouteSyncStatusDtoCopyWith<_DeviceRouteSyncStatusDto> get copyWith => __$DeviceRouteSyncStatusDtoCopyWithImpl<_DeviceRouteSyncStatusDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceRouteSyncStatusDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceRouteSyncStatusDto&&(identical(other.serviceType, serviceType) || other.serviceType == serviceType)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,serviceType,state);
}

@override
String toString() {
    return 'DeviceRouteSyncStatusDto(serviceType: $serviceType, state: $state)';
}


}

/// @nodoc
abstract mixin class _$DeviceRouteSyncStatusDtoCopyWith<$Res> implements $DeviceRouteSyncStatusDtoCopyWith<$Res> {
  factory _$DeviceRouteSyncStatusDtoCopyWith(_DeviceRouteSyncStatusDto value, $Res Function(_DeviceRouteSyncStatusDto) _then) = __$DeviceRouteSyncStatusDtoCopyWithImpl;
@override @useResult
$Res call({
 String serviceType, String state
});




}
/// @nodoc
class __$DeviceRouteSyncStatusDtoCopyWithImpl<$Res>
    implements _$DeviceRouteSyncStatusDtoCopyWith<$Res> {
  __$DeviceRouteSyncStatusDtoCopyWithImpl(this._self, this._then);

  final _DeviceRouteSyncStatusDto _self;
  final $Res Function(_DeviceRouteSyncStatusDto) _then;

/// Create a copy of DeviceRouteSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serviceType = null,Object? state = null,}) {
  return _then(_DeviceRouteSyncStatusDto(
serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
