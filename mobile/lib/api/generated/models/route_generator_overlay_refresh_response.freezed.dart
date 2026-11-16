// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_generator_overlay_refresh_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGeneratorOverlayRefreshResponse {

/// False when nothing started: the generator is off or unconfigured, or a pass is already running
 bool get started;/// One entry per team that is deposited, deleted, or kept (dry run only: a started pass answers 202 with no entries, it runs in the background)
 List<RouteGeneratorOverlayRefreshItem> get items;/// Identity of the graph the engine serves
 String? get graphId;
/// Create a copy of RouteGeneratorOverlayRefreshResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGeneratorOverlayRefreshResponseCopyWith<RouteGeneratorOverlayRefreshResponse> get copyWith => _$RouteGeneratorOverlayRefreshResponseCopyWithImpl<RouteGeneratorOverlayRefreshResponse>(this as RouteGeneratorOverlayRefreshResponse, _$identity);

  /// Serializes this RouteGeneratorOverlayRefreshResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGeneratorOverlayRefreshResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGeneratorOverlayRefreshResponse&&(identical(other.started, _this.started) || other.started == _this.started)&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.graphId, _this.graphId) || other.graphId == _this.graphId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGeneratorOverlayRefreshResponse;
  return Object.hash(runtimeType,_this.started,const DeepCollectionEquality().hash(_this.items),_this.graphId);
}

@override
String toString() {
  final _this = this as RouteGeneratorOverlayRefreshResponse;
  return 'RouteGeneratorOverlayRefreshResponse(started: ${_this.started}, items: ${_this.items}, graphId: ${_this.graphId})';
}


}

/// @nodoc
abstract mixin class $RouteGeneratorOverlayRefreshResponseCopyWith<$Res>  {
  factory $RouteGeneratorOverlayRefreshResponseCopyWith(RouteGeneratorOverlayRefreshResponse value, $Res Function(RouteGeneratorOverlayRefreshResponse) _then) = _$RouteGeneratorOverlayRefreshResponseCopyWithImpl;
@useResult
$Res call({
 bool started, List<RouteGeneratorOverlayRefreshItem> items, String? graphId
});




}
/// @nodoc
class _$RouteGeneratorOverlayRefreshResponseCopyWithImpl<$Res>
    implements $RouteGeneratorOverlayRefreshResponseCopyWith<$Res> {
  _$RouteGeneratorOverlayRefreshResponseCopyWithImpl(this._self, this._then);

  final RouteGeneratorOverlayRefreshResponse _self;
  final $Res Function(RouteGeneratorOverlayRefreshResponse) _then;

/// Create a copy of RouteGeneratorOverlayRefreshResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? started = null,Object? items = null,Object? graphId = freezed,}) {
  return _then(RouteGeneratorOverlayRefreshResponse(
started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<RouteGeneratorOverlayRefreshItem>,graphId: freezed == graphId ? _self.graphId : graphId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteGeneratorOverlayRefreshResponse].
extension RouteGeneratorOverlayRefreshResponsePatterns on RouteGeneratorOverlayRefreshResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGeneratorOverlayRefreshResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGeneratorOverlayRefreshResponse value)  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGeneratorOverlayRefreshResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool started,  List<RouteGeneratorOverlayRefreshItem> items,  String? graphId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshResponse() when $default != null:
return $default(_that.started,_that.items,_that.graphId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool started,  List<RouteGeneratorOverlayRefreshItem> items,  String? graphId)  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshResponse():
return $default(_that.started,_that.items,_that.graphId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool started,  List<RouteGeneratorOverlayRefreshItem> items,  String? graphId)?  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshResponse() when $default != null:
return $default(_that.started,_that.items,_that.graphId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGeneratorOverlayRefreshResponse implements RouteGeneratorOverlayRefreshResponse {
  const _RouteGeneratorOverlayRefreshResponse({required this.started, required  List<RouteGeneratorOverlayRefreshItem> items, this.graphId}): _items = items;
  factory _RouteGeneratorOverlayRefreshResponse.fromJson(Map<String, dynamic> json) => _$RouteGeneratorOverlayRefreshResponseFromJson(json);

/// False when nothing started: the generator is off or unconfigured, or a pass is already running
@override final  bool started;
/// One entry per team that is deposited, deleted, or kept (dry run only: a started pass answers 202 with no entries, it runs in the background)
 final  List<RouteGeneratorOverlayRefreshItem> _items;
/// One entry per team that is deposited, deleted, or kept (dry run only: a started pass answers 202 with no entries, it runs in the background)
@override List<RouteGeneratorOverlayRefreshItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

/// Identity of the graph the engine serves
@override final  String? graphId;

/// Create a copy of RouteGeneratorOverlayRefreshResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGeneratorOverlayRefreshResponseCopyWith<_RouteGeneratorOverlayRefreshResponse> get copyWith => __$RouteGeneratorOverlayRefreshResponseCopyWithImpl<_RouteGeneratorOverlayRefreshResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGeneratorOverlayRefreshResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGeneratorOverlayRefreshResponse&&(identical(other.started, started) || other.started == started)&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.graphId, graphId) || other.graphId == graphId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,started,const DeepCollectionEquality().hash(_items),graphId);
}

@override
String toString() {
    return 'RouteGeneratorOverlayRefreshResponse(started: $started, items: $items, graphId: $graphId)';
}


}

/// @nodoc
abstract mixin class _$RouteGeneratorOverlayRefreshResponseCopyWith<$Res> implements $RouteGeneratorOverlayRefreshResponseCopyWith<$Res> {
  factory _$RouteGeneratorOverlayRefreshResponseCopyWith(_RouteGeneratorOverlayRefreshResponse value, $Res Function(_RouteGeneratorOverlayRefreshResponse) _then) = __$RouteGeneratorOverlayRefreshResponseCopyWithImpl;
@override @useResult
$Res call({
 bool started, List<RouteGeneratorOverlayRefreshItem> items, String? graphId
});




}
/// @nodoc
class __$RouteGeneratorOverlayRefreshResponseCopyWithImpl<$Res>
    implements _$RouteGeneratorOverlayRefreshResponseCopyWith<$Res> {
  __$RouteGeneratorOverlayRefreshResponseCopyWithImpl(this._self, this._then);

  final _RouteGeneratorOverlayRefreshResponse _self;
  final $Res Function(_RouteGeneratorOverlayRefreshResponse) _then;

/// Create a copy of RouteGeneratorOverlayRefreshResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? started = null,Object? items = null,Object? graphId = freezed,}) {
  return _then(_RouteGeneratorOverlayRefreshResponse(
started: null == started ? _self.started : started // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<RouteGeneratorOverlayRefreshItem>,graphId: freezed == graphId ? _self.graphId : graphId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
