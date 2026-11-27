// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_gps_service_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminGpsServiceStatsDto {

/// The service (GARMIN, HAMMERHEAD)
 String get service;/// Connections
 int get connections;/// Accounts with at least one connection
 int get users;/// Connections with automatic sending on
 int get autoSync;/// Connections that must be reconnected
 int get reconnectRequired;/// Connections used during the last 30 days
 int get usedLast30Days;/// Routes sent or to send through these connections
 int get routeSyncs;/// Of which delivered
 int get routeSyncsSucceeded;/// Of which in error
 int get routeSyncsFailed;
/// Create a copy of AdminGpsServiceStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminGpsServiceStatsDtoCopyWith<AdminGpsServiceStatsDto> get copyWith => _$AdminGpsServiceStatsDtoCopyWithImpl<AdminGpsServiceStatsDto>(this as AdminGpsServiceStatsDto, _$identity);

  /// Serializes this AdminGpsServiceStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminGpsServiceStatsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminGpsServiceStatsDto&&(identical(other.service, _this.service) || other.service == _this.service)&&(identical(other.connections, _this.connections) || other.connections == _this.connections)&&(identical(other.users, _this.users) || other.users == _this.users)&&(identical(other.autoSync, _this.autoSync) || other.autoSync == _this.autoSync)&&(identical(other.reconnectRequired, _this.reconnectRequired) || other.reconnectRequired == _this.reconnectRequired)&&(identical(other.usedLast30Days, _this.usedLast30Days) || other.usedLast30Days == _this.usedLast30Days)&&(identical(other.routeSyncs, _this.routeSyncs) || other.routeSyncs == _this.routeSyncs)&&(identical(other.routeSyncsSucceeded, _this.routeSyncsSucceeded) || other.routeSyncsSucceeded == _this.routeSyncsSucceeded)&&(identical(other.routeSyncsFailed, _this.routeSyncsFailed) || other.routeSyncsFailed == _this.routeSyncsFailed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminGpsServiceStatsDto;
  return Object.hash(runtimeType,_this.service,_this.connections,_this.users,_this.autoSync,_this.reconnectRequired,_this.usedLast30Days,_this.routeSyncs,_this.routeSyncsSucceeded,_this.routeSyncsFailed);
}

@override
String toString() {
  final _this = this as AdminGpsServiceStatsDto;
  return 'AdminGpsServiceStatsDto(service: ${_this.service}, connections: ${_this.connections}, users: ${_this.users}, autoSync: ${_this.autoSync}, reconnectRequired: ${_this.reconnectRequired}, usedLast30Days: ${_this.usedLast30Days}, routeSyncs: ${_this.routeSyncs}, routeSyncsSucceeded: ${_this.routeSyncsSucceeded}, routeSyncsFailed: ${_this.routeSyncsFailed})';
}


}

/// @nodoc
abstract mixin class $AdminGpsServiceStatsDtoCopyWith<$Res>  {
  factory $AdminGpsServiceStatsDtoCopyWith(AdminGpsServiceStatsDto value, $Res Function(AdminGpsServiceStatsDto) _then) = _$AdminGpsServiceStatsDtoCopyWithImpl;
@useResult
$Res call({
 String service, int connections, int users, int autoSync, int reconnectRequired, int usedLast30Days, int routeSyncs, int routeSyncsSucceeded, int routeSyncsFailed
});




}
/// @nodoc
class _$AdminGpsServiceStatsDtoCopyWithImpl<$Res>
    implements $AdminGpsServiceStatsDtoCopyWith<$Res> {
  _$AdminGpsServiceStatsDtoCopyWithImpl(this._self, this._then);

  final AdminGpsServiceStatsDto _self;
  final $Res Function(AdminGpsServiceStatsDto) _then;

/// Create a copy of AdminGpsServiceStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? service = null,Object? connections = null,Object? users = null,Object? autoSync = null,Object? reconnectRequired = null,Object? usedLast30Days = null,Object? routeSyncs = null,Object? routeSyncsSucceeded = null,Object? routeSyncsFailed = null,}) {
  return _then(AdminGpsServiceStatsDto(
service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as int,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as int,reconnectRequired: null == reconnectRequired ? _self.reconnectRequired : reconnectRequired // ignore: cast_nullable_to_non_nullable
as int,usedLast30Days: null == usedLast30Days ? _self.usedLast30Days : usedLast30Days // ignore: cast_nullable_to_non_nullable
as int,routeSyncs: null == routeSyncs ? _self.routeSyncs : routeSyncs // ignore: cast_nullable_to_non_nullable
as int,routeSyncsSucceeded: null == routeSyncsSucceeded ? _self.routeSyncsSucceeded : routeSyncsSucceeded // ignore: cast_nullable_to_non_nullable
as int,routeSyncsFailed: null == routeSyncsFailed ? _self.routeSyncsFailed : routeSyncsFailed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminGpsServiceStatsDto].
extension AdminGpsServiceStatsDtoPatterns on AdminGpsServiceStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminGpsServiceStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminGpsServiceStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminGpsServiceStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminGpsServiceStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminGpsServiceStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminGpsServiceStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String service,  int connections,  int users,  int autoSync,  int reconnectRequired,  int usedLast30Days,  int routeSyncs,  int routeSyncsSucceeded,  int routeSyncsFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminGpsServiceStatsDto() when $default != null:
return $default(_that.service,_that.connections,_that.users,_that.autoSync,_that.reconnectRequired,_that.usedLast30Days,_that.routeSyncs,_that.routeSyncsSucceeded,_that.routeSyncsFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String service,  int connections,  int users,  int autoSync,  int reconnectRequired,  int usedLast30Days,  int routeSyncs,  int routeSyncsSucceeded,  int routeSyncsFailed)  $default,) {final _that = this;
switch (_that) {
case _AdminGpsServiceStatsDto():
return $default(_that.service,_that.connections,_that.users,_that.autoSync,_that.reconnectRequired,_that.usedLast30Days,_that.routeSyncs,_that.routeSyncsSucceeded,_that.routeSyncsFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String service,  int connections,  int users,  int autoSync,  int reconnectRequired,  int usedLast30Days,  int routeSyncs,  int routeSyncsSucceeded,  int routeSyncsFailed)?  $default,) {final _that = this;
switch (_that) {
case _AdminGpsServiceStatsDto() when $default != null:
return $default(_that.service,_that.connections,_that.users,_that.autoSync,_that.reconnectRequired,_that.usedLast30Days,_that.routeSyncs,_that.routeSyncsSucceeded,_that.routeSyncsFailed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminGpsServiceStatsDto implements AdminGpsServiceStatsDto {
  const _AdminGpsServiceStatsDto({required this.service, required this.connections, required this.users, required this.autoSync, required this.reconnectRequired, required this.usedLast30Days, required this.routeSyncs, required this.routeSyncsSucceeded, required this.routeSyncsFailed});
  factory _AdminGpsServiceStatsDto.fromJson(Map<String, dynamic> json) => _$AdminGpsServiceStatsDtoFromJson(json);

/// The service (GARMIN, HAMMERHEAD)
@override final  String service;
/// Connections
@override final  int connections;
/// Accounts with at least one connection
@override final  int users;
/// Connections with automatic sending on
@override final  int autoSync;
/// Connections that must be reconnected
@override final  int reconnectRequired;
/// Connections used during the last 30 days
@override final  int usedLast30Days;
/// Routes sent or to send through these connections
@override final  int routeSyncs;
/// Of which delivered
@override final  int routeSyncsSucceeded;
/// Of which in error
@override final  int routeSyncsFailed;

/// Create a copy of AdminGpsServiceStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminGpsServiceStatsDtoCopyWith<_AdminGpsServiceStatsDto> get copyWith => __$AdminGpsServiceStatsDtoCopyWithImpl<_AdminGpsServiceStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminGpsServiceStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminGpsServiceStatsDto&&(identical(other.service, service) || other.service == service)&&(identical(other.connections, connections) || other.connections == connections)&&(identical(other.users, users) || other.users == users)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.reconnectRequired, reconnectRequired) || other.reconnectRequired == reconnectRequired)&&(identical(other.usedLast30Days, usedLast30Days) || other.usedLast30Days == usedLast30Days)&&(identical(other.routeSyncs, routeSyncs) || other.routeSyncs == routeSyncs)&&(identical(other.routeSyncsSucceeded, routeSyncsSucceeded) || other.routeSyncsSucceeded == routeSyncsSucceeded)&&(identical(other.routeSyncsFailed, routeSyncsFailed) || other.routeSyncsFailed == routeSyncsFailed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,service,connections,users,autoSync,reconnectRequired,usedLast30Days,routeSyncs,routeSyncsSucceeded,routeSyncsFailed);
}

@override
String toString() {
    return 'AdminGpsServiceStatsDto(service: $service, connections: $connections, users: $users, autoSync: $autoSync, reconnectRequired: $reconnectRequired, usedLast30Days: $usedLast30Days, routeSyncs: $routeSyncs, routeSyncsSucceeded: $routeSyncsSucceeded, routeSyncsFailed: $routeSyncsFailed)';
}


}

/// @nodoc
abstract mixin class _$AdminGpsServiceStatsDtoCopyWith<$Res> implements $AdminGpsServiceStatsDtoCopyWith<$Res> {
  factory _$AdminGpsServiceStatsDtoCopyWith(_AdminGpsServiceStatsDto value, $Res Function(_AdminGpsServiceStatsDto) _then) = __$AdminGpsServiceStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 String service, int connections, int users, int autoSync, int reconnectRequired, int usedLast30Days, int routeSyncs, int routeSyncsSucceeded, int routeSyncsFailed
});




}
/// @nodoc
class __$AdminGpsServiceStatsDtoCopyWithImpl<$Res>
    implements _$AdminGpsServiceStatsDtoCopyWith<$Res> {
  __$AdminGpsServiceStatsDtoCopyWithImpl(this._self, this._then);

  final _AdminGpsServiceStatsDto _self;
  final $Res Function(_AdminGpsServiceStatsDto) _then;

/// Create a copy of AdminGpsServiceStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? service = null,Object? connections = null,Object? users = null,Object? autoSync = null,Object? reconnectRequired = null,Object? usedLast30Days = null,Object? routeSyncs = null,Object? routeSyncsSucceeded = null,Object? routeSyncsFailed = null,}) {
  return _then(_AdminGpsServiceStatsDto(
service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as int,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as int,reconnectRequired: null == reconnectRequired ? _self.reconnectRequired : reconnectRequired // ignore: cast_nullable_to_non_nullable
as int,usedLast30Days: null == usedLast30Days ? _self.usedLast30Days : usedLast30Days // ignore: cast_nullable_to_non_nullable
as int,routeSyncs: null == routeSyncs ? _self.routeSyncs : routeSyncs // ignore: cast_nullable_to_non_nullable
as int,routeSyncsSucceeded: null == routeSyncsSucceeded ? _self.routeSyncsSucceeded : routeSyncsSucceeded // ignore: cast_nullable_to_non_nullable
as int,routeSyncsFailed: null == routeSyncsFailed ? _self.routeSyncsFailed : routeSyncsFailed // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
