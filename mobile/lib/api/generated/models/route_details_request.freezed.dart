// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_details_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteDetailsRequest {

 String? get polyline;@JsonKey(name: 'polyline_precision') int? get polylinePrecision; List<Point>? get points; RouteDetailsOptions? get options;
/// Create a copy of RouteDetailsRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteDetailsRequestCopyWith<RouteDetailsRequest> get copyWith => _$RouteDetailsRequestCopyWithImpl<RouteDetailsRequest>(this as RouteDetailsRequest, _$identity);

  /// Serializes this RouteDetailsRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteDetailsRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteDetailsRequest&&(identical(other.polyline, _this.polyline) || other.polyline == _this.polyline)&&(identical(other.polylinePrecision, _this.polylinePrecision) || other.polylinePrecision == _this.polylinePrecision)&&const DeepCollectionEquality().equals(other.points, _this.points)&&(identical(other.options, _this.options) || other.options == _this.options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteDetailsRequest;
  return Object.hash(runtimeType,_this.polyline,_this.polylinePrecision,const DeepCollectionEquality().hash(_this.points),_this.options);
}

@override
String toString() {
  final _this = this as RouteDetailsRequest;
  return 'RouteDetailsRequest(polyline: ${_this.polyline}, polylinePrecision: ${_this.polylinePrecision}, points: ${_this.points}, options: ${_this.options})';
}


}

/// @nodoc
abstract mixin class $RouteDetailsRequestCopyWith<$Res>  {
  factory $RouteDetailsRequestCopyWith(RouteDetailsRequest value, $Res Function(RouteDetailsRequest) _then) = _$RouteDetailsRequestCopyWithImpl;
@useResult
$Res call({
 String? polyline,@JsonKey(name: 'polyline_precision') int? polylinePrecision, List<Point>? points, RouteDetailsOptions? options
});


$RouteDetailsOptionsCopyWith<$Res>? get options;

}
/// @nodoc
class _$RouteDetailsRequestCopyWithImpl<$Res>
    implements $RouteDetailsRequestCopyWith<$Res> {
  _$RouteDetailsRequestCopyWithImpl(this._self, this._then);

  final RouteDetailsRequest _self;
  final $Res Function(RouteDetailsRequest) _then;

/// Create a copy of RouteDetailsRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? polyline = freezed,Object? polylinePrecision = freezed,Object? points = freezed,Object? options = freezed,}) {
  return _then(RouteDetailsRequest(
polyline: freezed == polyline ? _self.polyline : polyline // ignore: cast_nullable_to_non_nullable
as String?,polylinePrecision: freezed == polylinePrecision ? _self.polylinePrecision : polylinePrecision // ignore: cast_nullable_to_non_nullable
as int?,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<Point>?,options: freezed == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as RouteDetailsOptions?,
  ));
}
/// Create a copy of RouteDetailsRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteDetailsOptionsCopyWith<$Res>? get options {
    if (_self.options == null) {
    return null;
  }

  return $RouteDetailsOptionsCopyWith<$Res>(_self.options!, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteDetailsRequest].
extension RouteDetailsRequestPatterns on RouteDetailsRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteDetailsRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteDetailsRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteDetailsRequest value)  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteDetailsRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? polyline, @JsonKey(name: 'polyline_precision')  int? polylinePrecision,  List<Point>? points,  RouteDetailsOptions? options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteDetailsRequest() when $default != null:
return $default(_that.polyline,_that.polylinePrecision,_that.points,_that.options);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? polyline, @JsonKey(name: 'polyline_precision')  int? polylinePrecision,  List<Point>? points,  RouteDetailsOptions? options)  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsRequest():
return $default(_that.polyline,_that.polylinePrecision,_that.points,_that.options);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? polyline, @JsonKey(name: 'polyline_precision')  int? polylinePrecision,  List<Point>? points,  RouteDetailsOptions? options)?  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsRequest() when $default != null:
return $default(_that.polyline,_that.polylinePrecision,_that.points,_that.options);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteDetailsRequest implements RouteDetailsRequest {
  const _RouteDetailsRequest({this.polyline, @JsonKey(name: 'polyline_precision') this.polylinePrecision,  List<Point>? points, this.options}): _points = points;
  factory _RouteDetailsRequest.fromJson(Map<String, dynamic> json) => _$RouteDetailsRequestFromJson(json);

@override final  String? polyline;
@override@JsonKey(name: 'polyline_precision') final  int? polylinePrecision;
 final  List<Point>? _points;
@override List<Point>? get points {
  final value = _points;
  if (value == null) return null;
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  RouteDetailsOptions? options;

/// Create a copy of RouteDetailsRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteDetailsRequestCopyWith<_RouteDetailsRequest> get copyWith => __$RouteDetailsRequestCopyWithImpl<_RouteDetailsRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteDetailsRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteDetailsRequest&&(identical(other.polyline, polyline) || other.polyline == polyline)&&(identical(other.polylinePrecision, polylinePrecision) || other.polylinePrecision == polylinePrecision)&&const DeepCollectionEquality().equals(other.points, _points)&&(identical(other.options, options) || other.options == options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,polyline,polylinePrecision,const DeepCollectionEquality().hash(_points),options);
}

@override
String toString() {
    return 'RouteDetailsRequest(polyline: $polyline, polylinePrecision: $polylinePrecision, points: $points, options: $options)';
}


}

/// @nodoc
abstract mixin class _$RouteDetailsRequestCopyWith<$Res> implements $RouteDetailsRequestCopyWith<$Res> {
  factory _$RouteDetailsRequestCopyWith(_RouteDetailsRequest value, $Res Function(_RouteDetailsRequest) _then) = __$RouteDetailsRequestCopyWithImpl;
@override @useResult
$Res call({
 String? polyline,@JsonKey(name: 'polyline_precision') int? polylinePrecision, List<Point>? points, RouteDetailsOptions? options
});


@override $RouteDetailsOptionsCopyWith<$Res>? get options;

}
/// @nodoc
class __$RouteDetailsRequestCopyWithImpl<$Res>
    implements _$RouteDetailsRequestCopyWith<$Res> {
  __$RouteDetailsRequestCopyWithImpl(this._self, this._then);

  final _RouteDetailsRequest _self;
  final $Res Function(_RouteDetailsRequest) _then;

/// Create a copy of RouteDetailsRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? polyline = freezed,Object? polylinePrecision = freezed,Object? points = freezed,Object? options = freezed,}) {
  return _then(_RouteDetailsRequest(
polyline: freezed == polyline ? _self.polyline : polyline // ignore: cast_nullable_to_non_nullable
as String?,polylinePrecision: freezed == polylinePrecision ? _self.polylinePrecision : polylinePrecision // ignore: cast_nullable_to_non_nullable
as int?,points: freezed == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<Point>?,options: freezed == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as RouteDetailsOptions?,
  ));
}

/// Create a copy of RouteDetailsRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteDetailsOptionsCopyWith<$Res>? get options {
    if (_self.options == null) {
    return null;
  }

  return $RouteDetailsOptionsCopyWith<$Res>(_self.options!, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

// dart format on
