// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'structure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Structure {

 String? get kind;@JsonKey(name: 'from_m') double? get fromM;@JsonKey(name: 'to_m') double? get toM;@JsonKey(name: 'length_m') double? get lengthM;@JsonKey(name: 'structure_source') String? get structureSource; String? get method;
/// Create a copy of Structure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StructureCopyWith<Structure> get copyWith => _$StructureCopyWithImpl<Structure>(this as Structure, _$identity);

  /// Serializes this Structure to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Structure;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Structure&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.fromM, _this.fromM) || other.fromM == _this.fromM)&&(identical(other.toM, _this.toM) || other.toM == _this.toM)&&(identical(other.lengthM, _this.lengthM) || other.lengthM == _this.lengthM)&&(identical(other.structureSource, _this.structureSource) || other.structureSource == _this.structureSource)&&(identical(other.method, _this.method) || other.method == _this.method));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Structure;
  return Object.hash(runtimeType,_this.kind,_this.fromM,_this.toM,_this.lengthM,_this.structureSource,_this.method);
}

@override
String toString() {
  final _this = this as Structure;
  return 'Structure(kind: ${_this.kind}, fromM: ${_this.fromM}, toM: ${_this.toM}, lengthM: ${_this.lengthM}, structureSource: ${_this.structureSource}, method: ${_this.method})';
}


}

/// @nodoc
abstract mixin class $StructureCopyWith<$Res>  {
  factory $StructureCopyWith(Structure value, $Res Function(Structure) _then) = _$StructureCopyWithImpl;
@useResult
$Res call({
 String? kind,@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM,@JsonKey(name: 'length_m') double? lengthM,@JsonKey(name: 'structure_source') String? structureSource, String? method
});




}
/// @nodoc
class _$StructureCopyWithImpl<$Res>
    implements $StructureCopyWith<$Res> {
  _$StructureCopyWithImpl(this._self, this._then);

  final Structure _self;
  final $Res Function(Structure) _then;

/// Create a copy of Structure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = freezed,Object? fromM = freezed,Object? toM = freezed,Object? lengthM = freezed,Object? structureSource = freezed,Object? method = freezed,}) {
  return _then(Structure(
kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,lengthM: freezed == lengthM ? _self.lengthM : lengthM // ignore: cast_nullable_to_non_nullable
as double?,structureSource: freezed == structureSource ? _self.structureSource : structureSource // ignore: cast_nullable_to_non_nullable
as String?,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Structure].
extension StructurePatterns on Structure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Structure value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Structure() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Structure value)  $default,){
final _that = this;
switch (_that) {
case _Structure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Structure value)?  $default,){
final _that = this;
switch (_that) {
case _Structure() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? kind, @JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM, @JsonKey(name: 'length_m')  double? lengthM, @JsonKey(name: 'structure_source')  String? structureSource,  String? method)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Structure() when $default != null:
return $default(_that.kind,_that.fromM,_that.toM,_that.lengthM,_that.structureSource,_that.method);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? kind, @JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM, @JsonKey(name: 'length_m')  double? lengthM, @JsonKey(name: 'structure_source')  String? structureSource,  String? method)  $default,) {final _that = this;
switch (_that) {
case _Structure():
return $default(_that.kind,_that.fromM,_that.toM,_that.lengthM,_that.structureSource,_that.method);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? kind, @JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM, @JsonKey(name: 'length_m')  double? lengthM, @JsonKey(name: 'structure_source')  String? structureSource,  String? method)?  $default,) {final _that = this;
switch (_that) {
case _Structure() when $default != null:
return $default(_that.kind,_that.fromM,_that.toM,_that.lengthM,_that.structureSource,_that.method);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Structure implements Structure {
  const _Structure({this.kind, @JsonKey(name: 'from_m') this.fromM, @JsonKey(name: 'to_m') this.toM, @JsonKey(name: 'length_m') this.lengthM, @JsonKey(name: 'structure_source') this.structureSource, this.method});
  factory _Structure.fromJson(Map<String, dynamic> json) => _$StructureFromJson(json);

@override final  String? kind;
@override@JsonKey(name: 'from_m') final  double? fromM;
@override@JsonKey(name: 'to_m') final  double? toM;
@override@JsonKey(name: 'length_m') final  double? lengthM;
@override@JsonKey(name: 'structure_source') final  String? structureSource;
@override final  String? method;

/// Create a copy of Structure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StructureCopyWith<_Structure> get copyWith => __$StructureCopyWithImpl<_Structure>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StructureToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Structure&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.fromM, fromM) || other.fromM == fromM)&&(identical(other.toM, toM) || other.toM == toM)&&(identical(other.lengthM, lengthM) || other.lengthM == lengthM)&&(identical(other.structureSource, structureSource) || other.structureSource == structureSource)&&(identical(other.method, method) || other.method == method));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,fromM,toM,lengthM,structureSource,method);
}

@override
String toString() {
    return 'Structure(kind: $kind, fromM: $fromM, toM: $toM, lengthM: $lengthM, structureSource: $structureSource, method: $method)';
}


}

/// @nodoc
abstract mixin class _$StructureCopyWith<$Res> implements $StructureCopyWith<$Res> {
  factory _$StructureCopyWith(_Structure value, $Res Function(_Structure) _then) = __$StructureCopyWithImpl;
@override @useResult
$Res call({
 String? kind,@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM,@JsonKey(name: 'length_m') double? lengthM,@JsonKey(name: 'structure_source') String? structureSource, String? method
});




}
/// @nodoc
class __$StructureCopyWithImpl<$Res>
    implements _$StructureCopyWith<$Res> {
  __$StructureCopyWithImpl(this._self, this._then);

  final _Structure _self;
  final $Res Function(_Structure) _then;

/// Create a copy of Structure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = freezed,Object? fromM = freezed,Object? toM = freezed,Object? lengthM = freezed,Object? structureSource = freezed,Object? method = freezed,}) {
  return _then(_Structure(
kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,lengthM: freezed == lengthM ? _self.lengthM : lengthM // ignore: cast_nullable_to_non_nullable
as double?,structureSource: freezed == structureSource ? _self.structureSource : structureSource // ignore: cast_nullable_to_non_nullable
as String?,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
