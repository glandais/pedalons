// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'elevation_refresh_retry_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ElevationRefreshRetryRequest {

/// List what would be retried, without changing anything
 bool get dryRun;/// Retry at most this many targets, oldest first (default 100)
 int? get limit;/// Only this kind of target (default: both)
 String? get kind;
/// Create a copy of ElevationRefreshRetryRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ElevationRefreshRetryRequestCopyWith<ElevationRefreshRetryRequest> get copyWith => _$ElevationRefreshRetryRequestCopyWithImpl<ElevationRefreshRetryRequest>(this as ElevationRefreshRetryRequest, _$identity);

  /// Serializes this ElevationRefreshRetryRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ElevationRefreshRetryRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ElevationRefreshRetryRequest&&(identical(other.dryRun, _this.dryRun) || other.dryRun == _this.dryRun)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ElevationRefreshRetryRequest;
  return Object.hash(runtimeType,_this.dryRun,_this.limit,_this.kind);
}

@override
String toString() {
  final _this = this as ElevationRefreshRetryRequest;
  return 'ElevationRefreshRetryRequest(dryRun: ${_this.dryRun}, limit: ${_this.limit}, kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $ElevationRefreshRetryRequestCopyWith<$Res>  {
  factory $ElevationRefreshRetryRequestCopyWith(ElevationRefreshRetryRequest value, $Res Function(ElevationRefreshRetryRequest) _then) = _$ElevationRefreshRetryRequestCopyWithImpl;
@useResult
$Res call({
 bool dryRun, int? limit, String? kind
});




}
/// @nodoc
class _$ElevationRefreshRetryRequestCopyWithImpl<$Res>
    implements $ElevationRefreshRetryRequestCopyWith<$Res> {
  _$ElevationRefreshRetryRequestCopyWithImpl(this._self, this._then);

  final ElevationRefreshRetryRequest _self;
  final $Res Function(ElevationRefreshRetryRequest) _then;

/// Create a copy of ElevationRefreshRetryRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dryRun = null,Object? limit = freezed,Object? kind = freezed,}) {
  return _then(ElevationRefreshRetryRequest(
dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ElevationRefreshRetryRequest].
extension ElevationRefreshRetryRequestPatterns on ElevationRefreshRetryRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ElevationRefreshRetryRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ElevationRefreshRetryRequest value)  $default,){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ElevationRefreshRetryRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool dryRun,  int? limit,  String? kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryRequest() when $default != null:
return $default(_that.dryRun,_that.limit,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool dryRun,  int? limit,  String? kind)  $default,) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryRequest():
return $default(_that.dryRun,_that.limit,_that.kind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool dryRun,  int? limit,  String? kind)?  $default,) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryRequest() when $default != null:
return $default(_that.dryRun,_that.limit,_that.kind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ElevationRefreshRetryRequest implements ElevationRefreshRetryRequest {
  const _ElevationRefreshRetryRequest({required this.dryRun, this.limit, this.kind});
  factory _ElevationRefreshRetryRequest.fromJson(Map<String, dynamic> json) => _$ElevationRefreshRetryRequestFromJson(json);

/// List what would be retried, without changing anything
@override final  bool dryRun;
/// Retry at most this many targets, oldest first (default 100)
@override final  int? limit;
/// Only this kind of target (default: both)
@override final  String? kind;

/// Create a copy of ElevationRefreshRetryRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ElevationRefreshRetryRequestCopyWith<_ElevationRefreshRetryRequest> get copyWith => __$ElevationRefreshRetryRequestCopyWithImpl<_ElevationRefreshRetryRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ElevationRefreshRetryRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ElevationRefreshRetryRequest&&(identical(other.dryRun, dryRun) || other.dryRun == dryRun)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,dryRun,limit,kind);
}

@override
String toString() {
    return 'ElevationRefreshRetryRequest(dryRun: $dryRun, limit: $limit, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$ElevationRefreshRetryRequestCopyWith<$Res> implements $ElevationRefreshRetryRequestCopyWith<$Res> {
  factory _$ElevationRefreshRetryRequestCopyWith(_ElevationRefreshRetryRequest value, $Res Function(_ElevationRefreshRetryRequest) _then) = __$ElevationRefreshRetryRequestCopyWithImpl;
@override @useResult
$Res call({
 bool dryRun, int? limit, String? kind
});




}
/// @nodoc
class __$ElevationRefreshRetryRequestCopyWithImpl<$Res>
    implements _$ElevationRefreshRetryRequestCopyWith<$Res> {
  __$ElevationRefreshRetryRequestCopyWithImpl(this._self, this._then);

  final _ElevationRefreshRetryRequest _self;
  final $Res Function(_ElevationRefreshRetryRequest) _then;

/// Create a copy of ElevationRefreshRetryRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dryRun = null,Object? limit = freezed,Object? kind = freezed,}) {
  return _then(_ElevationRefreshRetryRequest(
dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
