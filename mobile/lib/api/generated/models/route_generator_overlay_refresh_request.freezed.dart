// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_generator_overlay_refresh_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGeneratorOverlayRefreshRequest {

/// Deposit every team again, whatever its overlay: after a key rotation or a new graph
 bool get force;/// Say what would be done, without depositing or deleting anything
 bool get dryRun;/// Only this team (default: every team of every domain)
 String? get teamId;
/// Create a copy of RouteGeneratorOverlayRefreshRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGeneratorOverlayRefreshRequestCopyWith<RouteGeneratorOverlayRefreshRequest> get copyWith => _$RouteGeneratorOverlayRefreshRequestCopyWithImpl<RouteGeneratorOverlayRefreshRequest>(this as RouteGeneratorOverlayRefreshRequest, _$identity);

  /// Serializes this RouteGeneratorOverlayRefreshRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGeneratorOverlayRefreshRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGeneratorOverlayRefreshRequest&&(identical(other.force, _this.force) || other.force == _this.force)&&(identical(other.dryRun, _this.dryRun) || other.dryRun == _this.dryRun)&&(identical(other.teamId, _this.teamId) || other.teamId == _this.teamId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGeneratorOverlayRefreshRequest;
  return Object.hash(runtimeType,_this.force,_this.dryRun,_this.teamId);
}

@override
String toString() {
  final _this = this as RouteGeneratorOverlayRefreshRequest;
  return 'RouteGeneratorOverlayRefreshRequest(force: ${_this.force}, dryRun: ${_this.dryRun}, teamId: ${_this.teamId})';
}


}

/// @nodoc
abstract mixin class $RouteGeneratorOverlayRefreshRequestCopyWith<$Res>  {
  factory $RouteGeneratorOverlayRefreshRequestCopyWith(RouteGeneratorOverlayRefreshRequest value, $Res Function(RouteGeneratorOverlayRefreshRequest) _then) = _$RouteGeneratorOverlayRefreshRequestCopyWithImpl;
@useResult
$Res call({
 bool force, bool dryRun, String? teamId
});




}
/// @nodoc
class _$RouteGeneratorOverlayRefreshRequestCopyWithImpl<$Res>
    implements $RouteGeneratorOverlayRefreshRequestCopyWith<$Res> {
  _$RouteGeneratorOverlayRefreshRequestCopyWithImpl(this._self, this._then);

  final RouteGeneratorOverlayRefreshRequest _self;
  final $Res Function(RouteGeneratorOverlayRefreshRequest) _then;

/// Create a copy of RouteGeneratorOverlayRefreshRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? force = null,Object? dryRun = null,Object? teamId = freezed,}) {
  return _then(RouteGeneratorOverlayRefreshRequest(
force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,teamId: freezed == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteGeneratorOverlayRefreshRequest].
extension RouteGeneratorOverlayRefreshRequestPatterns on RouteGeneratorOverlayRefreshRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGeneratorOverlayRefreshRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGeneratorOverlayRefreshRequest value)  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGeneratorOverlayRefreshRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool force,  bool dryRun,  String? teamId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshRequest() when $default != null:
return $default(_that.force,_that.dryRun,_that.teamId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool force,  bool dryRun,  String? teamId)  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshRequest():
return $default(_that.force,_that.dryRun,_that.teamId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool force,  bool dryRun,  String? teamId)?  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshRequest() when $default != null:
return $default(_that.force,_that.dryRun,_that.teamId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGeneratorOverlayRefreshRequest implements RouteGeneratorOverlayRefreshRequest {
  const _RouteGeneratorOverlayRefreshRequest({required this.force, required this.dryRun, this.teamId});
  factory _RouteGeneratorOverlayRefreshRequest.fromJson(Map<String, dynamic> json) => _$RouteGeneratorOverlayRefreshRequestFromJson(json);

/// Deposit every team again, whatever its overlay: after a key rotation or a new graph
@override final  bool force;
/// Say what would be done, without depositing or deleting anything
@override final  bool dryRun;
/// Only this team (default: every team of every domain)
@override final  String? teamId;

/// Create a copy of RouteGeneratorOverlayRefreshRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGeneratorOverlayRefreshRequestCopyWith<_RouteGeneratorOverlayRefreshRequest> get copyWith => __$RouteGeneratorOverlayRefreshRequestCopyWithImpl<_RouteGeneratorOverlayRefreshRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGeneratorOverlayRefreshRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGeneratorOverlayRefreshRequest&&(identical(other.force, force) || other.force == force)&&(identical(other.dryRun, dryRun) || other.dryRun == dryRun)&&(identical(other.teamId, teamId) || other.teamId == teamId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,force,dryRun,teamId);
}

@override
String toString() {
    return 'RouteGeneratorOverlayRefreshRequest(force: $force, dryRun: $dryRun, teamId: $teamId)';
}


}

/// @nodoc
abstract mixin class _$RouteGeneratorOverlayRefreshRequestCopyWith<$Res> implements $RouteGeneratorOverlayRefreshRequestCopyWith<$Res> {
  factory _$RouteGeneratorOverlayRefreshRequestCopyWith(_RouteGeneratorOverlayRefreshRequest value, $Res Function(_RouteGeneratorOverlayRefreshRequest) _then) = __$RouteGeneratorOverlayRefreshRequestCopyWithImpl;
@override @useResult
$Res call({
 bool force, bool dryRun, String? teamId
});




}
/// @nodoc
class __$RouteGeneratorOverlayRefreshRequestCopyWithImpl<$Res>
    implements _$RouteGeneratorOverlayRefreshRequestCopyWith<$Res> {
  __$RouteGeneratorOverlayRefreshRequestCopyWithImpl(this._self, this._then);

  final _RouteGeneratorOverlayRefreshRequest _self;
  final $Res Function(_RouteGeneratorOverlayRefreshRequest) _then;

/// Create a copy of RouteGeneratorOverlayRefreshRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? force = null,Object? dryRun = null,Object? teamId = freezed,}) {
  return _then(_RouteGeneratorOverlayRefreshRequest(
force: null == force ? _self.force : force // ignore: cast_nullable_to_non_nullable
as bool,dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,teamId: freezed == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
