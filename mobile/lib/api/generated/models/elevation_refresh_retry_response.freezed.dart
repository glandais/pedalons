// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'elevation_refresh_retry_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ElevationRefreshRetryResponse {

/// Whether this was a dry run (nothing changed)
 bool get dryRun;/// Number of abandoned targets in the domain, before the limit
 int get matched;/// Targets listed, and retried unless dry run; at most the limit
 List<ElevationRefreshRetryItem> get items;
/// Create a copy of ElevationRefreshRetryResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ElevationRefreshRetryResponseCopyWith<ElevationRefreshRetryResponse> get copyWith => _$ElevationRefreshRetryResponseCopyWithImpl<ElevationRefreshRetryResponse>(this as ElevationRefreshRetryResponse, _$identity);

  /// Serializes this ElevationRefreshRetryResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ElevationRefreshRetryResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ElevationRefreshRetryResponse&&(identical(other.dryRun, _this.dryRun) || other.dryRun == _this.dryRun)&&(identical(other.matched, _this.matched) || other.matched == _this.matched)&&const DeepCollectionEquality().equals(other.items, _this.items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ElevationRefreshRetryResponse;
  return Object.hash(runtimeType,_this.dryRun,_this.matched,const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as ElevationRefreshRetryResponse;
  return 'ElevationRefreshRetryResponse(dryRun: ${_this.dryRun}, matched: ${_this.matched}, items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $ElevationRefreshRetryResponseCopyWith<$Res>  {
  factory $ElevationRefreshRetryResponseCopyWith(ElevationRefreshRetryResponse value, $Res Function(ElevationRefreshRetryResponse) _then) = _$ElevationRefreshRetryResponseCopyWithImpl;
@useResult
$Res call({
 bool dryRun, int matched, List<ElevationRefreshRetryItem> items
});




}
/// @nodoc
class _$ElevationRefreshRetryResponseCopyWithImpl<$Res>
    implements $ElevationRefreshRetryResponseCopyWith<$Res> {
  _$ElevationRefreshRetryResponseCopyWithImpl(this._self, this._then);

  final ElevationRefreshRetryResponse _self;
  final $Res Function(ElevationRefreshRetryResponse) _then;

/// Create a copy of ElevationRefreshRetryResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dryRun = null,Object? matched = null,Object? items = null,}) {
  return _then(ElevationRefreshRetryResponse(
dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ElevationRefreshRetryItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [ElevationRefreshRetryResponse].
extension ElevationRefreshRetryResponsePatterns on ElevationRefreshRetryResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ElevationRefreshRetryResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ElevationRefreshRetryResponse value)  $default,){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ElevationRefreshRetryResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool dryRun,  int matched,  List<ElevationRefreshRetryItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryResponse() when $default != null:
return $default(_that.dryRun,_that.matched,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool dryRun,  int matched,  List<ElevationRefreshRetryItem> items)  $default,) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryResponse():
return $default(_that.dryRun,_that.matched,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool dryRun,  int matched,  List<ElevationRefreshRetryItem> items)?  $default,) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryResponse() when $default != null:
return $default(_that.dryRun,_that.matched,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ElevationRefreshRetryResponse implements ElevationRefreshRetryResponse {
  const _ElevationRefreshRetryResponse({required this.dryRun, required this.matched, required  List<ElevationRefreshRetryItem> items}): _items = items;
  factory _ElevationRefreshRetryResponse.fromJson(Map<String, dynamic> json) => _$ElevationRefreshRetryResponseFromJson(json);

/// Whether this was a dry run (nothing changed)
@override final  bool dryRun;
/// Number of abandoned targets in the domain, before the limit
@override final  int matched;
/// Targets listed, and retried unless dry run; at most the limit
 final  List<ElevationRefreshRetryItem> _items;
/// Targets listed, and retried unless dry run; at most the limit
@override List<ElevationRefreshRetryItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of ElevationRefreshRetryResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ElevationRefreshRetryResponseCopyWith<_ElevationRefreshRetryResponse> get copyWith => __$ElevationRefreshRetryResponseCopyWithImpl<_ElevationRefreshRetryResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ElevationRefreshRetryResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ElevationRefreshRetryResponse&&(identical(other.dryRun, dryRun) || other.dryRun == dryRun)&&(identical(other.matched, matched) || other.matched == matched)&&const DeepCollectionEquality().equals(other.items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,dryRun,matched,const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'ElevationRefreshRetryResponse(dryRun: $dryRun, matched: $matched, items: $items)';
}


}

/// @nodoc
abstract mixin class _$ElevationRefreshRetryResponseCopyWith<$Res> implements $ElevationRefreshRetryResponseCopyWith<$Res> {
  factory _$ElevationRefreshRetryResponseCopyWith(_ElevationRefreshRetryResponse value, $Res Function(_ElevationRefreshRetryResponse) _then) = __$ElevationRefreshRetryResponseCopyWithImpl;
@override @useResult
$Res call({
 bool dryRun, int matched, List<ElevationRefreshRetryItem> items
});




}
/// @nodoc
class __$ElevationRefreshRetryResponseCopyWithImpl<$Res>
    implements _$ElevationRefreshRetryResponseCopyWith<$Res> {
  __$ElevationRefreshRetryResponseCopyWithImpl(this._self, this._then);

  final _ElevationRefreshRetryResponse _self;
  final $Res Function(_ElevationRefreshRetryResponse) _then;

/// Create a copy of ElevationRefreshRetryResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dryRun = null,Object? matched = null,Object? items = null,}) {
  return _then(_ElevationRefreshRetryResponse(
dryRun: null == dryRun ? _self.dryRun : dryRun // ignore: cast_nullable_to_non_nullable
as bool,matched: null == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ElevationRefreshRetryItem>,
  ));
}


}

// dart format on
