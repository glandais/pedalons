// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planner_junction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannerJunction {

 PlannerJunctionKind get kind; double get lng; double get lat; double? get ele;/// Index of the source track this point comes from; with idx or not at all
 int? get source;/// Index of this point in that source track
 int? get idx;
/// Create a copy of PlannerJunction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannerJunctionCopyWith<PlannerJunction> get copyWith => _$PlannerJunctionCopyWithImpl<PlannerJunction>(this as PlannerJunction, _$identity);

  /// Serializes this PlannerJunction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlannerJunction;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannerJunction&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.lng, _this.lng) || other.lng == _this.lng)&&(identical(other.lat, _this.lat) || other.lat == _this.lat)&&(identical(other.ele, _this.ele) || other.ele == _this.ele)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.idx, _this.idx) || other.idx == _this.idx));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlannerJunction;
  return Object.hash(runtimeType,_this.kind,_this.lng,_this.lat,_this.ele,_this.source,_this.idx);
}

@override
String toString() {
  final _this = this as PlannerJunction;
  return 'PlannerJunction(kind: ${_this.kind}, lng: ${_this.lng}, lat: ${_this.lat}, ele: ${_this.ele}, source: ${_this.source}, idx: ${_this.idx})';
}


}

/// @nodoc
abstract mixin class $PlannerJunctionCopyWith<$Res>  {
  factory $PlannerJunctionCopyWith(PlannerJunction value, $Res Function(PlannerJunction) _then) = _$PlannerJunctionCopyWithImpl;
@useResult
$Res call({
 PlannerJunctionKind kind, double lng, double lat, double? ele, int? source, int? idx
});




}
/// @nodoc
class _$PlannerJunctionCopyWithImpl<$Res>
    implements $PlannerJunctionCopyWith<$Res> {
  _$PlannerJunctionCopyWithImpl(this._self, this._then);

  final PlannerJunction _self;
  final $Res Function(PlannerJunction) _then;

/// Create a copy of PlannerJunction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? lng = null,Object? lat = null,Object? ele = freezed,Object? source = freezed,Object? idx = freezed,}) {
  return _then(PlannerJunction(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as PlannerJunctionKind,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as double?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as int?,idx: freezed == idx ? _self.idx : idx // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlannerJunction].
extension PlannerJunctionPatterns on PlannerJunction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannerJunction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannerJunction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannerJunction value)  $default,){
final _that = this;
switch (_that) {
case _PlannerJunction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannerJunction value)?  $default,){
final _that = this;
switch (_that) {
case _PlannerJunction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PlannerJunctionKind kind,  double lng,  double lat,  double? ele,  int? source,  int? idx)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannerJunction() when $default != null:
return $default(_that.kind,_that.lng,_that.lat,_that.ele,_that.source,_that.idx);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PlannerJunctionKind kind,  double lng,  double lat,  double? ele,  int? source,  int? idx)  $default,) {final _that = this;
switch (_that) {
case _PlannerJunction():
return $default(_that.kind,_that.lng,_that.lat,_that.ele,_that.source,_that.idx);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PlannerJunctionKind kind,  double lng,  double lat,  double? ele,  int? source,  int? idx)?  $default,) {final _that = this;
switch (_that) {
case _PlannerJunction() when $default != null:
return $default(_that.kind,_that.lng,_that.lat,_that.ele,_that.source,_that.idx);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannerJunction implements PlannerJunction {
  const _PlannerJunction({required this.kind, required this.lng, required this.lat, this.ele, this.source, this.idx});
  factory _PlannerJunction.fromJson(Map<String, dynamic> json) => _$PlannerJunctionFromJson(json);

@override final  PlannerJunctionKind kind;
@override final  double lng;
@override final  double lat;
@override final  double? ele;
/// Index of the source track this point comes from; with idx or not at all
@override final  int? source;
/// Index of this point in that source track
@override final  int? idx;

/// Create a copy of PlannerJunction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannerJunctionCopyWith<_PlannerJunction> get copyWith => __$PlannerJunctionCopyWithImpl<_PlannerJunction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannerJunctionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannerJunction&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.ele, ele) || other.ele == ele)&&(identical(other.source, source) || other.source == source)&&(identical(other.idx, idx) || other.idx == idx));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,lng,lat,ele,source,idx);
}

@override
String toString() {
    return 'PlannerJunction(kind: $kind, lng: $lng, lat: $lat, ele: $ele, source: $source, idx: $idx)';
}


}

/// @nodoc
abstract mixin class _$PlannerJunctionCopyWith<$Res> implements $PlannerJunctionCopyWith<$Res> {
  factory _$PlannerJunctionCopyWith(_PlannerJunction value, $Res Function(_PlannerJunction) _then) = __$PlannerJunctionCopyWithImpl;
@override @useResult
$Res call({
 PlannerJunctionKind kind, double lng, double lat, double? ele, int? source, int? idx
});




}
/// @nodoc
class __$PlannerJunctionCopyWithImpl<$Res>
    implements _$PlannerJunctionCopyWith<$Res> {
  __$PlannerJunctionCopyWithImpl(this._self, this._then);

  final _PlannerJunction _self;
  final $Res Function(_PlannerJunction) _then;

/// Create a copy of PlannerJunction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? lng = null,Object? lat = null,Object? ele = freezed,Object? source = freezed,Object? idx = freezed,}) {
  return _then(_PlannerJunction(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as PlannerJunctionKind,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as double?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as int?,idx: freezed == idx ? _self.idx : idx // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
