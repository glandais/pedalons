// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_publication_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamPublicationDto {

/// Team ID (TSID)
 String get id;/// Team name
 String get name;/// Team URL slug
 String get slug;/// Whether the team is public
 String get visibility;/// URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only.
 String? get logoUrl;
/// Create a copy of TeamPublicationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<TeamPublicationDto> get copyWith => _$TeamPublicationDtoCopyWithImpl<TeamPublicationDto>(this as TeamPublicationDto, _$identity);

  /// Serializes this TeamPublicationDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamPublicationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamPublicationDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.logoUrl, _this.logoUrl) || other.logoUrl == _this.logoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamPublicationDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.slug,_this.visibility,_this.logoUrl);
}

@override
String toString() {
  final _this = this as TeamPublicationDto;
  return 'TeamPublicationDto(id: ${_this.id}, name: ${_this.name}, slug: ${_this.slug}, visibility: ${_this.visibility}, logoUrl: ${_this.logoUrl})';
}


}

/// @nodoc
abstract mixin class $TeamPublicationDtoCopyWith<$Res>  {
  factory $TeamPublicationDtoCopyWith(TeamPublicationDto value, $Res Function(TeamPublicationDto) _then) = _$TeamPublicationDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String slug, String visibility, String? logoUrl
});




}
/// @nodoc
class _$TeamPublicationDtoCopyWithImpl<$Res>
    implements $TeamPublicationDtoCopyWith<$Res> {
  _$TeamPublicationDtoCopyWithImpl(this._self, this._then);

  final TeamPublicationDto _self;
  final $Res Function(TeamPublicationDto) _then;

/// Create a copy of TeamPublicationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? visibility = null,Object? logoUrl = freezed,}) {
  return _then(TeamPublicationDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TeamPublicationDto].
extension TeamPublicationDtoPatterns on TeamPublicationDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamPublicationDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamPublicationDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamPublicationDto value)  $default,){
final _that = this;
switch (_that) {
case _TeamPublicationDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamPublicationDto value)?  $default,){
final _that = this;
switch (_that) {
case _TeamPublicationDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String visibility,  String? logoUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamPublicationDto() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.visibility,_that.logoUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String visibility,  String? logoUrl)  $default,) {final _that = this;
switch (_that) {
case _TeamPublicationDto():
return $default(_that.id,_that.name,_that.slug,_that.visibility,_that.logoUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String slug,  String visibility,  String? logoUrl)?  $default,) {final _that = this;
switch (_that) {
case _TeamPublicationDto() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.visibility,_that.logoUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamPublicationDto implements TeamPublicationDto {
  const _TeamPublicationDto({required this.id, required this.name, required this.slug, required this.visibility, this.logoUrl});
  factory _TeamPublicationDto.fromJson(Map<String, dynamic> json) => _$TeamPublicationDtoFromJson(json);

/// Team ID (TSID)
@override final  String id;
/// Team name
@override final  String name;
/// Team URL slug
@override final  String slug;
/// Whether the team is public
@override final  String visibility;
/// URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? logoUrl;

/// Create a copy of TeamPublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamPublicationDtoCopyWith<_TeamPublicationDto> get copyWith => __$TeamPublicationDtoCopyWithImpl<_TeamPublicationDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamPublicationDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamPublicationDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,slug,visibility,logoUrl);
}

@override
String toString() {
    return 'TeamPublicationDto(id: $id, name: $name, slug: $slug, visibility: $visibility, logoUrl: $logoUrl)';
}


}

/// @nodoc
abstract mixin class _$TeamPublicationDtoCopyWith<$Res> implements $TeamPublicationDtoCopyWith<$Res> {
  factory _$TeamPublicationDtoCopyWith(_TeamPublicationDto value, $Res Function(_TeamPublicationDto) _then) = __$TeamPublicationDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String slug, String visibility, String? logoUrl
});




}
/// @nodoc
class __$TeamPublicationDtoCopyWithImpl<$Res>
    implements _$TeamPublicationDtoCopyWith<$Res> {
  __$TeamPublicationDtoCopyWithImpl(this._self, this._then);

  final _TeamPublicationDto _self;
  final $Res Function(_TeamPublicationDto) _then;

/// Create a copy of TeamPublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? visibility = null,Object? logoUrl = freezed,}) {
  return _then(_TeamPublicationDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
