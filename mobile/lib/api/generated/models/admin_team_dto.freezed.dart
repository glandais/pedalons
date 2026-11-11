// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_team_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdminTeamDto {

/// Team ID (TSID)
 String get id;/// Team name
 String get name;/// Team URL slug
 String get slug;/// Domain ID this team belongs to
 String get domainId;/// Domain hostname
 String get domainName;/// Team visibility
 String get visibility;/// Whether visibility is editable by team admins
 bool get visibilityEditable;/// Whether any domain user can join this team
 bool get joinable;/// Whether team admins can add members
 bool get addMemberAllowed;/// Whether the interactive route planner is open to this team
 bool get enableRoutePlanner;/// Whether a private team may publish content as public or unlisted, readable by link only and kept out of every listing
 bool get publicContentAllowed;/// Is team soft-deleted
 bool get deleted;/// Number of members
 int get memberCount;/// Team creation timestamp
 String get createdAt;
/// Create a copy of AdminTeamDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdminTeamDtoCopyWith<AdminTeamDto> get copyWith => _$AdminTeamDtoCopyWithImpl<AdminTeamDto>(this as AdminTeamDto, _$identity);

  /// Serializes this AdminTeamDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AdminTeamDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdminTeamDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.domainId, _this.domainId) || other.domainId == _this.domainId)&&(identical(other.domainName, _this.domainName) || other.domainName == _this.domainName)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.visibilityEditable, _this.visibilityEditable) || other.visibilityEditable == _this.visibilityEditable)&&(identical(other.joinable, _this.joinable) || other.joinable == _this.joinable)&&(identical(other.addMemberAllowed, _this.addMemberAllowed) || other.addMemberAllowed == _this.addMemberAllowed)&&(identical(other.enableRoutePlanner, _this.enableRoutePlanner) || other.enableRoutePlanner == _this.enableRoutePlanner)&&(identical(other.publicContentAllowed, _this.publicContentAllowed) || other.publicContentAllowed == _this.publicContentAllowed)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.memberCount, _this.memberCount) || other.memberCount == _this.memberCount)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AdminTeamDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.slug,_this.domainId,_this.domainName,_this.visibility,_this.visibilityEditable,_this.joinable,_this.addMemberAllowed,_this.enableRoutePlanner,_this.publicContentAllowed,_this.deleted,_this.memberCount,_this.createdAt);
}

@override
String toString() {
  final _this = this as AdminTeamDto;
  return 'AdminTeamDto(id: ${_this.id}, name: ${_this.name}, slug: ${_this.slug}, domainId: ${_this.domainId}, domainName: ${_this.domainName}, visibility: ${_this.visibility}, visibilityEditable: ${_this.visibilityEditable}, joinable: ${_this.joinable}, addMemberAllowed: ${_this.addMemberAllowed}, enableRoutePlanner: ${_this.enableRoutePlanner}, publicContentAllowed: ${_this.publicContentAllowed}, deleted: ${_this.deleted}, memberCount: ${_this.memberCount}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $AdminTeamDtoCopyWith<$Res>  {
  factory $AdminTeamDtoCopyWith(AdminTeamDto value, $Res Function(AdminTeamDto) _then) = _$AdminTeamDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, String slug, String domainId, String domainName, String visibility, bool visibilityEditable, bool joinable, bool addMemberAllowed, bool enableRoutePlanner, bool publicContentAllowed, bool deleted, int memberCount, String createdAt
});




}
/// @nodoc
class _$AdminTeamDtoCopyWithImpl<$Res>
    implements $AdminTeamDtoCopyWith<$Res> {
  _$AdminTeamDtoCopyWithImpl(this._self, this._then);

  final AdminTeamDto _self;
  final $Res Function(AdminTeamDto) _then;

/// Create a copy of AdminTeamDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? domainId = null,Object? domainName = null,Object? visibility = null,Object? visibilityEditable = null,Object? joinable = null,Object? addMemberAllowed = null,Object? enableRoutePlanner = null,Object? publicContentAllowed = null,Object? deleted = null,Object? memberCount = null,Object? createdAt = null,}) {
  return _then(AdminTeamDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,domainId: null == domainId ? _self.domainId : domainId // ignore: cast_nullable_to_non_nullable
as String,domainName: null == domainName ? _self.domainName : domainName // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,visibilityEditable: null == visibilityEditable ? _self.visibilityEditable : visibilityEditable // ignore: cast_nullable_to_non_nullable
as bool,joinable: null == joinable ? _self.joinable : joinable // ignore: cast_nullable_to_non_nullable
as bool,addMemberAllowed: null == addMemberAllowed ? _self.addMemberAllowed : addMemberAllowed // ignore: cast_nullable_to_non_nullable
as bool,enableRoutePlanner: null == enableRoutePlanner ? _self.enableRoutePlanner : enableRoutePlanner // ignore: cast_nullable_to_non_nullable
as bool,publicContentAllowed: null == publicContentAllowed ? _self.publicContentAllowed : publicContentAllowed // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AdminTeamDto].
extension AdminTeamDtoPatterns on AdminTeamDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdminTeamDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdminTeamDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdminTeamDto value)  $default,){
final _that = this;
switch (_that) {
case _AdminTeamDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdminTeamDto value)?  $default,){
final _that = this;
switch (_that) {
case _AdminTeamDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String domainId,  String domainName,  String visibility,  bool visibilityEditable,  bool joinable,  bool addMemberAllowed,  bool enableRoutePlanner,  bool publicContentAllowed,  bool deleted,  int memberCount,  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdminTeamDto() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.domainId,_that.domainName,_that.visibility,_that.visibilityEditable,_that.joinable,_that.addMemberAllowed,_that.enableRoutePlanner,_that.publicContentAllowed,_that.deleted,_that.memberCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String domainId,  String domainName,  String visibility,  bool visibilityEditable,  bool joinable,  bool addMemberAllowed,  bool enableRoutePlanner,  bool publicContentAllowed,  bool deleted,  int memberCount,  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _AdminTeamDto():
return $default(_that.id,_that.name,_that.slug,_that.domainId,_that.domainName,_that.visibility,_that.visibilityEditable,_that.joinable,_that.addMemberAllowed,_that.enableRoutePlanner,_that.publicContentAllowed,_that.deleted,_that.memberCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String slug,  String domainId,  String domainName,  String visibility,  bool visibilityEditable,  bool joinable,  bool addMemberAllowed,  bool enableRoutePlanner,  bool publicContentAllowed,  bool deleted,  int memberCount,  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _AdminTeamDto() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.domainId,_that.domainName,_that.visibility,_that.visibilityEditable,_that.joinable,_that.addMemberAllowed,_that.enableRoutePlanner,_that.publicContentAllowed,_that.deleted,_that.memberCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdminTeamDto implements AdminTeamDto {
  const _AdminTeamDto({required this.id, required this.name, required this.slug, required this.domainId, required this.domainName, required this.visibility, required this.visibilityEditable, required this.joinable, required this.addMemberAllowed, required this.enableRoutePlanner, required this.publicContentAllowed, required this.deleted, required this.memberCount, required this.createdAt});
  factory _AdminTeamDto.fromJson(Map<String, dynamic> json) => _$AdminTeamDtoFromJson(json);

/// Team ID (TSID)
@override final  String id;
/// Team name
@override final  String name;
/// Team URL slug
@override final  String slug;
/// Domain ID this team belongs to
@override final  String domainId;
/// Domain hostname
@override final  String domainName;
/// Team visibility
@override final  String visibility;
/// Whether visibility is editable by team admins
@override final  bool visibilityEditable;
/// Whether any domain user can join this team
@override final  bool joinable;
/// Whether team admins can add members
@override final  bool addMemberAllowed;
/// Whether the interactive route planner is open to this team
@override final  bool enableRoutePlanner;
/// Whether a private team may publish content as public or unlisted, readable by link only and kept out of every listing
@override final  bool publicContentAllowed;
/// Is team soft-deleted
@override final  bool deleted;
/// Number of members
@override final  int memberCount;
/// Team creation timestamp
@override final  String createdAt;

/// Create a copy of AdminTeamDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdminTeamDtoCopyWith<_AdminTeamDto> get copyWith => __$AdminTeamDtoCopyWithImpl<_AdminTeamDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdminTeamDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdminTeamDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.domainId, domainId) || other.domainId == domainId)&&(identical(other.domainName, domainName) || other.domainName == domainName)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.visibilityEditable, visibilityEditable) || other.visibilityEditable == visibilityEditable)&&(identical(other.joinable, joinable) || other.joinable == joinable)&&(identical(other.addMemberAllowed, addMemberAllowed) || other.addMemberAllowed == addMemberAllowed)&&(identical(other.enableRoutePlanner, enableRoutePlanner) || other.enableRoutePlanner == enableRoutePlanner)&&(identical(other.publicContentAllowed, publicContentAllowed) || other.publicContentAllowed == publicContentAllowed)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,slug,domainId,domainName,visibility,visibilityEditable,joinable,addMemberAllowed,enableRoutePlanner,publicContentAllowed,deleted,memberCount,createdAt);
}

@override
String toString() {
    return 'AdminTeamDto(id: $id, name: $name, slug: $slug, domainId: $domainId, domainName: $domainName, visibility: $visibility, visibilityEditable: $visibilityEditable, joinable: $joinable, addMemberAllowed: $addMemberAllowed, enableRoutePlanner: $enableRoutePlanner, publicContentAllowed: $publicContentAllowed, deleted: $deleted, memberCount: $memberCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AdminTeamDtoCopyWith<$Res> implements $AdminTeamDtoCopyWith<$Res> {
  factory _$AdminTeamDtoCopyWith(_AdminTeamDto value, $Res Function(_AdminTeamDto) _then) = __$AdminTeamDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String slug, String domainId, String domainName, String visibility, bool visibilityEditable, bool joinable, bool addMemberAllowed, bool enableRoutePlanner, bool publicContentAllowed, bool deleted, int memberCount, String createdAt
});




}
/// @nodoc
class __$AdminTeamDtoCopyWithImpl<$Res>
    implements _$AdminTeamDtoCopyWith<$Res> {
  __$AdminTeamDtoCopyWithImpl(this._self, this._then);

  final _AdminTeamDto _self;
  final $Res Function(_AdminTeamDto) _then;

/// Create a copy of AdminTeamDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? domainId = null,Object? domainName = null,Object? visibility = null,Object? visibilityEditable = null,Object? joinable = null,Object? addMemberAllowed = null,Object? enableRoutePlanner = null,Object? publicContentAllowed = null,Object? deleted = null,Object? memberCount = null,Object? createdAt = null,}) {
  return _then(_AdminTeamDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,domainId: null == domainId ? _self.domainId : domainId // ignore: cast_nullable_to_non_nullable
as String,domainName: null == domainName ? _self.domainName : domainName // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,visibilityEditable: null == visibilityEditable ? _self.visibilityEditable : visibilityEditable // ignore: cast_nullable_to_non_nullable
as bool,joinable: null == joinable ? _self.joinable : joinable // ignore: cast_nullable_to_non_nullable
as bool,addMemberAllowed: null == addMemberAllowed ? _self.addMemberAllowed : addMemberAllowed // ignore: cast_nullable_to_non_nullable
as bool,enableRoutePlanner: null == enableRoutePlanner ? _self.enableRoutePlanner : enableRoutePlanner // ignore: cast_nullable_to_non_nullable
as bool,publicContentAllowed: null == publicContentAllowed ? _self.publicContentAllowed : publicContentAllowed // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
