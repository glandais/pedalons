// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'elevation_refresh_retry_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ElevationRefreshRetryItem {

/// Kind of target
 String get kind;/// ID of the route or preview
 String get targetId;/// Failed attempts before the retry
 int get attempts;/// When the recomputation was first requested
 String get firstRequestedAt;/// Team slug (routes)
 String? get teamSlug;/// Route slug (routes)
 String? get routeSlug;/// Public identifier (previews)
 String? get previewPublicId;/// Last error recorded, before the retry
 String? get lastError;
/// Create a copy of ElevationRefreshRetryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ElevationRefreshRetryItemCopyWith<ElevationRefreshRetryItem> get copyWith => _$ElevationRefreshRetryItemCopyWithImpl<ElevationRefreshRetryItem>(this as ElevationRefreshRetryItem, _$identity);

  /// Serializes this ElevationRefreshRetryItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ElevationRefreshRetryItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ElevationRefreshRetryItem&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.targetId, _this.targetId) || other.targetId == _this.targetId)&&(identical(other.attempts, _this.attempts) || other.attempts == _this.attempts)&&(identical(other.firstRequestedAt, _this.firstRequestedAt) || other.firstRequestedAt == _this.firstRequestedAt)&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.previewPublicId, _this.previewPublicId) || other.previewPublicId == _this.previewPublicId)&&(identical(other.lastError, _this.lastError) || other.lastError == _this.lastError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ElevationRefreshRetryItem;
  return Object.hash(runtimeType,_this.kind,_this.targetId,_this.attempts,_this.firstRequestedAt,_this.teamSlug,_this.routeSlug,_this.previewPublicId,_this.lastError);
}

@override
String toString() {
  final _this = this as ElevationRefreshRetryItem;
  return 'ElevationRefreshRetryItem(kind: ${_this.kind}, targetId: ${_this.targetId}, attempts: ${_this.attempts}, firstRequestedAt: ${_this.firstRequestedAt}, teamSlug: ${_this.teamSlug}, routeSlug: ${_this.routeSlug}, previewPublicId: ${_this.previewPublicId}, lastError: ${_this.lastError})';
}


}

/// @nodoc
abstract mixin class $ElevationRefreshRetryItemCopyWith<$Res>  {
  factory $ElevationRefreshRetryItemCopyWith(ElevationRefreshRetryItem value, $Res Function(ElevationRefreshRetryItem) _then) = _$ElevationRefreshRetryItemCopyWithImpl;
@useResult
$Res call({
 String kind, String targetId, int attempts, String firstRequestedAt, String? teamSlug, String? routeSlug, String? previewPublicId, String? lastError
});




}
/// @nodoc
class _$ElevationRefreshRetryItemCopyWithImpl<$Res>
    implements $ElevationRefreshRetryItemCopyWith<$Res> {
  _$ElevationRefreshRetryItemCopyWithImpl(this._self, this._then);

  final ElevationRefreshRetryItem _self;
  final $Res Function(ElevationRefreshRetryItem) _then;

/// Create a copy of ElevationRefreshRetryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? targetId = null,Object? attempts = null,Object? firstRequestedAt = null,Object? teamSlug = freezed,Object? routeSlug = freezed,Object? previewPublicId = freezed,Object? lastError = freezed,}) {
  return _then(ElevationRefreshRetryItem(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,firstRequestedAt: null == firstRequestedAt ? _self.firstRequestedAt : firstRequestedAt // ignore: cast_nullable_to_non_nullable
as String,teamSlug: freezed == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,previewPublicId: freezed == previewPublicId ? _self.previewPublicId : previewPublicId // ignore: cast_nullable_to_non_nullable
as String?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ElevationRefreshRetryItem].
extension ElevationRefreshRetryItemPatterns on ElevationRefreshRetryItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ElevationRefreshRetryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ElevationRefreshRetryItem value)  $default,){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ElevationRefreshRetryItem value)?  $default,){
final _that = this;
switch (_that) {
case _ElevationRefreshRetryItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String targetId,  int attempts,  String firstRequestedAt,  String? teamSlug,  String? routeSlug,  String? previewPublicId,  String? lastError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryItem() when $default != null:
return $default(_that.kind,_that.targetId,_that.attempts,_that.firstRequestedAt,_that.teamSlug,_that.routeSlug,_that.previewPublicId,_that.lastError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String targetId,  int attempts,  String firstRequestedAt,  String? teamSlug,  String? routeSlug,  String? previewPublicId,  String? lastError)  $default,) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryItem():
return $default(_that.kind,_that.targetId,_that.attempts,_that.firstRequestedAt,_that.teamSlug,_that.routeSlug,_that.previewPublicId,_that.lastError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String targetId,  int attempts,  String firstRequestedAt,  String? teamSlug,  String? routeSlug,  String? previewPublicId,  String? lastError)?  $default,) {final _that = this;
switch (_that) {
case _ElevationRefreshRetryItem() when $default != null:
return $default(_that.kind,_that.targetId,_that.attempts,_that.firstRequestedAt,_that.teamSlug,_that.routeSlug,_that.previewPublicId,_that.lastError);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ElevationRefreshRetryItem implements ElevationRefreshRetryItem {
  const _ElevationRefreshRetryItem({required this.kind, required this.targetId, required this.attempts, required this.firstRequestedAt, this.teamSlug, this.routeSlug, this.previewPublicId, this.lastError});
  factory _ElevationRefreshRetryItem.fromJson(Map<String, dynamic> json) => _$ElevationRefreshRetryItemFromJson(json);

/// Kind of target
@override final  String kind;
/// ID of the route or preview
@override final  String targetId;
/// Failed attempts before the retry
@override final  int attempts;
/// When the recomputation was first requested
@override final  String firstRequestedAt;
/// Team slug (routes)
@override final  String? teamSlug;
/// Route slug (routes)
@override final  String? routeSlug;
/// Public identifier (previews)
@override final  String? previewPublicId;
/// Last error recorded, before the retry
@override final  String? lastError;

/// Create a copy of ElevationRefreshRetryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ElevationRefreshRetryItemCopyWith<_ElevationRefreshRetryItem> get copyWith => __$ElevationRefreshRetryItemCopyWithImpl<_ElevationRefreshRetryItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ElevationRefreshRetryItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ElevationRefreshRetryItem&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.attempts, attempts) || other.attempts == attempts)&&(identical(other.firstRequestedAt, firstRequestedAt) || other.firstRequestedAt == firstRequestedAt)&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.previewPublicId, previewPublicId) || other.previewPublicId == previewPublicId)&&(identical(other.lastError, lastError) || other.lastError == lastError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,targetId,attempts,firstRequestedAt,teamSlug,routeSlug,previewPublicId,lastError);
}

@override
String toString() {
    return 'ElevationRefreshRetryItem(kind: $kind, targetId: $targetId, attempts: $attempts, firstRequestedAt: $firstRequestedAt, teamSlug: $teamSlug, routeSlug: $routeSlug, previewPublicId: $previewPublicId, lastError: $lastError)';
}


}

/// @nodoc
abstract mixin class _$ElevationRefreshRetryItemCopyWith<$Res> implements $ElevationRefreshRetryItemCopyWith<$Res> {
  factory _$ElevationRefreshRetryItemCopyWith(_ElevationRefreshRetryItem value, $Res Function(_ElevationRefreshRetryItem) _then) = __$ElevationRefreshRetryItemCopyWithImpl;
@override @useResult
$Res call({
 String kind, String targetId, int attempts, String firstRequestedAt, String? teamSlug, String? routeSlug, String? previewPublicId, String? lastError
});




}
/// @nodoc
class __$ElevationRefreshRetryItemCopyWithImpl<$Res>
    implements _$ElevationRefreshRetryItemCopyWith<$Res> {
  __$ElevationRefreshRetryItemCopyWithImpl(this._self, this._then);

  final _ElevationRefreshRetryItem _self;
  final $Res Function(_ElevationRefreshRetryItem) _then;

/// Create a copy of ElevationRefreshRetryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? targetId = null,Object? attempts = null,Object? firstRequestedAt = null,Object? teamSlug = freezed,Object? routeSlug = freezed,Object? previewPublicId = freezed,Object? lastError = freezed,}) {
  return _then(_ElevationRefreshRetryItem(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,firstRequestedAt: null == firstRequestedAt ? _self.firstRequestedAt : firstRequestedAt // ignore: cast_nullable_to_non_nullable
as String,teamSlug: freezed == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,previewPublicId: freezed == previewPublicId ? _self.previewPublicId : previewPublicId // ignore: cast_nullable_to_non_nullable
as String?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
