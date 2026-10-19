// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planner_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannerState {

 int get version; RouterProfile get profile; List<PlannerSource> get sources; List<PlannerJunction> get junctions; List<PlannerPiece> get pieces;
/// Create a copy of PlannerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannerStateCopyWith<PlannerState> get copyWith => _$PlannerStateCopyWithImpl<PlannerState>(this as PlannerState, _$identity);

  /// Serializes this PlannerState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlannerState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannerState&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&const DeepCollectionEquality().equals(other.sources, _this.sources)&&const DeepCollectionEquality().equals(other.junctions, _this.junctions)&&const DeepCollectionEquality().equals(other.pieces, _this.pieces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlannerState;
  return Object.hash(runtimeType,_this.version,_this.profile,const DeepCollectionEquality().hash(_this.sources),const DeepCollectionEquality().hash(_this.junctions),const DeepCollectionEquality().hash(_this.pieces));
}

@override
String toString() {
  final _this = this as PlannerState;
  return 'PlannerState(version: ${_this.version}, profile: ${_this.profile}, sources: ${_this.sources}, junctions: ${_this.junctions}, pieces: ${_this.pieces})';
}


}

/// @nodoc
abstract mixin class $PlannerStateCopyWith<$Res>  {
  factory $PlannerStateCopyWith(PlannerState value, $Res Function(PlannerState) _then) = _$PlannerStateCopyWithImpl;
@useResult
$Res call({
 int version, RouterProfile profile, List<PlannerSource> sources, List<PlannerJunction> junctions, List<PlannerPiece> pieces
});




}
/// @nodoc
class _$PlannerStateCopyWithImpl<$Res>
    implements $PlannerStateCopyWith<$Res> {
  _$PlannerStateCopyWithImpl(this._self, this._then);

  final PlannerState _self;
  final $Res Function(PlannerState) _then;

/// Create a copy of PlannerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? profile = null,Object? sources = null,Object? junctions = null,Object? pieces = null,}) {
  return _then(PlannerState(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as RouterProfile,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<PlannerSource>,junctions: null == junctions ? _self.junctions : junctions // ignore: cast_nullable_to_non_nullable
as List<PlannerJunction>,pieces: null == pieces ? _self.pieces : pieces // ignore: cast_nullable_to_non_nullable
as List<PlannerPiece>,
  ));
}

}


/// Adds pattern-matching-related methods to [PlannerState].
extension PlannerStatePatterns on PlannerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannerState value)  $default,){
final _that = this;
switch (_that) {
case _PlannerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannerState value)?  $default,){
final _that = this;
switch (_that) {
case _PlannerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  RouterProfile profile,  List<PlannerSource> sources,  List<PlannerJunction> junctions,  List<PlannerPiece> pieces)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannerState() when $default != null:
return $default(_that.version,_that.profile,_that.sources,_that.junctions,_that.pieces);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  RouterProfile profile,  List<PlannerSource> sources,  List<PlannerJunction> junctions,  List<PlannerPiece> pieces)  $default,) {final _that = this;
switch (_that) {
case _PlannerState():
return $default(_that.version,_that.profile,_that.sources,_that.junctions,_that.pieces);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  RouterProfile profile,  List<PlannerSource> sources,  List<PlannerJunction> junctions,  List<PlannerPiece> pieces)?  $default,) {final _that = this;
switch (_that) {
case _PlannerState() when $default != null:
return $default(_that.version,_that.profile,_that.sources,_that.junctions,_that.pieces);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannerState implements PlannerState {
  const _PlannerState({required this.version, required this.profile, required  List<PlannerSource> sources, required  List<PlannerJunction> junctions, required  List<PlannerPiece> pieces}): _sources = sources,_junctions = junctions,_pieces = pieces;
  factory _PlannerState.fromJson(Map<String, dynamic> json) => _$PlannerStateFromJson(json);

@override final  int version;
@override final  RouterProfile profile;
 final  List<PlannerSource> _sources;
@override List<PlannerSource> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

 final  List<PlannerJunction> _junctions;
@override List<PlannerJunction> get junctions {
  if (_junctions is EqualUnmodifiableListView) return _junctions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_junctions);
}

 final  List<PlannerPiece> _pieces;
@override List<PlannerPiece> get pieces {
  if (_pieces is EqualUnmodifiableListView) return _pieces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pieces);
}


/// Create a copy of PlannerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannerStateCopyWith<_PlannerState> get copyWith => __$PlannerStateCopyWithImpl<_PlannerState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannerStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannerState&&(identical(other.version, version) || other.version == version)&&(identical(other.profile, profile) || other.profile == profile)&&const DeepCollectionEquality().equals(other.sources, _sources)&&const DeepCollectionEquality().equals(other.junctions, _junctions)&&const DeepCollectionEquality().equals(other.pieces, _pieces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,profile,const DeepCollectionEquality().hash(_sources),const DeepCollectionEquality().hash(_junctions),const DeepCollectionEquality().hash(_pieces));
}

@override
String toString() {
    return 'PlannerState(version: $version, profile: $profile, sources: $sources, junctions: $junctions, pieces: $pieces)';
}


}

/// @nodoc
abstract mixin class _$PlannerStateCopyWith<$Res> implements $PlannerStateCopyWith<$Res> {
  factory _$PlannerStateCopyWith(_PlannerState value, $Res Function(_PlannerState) _then) = __$PlannerStateCopyWithImpl;
@override @useResult
$Res call({
 int version, RouterProfile profile, List<PlannerSource> sources, List<PlannerJunction> junctions, List<PlannerPiece> pieces
});




}
/// @nodoc
class __$PlannerStateCopyWithImpl<$Res>
    implements _$PlannerStateCopyWith<$Res> {
  __$PlannerStateCopyWithImpl(this._self, this._then);

  final _PlannerState _self;
  final $Res Function(_PlannerState) _then;

/// Create a copy of PlannerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? profile = null,Object? sources = null,Object? junctions = null,Object? pieces = null,}) {
  return _then(_PlannerState(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as RouterProfile,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<PlannerSource>,junctions: null == junctions ? _self._junctions : junctions // ignore: cast_nullable_to_non_nullable
as List<PlannerJunction>,pieces: null == pieces ? _self._pieces : pieces // ignore: cast_nullable_to_non_nullable
as List<PlannerPiece>,
  ));
}


}

// dart format on
