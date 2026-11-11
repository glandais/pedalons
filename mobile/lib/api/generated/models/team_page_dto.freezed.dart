// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_page_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamPageDto {

/// Team
 TeamPublicationDto get team;/// Page ID (TSID)
 String get id;/// Page title
 String get title;/// Page URL slug
 String get slug;/// Page content
 MediaDto get media;/// Visibility level
 String get visibility;/// Page order
 int get order;/// Whether the page is soft-deleted
 bool get deleted;/// What the caller may do with the page: edit, delete (never the about page), and the visibilities it may be saved with.
 ContentPermissionsDto get permissions;
/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamPageDtoCopyWith<TeamPageDto> get copyWith => _$TeamPageDtoCopyWithImpl<TeamPageDto>(this as TeamPageDto, _$identity);

  /// Serializes this TeamPageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamPageDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamPageDto&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.order, _this.order) || other.order == _this.order)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.permissions, _this.permissions) || other.permissions == _this.permissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamPageDto;
  return Object.hash(runtimeType,_this.team,_this.id,_this.title,_this.slug,_this.media,_this.visibility,_this.order,_this.deleted,_this.permissions);
}

@override
String toString() {
  final _this = this as TeamPageDto;
  return 'TeamPageDto(team: ${_this.team}, id: ${_this.id}, title: ${_this.title}, slug: ${_this.slug}, media: ${_this.media}, visibility: ${_this.visibility}, order: ${_this.order}, deleted: ${_this.deleted}, permissions: ${_this.permissions})';
}


}

/// @nodoc
abstract mixin class $TeamPageDtoCopyWith<$Res>  {
  factory $TeamPageDtoCopyWith(TeamPageDto value, $Res Function(TeamPageDto) _then) = _$TeamPageDtoCopyWithImpl;
@useResult
$Res call({
 TeamPublicationDto team, String id, String title, String slug, MediaDto media, String visibility, int order, bool deleted, ContentPermissionsDto permissions
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;$ContentPermissionsDtoCopyWith<$Res> get permissions;

}
/// @nodoc
class _$TeamPageDtoCopyWithImpl<$Res>
    implements $TeamPageDtoCopyWith<$Res> {
  _$TeamPageDtoCopyWithImpl(this._self, this._then);

  final TeamPageDto _self;
  final $Res Function(TeamPageDto) _then;

/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? team = null,Object? id = null,Object? title = null,Object? slug = null,Object? media = null,Object? visibility = null,Object? order = null,Object? deleted = null,Object? permissions = null,}) {
  return _then(TeamPageDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ContentPermissionsDto,
  ));
}
/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentPermissionsDtoCopyWith<$Res> get permissions {
  
  return $ContentPermissionsDtoCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}
}


/// Adds pattern-matching-related methods to [TeamPageDto].
extension TeamPageDtoPatterns on TeamPageDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamPageDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamPageDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamPageDto value)  $default,){
final _that = this;
switch (_that) {
case _TeamPageDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamPageDto value)?  $default,){
final _that = this;
switch (_that) {
case _TeamPageDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TeamPublicationDto team,  String id,  String title,  String slug,  MediaDto media,  String visibility,  int order,  bool deleted,  ContentPermissionsDto permissions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamPageDto() when $default != null:
return $default(_that.team,_that.id,_that.title,_that.slug,_that.media,_that.visibility,_that.order,_that.deleted,_that.permissions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TeamPublicationDto team,  String id,  String title,  String slug,  MediaDto media,  String visibility,  int order,  bool deleted,  ContentPermissionsDto permissions)  $default,) {final _that = this;
switch (_that) {
case _TeamPageDto():
return $default(_that.team,_that.id,_that.title,_that.slug,_that.media,_that.visibility,_that.order,_that.deleted,_that.permissions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TeamPublicationDto team,  String id,  String title,  String slug,  MediaDto media,  String visibility,  int order,  bool deleted,  ContentPermissionsDto permissions)?  $default,) {final _that = this;
switch (_that) {
case _TeamPageDto() when $default != null:
return $default(_that.team,_that.id,_that.title,_that.slug,_that.media,_that.visibility,_that.order,_that.deleted,_that.permissions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamPageDto implements TeamPageDto {
  const _TeamPageDto({required this.team, required this.id, required this.title, required this.slug, required this.media, required this.visibility, required this.order, required this.deleted, required this.permissions});
  factory _TeamPageDto.fromJson(Map<String, dynamic> json) => _$TeamPageDtoFromJson(json);

/// Team
@override final  TeamPublicationDto team;
/// Page ID (TSID)
@override final  String id;
/// Page title
@override final  String title;
/// Page URL slug
@override final  String slug;
/// Page content
@override final  MediaDto media;
/// Visibility level
@override final  String visibility;
/// Page order
@override final  int order;
/// Whether the page is soft-deleted
@override final  bool deleted;
/// What the caller may do with the page: edit, delete (never the about page), and the visibilities it may be saved with.
@override final  ContentPermissionsDto permissions;

/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamPageDtoCopyWith<_TeamPageDto> get copyWith => __$TeamPageDtoCopyWithImpl<_TeamPageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamPageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamPageDto&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.media, media) || other.media == media)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.order, order) || other.order == order)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.permissions, permissions) || other.permissions == permissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,team,id,title,slug,media,visibility,order,deleted,permissions);
}

@override
String toString() {
    return 'TeamPageDto(team: $team, id: $id, title: $title, slug: $slug, media: $media, visibility: $visibility, order: $order, deleted: $deleted, permissions: $permissions)';
}


}

/// @nodoc
abstract mixin class _$TeamPageDtoCopyWith<$Res> implements $TeamPageDtoCopyWith<$Res> {
  factory _$TeamPageDtoCopyWith(_TeamPageDto value, $Res Function(_TeamPageDto) _then) = __$TeamPageDtoCopyWithImpl;
@override @useResult
$Res call({
 TeamPublicationDto team, String id, String title, String slug, MediaDto media, String visibility, int order, bool deleted, ContentPermissionsDto permissions
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;@override $ContentPermissionsDtoCopyWith<$Res> get permissions;

}
/// @nodoc
class __$TeamPageDtoCopyWithImpl<$Res>
    implements _$TeamPageDtoCopyWith<$Res> {
  __$TeamPageDtoCopyWithImpl(this._self, this._then);

  final _TeamPageDto _self;
  final $Res Function(_TeamPageDto) _then;

/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? team = null,Object? id = null,Object? title = null,Object? slug = null,Object? media = null,Object? visibility = null,Object? order = null,Object? deleted = null,Object? permissions = null,}) {
  return _then(_TeamPageDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ContentPermissionsDto,
  ));
}

/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of TeamPageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentPermissionsDtoCopyWith<$Res> get permissions {
  
  return $ContentPermissionsDtoCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}
}

// dart format on
