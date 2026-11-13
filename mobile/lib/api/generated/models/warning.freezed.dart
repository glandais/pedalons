// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'warning.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Warning {

 String? get code; String? get message;@JsonKey(name: 'from_m') double? get fromM;@JsonKey(name: 'to_m') double? get toM;
/// Create a copy of Warning
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WarningCopyWith<Warning> get copyWith => _$WarningCopyWithImpl<Warning>(this as Warning, _$identity);

  /// Serializes this Warning to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Warning;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Warning&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.fromM, _this.fromM) || other.fromM == _this.fromM)&&(identical(other.toM, _this.toM) || other.toM == _this.toM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Warning;
  return Object.hash(runtimeType,_this.code,_this.message,_this.fromM,_this.toM);
}

@override
String toString() {
  final _this = this as Warning;
  return 'Warning(code: ${_this.code}, message: ${_this.message}, fromM: ${_this.fromM}, toM: ${_this.toM})';
}


}

/// @nodoc
abstract mixin class $WarningCopyWith<$Res>  {
  factory $WarningCopyWith(Warning value, $Res Function(Warning) _then) = _$WarningCopyWithImpl;
@useResult
$Res call({
 String? code, String? message,@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM
});




}
/// @nodoc
class _$WarningCopyWithImpl<$Res>
    implements $WarningCopyWith<$Res> {
  _$WarningCopyWithImpl(this._self, this._then);

  final Warning _self;
  final $Res Function(Warning) _then;

/// Create a copy of Warning
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = freezed,Object? message = freezed,Object? fromM = freezed,Object? toM = freezed,}) {
  return _then(Warning(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [Warning].
extension WarningPatterns on Warning {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Warning value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Warning() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Warning value)  $default,){
final _that = this;
switch (_that) {
case _Warning():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Warning value)?  $default,){
final _that = this;
switch (_that) {
case _Warning() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? code,  String? message, @JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Warning() when $default != null:
return $default(_that.code,_that.message,_that.fromM,_that.toM);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? code,  String? message, @JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM)  $default,) {final _that = this;
switch (_that) {
case _Warning():
return $default(_that.code,_that.message,_that.fromM,_that.toM);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? code,  String? message, @JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM)?  $default,) {final _that = this;
switch (_that) {
case _Warning() when $default != null:
return $default(_that.code,_that.message,_that.fromM,_that.toM);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Warning implements Warning {
  const _Warning({this.code, this.message, @JsonKey(name: 'from_m') this.fromM, @JsonKey(name: 'to_m') this.toM});
  factory _Warning.fromJson(Map<String, dynamic> json) => _$WarningFromJson(json);

@override final  String? code;
@override final  String? message;
@override@JsonKey(name: 'from_m') final  double? fromM;
@override@JsonKey(name: 'to_m') final  double? toM;

/// Create a copy of Warning
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WarningCopyWith<_Warning> get copyWith => __$WarningCopyWithImpl<_Warning>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WarningToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Warning&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.fromM, fromM) || other.fromM == fromM)&&(identical(other.toM, toM) || other.toM == toM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,message,fromM,toM);
}

@override
String toString() {
    return 'Warning(code: $code, message: $message, fromM: $fromM, toM: $toM)';
}


}

/// @nodoc
abstract mixin class _$WarningCopyWith<$Res> implements $WarningCopyWith<$Res> {
  factory _$WarningCopyWith(_Warning value, $Res Function(_Warning) _then) = __$WarningCopyWithImpl;
@override @useResult
$Res call({
 String? code, String? message,@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM
});




}
/// @nodoc
class __$WarningCopyWithImpl<$Res>
    implements _$WarningCopyWith<$Res> {
  __$WarningCopyWithImpl(this._self, this._then);

  final _Warning _self;
  final $Res Function(_Warning) _then;

/// Create a copy of Warning
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = freezed,Object? message = freezed,Object? fromM = freezed,Object? toM = freezed,}) {
  return _then(_Warning(
code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
