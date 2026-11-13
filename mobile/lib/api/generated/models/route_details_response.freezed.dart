// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_details_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteDetailsResponse {

 Meta? get meta; String? get status; List<OutputPoint>? get points; List<Segment>? get segments; Summary? get summary; Quality? get quality; bool? get partial;
/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteDetailsResponseCopyWith<RouteDetailsResponse> get copyWith => _$RouteDetailsResponseCopyWithImpl<RouteDetailsResponse>(this as RouteDetailsResponse, _$identity);

  /// Serializes this RouteDetailsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteDetailsResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteDetailsResponse&&(identical(other.meta, _this.meta) || other.meta == _this.meta)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.points, _this.points)&&const DeepCollectionEquality().equals(other.segments, _this.segments)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.quality, _this.quality) || other.quality == _this.quality)&&(identical(other.partial, _this.partial) || other.partial == _this.partial));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteDetailsResponse;
  return Object.hash(runtimeType,_this.meta,_this.status,const DeepCollectionEquality().hash(_this.points),const DeepCollectionEquality().hash(_this.segments),_this.summary,_this.quality,_this.partial);
}

@override
String toString() {
  final _this = this as RouteDetailsResponse;
  return 'RouteDetailsResponse(meta: ${_this.meta}, status: ${_this.status}, points: ${_this.points}, segments: ${_this.segments}, summary: ${_this.summary}, quality: ${_this.quality}, partial: ${_this.partial})';
}


}

/// @nodoc
abstract mixin class $RouteDetailsResponseCopyWith<$Res>  {
  factory $RouteDetailsResponseCopyWith(RouteDetailsResponse value, $Res Function(RouteDetailsResponse) _then) = _$RouteDetailsResponseCopyWithImpl;
@useResult
$Res call({
 Meta? meta, String? status, List<OutputPoint>? points, List<Segment>? segments, Summary? summary, Quality? quality, bool? partial
});


$MetaCopyWith<$Res>? get meta;$SummaryCopyWith<$Res>? get summary;$QualityCopyWith<$Res>? get quality;

}
/// @nodoc
class _$RouteDetailsResponseCopyWithImpl<$Res>
    implements $RouteDetailsResponseCopyWith<$Res> {
  _$RouteDetailsResponseCopyWithImpl(this._self, this._then);

  final RouteDetailsResponse _self;
  final $Res Function(RouteDetailsResponse) _then;

/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? meta = freezed,Object? status = freezed,Object? points = freezed,Object? segments = freezed,Object? summary = freezed,Object? quality = freezed,Object? partial = freezed,}) {
  return _then(RouteDetailsResponse(
meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Meta?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<OutputPoint>?,segments: freezed == segments ? _self.segments : segments // ignore: cast_nullable_to_non_nullable
as List<Segment>?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as Summary?,quality: freezed == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as Quality?,partial: freezed == partial ? _self.partial : partial // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $MetaCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QualityCopyWith<$Res>? get quality {
    if (_self.quality == null) {
    return null;
  }

  return $QualityCopyWith<$Res>(_self.quality!, (value) {
    return _then(_self.copyWith(quality: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteDetailsResponse].
extension RouteDetailsResponsePatterns on RouteDetailsResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteDetailsResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteDetailsResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteDetailsResponse value)  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteDetailsResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RouteDetailsResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Meta? meta,  String? status,  List<OutputPoint>? points,  List<Segment>? segments,  Summary? summary,  Quality? quality,  bool? partial)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteDetailsResponse() when $default != null:
return $default(_that.meta,_that.status,_that.points,_that.segments,_that.summary,_that.quality,_that.partial);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Meta? meta,  String? status,  List<OutputPoint>? points,  List<Segment>? segments,  Summary? summary,  Quality? quality,  bool? partial)  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsResponse():
return $default(_that.meta,_that.status,_that.points,_that.segments,_that.summary,_that.quality,_that.partial);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Meta? meta,  String? status,  List<OutputPoint>? points,  List<Segment>? segments,  Summary? summary,  Quality? quality,  bool? partial)?  $default,) {final _that = this;
switch (_that) {
case _RouteDetailsResponse() when $default != null:
return $default(_that.meta,_that.status,_that.points,_that.segments,_that.summary,_that.quality,_that.partial);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteDetailsResponse implements RouteDetailsResponse {
  const _RouteDetailsResponse({this.meta, this.status,  List<OutputPoint>? points,  List<Segment>? segments, this.summary, this.quality, this.partial}): _points = points,_segments = segments;
  factory _RouteDetailsResponse.fromJson(Map<String, dynamic> json) => _$RouteDetailsResponseFromJson(json);

@override final  Meta? meta;
@override final  String? status;
 final  List<OutputPoint>? _points;
@override List<OutputPoint>? get points {
  final value = _points;
  if (value == null) return null;
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<Segment>? _segments;
@override List<Segment>? get segments {
  final value = _segments;
  if (value == null) return null;
  if (_segments is EqualUnmodifiableListView) return _segments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  Summary? summary;
@override final  Quality? quality;
@override final  bool? partial;

/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteDetailsResponseCopyWith<_RouteDetailsResponse> get copyWith => __$RouteDetailsResponseCopyWithImpl<_RouteDetailsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteDetailsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteDetailsResponse&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.points, _points)&&const DeepCollectionEquality().equals(other.segments, _segments)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.partial, partial) || other.partial == partial));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,meta,status,const DeepCollectionEquality().hash(_points),const DeepCollectionEquality().hash(_segments),summary,quality,partial);
}

@override
String toString() {
    return 'RouteDetailsResponse(meta: $meta, status: $status, points: $points, segments: $segments, summary: $summary, quality: $quality, partial: $partial)';
}


}

/// @nodoc
abstract mixin class _$RouteDetailsResponseCopyWith<$Res> implements $RouteDetailsResponseCopyWith<$Res> {
  factory _$RouteDetailsResponseCopyWith(_RouteDetailsResponse value, $Res Function(_RouteDetailsResponse) _then) = __$RouteDetailsResponseCopyWithImpl;
@override @useResult
$Res call({
 Meta? meta, String? status, List<OutputPoint>? points, List<Segment>? segments, Summary? summary, Quality? quality, bool? partial
});


@override $MetaCopyWith<$Res>? get meta;@override $SummaryCopyWith<$Res>? get summary;@override $QualityCopyWith<$Res>? get quality;

}
/// @nodoc
class __$RouteDetailsResponseCopyWithImpl<$Res>
    implements _$RouteDetailsResponseCopyWith<$Res> {
  __$RouteDetailsResponseCopyWithImpl(this._self, this._then);

  final _RouteDetailsResponse _self;
  final $Res Function(_RouteDetailsResponse) _then;

/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = freezed,Object? status = freezed,Object? points = freezed,Object? segments = freezed,Object? summary = freezed,Object? quality = freezed,Object? partial = freezed,}) {
  return _then(_RouteDetailsResponse(
meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Meta?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,points: freezed == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<OutputPoint>?,segments: freezed == segments ? _self._segments : segments // ignore: cast_nullable_to_non_nullable
as List<Segment>?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as Summary?,quality: freezed == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as Quality?,partial: freezed == partial ? _self.partial : partial // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetaCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $MetaCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}/// Create a copy of RouteDetailsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QualityCopyWith<$Res>? get quality {
    if (_self.quality == null) {
    return null;
  }

  return $QualityCopyWith<$Res>(_self.quality!, (value) {
    return _then(_self.copyWith(quality: value));
  });
}
}

// dart format on
