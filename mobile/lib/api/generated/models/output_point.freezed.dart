// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'output_point.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OutputPoint {

@JsonKey(name: 'd_m') double? get dM;@JsonKey(name: 'index') int? get indexField; String? get origin; List<String>? get reasons; double? get lat; double? get lon; double? get ele;@JsonKey(name: 'ele_smoothed') double? get eleSmoothed;@JsonKey(name: 'ele_method') String? get eleMethod;@JsonKey(name: 'gain_cum_m') double? get gainCumM;@JsonKey(name: 'loss_cum_m') double? get lossCumM; bool? get inserted;
/// Create a copy of OutputPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutputPointCopyWith<OutputPoint> get copyWith => _$OutputPointCopyWithImpl<OutputPoint>(this as OutputPoint, _$identity);

  /// Serializes this OutputPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OutputPoint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutputPoint&&(identical(other.dM, _this.dM) || other.dM == _this.dM)&&(identical(other.indexField, _this.indexField) || other.indexField == _this.indexField)&&(identical(other.origin, _this.origin) || other.origin == _this.origin)&&const DeepCollectionEquality().equals(other.reasons, _this.reasons)&&(identical(other.lat, _this.lat) || other.lat == _this.lat)&&(identical(other.lon, _this.lon) || other.lon == _this.lon)&&(identical(other.ele, _this.ele) || other.ele == _this.ele)&&(identical(other.eleSmoothed, _this.eleSmoothed) || other.eleSmoothed == _this.eleSmoothed)&&(identical(other.eleMethod, _this.eleMethod) || other.eleMethod == _this.eleMethod)&&(identical(other.gainCumM, _this.gainCumM) || other.gainCumM == _this.gainCumM)&&(identical(other.lossCumM, _this.lossCumM) || other.lossCumM == _this.lossCumM)&&(identical(other.inserted, _this.inserted) || other.inserted == _this.inserted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OutputPoint;
  return Object.hash(runtimeType,_this.dM,_this.indexField,_this.origin,const DeepCollectionEquality().hash(_this.reasons),_this.lat,_this.lon,_this.ele,_this.eleSmoothed,_this.eleMethod,_this.gainCumM,_this.lossCumM,_this.inserted);
}

@override
String toString() {
  final _this = this as OutputPoint;
  return 'OutputPoint(dM: ${_this.dM}, indexField: ${_this.indexField}, origin: ${_this.origin}, reasons: ${_this.reasons}, lat: ${_this.lat}, lon: ${_this.lon}, ele: ${_this.ele}, eleSmoothed: ${_this.eleSmoothed}, eleMethod: ${_this.eleMethod}, gainCumM: ${_this.gainCumM}, lossCumM: ${_this.lossCumM}, inserted: ${_this.inserted})';
}


}

/// @nodoc
abstract mixin class $OutputPointCopyWith<$Res>  {
  factory $OutputPointCopyWith(OutputPoint value, $Res Function(OutputPoint) _then) = _$OutputPointCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'd_m') double? dM,@JsonKey(name: 'index') int? indexField, String? origin, List<String>? reasons, double? lat, double? lon, double? ele,@JsonKey(name: 'ele_smoothed') double? eleSmoothed,@JsonKey(name: 'ele_method') String? eleMethod,@JsonKey(name: 'gain_cum_m') double? gainCumM,@JsonKey(name: 'loss_cum_m') double? lossCumM, bool? inserted
});




}
/// @nodoc
class _$OutputPointCopyWithImpl<$Res>
    implements $OutputPointCopyWith<$Res> {
  _$OutputPointCopyWithImpl(this._self, this._then);

  final OutputPoint _self;
  final $Res Function(OutputPoint) _then;

/// Create a copy of OutputPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dM = freezed,Object? indexField = freezed,Object? origin = freezed,Object? reasons = freezed,Object? lat = freezed,Object? lon = freezed,Object? ele = freezed,Object? eleSmoothed = freezed,Object? eleMethod = freezed,Object? gainCumM = freezed,Object? lossCumM = freezed,Object? inserted = freezed,}) {
  return _then(OutputPoint(
dM: freezed == dM ? _self.dM : dM // ignore: cast_nullable_to_non_nullable
as double?,indexField: freezed == indexField ? _self.indexField : indexField // ignore: cast_nullable_to_non_nullable
as int?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String?,reasons: freezed == reasons ? _self.reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<String>?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lon: freezed == lon ? _self.lon : lon // ignore: cast_nullable_to_non_nullable
as double?,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as double?,eleSmoothed: freezed == eleSmoothed ? _self.eleSmoothed : eleSmoothed // ignore: cast_nullable_to_non_nullable
as double?,eleMethod: freezed == eleMethod ? _self.eleMethod : eleMethod // ignore: cast_nullable_to_non_nullable
as String?,gainCumM: freezed == gainCumM ? _self.gainCumM : gainCumM // ignore: cast_nullable_to_non_nullable
as double?,lossCumM: freezed == lossCumM ? _self.lossCumM : lossCumM // ignore: cast_nullable_to_non_nullable
as double?,inserted: freezed == inserted ? _self.inserted : inserted // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [OutputPoint].
extension OutputPointPatterns on OutputPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OutputPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OutputPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OutputPoint value)  $default,){
final _that = this;
switch (_that) {
case _OutputPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OutputPoint value)?  $default,){
final _that = this;
switch (_that) {
case _OutputPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'd_m')  double? dM, @JsonKey(name: 'index')  int? indexField,  String? origin,  List<String>? reasons,  double? lat,  double? lon,  double? ele, @JsonKey(name: 'ele_smoothed')  double? eleSmoothed, @JsonKey(name: 'ele_method')  String? eleMethod, @JsonKey(name: 'gain_cum_m')  double? gainCumM, @JsonKey(name: 'loss_cum_m')  double? lossCumM,  bool? inserted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OutputPoint() when $default != null:
return $default(_that.dM,_that.indexField,_that.origin,_that.reasons,_that.lat,_that.lon,_that.ele,_that.eleSmoothed,_that.eleMethod,_that.gainCumM,_that.lossCumM,_that.inserted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'd_m')  double? dM, @JsonKey(name: 'index')  int? indexField,  String? origin,  List<String>? reasons,  double? lat,  double? lon,  double? ele, @JsonKey(name: 'ele_smoothed')  double? eleSmoothed, @JsonKey(name: 'ele_method')  String? eleMethod, @JsonKey(name: 'gain_cum_m')  double? gainCumM, @JsonKey(name: 'loss_cum_m')  double? lossCumM,  bool? inserted)  $default,) {final _that = this;
switch (_that) {
case _OutputPoint():
return $default(_that.dM,_that.indexField,_that.origin,_that.reasons,_that.lat,_that.lon,_that.ele,_that.eleSmoothed,_that.eleMethod,_that.gainCumM,_that.lossCumM,_that.inserted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'd_m')  double? dM, @JsonKey(name: 'index')  int? indexField,  String? origin,  List<String>? reasons,  double? lat,  double? lon,  double? ele, @JsonKey(name: 'ele_smoothed')  double? eleSmoothed, @JsonKey(name: 'ele_method')  String? eleMethod, @JsonKey(name: 'gain_cum_m')  double? gainCumM, @JsonKey(name: 'loss_cum_m')  double? lossCumM,  bool? inserted)?  $default,) {final _that = this;
switch (_that) {
case _OutputPoint() when $default != null:
return $default(_that.dM,_that.indexField,_that.origin,_that.reasons,_that.lat,_that.lon,_that.ele,_that.eleSmoothed,_that.eleMethod,_that.gainCumM,_that.lossCumM,_that.inserted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OutputPoint implements OutputPoint {
  const _OutputPoint({@JsonKey(name: 'd_m') this.dM, @JsonKey(name: 'index') this.indexField, this.origin,  List<String>? reasons, this.lat, this.lon, this.ele, @JsonKey(name: 'ele_smoothed') this.eleSmoothed, @JsonKey(name: 'ele_method') this.eleMethod, @JsonKey(name: 'gain_cum_m') this.gainCumM, @JsonKey(name: 'loss_cum_m') this.lossCumM, this.inserted}): _reasons = reasons;
  factory _OutputPoint.fromJson(Map<String, dynamic> json) => _$OutputPointFromJson(json);

@override@JsonKey(name: 'd_m') final  double? dM;
@override@JsonKey(name: 'index') final  int? indexField;
@override final  String? origin;
 final  List<String>? _reasons;
@override List<String>? get reasons {
  final value = _reasons;
  if (value == null) return null;
  if (_reasons is EqualUnmodifiableListView) return _reasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  double? lat;
@override final  double? lon;
@override final  double? ele;
@override@JsonKey(name: 'ele_smoothed') final  double? eleSmoothed;
@override@JsonKey(name: 'ele_method') final  String? eleMethod;
@override@JsonKey(name: 'gain_cum_m') final  double? gainCumM;
@override@JsonKey(name: 'loss_cum_m') final  double? lossCumM;
@override final  bool? inserted;

/// Create a copy of OutputPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OutputPointCopyWith<_OutputPoint> get copyWith => __$OutputPointCopyWithImpl<_OutputPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OutputPointToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OutputPoint&&(identical(other.dM, dM) || other.dM == dM)&&(identical(other.indexField, indexField) || other.indexField == indexField)&&(identical(other.origin, origin) || other.origin == origin)&&const DeepCollectionEquality().equals(other.reasons, _reasons)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lon, lon) || other.lon == lon)&&(identical(other.ele, ele) || other.ele == ele)&&(identical(other.eleSmoothed, eleSmoothed) || other.eleSmoothed == eleSmoothed)&&(identical(other.eleMethod, eleMethod) || other.eleMethod == eleMethod)&&(identical(other.gainCumM, gainCumM) || other.gainCumM == gainCumM)&&(identical(other.lossCumM, lossCumM) || other.lossCumM == lossCumM)&&(identical(other.inserted, inserted) || other.inserted == inserted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,dM,indexField,origin,const DeepCollectionEquality().hash(_reasons),lat,lon,ele,eleSmoothed,eleMethod,gainCumM,lossCumM,inserted);
}

@override
String toString() {
    return 'OutputPoint(dM: $dM, indexField: $indexField, origin: $origin, reasons: $reasons, lat: $lat, lon: $lon, ele: $ele, eleSmoothed: $eleSmoothed, eleMethod: $eleMethod, gainCumM: $gainCumM, lossCumM: $lossCumM, inserted: $inserted)';
}


}

/// @nodoc
abstract mixin class _$OutputPointCopyWith<$Res> implements $OutputPointCopyWith<$Res> {
  factory _$OutputPointCopyWith(_OutputPoint value, $Res Function(_OutputPoint) _then) = __$OutputPointCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'd_m') double? dM,@JsonKey(name: 'index') int? indexField, String? origin, List<String>? reasons, double? lat, double? lon, double? ele,@JsonKey(name: 'ele_smoothed') double? eleSmoothed,@JsonKey(name: 'ele_method') String? eleMethod,@JsonKey(name: 'gain_cum_m') double? gainCumM,@JsonKey(name: 'loss_cum_m') double? lossCumM, bool? inserted
});




}
/// @nodoc
class __$OutputPointCopyWithImpl<$Res>
    implements _$OutputPointCopyWith<$Res> {
  __$OutputPointCopyWithImpl(this._self, this._then);

  final _OutputPoint _self;
  final $Res Function(_OutputPoint) _then;

/// Create a copy of OutputPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dM = freezed,Object? indexField = freezed,Object? origin = freezed,Object? reasons = freezed,Object? lat = freezed,Object? lon = freezed,Object? ele = freezed,Object? eleSmoothed = freezed,Object? eleMethod = freezed,Object? gainCumM = freezed,Object? lossCumM = freezed,Object? inserted = freezed,}) {
  return _then(_OutputPoint(
dM: freezed == dM ? _self.dM : dM // ignore: cast_nullable_to_non_nullable
as double?,indexField: freezed == indexField ? _self.indexField : indexField // ignore: cast_nullable_to_non_nullable
as int?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String?,reasons: freezed == reasons ? _self._reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<String>?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lon: freezed == lon ? _self.lon : lon // ignore: cast_nullable_to_non_nullable
as double?,ele: freezed == ele ? _self.ele : ele // ignore: cast_nullable_to_non_nullable
as double?,eleSmoothed: freezed == eleSmoothed ? _self.eleSmoothed : eleSmoothed // ignore: cast_nullable_to_non_nullable
as double?,eleMethod: freezed == eleMethod ? _self.eleMethod : eleMethod // ignore: cast_nullable_to_non_nullable
as String?,gainCumM: freezed == gainCumM ? _self.gainCumM : gainCumM // ignore: cast_nullable_to_non_nullable
as double?,lossCumM: freezed == lossCumM ? _self.lossCumM : lossCumM // ignore: cast_nullable_to_non_nullable
as double?,inserted: freezed == inserted ? _self.inserted : inserted // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
