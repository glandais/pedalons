// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_activation_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminActivationResponse {

/// One row per week and domain that has at least one sign-up; a week without any is absent
 List<AdminActivationWeekDto> get weeks;/// How many weeks back the rows go
 int get weeksBack;
/// Create a copy of AdminActivationResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminActivationResponseCopyWith<AdminActivationResponse> get copyWith => _$AdminActivationResponseCopyWithImpl<AdminActivationResponse>(this as AdminActivationResponse, _$identity);

  /// Serializes this AdminActivationResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminActivationResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminActivationResponse&&const DeepCollectionEquality().equals(other.weeks, _this.weeks)&&(identical(other.weeksBack, _this.weeksBack) || other.weeksBack == _this.weeksBack));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminActivationResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.weeks),_this.weeksBack);
}

@override
String toString() {
  final _this = this as AdminActivationResponse;
  return 'AdminActivationResponse(weeks: ${_this.weeks}, weeksBack: ${_this.weeksBack})';
}


}

/// @nodoc
abstract mixin class $AdminActivationResponseCopyWith<$Res>  {
  factory $AdminActivationResponseCopyWith(AdminActivationResponse value, $Res Function(AdminActivationResponse) _then) = _$AdminActivationResponseCopyWithImpl;
@useResult
$Res call({
 List<AdminActivationWeekDto> weeks, int weeksBack
});




}
/// @nodoc
class _$AdminActivationResponseCopyWithImpl<$Res>
    implements $AdminActivationResponseCopyWith<$Res> {
  _$AdminActivationResponseCopyWithImpl(this._self, this._then);

  final AdminActivationResponse _self;
  final $Res Function(AdminActivationResponse) _then;

/// Create a copy of AdminActivationResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? weeks = null,Object? weeksBack = null,}) {
  return _then(AdminActivationResponse(
weeks: null == weeks ? _self.weeks : weeks // ignore: cast_nullable_to_non_nullable
as List<AdminActivationWeekDto>,weeksBack: null == weeksBack ? _self.weeksBack : weeksBack // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminActivationResponse].
extension AdminActivationResponsePatterns on AdminActivationResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminActivationResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminActivationResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminActivationResponse value)  $default,){
final _that = this;
switch (_that) {
case _AdminActivationResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminActivationResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AdminActivationResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AdminActivationWeekDto> weeks,  int weeksBack)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminActivationResponse() when $default != null:
return $default(_that.weeks,_that.weeksBack);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AdminActivationWeekDto> weeks,  int weeksBack)  $default,) {final _that = this;
switch (_that) {
case _AdminActivationResponse():
return $default(_that.weeks,_that.weeksBack);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AdminActivationWeekDto> weeks,  int weeksBack)?  $default,) {final _that = this;
switch (_that) {
case _AdminActivationResponse() when $default != null:
return $default(_that.weeks,_that.weeksBack);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminActivationResponse implements AdminActivationResponse {
  const _AdminActivationResponse({required  List<AdminActivationWeekDto> weeks, required this.weeksBack}): _weeks = weeks;
  factory _AdminActivationResponse.fromJson(Map<String, dynamic> json) => _$AdminActivationResponseFromJson(json);

/// One row per week and domain that has at least one sign-up; a week without any is absent
 final  List<AdminActivationWeekDto> _weeks;
/// One row per week and domain that has at least one sign-up; a week without any is absent
@override List<AdminActivationWeekDto> get weeks {
  if (_weeks is EqualUnmodifiableListView) return _weeks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weeks);
}

/// How many weeks back the rows go
@override final  int weeksBack;

/// Create a copy of AdminActivationResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminActivationResponseCopyWith<_AdminActivationResponse> get copyWith => __$AdminActivationResponseCopyWithImpl<_AdminActivationResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminActivationResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminActivationResponse&&const DeepCollectionEquality().equals(other.weeks, _weeks)&&(identical(other.weeksBack, weeksBack) || other.weeksBack == weeksBack));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_weeks),weeksBack);
}

@override
String toString() {
    return 'AdminActivationResponse(weeks: $weeks, weeksBack: $weeksBack)';
}


}

/// @nodoc
abstract mixin class _$AdminActivationResponseCopyWith<$Res> implements $AdminActivationResponseCopyWith<$Res> {
  factory _$AdminActivationResponseCopyWith(_AdminActivationResponse value, $Res Function(_AdminActivationResponse) _then) = __$AdminActivationResponseCopyWithImpl;
@override @useResult
$Res call({
 List<AdminActivationWeekDto> weeks, int weeksBack
});




}
/// @nodoc
class __$AdminActivationResponseCopyWithImpl<$Res>
    implements _$AdminActivationResponseCopyWith<$Res> {
  __$AdminActivationResponseCopyWithImpl(this._self, this._then);

  final _AdminActivationResponse _self;
  final $Res Function(_AdminActivationResponse) _then;

/// Create a copy of AdminActivationResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? weeks = null,Object? weeksBack = null,}) {
  return _then(_AdminActivationResponse(
weeks: null == weeks ? _self._weeks : weeks // ignore: cast_nullable_to_non_nullable
as List<AdminActivationWeekDto>,weeksBack: null == weeksBack ? _self.weeksBack : weeksBack // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
