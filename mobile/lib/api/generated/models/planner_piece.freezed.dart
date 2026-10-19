// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planner_piece.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannerPiece {

 PlannerPieceMode get mode;/// ROUTED and DIRECT: polyline6 of the points strictly inside the piece
 String? get line;/// ROUTED and DIRECT: one-dimension polyline of their elevations
 String? get ele;/// ROUTED: climb of the piece in metres
 double? get ascend;/// IMPORTED: index of the source track
 int? get source;/// IMPORTED: index in the source of the first junction
 int? get from;/// IMPORTED: index in the source of the last junction
 int? get to;/// ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown
 List<UnpavedSpan>? get unpaved;
/// Create a copy of PlannerPiece
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannerPieceCopyWith<PlannerPiece> get copyWith => _$PlannerPieceCopyWithImpl<PlannerPiece>(this as PlannerPiece, _$identity);

  /// Serializes this PlannerPiece to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlannerPiece;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannerPiece&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.line, _this.line) || other.line == _this.line)&&(identical(other.ele, _this.ele) || other.ele == _this.ele)&&(identical(other.ascend, _this.ascend) || other.ascend == _this.ascend)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.from, _this.from) || other.from == _this.from)&&(identical(other.to, _this.to) || other.to == _this.to)&&const DeepCollectionEquality().equals(other.unpaved, _this.unpaved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlannerPiece;
  return Object.hash(runtimeType,_this.mode,_this.line,_this.ele,_this.ascend,_this.source,_this.from,_this.to,const DeepCollectionEquality().hash(_this.unpaved));
}

@override
String toString() {
  final _this = this as PlannerPiece;
  return 'PlannerPiece(mode: ${_this.mode}, line: ${_this.line}, ele: ${_this.ele}, ascend: ${_this.ascend}, source: ${_this.source}, from: ${_this.from}, to: ${_this.to}, unpaved: ${_this.unpaved})';
}


}

/// @nodoc
abstract mixin class $PlannerPieceCopyWith<$Res>  {
  factory $PlannerPieceCopyWith(PlannerPiece value, $Res Function(PlannerPiece) _then) = _$PlannerPieceCopyWithImpl;
@useResult
$Res call({
 PlannerPieceMode mode, String? line, String? ele, double? ascend, int? source, int? from, int? to, List<UnpavedSpan>? unpaved
});




}
/// @nodoc
class _$PlannerPieceCopyWithImpl<$Res>
    implements $PlannerPieceCopyWith<$Res> {
  _$PlannerPieceCopyWithImpl(this._self, this._then);

  final PlannerPiece _self;
  final $Res Function(PlannerPiece) _then;

/// Create a copy of PlannerPiece
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? line = freezed,Object? ele = freezed,Object? ascend = freezed,Object? source = freezed,Object? from = freezed,Object? to = freezed,Object? unpaved = freezed,}) {
  return _then(PlannerPiece(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PlannerPieceMode,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as String?,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as String?,ascend: freezed == ascend ? _self.ascend : ascend // ignore: cast_nullable_to_non_nullable
as double?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as int?,from: freezed == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as int?,to: freezed == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as int?,unpaved: freezed == unpaved ? _self.unpaved : unpaved // ignore: cast_nullable_to_non_nullable
as List<UnpavedSpan>?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlannerPiece].
extension PlannerPiecePatterns on PlannerPiece {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannerPiece value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannerPiece() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannerPiece value)  $default,){
final _that = this;
switch (_that) {
case _PlannerPiece():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannerPiece value)?  $default,){
final _that = this;
switch (_that) {
case _PlannerPiece() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PlannerPieceMode mode,  String? line,  String? ele,  double? ascend,  int? source,  int? from,  int? to,  List<UnpavedSpan>? unpaved)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannerPiece() when $default != null:
return $default(_that.mode,_that.line,_that.ele,_that.ascend,_that.source,_that.from,_that.to,_that.unpaved);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PlannerPieceMode mode,  String? line,  String? ele,  double? ascend,  int? source,  int? from,  int? to,  List<UnpavedSpan>? unpaved)  $default,) {final _that = this;
switch (_that) {
case _PlannerPiece():
return $default(_that.mode,_that.line,_that.ele,_that.ascend,_that.source,_that.from,_that.to,_that.unpaved);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PlannerPieceMode mode,  String? line,  String? ele,  double? ascend,  int? source,  int? from,  int? to,  List<UnpavedSpan>? unpaved)?  $default,) {final _that = this;
switch (_that) {
case _PlannerPiece() when $default != null:
return $default(_that.mode,_that.line,_that.ele,_that.ascend,_that.source,_that.from,_that.to,_that.unpaved);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannerPiece implements PlannerPiece {
  const _PlannerPiece({required this.mode, this.line, this.ele, this.ascend, this.source, this.from, this.to,  List<UnpavedSpan>? unpaved}): _unpaved = unpaved;
  factory _PlannerPiece.fromJson(Map<String, dynamic> json) => _$PlannerPieceFromJson(json);

@override final  PlannerPieceMode mode;
/// ROUTED and DIRECT: polyline6 of the points strictly inside the piece
@override final  String? line;
/// ROUTED and DIRECT: one-dimension polyline of their elevations
@override final  String? ele;
/// ROUTED: climb of the piece in metres
@override final  double? ascend;
/// IMPORTED: index of the source track
@override final  int? source;
/// IMPORTED: index in the source of the first junction
@override final  int? from;
/// IMPORTED: index in the source of the last junction
@override final  int? to;
/// ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown
 final  List<UnpavedSpan>? _unpaved;
/// ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown
@override List<UnpavedSpan>? get unpaved {
  final value = _unpaved;
  if (value == null) return null;
  if (_unpaved is EqualUnmodifiableListView) return _unpaved;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of PlannerPiece
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannerPieceCopyWith<_PlannerPiece> get copyWith => __$PlannerPieceCopyWithImpl<_PlannerPiece>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannerPieceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannerPiece&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.line, line) || other.line == line)&&(identical(other.ele, ele) || other.ele == ele)&&(identical(other.ascend, ascend) || other.ascend == ascend)&&(identical(other.source, source) || other.source == source)&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&const DeepCollectionEquality().equals(other.unpaved, _unpaved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mode,line,ele,ascend,source,from,to,const DeepCollectionEquality().hash(_unpaved));
}

@override
String toString() {
    return 'PlannerPiece(mode: $mode, line: $line, ele: $ele, ascend: $ascend, source: $source, from: $from, to: $to, unpaved: $unpaved)';
}


}

/// @nodoc
abstract mixin class _$PlannerPieceCopyWith<$Res> implements $PlannerPieceCopyWith<$Res> {
  factory _$PlannerPieceCopyWith(_PlannerPiece value, $Res Function(_PlannerPiece) _then) = __$PlannerPieceCopyWithImpl;
@override @useResult
$Res call({
 PlannerPieceMode mode, String? line, String? ele, double? ascend, int? source, int? from, int? to, List<UnpavedSpan>? unpaved
});




}
/// @nodoc
class __$PlannerPieceCopyWithImpl<$Res>
    implements _$PlannerPieceCopyWith<$Res> {
  __$PlannerPieceCopyWithImpl(this._self, this._then);

  final _PlannerPiece _self;
  final $Res Function(_PlannerPiece) _then;

/// Create a copy of PlannerPiece
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? line = freezed,Object? ele = freezed,Object? ascend = freezed,Object? source = freezed,Object? from = freezed,Object? to = freezed,Object? unpaved = freezed,}) {
  return _then(_PlannerPiece(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PlannerPieceMode,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as String?,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as String?,ascend: freezed == ascend ? _self.ascend : ascend // ignore: cast_nullable_to_non_nullable
as double?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as int?,from: freezed == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as int?,to: freezed == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as int?,unpaved: freezed == unpaved ? _self._unpaved : unpaved // ignore: cast_nullable_to_non_nullable
as List<UnpavedSpan>?,
  ));
}


}

// dart format on
