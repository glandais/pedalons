// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'retouched_span_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RetouchedSpanDto {

/// Where on the ORIGINAL route, in metres from its start, the replaced stretch begins
 double get fromM;/// Where on the original route the replaced stretch ends; its length for MOVE_END and TRUNCATE (the rest is dropped)
 double get toM;/// Length of the new stretch in metres, 0 for TRUNCATE
 double get newM;/// Index in the polyline of the first point of the new stretch (up to it the polyline is the original route)
 int get startIndex;/// Index in the polyline of the last point of the new stretch
 int get endIndex;/// Share of the new stretch on the team's roads, 0 to 1 (measured on that stretch alone)
 double get teamShare;/// Share of the new stretch off pavement, 0 to 1 (as the route page)
 double get unpavedShare;/// Junctions the new stretch crosses more than once
 int get crossings;
/// Create a copy of RetouchedSpanDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RetouchedSpanDtoCopyWith<RetouchedSpanDto> get copyWith => _$RetouchedSpanDtoCopyWithImpl<RetouchedSpanDto>(this as RetouchedSpanDto, _$identity);

  /// Serializes this RetouchedSpanDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RetouchedSpanDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RetouchedSpanDto&&(identical(other.fromM, _this.fromM) || other.fromM == _this.fromM)&&(identical(other.toM, _this.toM) || other.toM == _this.toM)&&(identical(other.newM, _this.newM) || other.newM == _this.newM)&&(identical(other.startIndex, _this.startIndex) || other.startIndex == _this.startIndex)&&(identical(other.endIndex, _this.endIndex) || other.endIndex == _this.endIndex)&&(identical(other.teamShare, _this.teamShare) || other.teamShare == _this.teamShare)&&(identical(other.unpavedShare, _this.unpavedShare) || other.unpavedShare == _this.unpavedShare)&&(identical(other.crossings, _this.crossings) || other.crossings == _this.crossings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RetouchedSpanDto;
  return Object.hash(runtimeType,_this.fromM,_this.toM,_this.newM,_this.startIndex,_this.endIndex,_this.teamShare,_this.unpavedShare,_this.crossings);
}

@override
String toString() {
  final _this = this as RetouchedSpanDto;
  return 'RetouchedSpanDto(fromM: ${_this.fromM}, toM: ${_this.toM}, newM: ${_this.newM}, startIndex: ${_this.startIndex}, endIndex: ${_this.endIndex}, teamShare: ${_this.teamShare}, unpavedShare: ${_this.unpavedShare}, crossings: ${_this.crossings})';
}


}

/// @nodoc
abstract mixin class $RetouchedSpanDtoCopyWith<$Res>  {
  factory $RetouchedSpanDtoCopyWith(RetouchedSpanDto value, $Res Function(RetouchedSpanDto) _then) = _$RetouchedSpanDtoCopyWithImpl;
@useResult
$Res call({
 double fromM, double toM, double newM, int startIndex, int endIndex, double teamShare, double unpavedShare, int crossings
});




}
/// @nodoc
class _$RetouchedSpanDtoCopyWithImpl<$Res>
    implements $RetouchedSpanDtoCopyWith<$Res> {
  _$RetouchedSpanDtoCopyWithImpl(this._self, this._then);

  final RetouchedSpanDto _self;
  final $Res Function(RetouchedSpanDto) _then;

/// Create a copy of RetouchedSpanDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromM = null,Object? toM = null,Object? newM = null,Object? startIndex = null,Object? endIndex = null,Object? teamShare = null,Object? unpavedShare = null,Object? crossings = null,}) {
  return _then(RetouchedSpanDto(
fromM: null == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double,toM: null == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double,newM: null == newM ? _self.newM : newM // ignore: cast_nullable_to_non_nullable
as double,startIndex: null == startIndex ? _self.startIndex : startIndex // ignore: cast_nullable_to_non_nullable
as int,endIndex: null == endIndex ? _self.endIndex : endIndex // ignore: cast_nullable_to_non_nullable
as int,teamShare: null == teamShare ? _self.teamShare : teamShare // ignore: cast_nullable_to_non_nullable
as double,unpavedShare: null == unpavedShare ? _self.unpavedShare : unpavedShare // ignore: cast_nullable_to_non_nullable
as double,crossings: null == crossings ? _self.crossings : crossings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RetouchedSpanDto].
extension RetouchedSpanDtoPatterns on RetouchedSpanDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RetouchedSpanDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RetouchedSpanDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RetouchedSpanDto value)  $default,){
final _that = this;
switch (_that) {
case _RetouchedSpanDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RetouchedSpanDto value)?  $default,){
final _that = this;
switch (_that) {
case _RetouchedSpanDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double fromM,  double toM,  double newM,  int startIndex,  int endIndex,  double teamShare,  double unpavedShare,  int crossings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RetouchedSpanDto() when $default != null:
return $default(_that.fromM,_that.toM,_that.newM,_that.startIndex,_that.endIndex,_that.teamShare,_that.unpavedShare,_that.crossings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double fromM,  double toM,  double newM,  int startIndex,  int endIndex,  double teamShare,  double unpavedShare,  int crossings)  $default,) {final _that = this;
switch (_that) {
case _RetouchedSpanDto():
return $default(_that.fromM,_that.toM,_that.newM,_that.startIndex,_that.endIndex,_that.teamShare,_that.unpavedShare,_that.crossings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double fromM,  double toM,  double newM,  int startIndex,  int endIndex,  double teamShare,  double unpavedShare,  int crossings)?  $default,) {final _that = this;
switch (_that) {
case _RetouchedSpanDto() when $default != null:
return $default(_that.fromM,_that.toM,_that.newM,_that.startIndex,_that.endIndex,_that.teamShare,_that.unpavedShare,_that.crossings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RetouchedSpanDto implements RetouchedSpanDto {
  const _RetouchedSpanDto({required this.fromM, required this.toM, required this.newM, required this.startIndex, required this.endIndex, required this.teamShare, required this.unpavedShare, required this.crossings});
  factory _RetouchedSpanDto.fromJson(Map<String, dynamic> json) => _$RetouchedSpanDtoFromJson(json);

/// Where on the ORIGINAL route, in metres from its start, the replaced stretch begins
@override final  double fromM;
/// Where on the original route the replaced stretch ends; its length for MOVE_END and TRUNCATE (the rest is dropped)
@override final  double toM;
/// Length of the new stretch in metres, 0 for TRUNCATE
@override final  double newM;
/// Index in the polyline of the first point of the new stretch (up to it the polyline is the original route)
@override final  int startIndex;
/// Index in the polyline of the last point of the new stretch
@override final  int endIndex;
/// Share of the new stretch on the team's roads, 0 to 1 (measured on that stretch alone)
@override final  double teamShare;
/// Share of the new stretch off pavement, 0 to 1 (as the route page)
@override final  double unpavedShare;
/// Junctions the new stretch crosses more than once
@override final  int crossings;

/// Create a copy of RetouchedSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RetouchedSpanDtoCopyWith<_RetouchedSpanDto> get copyWith => __$RetouchedSpanDtoCopyWithImpl<_RetouchedSpanDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RetouchedSpanDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RetouchedSpanDto&&(identical(other.fromM, fromM) || other.fromM == fromM)&&(identical(other.toM, toM) || other.toM == toM)&&(identical(other.newM, newM) || other.newM == newM)&&(identical(other.startIndex, startIndex) || other.startIndex == startIndex)&&(identical(other.endIndex, endIndex) || other.endIndex == endIndex)&&(identical(other.teamShare, teamShare) || other.teamShare == teamShare)&&(identical(other.unpavedShare, unpavedShare) || other.unpavedShare == unpavedShare)&&(identical(other.crossings, crossings) || other.crossings == crossings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fromM,toM,newM,startIndex,endIndex,teamShare,unpavedShare,crossings);
}

@override
String toString() {
    return 'RetouchedSpanDto(fromM: $fromM, toM: $toM, newM: $newM, startIndex: $startIndex, endIndex: $endIndex, teamShare: $teamShare, unpavedShare: $unpavedShare, crossings: $crossings)';
}


}

/// @nodoc
abstract mixin class _$RetouchedSpanDtoCopyWith<$Res> implements $RetouchedSpanDtoCopyWith<$Res> {
  factory _$RetouchedSpanDtoCopyWith(_RetouchedSpanDto value, $Res Function(_RetouchedSpanDto) _then) = __$RetouchedSpanDtoCopyWithImpl;
@override @useResult
$Res call({
 double fromM, double toM, double newM, int startIndex, int endIndex, double teamShare, double unpavedShare, int crossings
});




}
/// @nodoc
class __$RetouchedSpanDtoCopyWithImpl<$Res>
    implements _$RetouchedSpanDtoCopyWith<$Res> {
  __$RetouchedSpanDtoCopyWithImpl(this._self, this._then);

  final _RetouchedSpanDto _self;
  final $Res Function(_RetouchedSpanDto) _then;

/// Create a copy of RetouchedSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fromM = null,Object? toM = null,Object? newM = null,Object? startIndex = null,Object? endIndex = null,Object? teamShare = null,Object? unpavedShare = null,Object? crossings = null,}) {
  return _then(_RetouchedSpanDto(
fromM: null == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double,toM: null == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double,newM: null == newM ? _self.newM : newM // ignore: cast_nullable_to_non_nullable
as double,startIndex: null == startIndex ? _self.startIndex : startIndex // ignore: cast_nullable_to_non_nullable
as int,endIndex: null == endIndex ? _self.endIndex : endIndex // ignore: cast_nullable_to_non_nullable
as int,teamShare: null == teamShare ? _self.teamShare : teamShare // ignore: cast_nullable_to_non_nullable
as double,unpavedShare: null == unpavedShare ? _self.unpavedShare : unpavedShare // ignore: cast_nullable_to_non_nullable
as double,crossings: null == crossings ? _self.crossings : crossings // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
