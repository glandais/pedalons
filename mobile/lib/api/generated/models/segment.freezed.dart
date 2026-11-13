// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'segment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Segment {

@JsonKey(name: 'from_m') double? get fromM;@JsonKey(name: 'to_m') double? get toM;@JsonKey(name: 'from_index') int? get fromIndex;@JsonKey(name: 'to_index') int? get toIndex; String? get structure;@JsonKey(name: 'structure_source') String? get structureSource; Surface? get surface;@JsonKey(name: 'way_kind') String? get wayKind; bool? get matched;
/// Create a copy of Segment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SegmentCopyWith<Segment> get copyWith => _$SegmentCopyWithImpl<Segment>(this as Segment, _$identity);

  /// Serializes this Segment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Segment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Segment&&(identical(other.fromM, _this.fromM) || other.fromM == _this.fromM)&&(identical(other.toM, _this.toM) || other.toM == _this.toM)&&(identical(other.fromIndex, _this.fromIndex) || other.fromIndex == _this.fromIndex)&&(identical(other.toIndex, _this.toIndex) || other.toIndex == _this.toIndex)&&(identical(other.structure, _this.structure) || other.structure == _this.structure)&&(identical(other.structureSource, _this.structureSource) || other.structureSource == _this.structureSource)&&(identical(other.surface, _this.surface) || other.surface == _this.surface)&&(identical(other.wayKind, _this.wayKind) || other.wayKind == _this.wayKind)&&(identical(other.matched, _this.matched) || other.matched == _this.matched));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Segment;
  return Object.hash(runtimeType,_this.fromM,_this.toM,_this.fromIndex,_this.toIndex,_this.structure,_this.structureSource,_this.surface,_this.wayKind,_this.matched);
}

@override
String toString() {
  final _this = this as Segment;
  return 'Segment(fromM: ${_this.fromM}, toM: ${_this.toM}, fromIndex: ${_this.fromIndex}, toIndex: ${_this.toIndex}, structure: ${_this.structure}, structureSource: ${_this.structureSource}, surface: ${_this.surface}, wayKind: ${_this.wayKind}, matched: ${_this.matched})';
}


}

/// @nodoc
abstract mixin class $SegmentCopyWith<$Res>  {
  factory $SegmentCopyWith(Segment value, $Res Function(Segment) _then) = _$SegmentCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM,@JsonKey(name: 'from_index') int? fromIndex,@JsonKey(name: 'to_index') int? toIndex, String? structure,@JsonKey(name: 'structure_source') String? structureSource, Surface? surface,@JsonKey(name: 'way_kind') String? wayKind, bool? matched
});


$SurfaceCopyWith<$Res>? get surface;

}
/// @nodoc
class _$SegmentCopyWithImpl<$Res>
    implements $SegmentCopyWith<$Res> {
  _$SegmentCopyWithImpl(this._self, this._then);

  final Segment _self;
  final $Res Function(Segment) _then;

/// Create a copy of Segment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromM = freezed,Object? toM = freezed,Object? fromIndex = freezed,Object? toIndex = freezed,Object? structure = freezed,Object? structureSource = freezed,Object? surface = freezed,Object? wayKind = freezed,Object? matched = freezed,}) {
  return _then(Segment(
fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,fromIndex: freezed == fromIndex ? _self.fromIndex : fromIndex // ignore: cast_nullable_to_non_nullable
as int?,toIndex: freezed == toIndex ? _self.toIndex : toIndex // ignore: cast_nullable_to_non_nullable
as int?,structure: freezed == structure ? _self.structure : structure // ignore: cast_nullable_to_non_nullable
as String?,structureSource: freezed == structureSource ? _self.structureSource : structureSource // ignore: cast_nullable_to_non_nullable
as String?,surface: freezed == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as Surface?,wayKind: freezed == wayKind ? _self.wayKind : wayKind // ignore: cast_nullable_to_non_nullable
as String?,matched: freezed == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of Segment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SurfaceCopyWith<$Res>? get surface {
    if (_self.surface == null) {
    return null;
  }

  return $SurfaceCopyWith<$Res>(_self.surface!, (value) {
    return _then(_self.copyWith(surface: value));
  });
}
}


/// Adds pattern-matching-related methods to [Segment].
extension SegmentPatterns on Segment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Segment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Segment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Segment value)  $default,){
final _that = this;
switch (_that) {
case _Segment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Segment value)?  $default,){
final _that = this;
switch (_that) {
case _Segment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM, @JsonKey(name: 'from_index')  int? fromIndex, @JsonKey(name: 'to_index')  int? toIndex,  String? structure, @JsonKey(name: 'structure_source')  String? structureSource,  Surface? surface, @JsonKey(name: 'way_kind')  String? wayKind,  bool? matched)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Segment() when $default != null:
return $default(_that.fromM,_that.toM,_that.fromIndex,_that.toIndex,_that.structure,_that.structureSource,_that.surface,_that.wayKind,_that.matched);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM, @JsonKey(name: 'from_index')  int? fromIndex, @JsonKey(name: 'to_index')  int? toIndex,  String? structure, @JsonKey(name: 'structure_source')  String? structureSource,  Surface? surface, @JsonKey(name: 'way_kind')  String? wayKind,  bool? matched)  $default,) {final _that = this;
switch (_that) {
case _Segment():
return $default(_that.fromM,_that.toM,_that.fromIndex,_that.toIndex,_that.structure,_that.structureSource,_that.surface,_that.wayKind,_that.matched);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM, @JsonKey(name: 'from_index')  int? fromIndex, @JsonKey(name: 'to_index')  int? toIndex,  String? structure, @JsonKey(name: 'structure_source')  String? structureSource,  Surface? surface, @JsonKey(name: 'way_kind')  String? wayKind,  bool? matched)?  $default,) {final _that = this;
switch (_that) {
case _Segment() when $default != null:
return $default(_that.fromM,_that.toM,_that.fromIndex,_that.toIndex,_that.structure,_that.structureSource,_that.surface,_that.wayKind,_that.matched);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Segment implements Segment {
  const _Segment({@JsonKey(name: 'from_m') this.fromM, @JsonKey(name: 'to_m') this.toM, @JsonKey(name: 'from_index') this.fromIndex, @JsonKey(name: 'to_index') this.toIndex, this.structure, @JsonKey(name: 'structure_source') this.structureSource, this.surface, @JsonKey(name: 'way_kind') this.wayKind, this.matched});
  factory _Segment.fromJson(Map<String, dynamic> json) => _$SegmentFromJson(json);

@override@JsonKey(name: 'from_m') final  double? fromM;
@override@JsonKey(name: 'to_m') final  double? toM;
@override@JsonKey(name: 'from_index') final  int? fromIndex;
@override@JsonKey(name: 'to_index') final  int? toIndex;
@override final  String? structure;
@override@JsonKey(name: 'structure_source') final  String? structureSource;
@override final  Surface? surface;
@override@JsonKey(name: 'way_kind') final  String? wayKind;
@override final  bool? matched;

/// Create a copy of Segment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SegmentCopyWith<_Segment> get copyWith => __$SegmentCopyWithImpl<_Segment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SegmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Segment&&(identical(other.fromM, fromM) || other.fromM == fromM)&&(identical(other.toM, toM) || other.toM == toM)&&(identical(other.fromIndex, fromIndex) || other.fromIndex == fromIndex)&&(identical(other.toIndex, toIndex) || other.toIndex == toIndex)&&(identical(other.structure, structure) || other.structure == structure)&&(identical(other.structureSource, structureSource) || other.structureSource == structureSource)&&(identical(other.surface, surface) || other.surface == surface)&&(identical(other.wayKind, wayKind) || other.wayKind == wayKind)&&(identical(other.matched, matched) || other.matched == matched));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fromM,toM,fromIndex,toIndex,structure,structureSource,surface,wayKind,matched);
}

@override
String toString() {
    return 'Segment(fromM: $fromM, toM: $toM, fromIndex: $fromIndex, toIndex: $toIndex, structure: $structure, structureSource: $structureSource, surface: $surface, wayKind: $wayKind, matched: $matched)';
}


}

/// @nodoc
abstract mixin class _$SegmentCopyWith<$Res> implements $SegmentCopyWith<$Res> {
  factory _$SegmentCopyWith(_Segment value, $Res Function(_Segment) _then) = __$SegmentCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM,@JsonKey(name: 'from_index') int? fromIndex,@JsonKey(name: 'to_index') int? toIndex, String? structure,@JsonKey(name: 'structure_source') String? structureSource, Surface? surface,@JsonKey(name: 'way_kind') String? wayKind, bool? matched
});


@override $SurfaceCopyWith<$Res>? get surface;

}
/// @nodoc
class __$SegmentCopyWithImpl<$Res>
    implements _$SegmentCopyWith<$Res> {
  __$SegmentCopyWithImpl(this._self, this._then);

  final _Segment _self;
  final $Res Function(_Segment) _then;

/// Create a copy of Segment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fromM = freezed,Object? toM = freezed,Object? fromIndex = freezed,Object? toIndex = freezed,Object? structure = freezed,Object? structureSource = freezed,Object? surface = freezed,Object? wayKind = freezed,Object? matched = freezed,}) {
  return _then(_Segment(
fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,fromIndex: freezed == fromIndex ? _self.fromIndex : fromIndex // ignore: cast_nullable_to_non_nullable
as int?,toIndex: freezed == toIndex ? _self.toIndex : toIndex // ignore: cast_nullable_to_non_nullable
as int?,structure: freezed == structure ? _self.structure : structure // ignore: cast_nullable_to_non_nullable
as String?,structureSource: freezed == structureSource ? _self.structureSource : structureSource // ignore: cast_nullable_to_non_nullable
as String?,surface: freezed == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as Surface?,wayKind: freezed == wayKind ? _self.wayKind : wayKind // ignore: cast_nullable_to_non_nullable
as String?,matched: freezed == matched ? _self.matched : matched // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of Segment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SurfaceCopyWith<$Res>? get surface {
    if (_self.surface == null) {
    return null;
  }

  return $SurfaceCopyWith<$Res>(_self.surface!, (value) {
    return _then(_self.copyWith(surface: value));
  });
}
}

// dart format on
