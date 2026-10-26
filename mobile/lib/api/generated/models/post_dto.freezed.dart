// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PostDto {

/// Type
 String get type;/// Team
 TeamPublicationDto get team;/// Publication ID (TSID)
 String get id;/// Publication URL slug
 String get slug;/// Publication name
 String get name;/// Publication media
 MediaDto get media;/// Publication date/time
 String get dateTime;/// IANA zone the post's times were entered in and read in: the team's at its last save. dateTime, publishAt are rendezvous in this zone.
 String get timezone;/// Publication status
 String get status;/// Visibility level
 String get visibility;/// Whether the post is soft-deleted
 bool get deleted;/// Whether the post is signed by the team rather than by its author. Readers are then not told who wrote it: createdBy is absent unless the caller administers the team or wrote the post.
 bool get signedAsTeam;/// The team's POST tags the post carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags;/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
 String? get excerpt;/// URL template of the post's first image, the one a card shows. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Publication timestamp
 String? get publishAt;/// Creation timestamp
 String? get createdAt;/// Number of comments, replies included. Absent when the caller may not read the comments of this post — comments are members-only, so an outsider is told nothing, not even zero.
 int? get commentCount;/// Who wrote the post. Absent when the caller is not a member of the team — member names are never sent to anyone else — and when the post is signed by the team (signedAsTeam) and the caller neither administers the team nor wrote it: render the team instead.
 PublicUserDto? get createdBy;
/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostDtoCopyWith<PostDto> get copyWith => _$PostDtoCopyWithImpl<PostDto>(this as PostDto, _$identity);

  /// Serializes this PostDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PostDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.signedAsTeam, _this.signedAsTeam) || other.signedAsTeam == _this.signedAsTeam)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.publishAt, _this.publishAt) || other.publishAt == _this.publishAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount)&&(identical(other.createdBy, _this.createdBy) || other.createdBy == _this.createdBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PostDto;
  return Object.hashAll([runtimeType,_this.type,_this.team,_this.id,_this.slug,_this.name,_this.media,_this.dateTime,_this.timezone,_this.status,_this.visibility,_this.deleted,_this.signedAsTeam,const DeepCollectionEquality().hash(_this.tags),_this.excerpt,_this.thumbnailUrl,_this.publishAt,_this.createdAt,_this.commentCount,_this.createdBy]);
}

@override
String toString() {
  final _this = this as PostDto;
  return 'PostDto(type: ${_this.type}, team: ${_this.team}, id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, media: ${_this.media}, dateTime: ${_this.dateTime}, timezone: ${_this.timezone}, status: ${_this.status}, visibility: ${_this.visibility}, deleted: ${_this.deleted}, signedAsTeam: ${_this.signedAsTeam}, tags: ${_this.tags}, excerpt: ${_this.excerpt}, thumbnailUrl: ${_this.thumbnailUrl}, publishAt: ${_this.publishAt}, createdAt: ${_this.createdAt}, commentCount: ${_this.commentCount}, createdBy: ${_this.createdBy})';
}


}

/// @nodoc
abstract mixin class $PostDtoCopyWith<$Res>  {
  factory $PostDtoCopyWith(PostDto value, $Res Function(PostDto) _then) = _$PostDtoCopyWithImpl;
@useResult
$Res call({
 String type, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String status, String visibility, bool deleted, bool signedAsTeam, List<TagDto> tags, String? excerpt, String? thumbnailUrl, String? publishAt, String? createdAt, int? commentCount, PublicUserDto? createdBy
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;$PublicUserDtoCopyWith<$Res>? get createdBy;

}
/// @nodoc
class _$PostDtoCopyWithImpl<$Res>
    implements $PostDtoCopyWith<$Res> {
  _$PostDtoCopyWithImpl(this._self, this._then);

  final PostDto _self;
  final $Res Function(PostDto) _then;

/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? status = null,Object? visibility = null,Object? deleted = null,Object? signedAsTeam = null,Object? tags = null,Object? excerpt = freezed,Object? thumbnailUrl = freezed,Object? publishAt = freezed,Object? createdAt = freezed,Object? commentCount = freezed,Object? createdBy = freezed,}) {
  return _then(PostDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,signedAsTeam: null == signedAsTeam ? _self.signedAsTeam : signedAsTeam // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as PublicUserDto?,
  ));
}
/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicUserDtoCopyWith<$Res>? get createdBy {
    if (_self.createdBy == null) {
    return null;
  }

  return $PublicUserDtoCopyWith<$Res>(_self.createdBy!, (value) {
    return _then(_self.copyWith(createdBy: value));
  });
}
}


/// Adds pattern-matching-related methods to [PostDto].
extension PostDtoPatterns on PostDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostDto value)  $default,){
final _that = this;
switch (_that) {
case _PostDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostDto value)?  $default,){
final _that = this;
switch (_that) {
case _PostDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String status,  String visibility,  bool deleted,  bool signedAsTeam,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  String? publishAt,  String? createdAt,  int? commentCount,  PublicUserDto? createdBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostDto() when $default != null:
return $default(_that.type,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.status,_that.visibility,_that.deleted,_that.signedAsTeam,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.publishAt,_that.createdAt,_that.commentCount,_that.createdBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String status,  String visibility,  bool deleted,  bool signedAsTeam,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  String? publishAt,  String? createdAt,  int? commentCount,  PublicUserDto? createdBy)  $default,) {final _that = this;
switch (_that) {
case _PostDto():
return $default(_that.type,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.status,_that.visibility,_that.deleted,_that.signedAsTeam,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.publishAt,_that.createdAt,_that.commentCount,_that.createdBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String status,  String visibility,  bool deleted,  bool signedAsTeam,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  String? publishAt,  String? createdAt,  int? commentCount,  PublicUserDto? createdBy)?  $default,) {final _that = this;
switch (_that) {
case _PostDto() when $default != null:
return $default(_that.type,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.status,_that.visibility,_that.deleted,_that.signedAsTeam,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.publishAt,_that.createdAt,_that.commentCount,_that.createdBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PostDto implements PostDto {
  const _PostDto({required this.type, required this.team, required this.id, required this.slug, required this.name, required this.media, required this.dateTime, required this.timezone, required this.status, required this.visibility, required this.deleted, required this.signedAsTeam, required  List<TagDto> tags, this.excerpt, this.thumbnailUrl, this.publishAt, this.createdAt, this.commentCount, this.createdBy}): _tags = tags;
  factory _PostDto.fromJson(Map<String, dynamic> json) => _$PostDtoFromJson(json);

/// Type
@override final  String type;
/// Team
@override final  TeamPublicationDto team;
/// Publication ID (TSID)
@override final  String id;
/// Publication URL slug
@override final  String slug;
/// Publication name
@override final  String name;
/// Publication media
@override final  MediaDto media;
/// Publication date/time
@override final  String dateTime;
/// IANA zone the post's times were entered in and read in: the team's at its last save. dateTime, publishAt are rendezvous in this zone.
@override final  String timezone;
/// Publication status
@override final  String status;
/// Visibility level
@override final  String visibility;
/// Whether the post is soft-deleted
@override final  bool deleted;
/// Whether the post is signed by the team rather than by its author. Readers are then not told who wrote it: createdBy is absent unless the caller administers the team or wrote the post.
@override final  bool signedAsTeam;
/// The team's POST tags the post carries, sorted by label. Empty when it carries none.
 final  List<TagDto> _tags;
/// The team's POST tags the post carries, sorted by label. Empty when it carries none.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
@override final  String? excerpt;
/// URL template of the post's first image, the one a card shows. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Publication timestamp
@override final  String? publishAt;
/// Creation timestamp
@override final  String? createdAt;
/// Number of comments, replies included. Absent when the caller may not read the comments of this post — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;
/// Who wrote the post. Absent when the caller is not a member of the team — member names are never sent to anyone else — and when the post is signed by the team (signedAsTeam) and the caller neither administers the team nor wrote it: render the team instead.
@override final  PublicUserDto? createdBy;

/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostDtoCopyWith<_PostDto> get copyWith => __$PostDtoCopyWithImpl<_PostDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostDto&&(identical(other.type, type) || other.type == type)&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.status, status) || other.status == status)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.signedAsTeam, signedAsTeam) || other.signedAsTeam == signedAsTeam)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,type,team,id,slug,name,media,dateTime,timezone,status,visibility,deleted,signedAsTeam,const DeepCollectionEquality().hash(_tags),excerpt,thumbnailUrl,publishAt,createdAt,commentCount,createdBy]);
}

@override
String toString() {
    return 'PostDto(type: $type, team: $team, id: $id, slug: $slug, name: $name, media: $media, dateTime: $dateTime, timezone: $timezone, status: $status, visibility: $visibility, deleted: $deleted, signedAsTeam: $signedAsTeam, tags: $tags, excerpt: $excerpt, thumbnailUrl: $thumbnailUrl, publishAt: $publishAt, createdAt: $createdAt, commentCount: $commentCount, createdBy: $createdBy)';
}


}

/// @nodoc
abstract mixin class _$PostDtoCopyWith<$Res> implements $PostDtoCopyWith<$Res> {
  factory _$PostDtoCopyWith(_PostDto value, $Res Function(_PostDto) _then) = __$PostDtoCopyWithImpl;
@override @useResult
$Res call({
 String type, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String status, String visibility, bool deleted, bool signedAsTeam, List<TagDto> tags, String? excerpt, String? thumbnailUrl, String? publishAt, String? createdAt, int? commentCount, PublicUserDto? createdBy
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;@override $PublicUserDtoCopyWith<$Res>? get createdBy;

}
/// @nodoc
class __$PostDtoCopyWithImpl<$Res>
    implements _$PostDtoCopyWith<$Res> {
  __$PostDtoCopyWithImpl(this._self, this._then);

  final _PostDto _self;
  final $Res Function(_PostDto) _then;

/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? status = null,Object? visibility = null,Object? deleted = null,Object? signedAsTeam = null,Object? tags = null,Object? excerpt = freezed,Object? thumbnailUrl = freezed,Object? publishAt = freezed,Object? createdAt = freezed,Object? commentCount = freezed,Object? createdBy = freezed,}) {
  return _then(_PostDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,signedAsTeam: null == signedAsTeam ? _self.signedAsTeam : signedAsTeam // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as PublicUserDto?,
  ));
}

/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of PostDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicUserDtoCopyWith<$Res>? get createdBy {
    if (_self.createdBy == null) {
    return null;
  }

  return $PublicUserDtoCopyWith<$Res>(_self.createdBy!, (value) {
    return _then(_self.copyWith(createdBy: value));
  });
}
}

// dart format on
