// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'unpaved_span.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UnpavedSpan {

 int get from; int get to;
/// Create a copy of UnpavedSpan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnpavedSpanCopyWith<UnpavedSpan> get copyWith => _$UnpavedSpanCopyWithImpl<UnpavedSpan>(this as UnpavedSpan, _$identity);

  /// Serializes this UnpavedSpan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UnpavedSpan;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnpavedSpan&&(identical(other.from, _this.from) || other.from == _this.from)&&(identical(other.to, _this.to) || other.to == _this.to));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UnpavedSpan;
  return Object.hash(runtimeType,_this.from,_this.to);
}

@override
String toString() {
  final _this = this as UnpavedSpan;
  return 'UnpavedSpan(from: ${_this.from}, to: ${_this.to})';
}


}

/// @nodoc
abstract mixin class $UnpavedSpanCopyWith<$Res>  {
  factory $UnpavedSpanCopyWith(UnpavedSpan value, $Res Function(UnpavedSpan) _then) = _$UnpavedSpanCopyWithImpl;
@useResult
$Res call({
 int from, int to
});




}
/// @nodoc
class _$UnpavedSpanCopyWithImpl<$Res>
    implements $UnpavedSpanCopyWith<$Res> {
  _$UnpavedSpanCopyWithImpl(this._self, this._then);

  final UnpavedSpan _self;
  final $Res Function(UnpavedSpan) _then;

/// Create a copy of UnpavedSpan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? to = null,}) {
  return _then(UnpavedSpan(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as int,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UnpavedSpan].
extension UnpavedSpanPatterns on UnpavedSpan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UnpavedSpan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UnpavedSpan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UnpavedSpan value)  $default,){
final _that = this;
switch (_that) {
case _UnpavedSpan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UnpavedSpan value)?  $default,){
final _that = this;
switch (_that) {
case _UnpavedSpan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int from,  int to)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UnpavedSpan() when $default != null:
return $default(_that.from,_that.to);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int from,  int to)  $default,) {final _that = this;
switch (_that) {
case _UnpavedSpan():
return $default(_that.from,_that.to);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int from,  int to)?  $default,) {final _that = this;
switch (_that) {
case _UnpavedSpan() when $default != null:
return $default(_that.from,_that.to);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UnpavedSpan implements UnpavedSpan {
  const _UnpavedSpan({required this.from, required this.to});
  factory _UnpavedSpan.fromJson(Map<String, dynamic> json) => _$UnpavedSpanFromJson(json);

@override final  int from;
@override final  int to;

/// Create a copy of UnpavedSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnpavedSpanCopyWith<_UnpavedSpan> get copyWith => __$UnpavedSpanCopyWithImpl<_UnpavedSpan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnpavedSpanToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnpavedSpan&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,from,to);
}

@override
String toString() {
    return 'UnpavedSpan(from: $from, to: $to)';
}


}

/// @nodoc
abstract mixin class _$UnpavedSpanCopyWith<$Res> implements $UnpavedSpanCopyWith<$Res> {
  factory _$UnpavedSpanCopyWith(_UnpavedSpan value, $Res Function(_UnpavedSpan) _then) = __$UnpavedSpanCopyWithImpl;
@override @useResult
$Res call({
 int from, int to
});




}
/// @nodoc
class __$UnpavedSpanCopyWithImpl<$Res>
    implements _$UnpavedSpanCopyWith<$Res> {
  __$UnpavedSpanCopyWithImpl(this._self, this._then);

  final _UnpavedSpan _self;
  final $Res Function(_UnpavedSpan) _then;

/// Create a copy of UnpavedSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? to = null,}) {
  return _then(_UnpavedSpan(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as int,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
