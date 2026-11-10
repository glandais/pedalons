// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_gps_sync_status_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGpsSyncStatusDto {

/// GPS service
 String get serviceType;/// SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed
 String get state;/// When the route was last sent to the service successfully. Absent while it never was.
 String? get syncedAt;
/// Create a copy of RouteGpsSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGpsSyncStatusDtoCopyWith<RouteGpsSyncStatusDto> get copyWith => _$RouteGpsSyncStatusDtoCopyWithImpl<RouteGpsSyncStatusDto>(this as RouteGpsSyncStatusDto, _$identity);

  /// Serializes this RouteGpsSyncStatusDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGpsSyncStatusDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGpsSyncStatusDto&&(identical(other.serviceType, _this.serviceType) || other.serviceType == _this.serviceType)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.syncedAt, _this.syncedAt) || other.syncedAt == _this.syncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGpsSyncStatusDto;
  return Object.hash(runtimeType,_this.serviceType,_this.state,_this.syncedAt);
}

@override
String toString() {
  final _this = this as RouteGpsSyncStatusDto;
  return 'RouteGpsSyncStatusDto(serviceType: ${_this.serviceType}, state: ${_this.state}, syncedAt: ${_this.syncedAt})';
}


}

/// @nodoc
abstract mixin class $RouteGpsSyncStatusDtoCopyWith<$Res>  {
  factory $RouteGpsSyncStatusDtoCopyWith(RouteGpsSyncStatusDto value, $Res Function(RouteGpsSyncStatusDto) _then) = _$RouteGpsSyncStatusDtoCopyWithImpl;
@useResult
$Res call({
 String serviceType, String state, String? syncedAt
});




}
/// @nodoc
class _$RouteGpsSyncStatusDtoCopyWithImpl<$Res>
    implements $RouteGpsSyncStatusDtoCopyWith<$Res> {
  _$RouteGpsSyncStatusDtoCopyWithImpl(this._self, this._then);

  final RouteGpsSyncStatusDto _self;
  final $Res Function(RouteGpsSyncStatusDto) _then;

/// Create a copy of RouteGpsSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serviceType = null,Object? state = null,Object? syncedAt = freezed,}) {
  return _then(RouteGpsSyncStatusDto(
serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,syncedAt: freezed == syncedAt ? _self.syncedAt : syncedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteGpsSyncStatusDto].
extension RouteGpsSyncStatusDtoPatterns on RouteGpsSyncStatusDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGpsSyncStatusDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGpsSyncStatusDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGpsSyncStatusDto value)  $default,){
final _that = this;
switch (_that) {
case _RouteGpsSyncStatusDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGpsSyncStatusDto value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGpsSyncStatusDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serviceType,  String state,  String? syncedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGpsSyncStatusDto() when $default != null:
return $default(_that.serviceType,_that.state,_that.syncedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serviceType,  String state,  String? syncedAt)  $default,) {final _that = this;
switch (_that) {
case _RouteGpsSyncStatusDto():
return $default(_that.serviceType,_that.state,_that.syncedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serviceType,  String state,  String? syncedAt)?  $default,) {final _that = this;
switch (_that) {
case _RouteGpsSyncStatusDto() when $default != null:
return $default(_that.serviceType,_that.state,_that.syncedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGpsSyncStatusDto implements RouteGpsSyncStatusDto {
  const _RouteGpsSyncStatusDto({required this.serviceType, required this.state, this.syncedAt});
  factory _RouteGpsSyncStatusDto.fromJson(Map<String, dynamic> json) => _$RouteGpsSyncStatusDtoFromJson(json);

/// GPS service
@override final  String serviceType;
/// SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed
@override final  String state;
/// When the route was last sent to the service successfully. Absent while it never was.
@override final  String? syncedAt;

/// Create a copy of RouteGpsSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGpsSyncStatusDtoCopyWith<_RouteGpsSyncStatusDto> get copyWith => __$RouteGpsSyncStatusDtoCopyWithImpl<_RouteGpsSyncStatusDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGpsSyncStatusDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGpsSyncStatusDto&&(identical(other.serviceType, serviceType) || other.serviceType == serviceType)&&(identical(other.state, state) || other.state == state)&&(identical(other.syncedAt, syncedAt) || other.syncedAt == syncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,serviceType,state,syncedAt);
}

@override
String toString() {
    return 'RouteGpsSyncStatusDto(serviceType: $serviceType, state: $state, syncedAt: $syncedAt)';
}


}

/// @nodoc
abstract mixin class _$RouteGpsSyncStatusDtoCopyWith<$Res> implements $RouteGpsSyncStatusDtoCopyWith<$Res> {
  factory _$RouteGpsSyncStatusDtoCopyWith(_RouteGpsSyncStatusDto value, $Res Function(_RouteGpsSyncStatusDto) _then) = __$RouteGpsSyncStatusDtoCopyWithImpl;
@override @useResult
$Res call({
 String serviceType, String state, String? syncedAt
});




}
/// @nodoc
class __$RouteGpsSyncStatusDtoCopyWithImpl<$Res>
    implements _$RouteGpsSyncStatusDtoCopyWith<$Res> {
  __$RouteGpsSyncStatusDtoCopyWithImpl(this._self, this._then);

  final _RouteGpsSyncStatusDto _self;
  final $Res Function(_RouteGpsSyncStatusDto) _then;

/// Create a copy of RouteGpsSyncStatusDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serviceType = null,Object? state = null,Object? syncedAt = freezed,}) {
  return _then(_RouteGpsSyncStatusDto(
serviceType: null == serviceType ? _self.serviceType : serviceType // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,syncedAt: freezed == syncedAt ? _self.syncedAt : syncedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
