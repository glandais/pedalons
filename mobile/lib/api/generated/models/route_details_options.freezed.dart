// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_details_options.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteDetailsOptions {

 RouteDetailsProfile? get profile; List<RouteDetailsSection>? get sections; Sampling? get sampling; Elevation? get elevation;@JsonKey(name: 'accept_partial') bool? get acceptPartial;
/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteDetailsOptionsCopyWith<RouteDetailsOptions> get copyWith => _$RouteDetailsOptionsCopyWithImpl<RouteDetailsOptions>(this as RouteDetailsOptions, _$identity);

  /// Serializes this RouteDetailsOptions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteDetailsOptions;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteDetailsOptions&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&const DeepCollectionEquality().equals(other.sections, _this.sections)&&(identical(other.sampling, _this.sampling) || other.sampling == _this.sampling)&&(identical(other.elevation, _this.elevation) || other.elevation == _this.elevation)&&(identical(other.acceptPartial, _this.acceptPartial) || other.acceptPartial == _this.acceptPartial));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteDetailsOptions;
  return Object.hash(runtimeType,_this.profile,const DeepCollectionEquality().hash(_this.sections),_this.sampling,_this.elevation,_this.acceptPartial);
}

@override
String toString() {
  final _this = this as RouteDetailsOptions;
  return 'RouteDetailsOptions(profile: ${_this.profile}, sections: ${_this.sections}, sampling: ${_this.sampling}, elevation: ${_this.elevation}, acceptPartial: ${_this.acceptPartial})';
}


}

/// @nodoc
abstract mixin class $RouteDetailsOptionsCopyWith<$Res>  {
  factory $RouteDetailsOptionsCopyWith(RouteDetailsOptions value, $Res Function(RouteDetailsOptions) _then) = _$RouteDetailsOptionsCopyWithImpl;
@useResult
$Res call({
 RouteDetailsProfile? profile, List<RouteDetailsSection>? sections, Sampling? sampling, Elevation? elevation,@JsonKey(name: 'accept_partial') bool? acceptPartial
});


$SamplingCopyWith<$Res>? get sampling;$ElevationCopyWith<$Res>? get elevation;

}
/// @nodoc
class _$RouteDetailsOptionsCopyWithImpl<$Res>
    implements $RouteDetailsOptionsCopyWith<$Res> {
  _$RouteDetailsOptionsCopyWithImpl(this._self, this._then);

  final RouteDetailsOptions _self;
  final $Res Function(RouteDetailsOptions) _then;

/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profile = freezed,Object? sections = freezed,Object? sampling = freezed,Object? elevation = freezed,Object? acceptPartial = freezed,}) {
  return _then(RouteDetailsOptions(
profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as RouteDetailsProfile?,sections: freezed == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as List<RouteDetailsSection>?,sampling: freezed == sampling ? _self.sampling : sampling // ignore: cast_nullable_to_non_nullable
as Sampling?,elevation: freezed == elevation ? _self.elevation : elevation // ignore: cast_nullable_to_non_nullable
as Elevation?,acceptPartial: freezed == acceptPartial ? _self.acceptPartial : acceptPartial // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SamplingCopyWith<$Res>? get sampling {
    if (_self.sampling == null) {
    return null;
  }

  return $SamplingCopyWith<$Res>(_self.sampling!, (value) {
    return _then(_self.copyWith(sampling: value));
  });
}/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ElevationCopyWith<$Res>? get elevation {
    if (_self.elevation == null) {
    return null;
  }

  return $ElevationCopyWith<$Res>(_self.elevation!, (value) {
    return _then(_self.copyWith(elevation: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteDetailsOptions].
extension RouteDetailsOptionsPatterns on RouteDetailsOptions {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteDetailsOptions value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteDetailsOptions() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteDetailsOptions value)  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsOptions():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteDetailsOptions value)?  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsOptions() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RouteDetailsProfile? profile,  List<RouteDetailsSection>? sections,  Sampling? sampling,  Elevation? elevation, @JsonKey(name: 'accept_partial')  bool? acceptPartial)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteDetailsOptions() when $default != null:
return $default(_that.profile,_that.sections,_that.sampling,_that.elevation,_that.acceptPartial);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RouteDetailsProfile? profile,  List<RouteDetailsSection>? sections,  Sampling? sampling,  Elevation? elevation, @JsonKey(name: 'accept_partial')  bool? acceptPartial)  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsOptions():
return $default(_that.profile,_that.sections,_that.sampling,_that.elevation,_that.acceptPartial);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RouteDetailsProfile? profile,  List<RouteDetailsSection>? sections,  Sampling? sampling,  Elevation? elevation, @JsonKey(name: 'accept_partial')  bool? acceptPartial)?  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsOptions() when $default != null:
return $default(_that.profile,_that.sections,_that.sampling,_that.elevation,_that.acceptPartial);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteDetailsOptions implements RouteDetailsOptions {
  const _RouteDetailsOptions({this.profile,  List<RouteDetailsSection>? sections, this.sampling, this.elevation, @JsonKey(name: 'accept_partial') this.acceptPartial}): _sections = sections;
  factory _RouteDetailsOptions.fromJson(Map<String, dynamic> json) => _$RouteDetailsOptionsFromJson(json);

@override final  RouteDetailsProfile? profile;
 final  List<RouteDetailsSection>? _sections;
@override List<RouteDetailsSection>? get sections {
  final value = _sections;
  if (value == null) return null;
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  Sampling? sampling;
@override final  Elevation? elevation;
@override@JsonKey(name: 'accept_partial') final  bool? acceptPartial;

/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteDetailsOptionsCopyWith<_RouteDetailsOptions> get copyWith => __$RouteDetailsOptionsCopyWithImpl<_RouteDetailsOptions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteDetailsOptionsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteDetailsOptions&&(identical(other.profile, profile) || other.profile == profile)&&const DeepCollectionEquality().equals(other.sections, _sections)&&(identical(other.sampling, sampling) || other.sampling == sampling)&&(identical(other.elevation, elevation) || other.elevation == elevation)&&(identical(other.acceptPartial, acceptPartial) || other.acceptPartial == acceptPartial));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,profile,const DeepCollectionEquality().hash(_sections),sampling,elevation,acceptPartial);
}

@override
String toString() {
    return 'RouteDetailsOptions(profile: $profile, sections: $sections, sampling: $sampling, elevation: $elevation, acceptPartial: $acceptPartial)';
}


}

/// @nodoc
abstract mixin class _$RouteDetailsOptionsCopyWith<$Res> implements $RouteDetailsOptionsCopyWith<$Res> {
  factory _$RouteDetailsOptionsCopyWith(_RouteDetailsOptions value, $Res Function(_RouteDetailsOptions) _then) = __$RouteDetailsOptionsCopyWithImpl;
@override @useResult
$Res call({
 RouteDetailsProfile? profile, List<RouteDetailsSection>? sections, Sampling? sampling, Elevation? elevation,@JsonKey(name: 'accept_partial') bool? acceptPartial
});


@override $SamplingCopyWith<$Res>? get sampling;@override $ElevationCopyWith<$Res>? get elevation;

}
/// @nodoc
class __$RouteDetailsOptionsCopyWithImpl<$Res>
    implements _$RouteDetailsOptionsCopyWith<$Res> {
  __$RouteDetailsOptionsCopyWithImpl(this._self, this._then);

  final _RouteDetailsOptions _self;
  final $Res Function(_RouteDetailsOptions) _then;

/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profile = freezed,Object? sections = freezed,Object? sampling = freezed,Object? elevation = freezed,Object? acceptPartial = freezed,}) {
  return _then(_RouteDetailsOptions(
profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as RouteDetailsProfile?,sections: freezed == sections ? _self._sections : sections // ignore: cast_nullable_to_non_nullable
as List<RouteDetailsSection>?,sampling: freezed == sampling ? _self.sampling : sampling // ignore: cast_nullable_to_non_nullable
as Sampling?,elevation: freezed == elevation ? _self.elevation : elevation // ignore: cast_nullable_to_non_nullable
as Elevation?,acceptPartial: freezed == acceptPartial ? _self.acceptPartial : acceptPartial // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SamplingCopyWith<$Res>? get sampling {
    if (_self.sampling == null) {
    return null;
  }

  return $SamplingCopyWith<$Res>(_self.sampling!, (value) {
    return _then(_self.copyWith(sampling: value));
  });
}/// Create a copy of RouteDetailsOptions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ElevationCopyWith<$Res>? get elevation {
    if (_self.elevation == null) {
    return null;
  }

  return $ElevationCopyWith<$Res>(_self.elevation!, (value) {
    return _then(_self.copyWith(elevation: value));
  });
}
}

// dart format on
