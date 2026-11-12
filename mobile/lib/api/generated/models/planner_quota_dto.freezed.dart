// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planner_quota_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannerQuotaDto {

/// Saves of a drawn track counted this month
 int get used;/// The day the count starts again: the first day of next month, in the team's zone for a team, in UTC for the personal quota
 String get resetsOn;/// Saves of a drawn track allowed per calendar month; null when unlimited
 int? get limit;
/// Create a copy of PlannerQuotaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannerQuotaDtoCopyWith<PlannerQuotaDto> get copyWith => _$PlannerQuotaDtoCopyWithImpl<PlannerQuotaDto>(this as PlannerQuotaDto, _$identity);

  /// Serializes this PlannerQuotaDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlannerQuotaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannerQuotaDto&&(identical(other.used, _this.used) || other.used == _this.used)&&(identical(other.resetsOn, _this.resetsOn) || other.resetsOn == _this.resetsOn)&&(identical(other.limit, _this.limit) || other.limit == _this.limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlannerQuotaDto;
  return Object.hash(runtimeType,_this.used,_this.resetsOn,_this.limit);
}

@override
String toString() {
  final _this = this as PlannerQuotaDto;
  return 'PlannerQuotaDto(used: ${_this.used}, resetsOn: ${_this.resetsOn}, limit: ${_this.limit})';
}


}

/// @nodoc
abstract mixin class $PlannerQuotaDtoCopyWith<$Res>  {
  factory $PlannerQuotaDtoCopyWith(PlannerQuotaDto value, $Res Function(PlannerQuotaDto) _then) = _$PlannerQuotaDtoCopyWithImpl;
@useResult
$Res call({
 int used, String resetsOn, int? limit
});




}
/// @nodoc
class _$PlannerQuotaDtoCopyWithImpl<$Res>
    implements $PlannerQuotaDtoCopyWith<$Res> {
  _$PlannerQuotaDtoCopyWithImpl(this._self, this._then);

  final PlannerQuotaDto _self;
  final $Res Function(PlannerQuotaDto) _then;

/// Create a copy of PlannerQuotaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? used = null,Object? resetsOn = null,Object? limit = freezed,}) {
  return _then(PlannerQuotaDto(
used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,resetsOn: null == resetsOn ? _self.resetsOn : resetsOn // ignore: cast_nullable_to_non_nullable
as String,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlannerQuotaDto].
extension PlannerQuotaDtoPatterns on PlannerQuotaDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannerQuotaDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannerQuotaDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannerQuotaDto value)  $default,){
final _that = this;
switch (_that) {
case _PlannerQuotaDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannerQuotaDto value)?  $default,){
final _that = this;
switch (_that) {
case _PlannerQuotaDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int used,  String resetsOn,  int? limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannerQuotaDto() when $default != null:
return $default(_that.used,_that.resetsOn,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int used,  String resetsOn,  int? limit)  $default,) {final _that = this;
switch (_that) {
case _PlannerQuotaDto():
return $default(_that.used,_that.resetsOn,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int used,  String resetsOn,  int? limit)?  $default,) {final _that = this;
switch (_that) {
case _PlannerQuotaDto() when $default != null:
return $default(_that.used,_that.resetsOn,_that.limit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannerQuotaDto implements PlannerQuotaDto {
  const _PlannerQuotaDto({required this.used, required this.resetsOn, this.limit});
  factory _PlannerQuotaDto.fromJson(Map<String, dynamic> json) => _$PlannerQuotaDtoFromJson(json);

/// Saves of a drawn track counted this month
@override final  int used;
/// The day the count starts again: the first day of next month, in the team's zone for a team, in UTC for the personal quota
@override final  String resetsOn;
/// Saves of a drawn track allowed per calendar month; null when unlimited
@override final  int? limit;

/// Create a copy of PlannerQuotaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannerQuotaDtoCopyWith<_PlannerQuotaDto> get copyWith => __$PlannerQuotaDtoCopyWithImpl<_PlannerQuotaDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannerQuotaDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannerQuotaDto&&(identical(other.used, used) || other.used == used)&&(identical(other.resetsOn, resetsOn) || other.resetsOn == resetsOn)&&(identical(other.limit, limit) || other.limit == limit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,used,resetsOn,limit);
}

@override
String toString() {
    return 'PlannerQuotaDto(used: $used, resetsOn: $resetsOn, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$PlannerQuotaDtoCopyWith<$Res> implements $PlannerQuotaDtoCopyWith<$Res> {
  factory _$PlannerQuotaDtoCopyWith(_PlannerQuotaDto value, $Res Function(_PlannerQuotaDto) _then) = __$PlannerQuotaDtoCopyWithImpl;
@override @useResult
$Res call({
 int used, String resetsOn, int? limit
});




}
/// @nodoc
class __$PlannerQuotaDtoCopyWithImpl<$Res>
    implements _$PlannerQuotaDtoCopyWith<$Res> {
  __$PlannerQuotaDtoCopyWithImpl(this._self, this._then);

  final _PlannerQuotaDto _self;
  final $Res Function(_PlannerQuotaDto) _then;

/// Create a copy of PlannerQuotaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? used = null,Object? resetsOn = null,Object? limit = freezed,}) {
  return _then(_PlannerQuotaDto(
used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,resetsOn: null == resetsOn ? _self.resetsOn : resetsOn // ignore: cast_nullable_to_non_nullable
as String,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
