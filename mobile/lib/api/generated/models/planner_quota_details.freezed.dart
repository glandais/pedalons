// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'planner_quota_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlannerQuotaDetails {

/// Type
 String get type;/// TEAM: the team is on the free plan and its monthly saves are spent. PERSONAL: the caller is a member of no unlocked team and their monthly saves in the GPX tools are spent.
 String get scope;/// Saves of a drawn track allowed per calendar month
 int get limit;/// Saves already counted this month
 int get current;/// The day the count starts again: the first day of next month, in the team's zone for TEAM, in UTC for PERSONAL
 String get resetsOn;/// Name of the team, for TEAM only
 String? get teamName;
/// Create a copy of PlannerQuotaDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlannerQuotaDetailsCopyWith<PlannerQuotaDetails> get copyWith => _$PlannerQuotaDetailsCopyWithImpl<PlannerQuotaDetails>(this as PlannerQuotaDetails, _$identity);

  /// Serializes this PlannerQuotaDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PlannerQuotaDetails;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlannerQuotaDetails&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.current, _this.current) || other.current == _this.current)&&(identical(other.resetsOn, _this.resetsOn) || other.resetsOn == _this.resetsOn)&&(identical(other.teamName, _this.teamName) || other.teamName == _this.teamName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PlannerQuotaDetails;
  return Object.hash(runtimeType,_this.type,_this.scope,_this.limit,_this.current,_this.resetsOn,_this.teamName);
}

@override
String toString() {
  final _this = this as PlannerQuotaDetails;
  return 'PlannerQuotaDetails(type: ${_this.type}, scope: ${_this.scope}, limit: ${_this.limit}, current: ${_this.current}, resetsOn: ${_this.resetsOn}, teamName: ${_this.teamName})';
}


}

/// @nodoc
abstract mixin class $PlannerQuotaDetailsCopyWith<$Res>  {
  factory $PlannerQuotaDetailsCopyWith(PlannerQuotaDetails value, $Res Function(PlannerQuotaDetails) _then) = _$PlannerQuotaDetailsCopyWithImpl;
@useResult
$Res call({
 String type, String scope, int limit, int current, String resetsOn, String? teamName
});




}
/// @nodoc
class _$PlannerQuotaDetailsCopyWithImpl<$Res>
    implements $PlannerQuotaDetailsCopyWith<$Res> {
  _$PlannerQuotaDetailsCopyWithImpl(this._self, this._then);

  final PlannerQuotaDetails _self;
  final $Res Function(PlannerQuotaDetails) _then;

/// Create a copy of PlannerQuotaDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? scope = null,Object? limit = null,Object? current = null,Object? resetsOn = null,Object? teamName = freezed,}) {
  return _then(PlannerQuotaDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,resetsOn: null == resetsOn ? _self.resetsOn : resetsOn // ignore: cast_nullable_to_non_nullable
as String,teamName: freezed == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlannerQuotaDetails].
extension PlannerQuotaDetailsPatterns on PlannerQuotaDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlannerQuotaDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlannerQuotaDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlannerQuotaDetails value)  $default,){
final _that = this;
switch (_that) {
case _PlannerQuotaDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlannerQuotaDetails value)?  $default,){
final _that = this;
switch (_that) {
case _PlannerQuotaDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String scope,  int limit,  int current,  String resetsOn,  String? teamName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlannerQuotaDetails() when $default != null:
return $default(_that.type,_that.scope,_that.limit,_that.current,_that.resetsOn,_that.teamName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String scope,  int limit,  int current,  String resetsOn,  String? teamName)  $default,) {final _that = this;
switch (_that) {
case _PlannerQuotaDetails():
return $default(_that.type,_that.scope,_that.limit,_that.current,_that.resetsOn,_that.teamName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String scope,  int limit,  int current,  String resetsOn,  String? teamName)?  $default,) {final _that = this;
switch (_that) {
case _PlannerQuotaDetails() when $default != null:
return $default(_that.type,_that.scope,_that.limit,_that.current,_that.resetsOn,_that.teamName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlannerQuotaDetails implements PlannerQuotaDetails {
  const _PlannerQuotaDetails({required this.type, required this.scope, required this.limit, required this.current, required this.resetsOn, this.teamName});
  factory _PlannerQuotaDetails.fromJson(Map<String, dynamic> json) => _$PlannerQuotaDetailsFromJson(json);

/// Type
@override final  String type;
/// TEAM: the team is on the free plan and its monthly saves are spent. PERSONAL: the caller is a member of no unlocked team and their monthly saves in the GPX tools are spent.
@override final  String scope;
/// Saves of a drawn track allowed per calendar month
@override final  int limit;
/// Saves already counted this month
@override final  int current;
/// The day the count starts again: the first day of next month, in the team's zone for TEAM, in UTC for PERSONAL
@override final  String resetsOn;
/// Name of the team, for TEAM only
@override final  String? teamName;

/// Create a copy of PlannerQuotaDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlannerQuotaDetailsCopyWith<_PlannerQuotaDetails> get copyWith => __$PlannerQuotaDetailsCopyWithImpl<_PlannerQuotaDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlannerQuotaDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlannerQuotaDetails&&(identical(other.type, type) || other.type == type)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.current, current) || other.current == current)&&(identical(other.resetsOn, resetsOn) || other.resetsOn == resetsOn)&&(identical(other.teamName, teamName) || other.teamName == teamName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,scope,limit,current,resetsOn,teamName);
}

@override
String toString() {
    return 'PlannerQuotaDetails(type: $type, scope: $scope, limit: $limit, current: $current, resetsOn: $resetsOn, teamName: $teamName)';
}


}

/// @nodoc
abstract mixin class _$PlannerQuotaDetailsCopyWith<$Res> implements $PlannerQuotaDetailsCopyWith<$Res> {
  factory _$PlannerQuotaDetailsCopyWith(_PlannerQuotaDetails value, $Res Function(_PlannerQuotaDetails) _then) = __$PlannerQuotaDetailsCopyWithImpl;
@override @useResult
$Res call({
 String type, String scope, int limit, int current, String resetsOn, String? teamName
});




}
/// @nodoc
class __$PlannerQuotaDetailsCopyWithImpl<$Res>
    implements _$PlannerQuotaDetailsCopyWith<$Res> {
  __$PlannerQuotaDetailsCopyWithImpl(this._self, this._then);

  final _PlannerQuotaDetails _self;
  final $Res Function(_PlannerQuotaDetails) _then;

/// Create a copy of PlannerQuotaDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? scope = null,Object? limit = null,Object? current = null,Object? resetsOn = null,Object? teamName = freezed,}) {
  return _then(_PlannerQuotaDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,resetsOn: null == resetsOn ? _self.resetsOn : resetsOn // ignore: cast_nullable_to_non_nullable
as String,teamName: freezed == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
