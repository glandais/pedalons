// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ad_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdDto {

/// Team
 TeamPublicationDto get team;/// Ad ID (TSID)
 String get id;/// Ad URL slug
 String get slug;/// Ad name
 String get name;/// Ad media
 MediaDto get media;/// URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'.
 List<String> get images;/// Ad status
 String get status;/// Visibility level
 String get visibility;/// Ad type
 String get adType;/// Creation timestamp
 String get createdAt;/// Creation timestamp
 String get updatedAt;/// Creator ID (TSID)
 String get createdById;/// Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.
 String get createdByDisplayName;/// Whether the ad is soft-deleted
 bool get deleted;/// The team's AD tags the ad carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags;/// Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter.
 String? get excerpt;/// URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Price
 num? get price;/// Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set.
 String? get rentalPeriod;/// Location description
 String? get locationDescription;/// Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one.
 AdDtoLocationGeometry? get locationGeometry;
/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdDtoCopyWith<AdDto> get copyWith => _$AdDtoCopyWithImpl<AdDto>(this as AdDto, _$identity);

  /// Serializes this AdDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdDto&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&const DeepCollectionEquality().equals(other.images, _this.images)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.adType, _this.adType) || other.adType == _this.adType)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.createdById, _this.createdById) || other.createdById == _this.createdById)&&(identical(other.createdByDisplayName, _this.createdByDisplayName) || other.createdByDisplayName == _this.createdByDisplayName)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.rentalPeriod, _this.rentalPeriod) || other.rentalPeriod == _this.rentalPeriod)&&(identical(other.locationDescription, _this.locationDescription) || other.locationDescription == _this.locationDescription)&&(identical(other.locationGeometry, _this.locationGeometry) || other.locationGeometry == _this.locationGeometry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdDto;
  return Object.hashAll([runtimeType,_this.team,_this.id,_this.slug,_this.name,_this.media,const DeepCollectionEquality().hash(_this.images),_this.status,_this.visibility,_this.adType,_this.createdAt,_this.updatedAt,_this.createdById,_this.createdByDisplayName,_this.deleted,const DeepCollectionEquality().hash(_this.tags),_this.excerpt,_this.thumbnailUrl,_this.price,_this.rentalPeriod,_this.locationDescription,_this.locationGeometry]);
}

@override
String toString() {
  final _this = this as AdDto;
  return 'AdDto(team: ${_this.team}, id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, media: ${_this.media}, images: ${_this.images}, status: ${_this.status}, visibility: ${_this.visibility}, adType: ${_this.adType}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, createdById: ${_this.createdById}, createdByDisplayName: ${_this.createdByDisplayName}, deleted: ${_this.deleted}, tags: ${_this.tags}, excerpt: ${_this.excerpt}, thumbnailUrl: ${_this.thumbnailUrl}, price: ${_this.price}, rentalPeriod: ${_this.rentalPeriod}, locationDescription: ${_this.locationDescription}, locationGeometry: ${_this.locationGeometry})';
}


}

/// @nodoc
abstract mixin class $AdDtoCopyWith<$Res>  {
  factory $AdDtoCopyWith(AdDto value, $Res Function(AdDto) _then) = _$AdDtoCopyWithImpl;
@useResult
$Res call({
 TeamPublicationDto team, String id, String slug, String name, MediaDto media, List<String> images, String status, String visibility, String adType, String createdAt, String updatedAt, String createdById, String createdByDisplayName, bool deleted, List<TagDto> tags, String? excerpt, String? thumbnailUrl, num? price, String? rentalPeriod, String? locationDescription, AdDtoLocationGeometry? locationGeometry
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;$AdDtoLocationGeometryCopyWith<$Res>? get locationGeometry;

}
/// @nodoc
class _$AdDtoCopyWithImpl<$Res>
    implements $AdDtoCopyWith<$Res> {
  _$AdDtoCopyWithImpl(this._self, this._then);

  final AdDto _self;
  final $Res Function(AdDto) _then;

/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? images = null,Object? status = null,Object? visibility = null,Object? adType = null,Object? createdAt = null,Object? updatedAt = null,Object? createdById = null,Object? createdByDisplayName = null,Object? deleted = null,Object? tags = null,Object? excerpt = freezed,Object? thumbnailUrl = freezed,Object? price = freezed,Object? rentalPeriod = freezed,Object? locationDescription = freezed,Object? locationGeometry = freezed,}) {
  return _then(AdDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,images: null == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,adType: null == adType ? _self.adType : adType // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,createdById: null == createdById ? _self.createdById : createdById // ignore: cast_nullable_to_non_nullable
as String,createdByDisplayName: null == createdByDisplayName ? _self.createdByDisplayName : createdByDisplayName // ignore: cast_nullable_to_non_nullable
as String,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as num?,rentalPeriod: freezed == rentalPeriod ? _self.rentalPeriod : rentalPeriod // ignore: cast_nullable_to_non_nullable
as String?,locationDescription: freezed == locationDescription ? _self.locationDescription : locationDescription // ignore: cast_nullable_to_non_nullable
as String?,locationGeometry: freezed == locationGeometry ? _self.locationGeometry : locationGeometry // ignore: cast_nullable_to_non_nullable
as AdDtoLocationGeometry?,
  ));
}
/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdDtoLocationGeometryCopyWith<$Res>? get locationGeometry {
    if (_self.locationGeometry == null) {
    return null;
  }

  return $AdDtoLocationGeometryCopyWith<$Res>(_self.locationGeometry!, (value) {
    return _then(_self.copyWith(locationGeometry: value));
  });
}
}


/// Adds pattern-matching-related methods to [AdDto].
extension AdDtoPatterns on AdDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdDto value)  $default,){
final _that = this;
switch (_that) {
case _AdDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  List<String> images,  String status,  String visibility,  String adType,  String createdAt,  String updatedAt,  String createdById,  String createdByDisplayName,  bool deleted,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  num? price,  String? rentalPeriod,  String? locationDescription,  AdDtoLocationGeometry? locationGeometry)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdDto() when $default != null:
return $default(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.images,_that.status,_that.visibility,_that.adType,_that.createdAt,_that.updatedAt,_that.createdById,_that.createdByDisplayName,_that.deleted,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.price,_that.rentalPeriod,_that.locationDescription,_that.locationGeometry);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  List<String> images,  String status,  String visibility,  String adType,  String createdAt,  String updatedAt,  String createdById,  String createdByDisplayName,  bool deleted,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  num? price,  String? rentalPeriod,  String? locationDescription,  AdDtoLocationGeometry? locationGeometry)  $default,) {final _that = this;
switch (_that) {
case _AdDto():
return $default(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.images,_that.status,_that.visibility,_that.adType,_that.createdAt,_that.updatedAt,_that.createdById,_that.createdByDisplayName,_that.deleted,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.price,_that.rentalPeriod,_that.locationDescription,_that.locationGeometry);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  List<String> images,  String status,  String visibility,  String adType,  String createdAt,  String updatedAt,  String createdById,  String createdByDisplayName,  bool deleted,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  num? price,  String? rentalPeriod,  String? locationDescription,  AdDtoLocationGeometry? locationGeometry)?  $default,) {final _that = this;
switch (_that) {
case _AdDto() when $default != null:
return $default(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.images,_that.status,_that.visibility,_that.adType,_that.createdAt,_that.updatedAt,_that.createdById,_that.createdByDisplayName,_that.deleted,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.price,_that.rentalPeriod,_that.locationDescription,_that.locationGeometry);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdDto implements AdDto {
  const _AdDto({required this.team, required this.id, required this.slug, required this.name, required this.media, required  List<String> images, required this.status, required this.visibility, required this.adType, required this.createdAt, required this.updatedAt, required this.createdById, required this.createdByDisplayName, required this.deleted, required  List<TagDto> tags, this.excerpt, this.thumbnailUrl, this.price, this.rentalPeriod, this.locationDescription, this.locationGeometry}): _images = images,_tags = tags;
  factory _AdDto.fromJson(Map<String, dynamic> json) => _$AdDtoFromJson(json);

/// Team
@override final  TeamPublicationDto team;
/// Ad ID (TSID)
@override final  String id;
/// Ad URL slug
@override final  String slug;
/// Ad name
@override final  String name;
/// Ad media
@override final  MediaDto media;
/// URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'.
 final  List<String> _images;
/// URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'.
@override List<String> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}

/// Ad status
@override final  String status;
/// Visibility level
@override final  String visibility;
/// Ad type
@override final  String adType;
/// Creation timestamp
@override final  String createdAt;
/// Creation timestamp
@override final  String updatedAt;
/// Creator ID (TSID)
@override final  String createdById;
/// Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.
@override final  String createdByDisplayName;
/// Whether the ad is soft-deleted
@override final  bool deleted;
/// The team's AD tags the ad carries, sorted by label. Empty when it carries none.
 final  List<TagDto> _tags;
/// The team's AD tags the ad carries, sorted by label. Empty when it carries none.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter.
@override final  String? excerpt;
/// URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Price
@override final  num? price;
/// Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set.
@override final  String? rentalPeriod;
/// Location description
@override final  String? locationDescription;
/// Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one.
@override final  AdDtoLocationGeometry? locationGeometry;

/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdDtoCopyWith<_AdDto> get copyWith => __$AdDtoCopyWithImpl<_AdDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdDto&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&const DeepCollectionEquality().equals(other.images, _images)&&(identical(other.status, status) || other.status == status)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.adType, adType) || other.adType == adType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdById, createdById) || other.createdById == createdById)&&(identical(other.createdByDisplayName, createdByDisplayName) || other.createdByDisplayName == createdByDisplayName)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.price, price) || other.price == price)&&(identical(other.rentalPeriod, rentalPeriod) || other.rentalPeriod == rentalPeriod)&&(identical(other.locationDescription, locationDescription) || other.locationDescription == locationDescription)&&(identical(other.locationGeometry, locationGeometry) || other.locationGeometry == locationGeometry));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,team,id,slug,name,media,const DeepCollectionEquality().hash(_images),status,visibility,adType,createdAt,updatedAt,createdById,createdByDisplayName,deleted,const DeepCollectionEquality().hash(_tags),excerpt,thumbnailUrl,price,rentalPeriod,locationDescription,locationGeometry]);
}

@override
String toString() {
    return 'AdDto(team: $team, id: $id, slug: $slug, name: $name, media: $media, images: $images, status: $status, visibility: $visibility, adType: $adType, createdAt: $createdAt, updatedAt: $updatedAt, createdById: $createdById, createdByDisplayName: $createdByDisplayName, deleted: $deleted, tags: $tags, excerpt: $excerpt, thumbnailUrl: $thumbnailUrl, price: $price, rentalPeriod: $rentalPeriod, locationDescription: $locationDescription, locationGeometry: $locationGeometry)';
}


}

/// @nodoc
abstract mixin class _$AdDtoCopyWith<$Res> implements $AdDtoCopyWith<$Res> {
  factory _$AdDtoCopyWith(_AdDto value, $Res Function(_AdDto) _then) = __$AdDtoCopyWithImpl;
@override @useResult
$Res call({
 TeamPublicationDto team, String id, String slug, String name, MediaDto media, List<String> images, String status, String visibility, String adType, String createdAt, String updatedAt, String createdById, String createdByDisplayName, bool deleted, List<TagDto> tags, String? excerpt, String? thumbnailUrl, num? price, String? rentalPeriod, String? locationDescription, AdDtoLocationGeometry? locationGeometry
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;@override $AdDtoLocationGeometryCopyWith<$Res>? get locationGeometry;

}
/// @nodoc
class __$AdDtoCopyWithImpl<$Res>
    implements _$AdDtoCopyWith<$Res> {
  __$AdDtoCopyWithImpl(this._self, this._then);

  final _AdDto _self;
  final $Res Function(_AdDto) _then;

/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? images = null,Object? status = null,Object? visibility = null,Object? adType = null,Object? createdAt = null,Object? updatedAt = null,Object? createdById = null,Object? createdByDisplayName = null,Object? deleted = null,Object? tags = null,Object? excerpt = freezed,Object? thumbnailUrl = freezed,Object? price = freezed,Object? rentalPeriod = freezed,Object? locationDescription = freezed,Object? locationGeometry = freezed,}) {
  return _then(_AdDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,images: null == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<String>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,adType: null == adType ? _self.adType : adType // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,createdById: null == createdById ? _self.createdById : createdById // ignore: cast_nullable_to_non_nullable
as String,createdByDisplayName: null == createdByDisplayName ? _self.createdByDisplayName : createdByDisplayName // ignore: cast_nullable_to_non_nullable
as String,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as num?,rentalPeriod: freezed == rentalPeriod ? _self.rentalPeriod : rentalPeriod // ignore: cast_nullable_to_non_nullable
as String?,locationDescription: freezed == locationDescription ? _self.locationDescription : locationDescription // ignore: cast_nullable_to_non_nullable
as String?,locationGeometry: freezed == locationGeometry ? _self.locationGeometry : locationGeometry // ignore: cast_nullable_to_non_nullable
as AdDtoLocationGeometry?,
  ));
}

/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of AdDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdDtoLocationGeometryCopyWith<$Res>? get locationGeometry {
    if (_self.locationGeometry == null) {
    return null;
  }

  return $AdDtoLocationGeometryCopyWith<$Res>(_self.locationGeometry!, (value) {
    return _then(_self.copyWith(locationGeometry: value));
  });
}
}

// dart format on
