// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_member_limit_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamMemberLimitDetails {

/// Type
 String get type;/// Member cap of the team's tier
 int get limit;/// What was counted against the cap: active members, plus pending invitations when sending one
 int get current;
/// Create a copy of TeamMemberLimitDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamMemberLimitDetailsCopyWith<TeamMemberLimitDetails> get copyWith => _$TeamMemberLimitDetailsCopyWithImpl<TeamMemberLimitDetails>(this as TeamMemberLimitDetails, _$identity);

  /// Serializes this TeamMemberLimitDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamMemberLimitDetails;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamMemberLimitDetails&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.current, _this.current) || other.current == _this.current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamMemberLimitDetails;
  return Object.hash(runtimeType,_this.type,_this.limit,_this.current);
}

@override
String toString() {
  final _this = this as TeamMemberLimitDetails;
  return 'TeamMemberLimitDetails(type: ${_this.type}, limit: ${_this.limit}, current: ${_this.current})';
}


}

/// @nodoc
abstract mixin class $TeamMemberLimitDetailsCopyWith<$Res>  {
  factory $TeamMemberLimitDetailsCopyWith(TeamMemberLimitDetails value, $Res Function(TeamMemberLimitDetails) _then) = _$TeamMemberLimitDetailsCopyWithImpl;
@useResult
$Res call({
 String type, int limit, int current
});




}
/// @nodoc
class _$TeamMemberLimitDetailsCopyWithImpl<$Res>
    implements $TeamMemberLimitDetailsCopyWith<$Res> {
  _$TeamMemberLimitDetailsCopyWithImpl(this._self, this._then);

  final TeamMemberLimitDetails _self;
  final $Res Function(TeamMemberLimitDetails) _then;

/// Create a copy of TeamMemberLimitDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? limit = null,Object? current = null,}) {
  return _then(TeamMemberLimitDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TeamMemberLimitDetails].
extension TeamMemberLimitDetailsPatterns on TeamMemberLimitDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamMemberLimitDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamMemberLimitDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamMemberLimitDetails value)  $default,){
final _that = this;
switch (_that) {
case _TeamMemberLimitDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamMemberLimitDetails value)?  $default,){
final _that = this;
switch (_that) {
case _TeamMemberLimitDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  int limit,  int current)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamMemberLimitDetails() when $default != null:
return $default(_that.type,_that.limit,_that.current);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  int limit,  int current)  $default,) {final _that = this;
switch (_that) {
case _TeamMemberLimitDetails():
return $default(_that.type,_that.limit,_that.current);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  int limit,  int current)?  $default,) {final _that = this;
switch (_that) {
case _TeamMemberLimitDetails() when $default != null:
return $default(_that.type,_that.limit,_that.current);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamMemberLimitDetails implements TeamMemberLimitDetails {
  const _TeamMemberLimitDetails({required this.type, required this.limit, required this.current});
  factory _TeamMemberLimitDetails.fromJson(Map<String, dynamic> json) => _$TeamMemberLimitDetailsFromJson(json);

/// Type
@override final  String type;
/// Member cap of the team's tier
@override final  int limit;
/// What was counted against the cap: active members, plus pending invitations when sending one
@override final  int current;

/// Create a copy of TeamMemberLimitDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamMemberLimitDetailsCopyWith<_TeamMemberLimitDetails> get copyWith => __$TeamMemberLimitDetailsCopyWithImpl<_TeamMemberLimitDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamMemberLimitDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamMemberLimitDetails&&(identical(other.type, type) || other.type == type)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,limit,current);
}

@override
String toString() {
    return 'TeamMemberLimitDetails(type: $type, limit: $limit, current: $current)';
}


}

/// @nodoc
abstract mixin class _$TeamMemberLimitDetailsCopyWith<$Res> implements $TeamMemberLimitDetailsCopyWith<$Res> {
  factory _$TeamMemberLimitDetailsCopyWith(_TeamMemberLimitDetails value, $Res Function(_TeamMemberLimitDetails) _then) = __$TeamMemberLimitDetailsCopyWithImpl;
@override @useResult
$Res call({
 String type, int limit, int current
});




}
/// @nodoc
class __$TeamMemberLimitDetailsCopyWithImpl<$Res>
    implements _$TeamMemberLimitDetailsCopyWith<$Res> {
  __$TeamMemberLimitDetailsCopyWithImpl(this._self, this._then);

  final _TeamMemberLimitDetails _self;
  final $Res Function(_TeamMemberLimitDetails) _then;

/// Create a copy of TeamMemberLimitDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? limit = null,Object? current = null,}) {
  return _then(_TeamMemberLimitDetails(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
