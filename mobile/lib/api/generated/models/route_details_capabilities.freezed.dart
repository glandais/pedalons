// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_details_capabilities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteDetailsCapabilities {

@JsonKey(name: 'api_version') String? get apiVersion; Limits? get limits; Enums? get enums; Data? get data;
/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteDetailsCapabilitiesCopyWith<RouteDetailsCapabilities> get copyWith => _$RouteDetailsCapabilitiesCopyWithImpl<RouteDetailsCapabilities>(this as RouteDetailsCapabilities, _$identity);

  /// Serializes this RouteDetailsCapabilities to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteDetailsCapabilities;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteDetailsCapabilities&&(identical(other.apiVersion, _this.apiVersion) || other.apiVersion == _this.apiVersion)&&(identical(other.limits, _this.limits) || other.limits == _this.limits)&&(identical(other.enums, _this.enums) || other.enums == _this.enums)&&(identical(other.data, _this.data) || other.data == _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteDetailsCapabilities;
  return Object.hash(runtimeType,_this.apiVersion,_this.limits,_this.enums,_this.data);
}

@override
String toString() {
  final _this = this as RouteDetailsCapabilities;
  return 'RouteDetailsCapabilities(apiVersion: ${_this.apiVersion}, limits: ${_this.limits}, enums: ${_this.enums}, data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $RouteDetailsCapabilitiesCopyWith<$Res>  {
  factory $RouteDetailsCapabilitiesCopyWith(RouteDetailsCapabilities value, $Res Function(RouteDetailsCapabilities) _then) = _$RouteDetailsCapabilitiesCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'api_version') String? apiVersion, Limits? limits, Enums? enums, Data? data
});


$LimitsCopyWith<$Res>? get limits;$EnumsCopyWith<$Res>? get enums;$DataCopyWith<$Res>? get data;

}
/// @nodoc
class _$RouteDetailsCapabilitiesCopyWithImpl<$Res>
    implements $RouteDetailsCapabilitiesCopyWith<$Res> {
  _$RouteDetailsCapabilitiesCopyWithImpl(this._self, this._then);

  final RouteDetailsCapabilities _self;
  final $Res Function(RouteDetailsCapabilities) _then;

/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiVersion = freezed,Object? limits = freezed,Object? enums = freezed,Object? data = freezed,}) {
  return _then(RouteDetailsCapabilities(
apiVersion: freezed == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String?,limits: freezed == limits ? _self.limits : limits // ignore: cast_nullable_to_non_nullable
as Limits?,enums: freezed == enums ? _self.enums : enums // ignore: cast_nullable_to_non_nullable
as Enums?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Data?,
  ));
}
/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LimitsCopyWith<$Res>? get limits {
    if (_self.limits == null) {
    return null;
  }

  return $LimitsCopyWith<$Res>(_self.limits!, (value) {
    return _then(_self.copyWith(limits: value));
  });
}/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EnumsCopyWith<$Res>? get enums {
    if (_self.enums == null) {
    return null;
  }

  return $EnumsCopyWith<$Res>(_self.enums!, (value) {
    return _then(_self.copyWith(enums: value));
  });
}/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DataCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $DataCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteDetailsCapabilities].
extension RouteDetailsCapabilitiesPatterns on RouteDetailsCapabilities {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteDetailsCapabilities value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteDetailsCapabilities() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteDetailsCapabilities value)  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsCapabilities():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteDetailsCapabilities value)?  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsCapabilities() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'api_version')  String? apiVersion,  Limits? limits,  Enums? enums,  Data? data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteDetailsCapabilities() when $default != null:
return $default(_that.apiVersion,_that.limits,_that.enums,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'api_version')  String? apiVersion,  Limits? limits,  Enums? enums,  Data? data)  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsCapabilities():
return $default(_that.apiVersion,_that.limits,_that.enums,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'api_version')  String? apiVersion,  Limits? limits,  Enums? enums,  Data? data)?  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsCapabilities() when $default != null:
return $default(_that.apiVersion,_that.limits,_that.enums,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteDetailsCapabilities implements RouteDetailsCapabilities {
  const _RouteDetailsCapabilities({@JsonKey(name: 'api_version') this.apiVersion, this.limits, this.enums, this.data});
  factory _RouteDetailsCapabilities.fromJson(Map<String, dynamic> json) => _$RouteDetailsCapabilitiesFromJson(json);

@override@JsonKey(name: 'api_version') final  String? apiVersion;
@override final  Limits? limits;
@override final  Enums? enums;
@override final  Data? data;

/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteDetailsCapabilitiesCopyWith<_RouteDetailsCapabilities> get copyWith => __$RouteDetailsCapabilitiesCopyWithImpl<_RouteDetailsCapabilities>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteDetailsCapabilitiesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteDetailsCapabilities&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&(identical(other.limits, limits) || other.limits == limits)&&(identical(other.enums, enums) || other.enums == enums)&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,apiVersion,limits,enums,data);
}

@override
String toString() {
    return 'RouteDetailsCapabilities(apiVersion: $apiVersion, limits: $limits, enums: $enums, data: $data)';
}


}

/// @nodoc
abstract mixin class _$RouteDetailsCapabilitiesCopyWith<$Res> implements $RouteDetailsCapabilitiesCopyWith<$Res> {
  factory _$RouteDetailsCapabilitiesCopyWith(_RouteDetailsCapabilities value, $Res Function(_RouteDetailsCapabilities) _then) = __$RouteDetailsCapabilitiesCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'api_version') String? apiVersion, Limits? limits, Enums? enums, Data? data
});


@override $LimitsCopyWith<$Res>? get limits;@override $EnumsCopyWith<$Res>? get enums;@override $DataCopyWith<$Res>? get data;

}
/// @nodoc
class __$RouteDetailsCapabilitiesCopyWithImpl<$Res>
    implements _$RouteDetailsCapabilitiesCopyWith<$Res> {
  __$RouteDetailsCapabilitiesCopyWithImpl(this._self, this._then);

  final _RouteDetailsCapabilities _self;
  final $Res Function(_RouteDetailsCapabilities) _then;

/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiVersion = freezed,Object? limits = freezed,Object? enums = freezed,Object? data = freezed,}) {
  return _then(_RouteDetailsCapabilities(
apiVersion: freezed == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String?,limits: freezed == limits ? _self.limits : limits // ignore: cast_nullable_to_non_nullable
as Limits?,enums: freezed == enums ? _self.enums : enums // ignore: cast_nullable_to_non_nullable
as Enums?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Data?,
  ));
}

/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LimitsCopyWith<$Res>? get limits {
    if (_self.limits == null) {
    return null;
  }

  return $LimitsCopyWith<$Res>(_self.limits!, (value) {
    return _then(_self.copyWith(limits: value));
  });
}/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EnumsCopyWith<$Res>? get enums {
    if (_self.enums == null) {
    return null;
  }

  return $EnumsCopyWith<$Res>(_self.enums!, (value) {
    return _then(_self.copyWith(enums: value));
  });
}/// Create a copy of RouteDetailsCapabilities
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DataCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $DataCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
