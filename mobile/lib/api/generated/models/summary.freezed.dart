// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Summary {

@JsonKey(name: 'length_m') double? get lengthM;@JsonKey(name: 'gain_m') double? get gainM;@JsonKey(name: 'loss_m') double? get lossM;@JsonKey(name: 'ele_min_m') double? get eleMinM;@JsonKey(name: 'ele_max_m') double? get eleMaxM; List<Structure>? get structures;@JsonKey(name: 'terrain_m') Map<String, double>? get terrainM;
/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SummaryCopyWith<Summary> get copyWith => _$SummaryCopyWithImpl<Summary>(this as Summary, _$identity);

  /// Serializes this Summary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Summary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Summary&&(identical(other.lengthM, _this.lengthM) || other.lengthM == _this.lengthM)&&(identical(other.gainM, _this.gainM) || other.gainM == _this.gainM)&&(identical(other.lossM, _this.lossM) || other.lossM == _this.lossM)&&(identical(other.eleMinM, _this.eleMinM) || other.eleMinM == _this.eleMinM)&&(identical(other.eleMaxM, _this.eleMaxM) || other.eleMaxM == _this.eleMaxM)&&const DeepCollectionEquality().equals(other.structures, _this.structures)&&const DeepCollectionEquality().equals(other.terrainM, _this.terrainM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Summary;
  return Object.hash(runtimeType,_this.lengthM,_this.gainM,_this.lossM,_this.eleMinM,_this.eleMaxM,const DeepCollectionEquality().hash(_this.structures),const DeepCollectionEquality().hash(_this.terrainM));
}

@override
String toString() {
  final _this = this as Summary;
  return 'Summary(lengthM: ${_this.lengthM}, gainM: ${_this.gainM}, lossM: ${_this.lossM}, eleMinM: ${_this.eleMinM}, eleMaxM: ${_this.eleMaxM}, structures: ${_this.structures}, terrainM: ${_this.terrainM})';
}


}

/// @nodoc
abstract mixin class $SummaryCopyWith<$Res>  {
  factory $SummaryCopyWith(Summary value, $Res Function(Summary) _then) = _$SummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'length_m') double? lengthM,@JsonKey(name: 'gain_m') double? gainM,@JsonKey(name: 'loss_m') double? lossM,@JsonKey(name: 'ele_min_m') double? eleMinM,@JsonKey(name: 'ele_max_m') double? eleMaxM, List<Structure>? structures,@JsonKey(name: 'terrain_m') Map<String, double>? terrainM
});




}
/// @nodoc
class _$SummaryCopyWithImpl<$Res>
    implements $SummaryCopyWith<$Res> {
  _$SummaryCopyWithImpl(this._self, this._then);

  final Summary _self;
  final $Res Function(Summary) _then;

/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lengthM = freezed,Object? gainM = freezed,Object? lossM = freezed,Object? eleMinM = freezed,Object? eleMaxM = freezed,Object? structures = freezed,Object? terrainM = freezed,}) {
  return _then(Summary(
lengthM: freezed == lengthM ? _self.lengthM : lengthM // ignore: cast_nullable_to_non_nullable
as double?,gainM: freezed == gainM ? _self.gainM : gainM // ignore: cast_nullable_to_non_nullable
as double?,lossM: freezed == lossM ? _self.lossM : lossM // ignore: cast_nullable_to_non_nullable
as double?,eleMinM: freezed == eleMinM ? _self.eleMinM : eleMinM // ignore: cast_nullable_to_non_nullable
as double?,eleMaxM: freezed == eleMaxM ? _self.eleMaxM : eleMaxM // ignore: cast_nullable_to_non_nullable
as double?,structures: freezed == structures ? _self.structures : structures // ignore: cast_nullable_to_non_nullable
as List<Structure>?,terrainM: freezed == terrainM ? _self.terrainM : terrainM // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,
  ));
}

}


/// Adds pattern-matching-related methods to [Summary].
extension SummaryPatterns on Summary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Summary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Summary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Summary value)  $default,){
final _that = this;
switch (_that) {
case _Summary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Summary value)?  $default,){
final _that = this;
switch (_that) {
case _Summary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'length_m')  double? lengthM, @JsonKey(name: 'gain_m')  double? gainM, @JsonKey(name: 'loss_m')  double? lossM, @JsonKey(name: 'ele_min_m')  double? eleMinM, @JsonKey(name: 'ele_max_m')  double? eleMaxM,  List<Structure>? structures, @JsonKey(name: 'terrain_m')  Map<String, double>? terrainM)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Summary() when $default != null:
return $default(_that.lengthM,_that.gainM,_that.lossM,_that.eleMinM,_that.eleMaxM,_that.structures,_that.terrainM);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'length_m')  double? lengthM, @JsonKey(name: 'gain_m')  double? gainM, @JsonKey(name: 'loss_m')  double? lossM, @JsonKey(name: 'ele_min_m')  double? eleMinM, @JsonKey(name: 'ele_max_m')  double? eleMaxM,  List<Structure>? structures, @JsonKey(name: 'terrain_m')  Map<String, double>? terrainM)  $default,) {final _that = this;
switch (_that) {
case _Summary():
return $default(_that.lengthM,_that.gainM,_that.lossM,_that.eleMinM,_that.eleMaxM,_that.structures,_that.terrainM);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'length_m')  double? lengthM, @JsonKey(name: 'gain_m')  double? gainM, @JsonKey(name: 'loss_m')  double? lossM, @JsonKey(name: 'ele_min_m')  double? eleMinM, @JsonKey(name: 'ele_max_m')  double? eleMaxM,  List<Structure>? structures, @JsonKey(name: 'terrain_m')  Map<String, double>? terrainM)?  $default,) {final _that = this;
switch (_that) {
case _Summary() when $default != null:
return $default(_that.lengthM,_that.gainM,_that.lossM,_that.eleMinM,_that.eleMaxM,_that.structures,_that.terrainM);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Summary implements Summary {
  const _Summary({@JsonKey(name: 'length_m') this.lengthM, @JsonKey(name: 'gain_m') this.gainM, @JsonKey(name: 'loss_m') this.lossM, @JsonKey(name: 'ele_min_m') this.eleMinM, @JsonKey(name: 'ele_max_m') this.eleMaxM,  List<Structure>? structures, @JsonKey(name: 'terrain_m')  Map<String, double>? terrainM}): _structures = structures,_terrainM = terrainM;
  factory _Summary.fromJson(Map<String, dynamic> json) => _$SummaryFromJson(json);

@override@JsonKey(name: 'length_m') final  double? lengthM;
@override@JsonKey(name: 'gain_m') final  double? gainM;
@override@JsonKey(name: 'loss_m') final  double? lossM;
@override@JsonKey(name: 'ele_min_m') final  double? eleMinM;
@override@JsonKey(name: 'ele_max_m') final  double? eleMaxM;
 final  List<Structure>? _structures;
@override List<Structure>? get structures {
  final value = _structures;
  if (value == null) return null;
  if (_structures is EqualUnmodifiableListView) return _structures;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  Map<String, double>? _terrainM;
@override@JsonKey(name: 'terrain_m') Map<String, double>? get terrainM {
  final value = _terrainM;
  if (value == null) return null;
  if (_terrainM is EqualUnmodifiableMapView) return _terrainM;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SummaryCopyWith<_Summary> get copyWith => __$SummaryCopyWithImpl<_Summary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Summary&&(identical(other.lengthM, lengthM) || other.lengthM == lengthM)&&(identical(other.gainM, gainM) || other.gainM == gainM)&&(identical(other.lossM, lossM) || other.lossM == lossM)&&(identical(other.eleMinM, eleMinM) || other.eleMinM == eleMinM)&&(identical(other.eleMaxM, eleMaxM) || other.eleMaxM == eleMaxM)&&const DeepCollectionEquality().equals(other.structures, _structures)&&const DeepCollectionEquality().equals(other.terrainM, _terrainM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,lengthM,gainM,lossM,eleMinM,eleMaxM,const DeepCollectionEquality().hash(_structures),const DeepCollectionEquality().hash(_terrainM));
}

@override
String toString() {
    return 'Summary(lengthM: $lengthM, gainM: $gainM, lossM: $lossM, eleMinM: $eleMinM, eleMaxM: $eleMaxM, structures: $structures, terrainM: $terrainM)';
}


}

/// @nodoc
abstract mixin class _$SummaryCopyWith<$Res> implements $SummaryCopyWith<$Res> {
  factory _$SummaryCopyWith(_Summary value, $Res Function(_Summary) _then) = __$SummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'length_m') double? lengthM,@JsonKey(name: 'gain_m') double? gainM,@JsonKey(name: 'loss_m') double? lossM,@JsonKey(name: 'ele_min_m') double? eleMinM,@JsonKey(name: 'ele_max_m') double? eleMaxM, List<Structure>? structures,@JsonKey(name: 'terrain_m') Map<String, double>? terrainM
});




}
/// @nodoc
class __$SummaryCopyWithImpl<$Res>
    implements _$SummaryCopyWith<$Res> {
  __$SummaryCopyWithImpl(this._self, this._then);

  final _Summary _self;
  final $Res Function(_Summary) _then;

/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lengthM = freezed,Object? gainM = freezed,Object? lossM = freezed,Object? eleMinM = freezed,Object? eleMaxM = freezed,Object? structures = freezed,Object? terrainM = freezed,}) {
  return _then(_Summary(
lengthM: freezed == lengthM ? _self.lengthM : lengthM // ignore: cast_nullable_to_non_nullable
as double?,gainM: freezed == gainM ? _self.gainM : gainM // ignore: cast_nullable_to_non_nullable
as double?,lossM: freezed == lossM ? _self.lossM : lossM // ignore: cast_nullable_to_non_nullable
as double?,eleMinM: freezed == eleMinM ? _self.eleMinM : eleMinM // ignore: cast_nullable_to_non_nullable
as double?,eleMaxM: freezed == eleMaxM ? _self.eleMaxM : eleMaxM // ignore: cast_nullable_to_non_nullable
as double?,structures: freezed == structures ? _self._structures : structures // ignore: cast_nullable_to_non_nullable
as List<Structure>?,terrainM: freezed == terrainM ? _self._terrainM : terrainM // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,
  ));
}


}

// dart format on
