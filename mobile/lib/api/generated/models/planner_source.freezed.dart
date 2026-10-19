// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planner_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannerSource {

/// Polyline (precision 6, latitude then longitude) of the source track
 String get line;/// Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100]
 double get ascendScale;/// One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation
 String? get ele;/// One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele
 String? get climb;
/// Create a copy of PlannerSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannerSourceCopyWith<PlannerSource> get copyWith => _$PlannerSourceCopyWithImpl<PlannerSource>(this as PlannerSource, _$identity);

  /// Serializes this PlannerSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlannerSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannerSource&&(identical(other.line, _this.line) || other.line == _this.line)&&(identical(other.ascendScale, _this.ascendScale) || other.ascendScale == _this.ascendScale)&&(identical(other.ele, _this.ele) || other.ele == _this.ele)&&(identical(other.climb, _this.climb) || other.climb == _this.climb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlannerSource;
  return Object.hash(runtimeType,_this.line,_this.ascendScale,_this.ele,_this.climb);
}

@override
String toString() {
  final _this = this as PlannerSource;
  return 'PlannerSource(line: ${_this.line}, ascendScale: ${_this.ascendScale}, ele: ${_this.ele}, climb: ${_this.climb})';
}


}

/// @nodoc
abstract mixin class $PlannerSourceCopyWith<$Res>  {
  factory $PlannerSourceCopyWith(PlannerSource value, $Res Function(PlannerSource) _then) = _$PlannerSourceCopyWithImpl;
@useResult
$Res call({
 String line, double ascendScale, String? ele, String? climb
});




}
/// @nodoc
class _$PlannerSourceCopyWithImpl<$Res>
    implements $PlannerSourceCopyWith<$Res> {
  _$PlannerSourceCopyWithImpl(this._self, this._then);

  final PlannerSource _self;
  final $Res Function(PlannerSource) _then;

/// Create a copy of PlannerSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? line = null,Object? ascendScale = null,Object? ele = freezed,Object? climb = freezed,}) {
  return _then(PlannerSource(
line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as String,ascendScale: null == ascendScale ? _self.ascendScale : ascendScale // ignore: cast_nullable_to_non_nullable
as double,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as String?,climb: freezed == climb ? _self.climb : climb // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlannerSource].
extension PlannerSourcePatterns on PlannerSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannerSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannerSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannerSource value)  $default,){
final _that = this;
switch (_that) {
case _PlannerSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannerSource value)?  $default,){
final _that = this;
switch (_that) {
case _PlannerSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String line,  double ascendScale,  String? ele,  String? climb)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannerSource() when $default != null:
return $default(_that.line,_that.ascendScale,_that.ele,_that.climb);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String line,  double ascendScale,  String? ele,  String? climb)  $default,) {final _that = this;
switch (_that) {
case _PlannerSource():
return $default(_that.line,_that.ascendScale,_that.ele,_that.climb);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String line,  double ascendScale,  String? ele,  String? climb)?  $default,) {final _that = this;
switch (_that) {
case _PlannerSource() when $default != null:
return $default(_that.line,_that.ascendScale,_that.ele,_that.climb);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannerSource implements PlannerSource {
  const _PlannerSource({required this.line, required this.ascendScale, this.ele, this.climb});
  factory _PlannerSource.fromJson(Map<String, dynamic> json) => _$PlannerSourceFromJson(json);

/// Polyline (precision 6, latitude then longitude) of the source track
@override final  String line;
/// Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100]
@override final  double ascendScale;
/// One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation
@override final  String? ele;
/// One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele
@override final  String? climb;

/// Create a copy of PlannerSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannerSourceCopyWith<_PlannerSource> get copyWith => __$PlannerSourceCopyWithImpl<_PlannerSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannerSourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannerSource&&(identical(other.line, line) || other.line == line)&&(identical(other.ascendScale, ascendScale) || other.ascendScale == ascendScale)&&(identical(other.ele, ele) || other.ele == ele)&&(identical(other.climb, climb) || other.climb == climb));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,line,ascendScale,ele,climb);
}

@override
String toString() {
    return 'PlannerSource(line: $line, ascendScale: $ascendScale, ele: $ele, climb: $climb)';
}


}

/// @nodoc
abstract mixin class _$PlannerSourceCopyWith<$Res> implements $PlannerSourceCopyWith<$Res> {
  factory _$PlannerSourceCopyWith(_PlannerSource value, $Res Function(_PlannerSource) _then) = __$PlannerSourceCopyWithImpl;
@override @useResult
$Res call({
 String line, double ascendScale, String? ele, String? climb
});




}
/// @nodoc
class __$PlannerSourceCopyWithImpl<$Res>
    implements _$PlannerSourceCopyWith<$Res> {
  __$PlannerSourceCopyWithImpl(this._self, this._then);

  final _PlannerSource _self;
  final $Res Function(_PlannerSource) _then;

/// Create a copy of PlannerSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? line = null,Object? ascendScale = null,Object? ele = freezed,Object? climb = freezed,}) {
  return _then(_PlannerSource(
line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as String,ascendScale: null == ascendScale ? _self.ascendScale : ascendScale // ignore: cast_nullable_to_non_nullable
as double,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as String?,climb: freezed == climb ? _self.climb : climb // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
