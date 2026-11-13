// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quality.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Quality {

 List<TerrainRange>? get terrain; List<Warning>? get warnings;@JsonKey(name: 'structure_correction') JsonNode? get structureCorrection;
/// Create a copy of Quality
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QualityCopyWith<Quality> get copyWith => _$QualityCopyWithImpl<Quality>(this as Quality, _$identity);

  /// Serializes this Quality to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Quality;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Quality&&const DeepCollectionEquality().equals(other.terrain, _this.terrain)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.structureCorrection, _this.structureCorrection) || other.structureCorrection == _this.structureCorrection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Quality;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.terrain),const DeepCollectionEquality().hash(_this.warnings),_this.structureCorrection);
}

@override
String toString() {
  final _this = this as Quality;
  return 'Quality(terrain: ${_this.terrain}, warnings: ${_this.warnings}, structureCorrection: ${_this.structureCorrection})';
}


}

/// @nodoc
abstract mixin class $QualityCopyWith<$Res>  {
  factory $QualityCopyWith(Quality value, $Res Function(Quality) _then) = _$QualityCopyWithImpl;
@useResult
$Res call({
 List<TerrainRange>? terrain, List<Warning>? warnings,@JsonKey(name: 'structure_correction') JsonNode? structureCorrection
});


$JsonNodeCopyWith<$Res>? get structureCorrection;

}
/// @nodoc
class _$QualityCopyWithImpl<$Res>
    implements $QualityCopyWith<$Res> {
  _$QualityCopyWithImpl(this._self, this._then);

  final Quality _self;
  final $Res Function(Quality) _then;

/// Create a copy of Quality
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? terrain = freezed,Object? warnings = freezed,Object? structureCorrection = freezed,}) {
  return _then(Quality(
terrain: freezed == terrain ? _self.terrain : terrain // ignore: cast_nullable_to_non_nullable
as List<TerrainRange>?,warnings: freezed == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<Warning>?,structureCorrection: freezed == structureCorrection ? _self.structureCorrection : structureCorrection // ignore: cast_nullable_to_non_nullable
as JsonNode?,
  ));
}
/// Create a copy of Quality
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JsonNodeCopyWith<$Res>? get structureCorrection {
    if (_self.structureCorrection == null) {
    return null;
  }

  return $JsonNodeCopyWith<$Res>(_self.structureCorrection!, (value) {
    return _then(_self.copyWith(structureCorrection: value));
  });
}
}


/// Adds pattern-matching-related methods to [Quality].
extension QualityPatterns on Quality {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Quality value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Quality() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Quality value)  $default,){
final _that = this;
switch (_that) {
case _Quality():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Quality value)?  $default,){
final _that = this;
switch (_that) {
case _Quality() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TerrainRange>? terrain,  List<Warning>? warnings, @JsonKey(name: 'structure_correction')  JsonNode? structureCorrection)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Quality() when $default != null:
return $default(_that.terrain,_that.warnings,_that.structureCorrection);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TerrainRange>? terrain,  List<Warning>? warnings, @JsonKey(name: 'structure_correction')  JsonNode? structureCorrection)  $default,) {final _that = this;
switch (_that) {
case _Quality():
return $default(_that.terrain,_that.warnings,_that.structureCorrection);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TerrainRange>? terrain,  List<Warning>? warnings, @JsonKey(name: 'structure_correction')  JsonNode? structureCorrection)?  $default,) {final _that = this;
switch (_that) {
case _Quality() when $default != null:
return $default(_that.terrain,_that.warnings,_that.structureCorrection);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Quality implements Quality {
  const _Quality({ List<TerrainRange>? terrain,  List<Warning>? warnings, @JsonKey(name: 'structure_correction') this.structureCorrection}): _terrain = terrain,_warnings = warnings;
  factory _Quality.fromJson(Map<String, dynamic> json) => _$QualityFromJson(json);

 final  List<TerrainRange>? _terrain;
@override List<TerrainRange>? get terrain {
  final value = _terrain;
  if (value == null) return null;
  if (_terrain is EqualUnmodifiableListView) return _terrain;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<Warning>? _warnings;
@override List<Warning>? get warnings {
  final value = _warnings;
  if (value == null) return null;
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'structure_correction') final  JsonNode? structureCorrection;

/// Create a copy of Quality
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QualityCopyWith<_Quality> get copyWith => __$QualityCopyWithImpl<_Quality>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QualityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Quality&&const DeepCollectionEquality().equals(other.terrain, _terrain)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.structureCorrection, structureCorrection) || other.structureCorrection == structureCorrection));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_terrain),const DeepCollectionEquality().hash(_warnings),structureCorrection);
}

@override
String toString() {
    return 'Quality(terrain: $terrain, warnings: $warnings, structureCorrection: $structureCorrection)';
}


}

/// @nodoc
abstract mixin class _$QualityCopyWith<$Res> implements $QualityCopyWith<$Res> {
  factory _$QualityCopyWith(_Quality value, $Res Function(_Quality) _then) = __$QualityCopyWithImpl;
@override @useResult
$Res call({
 List<TerrainRange>? terrain, List<Warning>? warnings,@JsonKey(name: 'structure_correction') JsonNode? structureCorrection
});


@override $JsonNodeCopyWith<$Res>? get structureCorrection;

}
/// @nodoc
class __$QualityCopyWithImpl<$Res>
    implements _$QualityCopyWith<$Res> {
  __$QualityCopyWithImpl(this._self, this._then);

  final _Quality _self;
  final $Res Function(_Quality) _then;

/// Create a copy of Quality
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? terrain = freezed,Object? warnings = freezed,Object? structureCorrection = freezed,}) {
  return _then(_Quality(
terrain: freezed == terrain ? _self._terrain : terrain // ignore: cast_nullable_to_non_nullable
as List<TerrainRange>?,warnings: freezed == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<Warning>?,structureCorrection: freezed == structureCorrection ? _self.structureCorrection : structureCorrection // ignore: cast_nullable_to_non_nullable
as JsonNode?,
  ));
}

/// Create a copy of Quality
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JsonNodeCopyWith<$Res>? get structureCorrection {
    if (_self.structureCorrection == null) {
    return null;
  }

  return $JsonNodeCopyWith<$Res>(_self.structureCorrection!, (value) {
    return _then(_self.copyWith(structureCorrection: value));
  });
}
}

// dart format on
