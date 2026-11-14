// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'paired_device_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PairedDeviceDto {

/// Pairing ID, to unpair the device
 String get id;/// Kind of device. OTHER for an external application: applicationName then names it
 String get type;/// When the device was paired
 String get pairedAt;/// For an access opened through OAuth, the name the application gave itself (client_id) — unverified. Absent for a device.
 String? get applicationName;/// When the device last renewed its access
 String? get lastUsedAt;
/// Create a copy of PairedDeviceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairedDeviceDtoCopyWith<PairedDeviceDto> get copyWith => _$PairedDeviceDtoCopyWithImpl<PairedDeviceDto>(this as PairedDeviceDto, _$identity);

  /// Serializes this PairedDeviceDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PairedDeviceDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairedDeviceDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.pairedAt, _this.pairedAt) || other.pairedAt == _this.pairedAt)&&(identical(other.applicationName, _this.applicationName) || other.applicationName == _this.applicationName)&&(identical(other.lastUsedAt, _this.lastUsedAt) || other.lastUsedAt == _this.lastUsedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PairedDeviceDto;
  return Object.hash(runtimeType,_this.id,_this.type,_this.pairedAt,_this.applicationName,_this.lastUsedAt);
}

@override
String toString() {
  final _this = this as PairedDeviceDto;
  return 'PairedDeviceDto(id: ${_this.id}, type: ${_this.type}, pairedAt: ${_this.pairedAt}, applicationName: ${_this.applicationName}, lastUsedAt: ${_this.lastUsedAt})';
}


}

/// @nodoc
abstract mixin class $PairedDeviceDtoCopyWith<$Res>  {
  factory $PairedDeviceDtoCopyWith(PairedDeviceDto value, $Res Function(PairedDeviceDto) _then) = _$PairedDeviceDtoCopyWithImpl;
@useResult
$Res call({
 String id, String type, String pairedAt, String? applicationName, String? lastUsedAt
});




}
/// @nodoc
class _$PairedDeviceDtoCopyWithImpl<$Res>
    implements $PairedDeviceDtoCopyWith<$Res> {
  _$PairedDeviceDtoCopyWithImpl(this._self, this._then);

  final PairedDeviceDto _self;
  final $Res Function(PairedDeviceDto) _then;

/// Create a copy of PairedDeviceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? pairedAt = null,Object? applicationName = freezed,Object? lastUsedAt = freezed,}) {
  return _then(PairedDeviceDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,pairedAt: null == pairedAt ? _self.pairedAt : pairedAt // ignore: cast_nullable_to_non_nullable
as String,applicationName: freezed == applicationName ? _self.applicationName : applicationName // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PairedDeviceDto].
extension PairedDeviceDtoPatterns on PairedDeviceDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PairedDeviceDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PairedDeviceDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PairedDeviceDto value)  $default,){
final _that = this;
switch (_that) {
case _PairedDeviceDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PairedDeviceDto value)?  $default,){
final _that = this;
switch (_that) {
case _PairedDeviceDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String pairedAt,  String? applicationName,  String? lastUsedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PairedDeviceDto() when $default != null:
return $default(_that.id,_that.type,_that.pairedAt,_that.applicationName,_that.lastUsedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String pairedAt,  String? applicationName,  String? lastUsedAt)  $default,) {final _that = this;
switch (_that) {
case _PairedDeviceDto():
return $default(_that.id,_that.type,_that.pairedAt,_that.applicationName,_that.lastUsedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String pairedAt,  String? applicationName,  String? lastUsedAt)?  $default,) {final _that = this;
switch (_that) {
case _PairedDeviceDto() when $default != null:
return $default(_that.id,_that.type,_that.pairedAt,_that.applicationName,_that.lastUsedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PairedDeviceDto implements PairedDeviceDto {
  const _PairedDeviceDto({required this.id, required this.type, required this.pairedAt, this.applicationName, this.lastUsedAt});
  factory _PairedDeviceDto.fromJson(Map<String, dynamic> json) => _$PairedDeviceDtoFromJson(json);

/// Pairing ID, to unpair the device
@override final  String id;
/// Kind of device. OTHER for an external application: applicationName then names it
@override final  String type;
/// When the device was paired
@override final  String pairedAt;
/// For an access opened through OAuth, the name the application gave itself (client_id) — unverified. Absent for a device.
@override final  String? applicationName;
/// When the device last renewed its access
@override final  String? lastUsedAt;

/// Create a copy of PairedDeviceDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PairedDeviceDtoCopyWith<_PairedDeviceDto> get copyWith => __$PairedDeviceDtoCopyWithImpl<_PairedDeviceDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PairedDeviceDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PairedDeviceDto&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.pairedAt, pairedAt) || other.pairedAt == pairedAt)&&(identical(other.applicationName, applicationName) || other.applicationName == applicationName)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,type,pairedAt,applicationName,lastUsedAt);
}

@override
String toString() {
    return 'PairedDeviceDto(id: $id, type: $type, pairedAt: $pairedAt, applicationName: $applicationName, lastUsedAt: $lastUsedAt)';
}


}

/// @nodoc
abstract mixin class _$PairedDeviceDtoCopyWith<$Res> implements $PairedDeviceDtoCopyWith<$Res> {
  factory _$PairedDeviceDtoCopyWith(_PairedDeviceDto value, $Res Function(_PairedDeviceDto) _then) = __$PairedDeviceDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String pairedAt, String? applicationName, String? lastUsedAt
});




}
/// @nodoc
class __$PairedDeviceDtoCopyWithImpl<$Res>
    implements _$PairedDeviceDtoCopyWith<$Res> {
  __$PairedDeviceDtoCopyWithImpl(this._self, this._then);

  final _PairedDeviceDto _self;
  final $Res Function(_PairedDeviceDto) _then;

/// Create a copy of PairedDeviceDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? pairedAt = null,Object? applicationName = freezed,Object? lastUsedAt = freezed,}) {
  return _then(_PairedDeviceDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,pairedAt: null == pairedAt ? _self.pairedAt : pairedAt // ignore: cast_nullable_to_non_nullable
as String,applicationName: freezed == applicationName ? _self.applicationName : applicationName // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
