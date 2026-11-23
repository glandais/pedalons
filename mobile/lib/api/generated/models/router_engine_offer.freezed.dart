// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'router_engine_offer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouterEngineOffer {

 RouterEngine get engine; List<RouterProfile> get profiles;/// What the engine really accepts beyond the profiles, from its capabilities: the screen shows a control only when its option is listed. Empty for STADIA.
 List<RouterEngineOption> get options;
/// Create a copy of RouterEngineOffer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouterEngineOfferCopyWith<RouterEngineOffer> get copyWith => _$RouterEngineOfferCopyWithImpl<RouterEngineOffer>(this as RouterEngineOffer, _$identity);

  /// Serializes this RouterEngineOffer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouterEngineOffer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouterEngineOffer&&(identical(other.engine, _this.engine) || other.engine == _this.engine)&&const DeepCollectionEquality().equals(other.profiles, _this.profiles)&&const DeepCollectionEquality().equals(other.options, _this.options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouterEngineOffer;
  return Object.hash(runtimeType,_this.engine,const DeepCollectionEquality().hash(_this.profiles),const DeepCollectionEquality().hash(_this.options));
}

@override
String toString() {
  final _this = this as RouterEngineOffer;
  return 'RouterEngineOffer(engine: ${_this.engine}, profiles: ${_this.profiles}, options: ${_this.options})';
}


}

/// @nodoc
abstract mixin class $RouterEngineOfferCopyWith<$Res>  {
  factory $RouterEngineOfferCopyWith(RouterEngineOffer value, $Res Function(RouterEngineOffer) _then) = _$RouterEngineOfferCopyWithImpl;
@useResult
$Res call({
 RouterEngine engine, List<RouterProfile> profiles, List<RouterEngineOption> options
});




}
/// @nodoc
class _$RouterEngineOfferCopyWithImpl<$Res>
    implements $RouterEngineOfferCopyWith<$Res> {
  _$RouterEngineOfferCopyWithImpl(this._self, this._then);

  final RouterEngineOffer _self;
  final $Res Function(RouterEngineOffer) _then;

/// Create a copy of RouterEngineOffer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? engine = null,Object? profiles = null,Object? options = null,}) {
  return _then(RouterEngineOffer(
engine: null == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as RouterEngine,profiles: null == profiles ? _self.profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<RouterProfile>,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<RouterEngineOption>,
  ));
}

}


/// Adds pattern-matching-related methods to [RouterEngineOffer].
extension RouterEngineOfferPatterns on RouterEngineOffer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouterEngineOffer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouterEngineOffer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouterEngineOffer value)  $default,){
final _that = this;
switch (_that) {
case _RouterEngineOffer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouterEngineOffer value)?  $default,){
final _that = this;
switch (_that) {
case _RouterEngineOffer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RouterEngine engine,  List<RouterProfile> profiles,  List<RouterEngineOption> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouterEngineOffer() when $default != null:
return $default(_that.engine,_that.profiles,_that.options);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RouterEngine engine,  List<RouterProfile> profiles,  List<RouterEngineOption> options)  $default,) {final _that = this;
switch (_that) {
case _RouterEngineOffer():
return $default(_that.engine,_that.profiles,_that.options);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RouterEngine engine,  List<RouterProfile> profiles,  List<RouterEngineOption> options)?  $default,) {final _that = this;
switch (_that) {
case _RouterEngineOffer() when $default != null:
return $default(_that.engine,_that.profiles,_that.options);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouterEngineOffer implements RouterEngineOffer {
  const _RouterEngineOffer({required this.engine, required  List<RouterProfile> profiles, required  List<RouterEngineOption> options}): _profiles = profiles,_options = options;
  factory _RouterEngineOffer.fromJson(Map<String, dynamic> json) => _$RouterEngineOfferFromJson(json);

@override final  RouterEngine engine;
 final  List<RouterProfile> _profiles;
@override List<RouterProfile> get profiles {
  if (_profiles is EqualUnmodifiableListView) return _profiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_profiles);
}

/// What the engine really accepts beyond the profiles, from its capabilities: the screen shows a control only when its option is listed. Empty for STADIA.
 final  List<RouterEngineOption> _options;
/// What the engine really accepts beyond the profiles, from its capabilities: the screen shows a control only when its option is listed. Empty for STADIA.
@override List<RouterEngineOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of RouterEngineOffer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouterEngineOfferCopyWith<_RouterEngineOffer> get copyWith => __$RouterEngineOfferCopyWithImpl<_RouterEngineOffer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouterEngineOfferToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouterEngineOffer&&(identical(other.engine, engine) || other.engine == engine)&&const DeepCollectionEquality().equals(other.profiles, _profiles)&&const DeepCollectionEquality().equals(other.options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,engine,const DeepCollectionEquality().hash(_profiles),const DeepCollectionEquality().hash(_options));
}

@override
String toString() {
    return 'RouterEngineOffer(engine: $engine, profiles: $profiles, options: $options)';
}


}

/// @nodoc
abstract mixin class _$RouterEngineOfferCopyWith<$Res> implements $RouterEngineOfferCopyWith<$Res> {
  factory _$RouterEngineOfferCopyWith(_RouterEngineOffer value, $Res Function(_RouterEngineOffer) _then) = __$RouterEngineOfferCopyWithImpl;
@override @useResult
$Res call({
 RouterEngine engine, List<RouterProfile> profiles, List<RouterEngineOption> options
});




}
/// @nodoc
class __$RouterEngineOfferCopyWithImpl<$Res>
    implements _$RouterEngineOfferCopyWith<$Res> {
  __$RouterEngineOfferCopyWithImpl(this._self, this._then);

  final _RouterEngineOffer _self;
  final $Res Function(_RouterEngineOffer) _then;

/// Create a copy of RouterEngineOffer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? engine = null,Object? profiles = null,Object? options = null,}) {
  return _then(_RouterEngineOffer(
engine: null == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as RouterEngine,profiles: null == profiles ? _self._profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<RouterProfile>,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<RouterEngineOption>,
  ));
}


}

// dart format on
