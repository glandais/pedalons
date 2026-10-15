// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_template_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideTemplateDto {

/// Team
 TeamPublicationDto get team;/// Template ID (TSID)
 String get id;/// Template slug
 String get slug;/// Template name
 String get name;/// Template description (markdown)
 String get markdown;/// Visibility level
 String get visibility;/// Default status
 String get status;/// Creation timestamp
 String get createdAt;/// Last update timestamp
 String get updatedAt;/// Number of groups
 int get groupCount;/// Template groups
 List<RideTemplateGroupDto> get groups;/// The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after.
 List<TagDto> get tags;/// The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing.
 int? get nextNumber;
/// Create a copy of RideTemplateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideTemplateDtoCopyWith<RideTemplateDto> get copyWith => _$RideTemplateDtoCopyWithImpl<RideTemplateDto>(this as RideTemplateDto, _$identity);

  /// Serializes this RideTemplateDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RideTemplateDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideTemplateDto&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.markdown, _this.markdown) || other.markdown == _this.markdown)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.groupCount, _this.groupCount) || other.groupCount == _this.groupCount)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.nextNumber, _this.nextNumber) || other.nextNumber == _this.nextNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RideTemplateDto;
  return Object.hash(runtimeType,_this.team,_this.id,_this.slug,_this.name,_this.markdown,_this.visibility,_this.status,_this.createdAt,_this.updatedAt,_this.groupCount,const DeepCollectionEquality().hash(_this.groups),const DeepCollectionEquality().hash(_this.tags),_this.nextNumber);
}

@override
String toString() {
  final _this = this as RideTemplateDto;
  return 'RideTemplateDto(team: ${_this.team}, id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, markdown: ${_this.markdown}, visibility: ${_this.visibility}, status: ${_this.status}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, groupCount: ${_this.groupCount}, groups: ${_this.groups}, tags: ${_this.tags}, nextNumber: ${_this.nextNumber})';
}


}

/// @nodoc
abstract mixin class $RideTemplateDtoCopyWith<$Res>  {
  factory $RideTemplateDtoCopyWith(RideTemplateDto value, $Res Function(RideTemplateDto) _then) = _$RideTemplateDtoCopyWithImpl;
@useResult
$Res call({
 TeamPublicationDto team, String id, String slug, String name, String markdown, String visibility, String status, String createdAt, String updatedAt, int groupCount, List<RideTemplateGroupDto> groups, List<TagDto> tags, int? nextNumber
});


$TeamPublicationDtoCopyWith<$Res> get team;

}
/// @nodoc
class _$RideTemplateDtoCopyWithImpl<$Res>
    implements $RideTemplateDtoCopyWith<$Res> {
  _$RideTemplateDtoCopyWithImpl(this._self, this._then);

  final RideTemplateDto _self;
  final $Res Function(RideTemplateDto) _then;

/// Create a copy of RideTemplateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? markdown = null,Object? visibility = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? groupCount = null,Object? groups = null,Object? tags = null,Object? nextNumber = freezed,}) {
  return _then(RideTemplateDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,groupCount: null == groupCount ? _self.groupCount : groupCount // ignore: cast_nullable_to_non_nullable
as int,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<RideTemplateGroupDto>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,nextNumber: freezed == nextNumber ? _self.nextNumber : nextNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of RideTemplateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}
}


/// Adds pattern-matching-related methods to [RideTemplateDto].
extension RideTemplateDtoPatterns on RideTemplateDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideTemplateDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideTemplateDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideTemplateDto value)  $default,){
final _that = this;
switch (_that) {
case _RideTemplateDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideTemplateDto value)?  $default,){
final _that = this;
switch (_that) {
case _RideTemplateDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  String markdown,  String visibility,  String status,  String createdAt,  String updatedAt,  int groupCount,  List<RideTemplateGroupDto> groups,  List<TagDto> tags,  int? nextNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideTemplateDto() when $default != null:
return $default(_that.team,_that.id,_that.slug,_that.name,_that.markdown,_that.visibility,_that.status,_that.createdAt,_that.updatedAt,_that.groupCount,_that.groups,_that.tags,_that.nextNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  String markdown,  String visibility,  String status,  String createdAt,  String updatedAt,  int groupCount,  List<RideTemplateGroupDto> groups,  List<TagDto> tags,  int? nextNumber)  $default,) {final _that = this;
switch (_that) {
case _RideTemplateDto():
return $default(_that.team,_that.id,_that.slug,_that.name,_that.markdown,_that.visibility,_that.status,_that.createdAt,_that.updatedAt,_that.groupCount,_that.groups,_that.tags,_that.nextNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TeamPublicationDto team,  String id,  String slug,  String name,  String markdown,  String visibility,  String status,  String createdAt,  String updatedAt,  int groupCount,  List<RideTemplateGroupDto> groups,  List<TagDto> tags,  int? nextNumber)?  $default,) {final _that = this;
switch (_that) {
case _RideTemplateDto() when $default != null:
return $default(_that.team,_that.id,_that.slug,_that.name,_that.markdown,_that.visibility,_that.status,_that.createdAt,_that.updatedAt,_that.groupCount,_that.groups,_that.tags,_that.nextNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideTemplateDto implements RideTemplateDto {
  const _RideTemplateDto({required this.team, required this.id, required this.slug, required this.name, required this.markdown, required this.visibility, required this.status, required this.createdAt, required this.updatedAt, required this.groupCount, required  List<RideTemplateGroupDto> groups, required  List<TagDto> tags, this.nextNumber}): _groups = groups,_tags = tags;
  factory _RideTemplateDto.fromJson(Map<String, dynamic> json) => _$RideTemplateDtoFromJson(json);

/// Team
@override final  TeamPublicationDto team;
/// Template ID (TSID)
@override final  String id;
/// Template slug
@override final  String slug;
/// Template name
@override final  String name;
/// Template description (markdown)
@override final  String markdown;
/// Visibility level
@override final  String visibility;
/// Default status
@override final  String status;
/// Creation timestamp
@override final  String createdAt;
/// Last update timestamp
@override final  String updatedAt;
/// Number of groups
@override final  int groupCount;
/// Template groups
 final  List<RideTemplateGroupDto> _groups;
/// Template groups
@override List<RideTemplateGroupDto> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

/// The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after.
 final  List<TagDto> _tags;
/// The team's RIDE tags of the template, sorted by label. Copied onto a ride created from it: a client prefills the ride's tagIds with them, editable before and after.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// The number the next ride created from this template takes: a client prefills the ride's name with « name #nextNumber » and sends RideRequest.templateId, which raises it by one. Null: the template numbers nothing.
@override final  int? nextNumber;

/// Create a copy of RideTemplateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideTemplateDtoCopyWith<_RideTemplateDto> get copyWith => __$RideTemplateDtoCopyWithImpl<_RideTemplateDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideTemplateDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideTemplateDto&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.markdown, markdown) || other.markdown == markdown)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.groupCount, groupCount) || other.groupCount == groupCount)&&const DeepCollectionEquality().equals(other.groups, _groups)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.nextNumber, nextNumber) || other.nextNumber == nextNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,team,id,slug,name,markdown,visibility,status,createdAt,updatedAt,groupCount,const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_tags),nextNumber);
}

@override
String toString() {
    return 'RideTemplateDto(team: $team, id: $id, slug: $slug, name: $name, markdown: $markdown, visibility: $visibility, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, groupCount: $groupCount, groups: $groups, tags: $tags, nextNumber: $nextNumber)';
}


}

/// @nodoc
abstract mixin class _$RideTemplateDtoCopyWith<$Res> implements $RideTemplateDtoCopyWith<$Res> {
  factory _$RideTemplateDtoCopyWith(_RideTemplateDto value, $Res Function(_RideTemplateDto) _then) = __$RideTemplateDtoCopyWithImpl;
@override @useResult
$Res call({
 TeamPublicationDto team, String id, String slug, String name, String markdown, String visibility, String status, String createdAt, String updatedAt, int groupCount, List<RideTemplateGroupDto> groups, List<TagDto> tags, int? nextNumber
});


@override $TeamPublicationDtoCopyWith<$Res> get team;

}
/// @nodoc
class __$RideTemplateDtoCopyWithImpl<$Res>
    implements _$RideTemplateDtoCopyWith<$Res> {
  __$RideTemplateDtoCopyWithImpl(this._self, this._then);

  final _RideTemplateDto _self;
  final $Res Function(_RideTemplateDto) _then;

/// Create a copy of RideTemplateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? markdown = null,Object? visibility = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? groupCount = null,Object? groups = null,Object? tags = null,Object? nextNumber = freezed,}) {
  return _then(_RideTemplateDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,markdown: null == markdown ? _self.markdown : markdown // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,groupCount: null == groupCount ? _self.groupCount : groupCount // ignore: cast_nullable_to_non_nullable
as int,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<RideTemplateGroupDto>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,nextNumber: freezed == nextNumber ? _self.nextNumber : nextNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of RideTemplateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}
}

// dart format on
