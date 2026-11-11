// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'content_visibilities_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ContentVisibilitiesDto {

 List<Visibility> get ride; List<Visibility> get rideTemplate; List<Visibility> get route; List<Visibility> get post; List<Visibility> get trip; List<Visibility> get teamPage;/// Always [TEAM]: ads are members-only in every team.
 List<Visibility> get ad;
/// Create a copy of ContentVisibilitiesDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContentVisibilitiesDtoCopyWith<ContentVisibilitiesDto> get copyWith => _$ContentVisibilitiesDtoCopyWithImpl<ContentVisibilitiesDto>(this as ContentVisibilitiesDto, _$identity);

  /// Serializes this ContentVisibilitiesDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ContentVisibilitiesDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContentVisibilitiesDto&&const DeepCollectionEquality().equals(other.ride, _this.ride)&&const DeepCollectionEquality().equals(other.rideTemplate, _this.rideTemplate)&&const DeepCollectionEquality().equals(other.route, _this.route)&&const DeepCollectionEquality().equals(other.post, _this.post)&&const DeepCollectionEquality().equals(other.trip, _this.trip)&&const DeepCollectionEquality().equals(other.teamPage, _this.teamPage)&&const DeepCollectionEquality().equals(other.ad, _this.ad));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ContentVisibilitiesDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.ride),const DeepCollectionEquality().hash(_this.rideTemplate),const DeepCollectionEquality().hash(_this.route),const DeepCollectionEquality().hash(_this.post),const DeepCollectionEquality().hash(_this.trip),const DeepCollectionEquality().hash(_this.teamPage),const DeepCollectionEquality().hash(_this.ad));
}

@override
String toString() {
  final _this = this as ContentVisibilitiesDto;
  return 'ContentVisibilitiesDto(ride: ${_this.ride}, rideTemplate: ${_this.rideTemplate}, route: ${_this.route}, post: ${_this.post}, trip: ${_this.trip}, teamPage: ${_this.teamPage}, ad: ${_this.ad})';
}


}

/// @nodoc
abstract mixin class $ContentVisibilitiesDtoCopyWith<$Res>  {
  factory $ContentVisibilitiesDtoCopyWith(ContentVisibilitiesDto value, $Res Function(ContentVisibilitiesDto) _then) = _$ContentVisibilitiesDtoCopyWithImpl;
@useResult
$Res call({
 List<Visibility> ride, List<Visibility> rideTemplate, List<Visibility> route, List<Visibility> post, List<Visibility> trip, List<Visibility> teamPage, List<Visibility> ad
});




}
/// @nodoc
class _$ContentVisibilitiesDtoCopyWithImpl<$Res>
    implements $ContentVisibilitiesDtoCopyWith<$Res> {
  _$ContentVisibilitiesDtoCopyWithImpl(this._self, this._then);

  final ContentVisibilitiesDto _self;
  final $Res Function(ContentVisibilitiesDto) _then;

/// Create a copy of ContentVisibilitiesDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ride = null,Object? rideTemplate = null,Object? route = null,Object? post = null,Object? trip = null,Object? teamPage = null,Object? ad = null,}) {
  return _then(ContentVisibilitiesDto(
ride: null == ride ? _self.ride : ride // ignore: cast_nullable_to_non_nullable
as List<Visibility>,rideTemplate: null == rideTemplate ? _self.rideTemplate : rideTemplate // ignore: cast_nullable_to_non_nullable
as List<Visibility>,route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as List<Visibility>,post: null == post ? _self.post : post // ignore: cast_nullable_to_non_nullable
as List<Visibility>,trip: null == trip ? _self.trip : trip // ignore: cast_nullable_to_non_nullable
as List<Visibility>,teamPage: null == teamPage ? _self.teamPage : teamPage // ignore: cast_nullable_to_non_nullable
as List<Visibility>,ad: null == ad ? _self.ad : ad // ignore: cast_nullable_to_non_nullable
as List<Visibility>,
  ));
}

}


/// Adds pattern-matching-related methods to [ContentVisibilitiesDto].
extension ContentVisibilitiesDtoPatterns on ContentVisibilitiesDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContentVisibilitiesDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContentVisibilitiesDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContentVisibilitiesDto value)  $default,){
final _that = this;
switch (_that) {
case _ContentVisibilitiesDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContentVisibilitiesDto value)?  $default,){
final _that = this;
switch (_that) {
case _ContentVisibilitiesDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Visibility> ride,  List<Visibility> rideTemplate,  List<Visibility> route,  List<Visibility> post,  List<Visibility> trip,  List<Visibility> teamPage,  List<Visibility> ad)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContentVisibilitiesDto() when $default != null:
return $default(_that.ride,_that.rideTemplate,_that.route,_that.post,_that.trip,_that.teamPage,_that.ad);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Visibility> ride,  List<Visibility> rideTemplate,  List<Visibility> route,  List<Visibility> post,  List<Visibility> trip,  List<Visibility> teamPage,  List<Visibility> ad)  $default,) {final _that = this;
switch (_that) {
case _ContentVisibilitiesDto():
return $default(_that.ride,_that.rideTemplate,_that.route,_that.post,_that.trip,_that.teamPage,_that.ad);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Visibility> ride,  List<Visibility> rideTemplate,  List<Visibility> route,  List<Visibility> post,  List<Visibility> trip,  List<Visibility> teamPage,  List<Visibility> ad)?  $default,) {final _that = this;
switch (_that) {
case _ContentVisibilitiesDto() when $default != null:
return $default(_that.ride,_that.rideTemplate,_that.route,_that.post,_that.trip,_that.teamPage,_that.ad);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ContentVisibilitiesDto implements ContentVisibilitiesDto {
  const _ContentVisibilitiesDto({required  List<Visibility> ride, required  List<Visibility> rideTemplate, required  List<Visibility> route, required  List<Visibility> post, required  List<Visibility> trip, required  List<Visibility> teamPage, required  List<Visibility> ad}): _ride = ride,_rideTemplate = rideTemplate,_route = route,_post = post,_trip = trip,_teamPage = teamPage,_ad = ad;
  factory _ContentVisibilitiesDto.fromJson(Map<String, dynamic> json) => _$ContentVisibilitiesDtoFromJson(json);

 final  List<Visibility> _ride;
@override List<Visibility> get ride {
  if (_ride is EqualUnmodifiableListView) return _ride;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ride);
}

 final  List<Visibility> _rideTemplate;
@override List<Visibility> get rideTemplate {
  if (_rideTemplate is EqualUnmodifiableListView) return _rideTemplate;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rideTemplate);
}

 final  List<Visibility> _route;
@override List<Visibility> get route {
  if (_route is EqualUnmodifiableListView) return _route;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_route);
}

 final  List<Visibility> _post;
@override List<Visibility> get post {
  if (_post is EqualUnmodifiableListView) return _post;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_post);
}

 final  List<Visibility> _trip;
@override List<Visibility> get trip {
  if (_trip is EqualUnmodifiableListView) return _trip;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trip);
}

 final  List<Visibility> _teamPage;
@override List<Visibility> get teamPage {
  if (_teamPage is EqualUnmodifiableListView) return _teamPage;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_teamPage);
}

/// Always [TEAM]: ads are members-only in every team.
 final  List<Visibility> _ad;
/// Always [TEAM]: ads are members-only in every team.
@override List<Visibility> get ad {
  if (_ad is EqualUnmodifiableListView) return _ad;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ad);
}


/// Create a copy of ContentVisibilitiesDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContentVisibilitiesDtoCopyWith<_ContentVisibilitiesDto> get copyWith => __$ContentVisibilitiesDtoCopyWithImpl<_ContentVisibilitiesDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContentVisibilitiesDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContentVisibilitiesDto&&const DeepCollectionEquality().equals(other.ride, _ride)&&const DeepCollectionEquality().equals(other.rideTemplate, _rideTemplate)&&const DeepCollectionEquality().equals(other.route, _route)&&const DeepCollectionEquality().equals(other.post, _post)&&const DeepCollectionEquality().equals(other.trip, _trip)&&const DeepCollectionEquality().equals(other.teamPage, _teamPage)&&const DeepCollectionEquality().equals(other.ad, _ad));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_ride),const DeepCollectionEquality().hash(_rideTemplate),const DeepCollectionEquality().hash(_route),const DeepCollectionEquality().hash(_post),const DeepCollectionEquality().hash(_trip),const DeepCollectionEquality().hash(_teamPage),const DeepCollectionEquality().hash(_ad));
}

@override
String toString() {
    return 'ContentVisibilitiesDto(ride: $ride, rideTemplate: $rideTemplate, route: $route, post: $post, trip: $trip, teamPage: $teamPage, ad: $ad)';
}


}

/// @nodoc
abstract mixin class _$ContentVisibilitiesDtoCopyWith<$Res> implements $ContentVisibilitiesDtoCopyWith<$Res> {
  factory _$ContentVisibilitiesDtoCopyWith(_ContentVisibilitiesDto value, $Res Function(_ContentVisibilitiesDto) _then) = __$ContentVisibilitiesDtoCopyWithImpl;
@override @useResult
$Res call({
 List<Visibility> ride, List<Visibility> rideTemplate, List<Visibility> route, List<Visibility> post, List<Visibility> trip, List<Visibility> teamPage, List<Visibility> ad
});




}
/// @nodoc
class __$ContentVisibilitiesDtoCopyWithImpl<$Res>
    implements _$ContentVisibilitiesDtoCopyWith<$Res> {
  __$ContentVisibilitiesDtoCopyWithImpl(this._self, this._then);

  final _ContentVisibilitiesDto _self;
  final $Res Function(_ContentVisibilitiesDto) _then;

/// Create a copy of ContentVisibilitiesDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ride = null,Object? rideTemplate = null,Object? route = null,Object? post = null,Object? trip = null,Object? teamPage = null,Object? ad = null,}) {
  return _then(_ContentVisibilitiesDto(
ride: null == ride ? _self._ride : ride // ignore: cast_nullable_to_non_nullable
as List<Visibility>,rideTemplate: null == rideTemplate ? _self._rideTemplate : rideTemplate // ignore: cast_nullable_to_non_nullable
as List<Visibility>,route: null == route ? _self._route : route // ignore: cast_nullable_to_non_nullable
as List<Visibility>,post: null == post ? _self._post : post // ignore: cast_nullable_to_non_nullable
as List<Visibility>,trip: null == trip ? _self._trip : trip // ignore: cast_nullable_to_non_nullable
as List<Visibility>,teamPage: null == teamPage ? _self._teamPage : teamPage // ignore: cast_nullable_to_non_nullable
as List<Visibility>,ad: null == ad ? _self._ad : ad // ignore: cast_nullable_to_non_nullable
as List<Visibility>,
  ));
}


}

// dart format on
