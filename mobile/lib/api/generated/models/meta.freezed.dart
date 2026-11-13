// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meta.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Meta {

@JsonKey(name: 'api_version') String? get apiVersion;@JsonKey(name: 'rules_version') String? get rulesVersion; String? get profile;@JsonKey(name: 'data_versions') JsonNode? get dataVersions;
/// Create a copy of Meta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetaCopyWith<Meta> get copyWith => _$MetaCopyWithImpl<Meta>(this as Meta, _$identity);

  /// Serializes this Meta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Meta;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Meta&&(identical(other.apiVersion, _this.apiVersion) || other.apiVersion == _this.apiVersion)&&(identical(other.rulesVersion, _this.rulesVersion) || other.rulesVersion == _this.rulesVersion)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&(identical(other.dataVersions, _this.dataVersions) || other.dataVersions == _this.dataVersions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Meta;
  return Object.hash(runtimeType,_this.apiVersion,_this.rulesVersion,_this.profile,_this.dataVersions);
}

@override
String toString() {
  final _this = this as Meta;
  return 'Meta(apiVersion: ${_this.apiVersion}, rulesVersion: ${_this.rulesVersion}, profile: ${_this.profile}, dataVersions: ${_this.dataVersions})';
}


}

/// @nodoc
abstract mixin class $MetaCopyWith<$Res>  {
  factory $MetaCopyWith(Meta value, $Res Function(Meta) _then) = _$MetaCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'api_version') String? apiVersion,@JsonKey(name: 'rules_version') String? rulesVersion, String? profile,@JsonKey(name: 'data_versions') JsonNode? dataVersions
});


$JsonNodeCopyWith<$Res>? get dataVersions;

}
/// @nodoc
class _$MetaCopyWithImpl<$Res>
    implements $MetaCopyWith<$Res> {
  _$MetaCopyWithImpl(this._self, this._then);

  final Meta _self;
  final $Res Function(Meta) _then;

/// Create a copy of Meta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiVersion = freezed,Object? rulesVersion = freezed,Object? profile = freezed,Object? dataVersions = freezed,}) {
  return _then(Meta(
apiVersion: freezed == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String?,rulesVersion: freezed == rulesVersion ? _self.rulesVersion : rulesVersion // ignore: cast_nullable_to_non_nullable
as String?,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as String?,dataVersions: freezed == dataVersions ? _self.dataVersions : dataVersions // ignore: cast_nullable_to_non_nullable
as JsonNode?,
  ));
}
/// Create a copy of Meta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JsonNodeCopyWith<$Res>? get dataVersions {
    if (_self.dataVersions == null) {
    return null;
  }

  return $JsonNodeCopyWith<$Res>(_self.dataVersions!, (value) {
    return _then(_self.copyWith(dataVersions: value));
  });
}
}


/// Adds pattern-matching-related methods to [Meta].
extension MetaPatterns on Meta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Meta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Meta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Meta value)  $default,){
final _that = this;
switch (_that) {
case _Meta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Meta value)?  $default,){
final _that = this;
switch (_that) {
case _Meta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'api_version')  String? apiVersion, @JsonKey(name: 'rules_version')  String? rulesVersion,  String? profile, @JsonKey(name: 'data_versions')  JsonNode? dataVersions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Meta() when $default != null:
return $default(_that.apiVersion,_that.rulesVersion,_that.profile,_that.dataVersions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'api_version')  String? apiVersion, @JsonKey(name: 'rules_version')  String? rulesVersion,  String? profile, @JsonKey(name: 'data_versions')  JsonNode? dataVersions)  $default,) {final _that = this;
switch (_that) {
case _Meta():
return $default(_that.apiVersion,_that.rulesVersion,_that.profile,_that.dataVersions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'api_version')  String? apiVersion, @JsonKey(name: 'rules_version')  String? rulesVersion,  String? profile, @JsonKey(name: 'data_versions')  JsonNode? dataVersions)?  $default,) {final _that = this;
switch (_that) {
case _Meta() when $default != null:
return $default(_that.apiVersion,_that.rulesVersion,_that.profile,_that.dataVersions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Meta implements Meta {
  const _Meta({@JsonKey(name: 'api_version') this.apiVersion, @JsonKey(name: 'rules_version') this.rulesVersion, this.profile, @JsonKey(name: 'data_versions') this.dataVersions});
  factory _Meta.fromJson(Map<String, dynamic> json) => _$MetaFromJson(json);

@override@JsonKey(name: 'api_version') final  String? apiVersion;
@override@JsonKey(name: 'rules_version') final  String? rulesVersion;
@override final  String? profile;
@override@JsonKey(name: 'data_versions') final  JsonNode? dataVersions;

/// Create a copy of Meta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetaCopyWith<_Meta> get copyWith => __$MetaCopyWithImpl<_Meta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Meta&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&(identical(other.rulesVersion, rulesVersion) || other.rulesVersion == rulesVersion)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.dataVersions, dataVersions) || other.dataVersions == dataVersions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,apiVersion,rulesVersion,profile,dataVersions);
}

@override
String toString() {
    return 'Meta(apiVersion: $apiVersion, rulesVersion: $rulesVersion, profile: $profile, dataVersions: $dataVersions)';
}


}

/// @nodoc
abstract mixin class _$MetaCopyWith<$Res> implements $MetaCopyWith<$Res> {
  factory _$MetaCopyWith(_Meta value, $Res Function(_Meta) _then) = __$MetaCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'api_version') String? apiVersion,@JsonKey(name: 'rules_version') String? rulesVersion, String? profile,@JsonKey(name: 'data_versions') JsonNode? dataVersions
});


@override $JsonNodeCopyWith<$Res>? get dataVersions;

}
/// @nodoc
class __$MetaCopyWithImpl<$Res>
    implements _$MetaCopyWith<$Res> {
  __$MetaCopyWithImpl(this._self, this._then);

  final _Meta _self;
  final $Res Function(_Meta) _then;

/// Create a copy of Meta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiVersion = freezed,Object? rulesVersion = freezed,Object? profile = freezed,Object? dataVersions = freezed,}) {
  return _then(_Meta(
apiVersion: freezed == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String?,rulesVersion: freezed == rulesVersion ? _self.rulesVersion : rulesVersion // ignore: cast_nullable_to_non_nullable
as String?,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as String?,dataVersions: freezed == dataVersions ? _self.dataVersions : dataVersions // ignore: cast_nullable_to_non_nullable
as JsonNode?,
  ));
}

/// Create a copy of Meta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JsonNodeCopyWith<$Res>? get dataVersions {
    if (_self.dataVersions == null) {
    return null;
  }

  return $JsonNodeCopyWith<$Res>(_self.dataVersions!, (value) {
    return _then(_self.copyWith(dataVersions: value));
  });
}
}

// dart format on
