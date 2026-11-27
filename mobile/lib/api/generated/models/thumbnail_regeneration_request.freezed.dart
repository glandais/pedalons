// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'thumbnail_regeneration_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ThumbnailRegenerationRequest {

/// List what would be redrawn, without redrawing anything
 bool get dryRun;/// Only thumbnails drawn at or after this instant
 String? get renderedFrom;/// Only thumbnails drawn before this instant
 String? get renderedTo;/// Only thumbnails whose stored file is smaller than this many bytes, or has no file. A map drawn without its background weighs a few kB, a real one tens.
 int? get suspectBelowBytes;/// Also redraw the routes, rides and trips that have a route to draw but lack a light or dark thumbnail — what a failed render leaves behind
 bool? get includeMissing;/// Also redraw the routes, rides and trips with a thumbnail drawn before the current basemap — what the automatic catch-up redraws by itself, in the background
 bool? get outdated;/// Also redraw the routes, rides and trips the automatic catch-up gave up on after repeated failures, which it no longer tries
 bool? get givenUp;/// Redraw at most this many entities (default 100)
 int? get limit;
/// Create a copy of ThumbnailRegenerationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThumbnailRegenerationRequestCopyWith<ThumbnailRegenerationRequest> get copyWith => _$ThumbnailRegenerationRequestCopyWithImpl<ThumbnailRegenerationRequest>(this as ThumbnailRegenerationRequest, _$identity);

  /// Serializes this ThumbnailRegenerationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ThumbnailRegenerationRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThumbnailRegenerationRequest&&(identical(other.dryRun, _this.dryRun) || other.dryRun == _this.dryRun)&&(identical(other.renderedFrom, _this.renderedFrom) || other.renderedFrom == _this.renderedFrom)&&(identical(other.renderedTo, _this.renderedTo) || other.renderedTo == _this.renderedTo)&&(identical(other.suspectBelowBytes, _this.suspectBelowBytes) || other.suspectBelowBytes == _this.suspectBelowBytes)&&(identical(other.includeMissing, _this.includeMissing) || other.includeMissing == _this.includeMissing)&&(identical(other.outdated, _this.outdated) || other.outdated == _this.outdated)&&(identical(other.givenUp, _this.givenUp) || other.givenUp == _this.givenUp)&&(identical(other.limit, _this.limit) || other.limit == _this.limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ThumbnailRegenerationRequest;
  return Object.hash(runtimeType,_this.dryRun,_this.renderedFrom,_this.renderedTo,_this.suspectBelowBytes,_this.includeMissing,_this.outdated,_this.givenUp,_this.limit);
}

@override
String toString() {
  final _this = this as ThumbnailRegenerationRequest;
  return 'ThumbnailRegenerationRequest(dryRun: ${_this.dryRun}, renderedFrom: ${_this.renderedFrom}, renderedTo: ${_this.renderedTo}, suspectBelowBytes: ${_this.suspectBelowBytes}, includeMissing: ${_this.includeMissing}, outdated: ${_this.outdated}, givenUp: ${_this.givenUp}, limit: ${_this.limit})';
}


}

/// @nodoc
abstract mixin class $ThumbnailRegenerationRequestCopyWith<$Res>  {
  factory $ThumbnailRegenerationRequestCopyWith(ThumbnailRegenerationRequest value, $Res Function(ThumbnailRegenerationRequest) _then) = _$ThumbnailRegenerationRequestCopyWithImpl;
@useResult
$Res call({
 bool dryRun, String? renderedFrom, String? renderedTo, int? suspectBelowBytes, bool? includeMissing, bool? outdated, bool? givenUp, int? limit
});




}
/// @nodoc
class _$ThumbnailRegenerationRequestCopyWithImpl<$Res>
    implements $ThumbnailRegenerationRequestCopyWith<$Res> {
  _$ThumbnailRegenerationRequestCopyWithImpl(this._self, this._then);

  final ThumbnailRegenerationRequest _self;
  final $Res Function(ThumbnailRegenerationRequest) _then;

/// Create a copy of ThumbnailRegenerationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dryRun = null,Object? renderedFrom = freezed,Object? renderedTo = freezed,Object? suspectBelowBytes = freezed,Object? includeMissing = freezed,Object? outdated = freezed,Object? givenUp = freezed,Object? limit = freezed,}) {
  return _then(ThumbnailRegenerationRequest(
dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,renderedFrom: freezed == renderedFrom ? _self.renderedFrom : renderedFrom // ignore: cast_nullable_to_non_nullable
as String?,renderedTo: freezed == renderedTo ? _self.renderedTo : renderedTo // ignore: cast_nullable_to_non_nullable
as String?,suspectBelowBytes: freezed == suspectBelowBytes ? _self.suspectBelowBytes : suspectBelowBytes // ignore: cast_nullable_to_non_nullable
as int?,includeMissing: freezed == includeMissing ? _self.includeMissing : includeMissing // ignore: cast_nullable_to_non_nullable
as bool?,outdated: freezed == outdated ? _self.outdated : outdated // ignore: cast_nullable_to_non_nullable
as bool?,givenUp: freezed == givenUp ? _self.givenUp : givenUp // ignore: cast_nullable_to_non_nullable
as bool?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ThumbnailRegenerationRequest].
extension ThumbnailRegenerationRequestPatterns on ThumbnailRegenerationRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThumbnailRegenerationRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThumbnailRegenerationRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThumbnailRegenerationRequest value)  $default,){
final _that = this;
switch (_that) {
case _ThumbnailRegenerationRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThumbnailRegenerationRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ThumbnailRegenerationRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool dryRun,  String? renderedFrom,  String? renderedTo,  int? suspectBelowBytes,  bool? includeMissing,  bool? outdated,  bool? givenUp,  int? limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThumbnailRegenerationRequest() when $default != null:
return $default(_that.dryRun,_that.renderedFrom,_that.renderedTo,_that.suspectBelowBytes,_that.includeMissing,_that.outdated,_that.givenUp,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool dryRun,  String? renderedFrom,  String? renderedTo,  int? suspectBelowBytes,  bool? includeMissing,  bool? outdated,  bool? givenUp,  int? limit)  $default,) {final _that = this;
switch (_that) {
case _ThumbnailRegenerationRequest():
return $default(_that.dryRun,_that.renderedFrom,_that.renderedTo,_that.suspectBelowBytes,_that.includeMissing,_that.outdated,_that.givenUp,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool dryRun,  String? renderedFrom,  String? renderedTo,  int? suspectBelowBytes,  bool? includeMissing,  bool? outdated,  bool? givenUp,  int? limit)?  $default,) {final _that = this;
switch (_that) {
case _ThumbnailRegenerationRequest() when $default != null:
return $default(_that.dryRun,_that.renderedFrom,_that.renderedTo,_that.suspectBelowBytes,_that.includeMissing,_that.outdated,_that.givenUp,_that.limit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ThumbnailRegenerationRequest implements ThumbnailRegenerationRequest {
  const _ThumbnailRegenerationRequest({required this.dryRun, this.renderedFrom, this.renderedTo, this.suspectBelowBytes, this.includeMissing, this.outdated, this.givenUp, this.limit});
  factory _ThumbnailRegenerationRequest.fromJson(Map<String, dynamic> json) => _$ThumbnailRegenerationRequestFromJson(json);

/// List what would be redrawn, without redrawing anything
@override final  bool dryRun;
/// Only thumbnails drawn at or after this instant
@override final  String? renderedFrom;
/// Only thumbnails drawn before this instant
@override final  String? renderedTo;
/// Only thumbnails whose stored file is smaller than this many bytes, or has no file. A map drawn without its background weighs a few kB, a real one tens.
@override final  int? suspectBelowBytes;
/// Also redraw the routes, rides and trips that have a route to draw but lack a light or dark thumbnail — what a failed render leaves behind
@override final  bool? includeMissing;
/// Also redraw the routes, rides and trips with a thumbnail drawn before the current basemap — what the automatic catch-up redraws by itself, in the background
@override final  bool? outdated;
/// Also redraw the routes, rides and trips the automatic catch-up gave up on after repeated failures, which it no longer tries
@override final  bool? givenUp;
/// Redraw at most this many entities (default 100)
@override final  int? limit;

/// Create a copy of ThumbnailRegenerationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThumbnailRegenerationRequestCopyWith<_ThumbnailRegenerationRequest> get copyWith => __$ThumbnailRegenerationRequestCopyWithImpl<_ThumbnailRegenerationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ThumbnailRegenerationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThumbnailRegenerationRequest&&(identical(other.dryRun, dryRun) || other.dryRun == dryRun)&&(identical(other.renderedFrom, renderedFrom) || other.renderedFrom == renderedFrom)&&(identical(other.renderedTo, renderedTo) || other.renderedTo == renderedTo)&&(identical(other.suspectBelowBytes, suspectBelowBytes) || other.suspectBelowBytes == suspectBelowBytes)&&(identical(other.includeMissing, includeMissing) || other.includeMissing == includeMissing)&&(identical(other.outdated, outdated) || other.outdated == outdated)&&(identical(other.givenUp, givenUp) || other.givenUp == givenUp)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,dryRun,renderedFrom,renderedTo,suspectBelowBytes,includeMissing,outdated,givenUp,limit);
}

@override
String toString() {
    return 'ThumbnailRegenerationRequest(dryRun: $dryRun, renderedFrom: $renderedFrom, renderedTo: $renderedTo, suspectBelowBytes: $suspectBelowBytes, includeMissing: $includeMissing, outdated: $outdated, givenUp: $givenUp, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$ThumbnailRegenerationRequestCopyWith<$Res> implements $ThumbnailRegenerationRequestCopyWith<$Res> {
  factory _$ThumbnailRegenerationRequestCopyWith(_ThumbnailRegenerationRequest value, $Res Function(_ThumbnailRegenerationRequest) _then) = __$ThumbnailRegenerationRequestCopyWithImpl;
@override @useResult
$Res call({
 bool dryRun, String? renderedFrom, String? renderedTo, int? suspectBelowBytes, bool? includeMissing, bool? outdated, bool? givenUp, int? limit
});




}
/// @nodoc
class __$ThumbnailRegenerationRequestCopyWithImpl<$Res>
    implements _$ThumbnailRegenerationRequestCopyWith<$Res> {
  __$ThumbnailRegenerationRequestCopyWithImpl(this._self, this._then);

  final _ThumbnailRegenerationRequest _self;
  final $Res Function(_ThumbnailRegenerationRequest) _then;

/// Create a copy of ThumbnailRegenerationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dryRun = null,Object? renderedFrom = freezed,Object? renderedTo = freezed,Object? suspectBelowBytes = freezed,Object? includeMissing = freezed,Object? outdated = freezed,Object? givenUp = freezed,Object? limit = freezed,}) {
  return _then(_ThumbnailRegenerationRequest(
dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,renderedFrom: freezed == renderedFrom ? _self.renderedFrom : renderedFrom // ignore: cast_nullable_to_non_nullable
as String?,renderedTo: freezed == renderedTo ? _self.renderedTo : renderedTo // ignore: cast_nullable_to_non_nullable
as String?,suspectBelowBytes: freezed == suspectBelowBytes ? _self.suspectBelowBytes : suspectBelowBytes // ignore: cast_nullable_to_non_nullable
as int?,includeMissing: freezed == includeMissing ? _self.includeMissing : includeMissing // ignore: cast_nullable_to_non_nullable
as bool?,outdated: freezed == outdated ? _self.outdated : outdated // ignore: cast_nullable_to_non_nullable
as bool?,givenUp: freezed == givenUp ? _self.givenUp : givenUp // ignore: cast_nullable_to_non_nullable
as bool?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
