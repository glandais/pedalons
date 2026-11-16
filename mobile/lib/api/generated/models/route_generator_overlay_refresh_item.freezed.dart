// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_generator_overlay_refresh_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGeneratorOverlayRefreshItem {

/// ID of the team
 String get teamId;/// Slug of the team
 String get teamSlug;/// What is done
 String get action;/// Why
 String get reason;/// State of the overlay at the engine: absent, ready or stale
 String? get state;/// When it was deposited
 String? get depositedAt;/// When the engine drops it if it is not deposited again
 String? get expiresAt;
/// Create a copy of RouteGeneratorOverlayRefreshItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGeneratorOverlayRefreshItemCopyWith<RouteGeneratorOverlayRefreshItem> get copyWith => _$RouteGeneratorOverlayRefreshItemCopyWithImpl<RouteGeneratorOverlayRefreshItem>(this as RouteGeneratorOverlayRefreshItem, _$identity);

  /// Serializes this RouteGeneratorOverlayRefreshItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGeneratorOverlayRefreshItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGeneratorOverlayRefreshItem&&(identical(other.teamId, _this.teamId) || other.teamId == _this.teamId)&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.action, _this.action) || other.action == _this.action)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.depositedAt, _this.depositedAt) || other.depositedAt == _this.depositedAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGeneratorOverlayRefreshItem;
  return Object.hash(runtimeType,_this.teamId,_this.teamSlug,_this.action,_this.reason,_this.state,_this.depositedAt,_this.expiresAt);
}

@override
String toString() {
  final _this = this as RouteGeneratorOverlayRefreshItem;
  return 'RouteGeneratorOverlayRefreshItem(teamId: ${_this.teamId}, teamSlug: ${_this.teamSlug}, action: ${_this.action}, reason: ${_this.reason}, state: ${_this.state}, depositedAt: ${_this.depositedAt}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $RouteGeneratorOverlayRefreshItemCopyWith<$Res>  {
  factory $RouteGeneratorOverlayRefreshItemCopyWith(RouteGeneratorOverlayRefreshItem value, $Res Function(RouteGeneratorOverlayRefreshItem) _then) = _$RouteGeneratorOverlayRefreshItemCopyWithImpl;
@useResult
$Res call({
 String teamId, String teamSlug, String action, String reason, String? state, String? depositedAt, String? expiresAt
});




}
/// @nodoc
class _$RouteGeneratorOverlayRefreshItemCopyWithImpl<$Res>
    implements $RouteGeneratorOverlayRefreshItemCopyWith<$Res> {
  _$RouteGeneratorOverlayRefreshItemCopyWithImpl(this._self, this._then);

  final RouteGeneratorOverlayRefreshItem _self;
  final $Res Function(RouteGeneratorOverlayRefreshItem) _then;

/// Create a copy of RouteGeneratorOverlayRefreshItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? teamId = null,Object? teamSlug = null,Object? action = null,Object? reason = null,Object? state = freezed,Object? depositedAt = freezed,Object? expiresAt = freezed,}) {
  return _then(RouteGeneratorOverlayRefreshItem(
teamId: null == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as String,teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,depositedAt: freezed == depositedAt ? _self.depositedAt : depositedAt // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteGeneratorOverlayRefreshItem].
extension RouteGeneratorOverlayRefreshItemPatterns on RouteGeneratorOverlayRefreshItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGeneratorOverlayRefreshItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGeneratorOverlayRefreshItem value)  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGeneratorOverlayRefreshItem value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String teamId,  String teamSlug,  String action,  String reason,  String? state,  String? depositedAt,  String? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshItem() when $default != null:
return $default(_that.teamId,_that.teamSlug,_that.action,_that.reason,_that.state,_that.depositedAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String teamId,  String teamSlug,  String action,  String reason,  String? state,  String? depositedAt,  String? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshItem():
return $default(_that.teamId,_that.teamSlug,_that.action,_that.reason,_that.state,_that.depositedAt,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String teamId,  String teamSlug,  String action,  String reason,  String? state,  String? depositedAt,  String? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorOverlayRefreshItem() when $default != null:
return $default(_that.teamId,_that.teamSlug,_that.action,_that.reason,_that.state,_that.depositedAt,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGeneratorOverlayRefreshItem implements RouteGeneratorOverlayRefreshItem {
  const _RouteGeneratorOverlayRefreshItem({required this.teamId, required this.teamSlug, required this.action, required this.reason, this.state, this.depositedAt, this.expiresAt});
  factory _RouteGeneratorOverlayRefreshItem.fromJson(Map<String, dynamic> json) => _$RouteGeneratorOverlayRefreshItemFromJson(json);

/// ID of the team
@override final  String teamId;
/// Slug of the team
@override final  String teamSlug;
/// What is done
@override final  String action;
/// Why
@override final  String reason;
/// State of the overlay at the engine: absent, ready or stale
@override final  String? state;
/// When it was deposited
@override final  String? depositedAt;
/// When the engine drops it if it is not deposited again
@override final  String? expiresAt;

/// Create a copy of RouteGeneratorOverlayRefreshItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGeneratorOverlayRefreshItemCopyWith<_RouteGeneratorOverlayRefreshItem> get copyWith => __$RouteGeneratorOverlayRefreshItemCopyWithImpl<_RouteGeneratorOverlayRefreshItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGeneratorOverlayRefreshItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGeneratorOverlayRefreshItem&&(identical(other.teamId, teamId) || other.teamId == teamId)&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.action, action) || other.action == action)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.state, state) || other.state == state)&&(identical(other.depositedAt, depositedAt) || other.depositedAt == depositedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,teamId,teamSlug,action,reason,state,depositedAt,expiresAt);
}

@override
String toString() {
    return 'RouteGeneratorOverlayRefreshItem(teamId: $teamId, teamSlug: $teamSlug, action: $action, reason: $reason, state: $state, depositedAt: $depositedAt, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$RouteGeneratorOverlayRefreshItemCopyWith<$Res> implements $RouteGeneratorOverlayRefreshItemCopyWith<$Res> {
  factory _$RouteGeneratorOverlayRefreshItemCopyWith(_RouteGeneratorOverlayRefreshItem value, $Res Function(_RouteGeneratorOverlayRefreshItem) _then) = __$RouteGeneratorOverlayRefreshItemCopyWithImpl;
@override @useResult
$Res call({
 String teamId, String teamSlug, String action, String reason, String? state, String? depositedAt, String? expiresAt
});




}
/// @nodoc
class __$RouteGeneratorOverlayRefreshItemCopyWithImpl<$Res>
    implements _$RouteGeneratorOverlayRefreshItemCopyWith<$Res> {
  __$RouteGeneratorOverlayRefreshItemCopyWithImpl(this._self, this._then);

  final _RouteGeneratorOverlayRefreshItem _self;
  final $Res Function(_RouteGeneratorOverlayRefreshItem) _then;

/// Create a copy of RouteGeneratorOverlayRefreshItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? teamId = null,Object? teamSlug = null,Object? action = null,Object? reason = null,Object? state = freezed,Object? depositedAt = freezed,Object? expiresAt = freezed,}) {
  return _then(_RouteGeneratorOverlayRefreshItem(
teamId: null == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as String,teamSlug: null == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,depositedAt: freezed == depositedAt ? _self.depositedAt : depositedAt // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
