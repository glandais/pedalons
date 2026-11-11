// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'content_permissions_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ContentPermissionsDto {

/// Whether the caller may edit this entity (the update endpoints would accept it). For a trip stage, whether they may edit its trip, which a stage is written through. For the team's about page, whether they may edit it through the team update, the only way it is written.
 bool get canEdit;/// Whether the caller may delete this entity. For a trip stage, whether they may delete its trip.
 bool get canDelete;/// Whether search engines may index the entity's page: the rule of the sitemap — entity PUBLIC, team PUBLIC, published or cancelled, not hidden by moderation. False means the page must carry noindex. A trip stage carries its trip's answer.
 bool get indexable;/// Rides and trips only: whether the caller may register — a member of the team (or a platform admin), the entity published. On a detail it is exact about timing too: false once every group of the ride has left or the trip is finished, as the join endpoints answer. On list rows it does not look at timing, so it may be true on a row and false on the detail of the same entity. Never counts capacity: a full group still refuses. Absent on the other types.
 bool? get canRegister;/// Whether the caller may read and write the comment thread: a member of the team or a platform admin, whatever the entity's visibility. Absent on the types that carry no comments (team pages, ads).
 bool? get canComment;/// Rides and trips only: whether the caller may see who takes part (names, the participants endpoints). Same rule as canComment. When false, only the counts are sent. Absent on the other types.
 bool? get canSeeParticipants;/// The visibilities this entity may be saved with, in the order of the Visibility enum; an editor hides its selector when there is only one. For a route used by a ride or a trip that is not TEAM (drafts included, deleted ones not), TEAM is left out: saving it as TEAM is refused with INCOMPATIBLE_VISIBILITY. That can leave the list empty, when the team accepts nothing but TEAM any more: the route cannot be saved until those usages go TEAM. Present on a detail only: absent on list rows, on embedded summaries, on the types without a visibility of their own (trip stages) and on the team's about page, whose visibility no endpoint sets. Clients that create read TeamDetailDto.allowedContentVisibilities instead.
 List<Visibility>? get allowedVisibilities;
/// Create a copy of ContentPermissionsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContentPermissionsDtoCopyWith<ContentPermissionsDto> get copyWith => _$ContentPermissionsDtoCopyWithImpl<ContentPermissionsDto>(this as ContentPermissionsDto, _$identity);

  /// Serializes this ContentPermissionsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ContentPermissionsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContentPermissionsDto&&(identical(other.canEdit, _this.canEdit) || other.canEdit == _this.canEdit)&&(identical(other.canDelete, _this.canDelete) || other.canDelete == _this.canDelete)&&(identical(other.indexable, _this.indexable) || other.indexable == _this.indexable)&&(identical(other.canRegister, _this.canRegister) || other.canRegister == _this.canRegister)&&(identical(other.canComment, _this.canComment) || other.canComment == _this.canComment)&&(identical(other.canSeeParticipants, _this.canSeeParticipants) || other.canSeeParticipants == _this.canSeeParticipants)&&const DeepCollectionEquality().equals(other.allowedVisibilities, _this.allowedVisibilities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ContentPermissionsDto;
  return Object.hash(runtimeType,_this.canEdit,_this.canDelete,_this.indexable,_this.canRegister,_this.canComment,_this.canSeeParticipants,const DeepCollectionEquality().hash(_this.allowedVisibilities));
}

@override
String toString() {
  final _this = this as ContentPermissionsDto;
  return 'ContentPermissionsDto(canEdit: ${_this.canEdit}, canDelete: ${_this.canDelete}, indexable: ${_this.indexable}, canRegister: ${_this.canRegister}, canComment: ${_this.canComment}, canSeeParticipants: ${_this.canSeeParticipants}, allowedVisibilities: ${_this.allowedVisibilities})';
}


}

/// @nodoc
abstract mixin class $ContentPermissionsDtoCopyWith<$Res>  {
  factory $ContentPermissionsDtoCopyWith(ContentPermissionsDto value, $Res Function(ContentPermissionsDto) _then) = _$ContentPermissionsDtoCopyWithImpl;
@useResult
$Res call({
 bool canEdit, bool canDelete, bool indexable, bool? canRegister, bool? canComment, bool? canSeeParticipants, List<Visibility>? allowedVisibilities
});




}
/// @nodoc
class _$ContentPermissionsDtoCopyWithImpl<$Res>
    implements $ContentPermissionsDtoCopyWith<$Res> {
  _$ContentPermissionsDtoCopyWithImpl(this._self, this._then);

  final ContentPermissionsDto _self;
  final $Res Function(ContentPermissionsDto) _then;

/// Create a copy of ContentPermissionsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? canEdit = null,Object? canDelete = null,Object? indexable = null,Object? canRegister = freezed,Object? canComment = freezed,Object? canSeeParticipants = freezed,Object? allowedVisibilities = freezed,}) {
  return _then(ContentPermissionsDto(
canEdit: null == canEdit ? _self.canEdit : canEdit // ignore: cast_nullable_to_non_nullable
as bool,canDelete: null == canDelete ? _self.canDelete : canDelete // ignore: cast_nullable_to_non_nullable
as bool,indexable: null == indexable ? _self.indexable : indexable // ignore: cast_nullable_to_non_nullable
as bool,canRegister: freezed == canRegister ? _self.canRegister : canRegister // ignore: cast_nullable_to_non_nullable
as bool?,canComment: freezed == canComment ? _self.canComment : canComment // ignore: cast_nullable_to_non_nullable
as bool?,canSeeParticipants: freezed == canSeeParticipants ? _self.canSeeParticipants : canSeeParticipants // ignore: cast_nullable_to_non_nullable
as bool?,allowedVisibilities: freezed == allowedVisibilities ? _self.allowedVisibilities : allowedVisibilities // ignore: cast_nullable_to_non_nullable
as List<Visibility>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ContentPermissionsDto].
extension ContentPermissionsDtoPatterns on ContentPermissionsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContentPermissionsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContentPermissionsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContentPermissionsDto value)  $default,){
final _that = this;
switch (_that) {
case _ContentPermissionsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContentPermissionsDto value)?  $default,){
final _that = this;
switch (_that) {
case _ContentPermissionsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool canEdit,  bool canDelete,  bool indexable,  bool? canRegister,  bool? canComment,  bool? canSeeParticipants,  List<Visibility>? allowedVisibilities)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContentPermissionsDto() when $default != null:
return $default(_that.canEdit,_that.canDelete,_that.indexable,_that.canRegister,_that.canComment,_that.canSeeParticipants,_that.allowedVisibilities);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool canEdit,  bool canDelete,  bool indexable,  bool? canRegister,  bool? canComment,  bool? canSeeParticipants,  List<Visibility>? allowedVisibilities)  $default,) {final _that = this;
switch (_that) {
case _ContentPermissionsDto():
return $default(_that.canEdit,_that.canDelete,_that.indexable,_that.canRegister,_that.canComment,_that.canSeeParticipants,_that.allowedVisibilities);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool canEdit,  bool canDelete,  bool indexable,  bool? canRegister,  bool? canComment,  bool? canSeeParticipants,  List<Visibility>? allowedVisibilities)?  $default,) {final _that = this;
switch (_that) {
case _ContentPermissionsDto() when $default != null:
return $default(_that.canEdit,_that.canDelete,_that.indexable,_that.canRegister,_that.canComment,_that.canSeeParticipants,_that.allowedVisibilities);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ContentPermissionsDto implements ContentPermissionsDto {
  const _ContentPermissionsDto({required this.canEdit, required this.canDelete, required this.indexable, this.canRegister, this.canComment, this.canSeeParticipants,  List<Visibility>? allowedVisibilities}): _allowedVisibilities = allowedVisibilities;
  factory _ContentPermissionsDto.fromJson(Map<String, dynamic> json) => _$ContentPermissionsDtoFromJson(json);

/// Whether the caller may edit this entity (the update endpoints would accept it). For a trip stage, whether they may edit its trip, which a stage is written through. For the team's about page, whether they may edit it through the team update, the only way it is written.
@override final  bool canEdit;
/// Whether the caller may delete this entity. For a trip stage, whether they may delete its trip.
@override final  bool canDelete;
/// Whether search engines may index the entity's page: the rule of the sitemap — entity PUBLIC, team PUBLIC, published or cancelled, not hidden by moderation. False means the page must carry noindex. A trip stage carries its trip's answer.
@override final  bool indexable;
/// Rides and trips only: whether the caller may register — a member of the team (or a platform admin), the entity published. On a detail it is exact about timing too: false once every group of the ride has left or the trip is finished, as the join endpoints answer. On list rows it does not look at timing, so it may be true on a row and false on the detail of the same entity. Never counts capacity: a full group still refuses. Absent on the other types.
@override final  bool? canRegister;
/// Whether the caller may read and write the comment thread: a member of the team or a platform admin, whatever the entity's visibility. Absent on the types that carry no comments (team pages, ads).
@override final  bool? canComment;
/// Rides and trips only: whether the caller may see who takes part (names, the participants endpoints). Same rule as canComment. When false, only the counts are sent. Absent on the other types.
@override final  bool? canSeeParticipants;
/// The visibilities this entity may be saved with, in the order of the Visibility enum; an editor hides its selector when there is only one. For a route used by a ride or a trip that is not TEAM (drafts included, deleted ones not), TEAM is left out: saving it as TEAM is refused with INCOMPATIBLE_VISIBILITY. That can leave the list empty, when the team accepts nothing but TEAM any more: the route cannot be saved until those usages go TEAM. Present on a detail only: absent on list rows, on embedded summaries, on the types without a visibility of their own (trip stages) and on the team's about page, whose visibility no endpoint sets. Clients that create read TeamDetailDto.allowedContentVisibilities instead.
 final  List<Visibility>? _allowedVisibilities;
/// The visibilities this entity may be saved with, in the order of the Visibility enum; an editor hides its selector when there is only one. For a route used by a ride or a trip that is not TEAM (drafts included, deleted ones not), TEAM is left out: saving it as TEAM is refused with INCOMPATIBLE_VISIBILITY. That can leave the list empty, when the team accepts nothing but TEAM any more: the route cannot be saved until those usages go TEAM. Present on a detail only: absent on list rows, on embedded summaries, on the types without a visibility of their own (trip stages) and on the team's about page, whose visibility no endpoint sets. Clients that create read TeamDetailDto.allowedContentVisibilities instead.
@override List<Visibility>? get allowedVisibilities {
  final value = _allowedVisibilities;
  if (value == null) return null;
  if (_allowedVisibilities is EqualUnmodifiableListView) return _allowedVisibilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of ContentPermissionsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContentPermissionsDtoCopyWith<_ContentPermissionsDto> get copyWith => __$ContentPermissionsDtoCopyWithImpl<_ContentPermissionsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContentPermissionsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContentPermissionsDto&&(identical(other.canEdit, canEdit) || other.canEdit == canEdit)&&(identical(other.canDelete, canDelete) || other.canDelete == canDelete)&&(identical(other.indexable, indexable) || other.indexable == indexable)&&(identical(other.canRegister, canRegister) || other.canRegister == canRegister)&&(identical(other.canComment, canComment) || other.canComment == canComment)&&(identical(other.canSeeParticipants, canSeeParticipants) || other.canSeeParticipants == canSeeParticipants)&&const DeepCollectionEquality().equals(other.allowedVisibilities, _allowedVisibilities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,canEdit,canDelete,indexable,canRegister,canComment,canSeeParticipants,const DeepCollectionEquality().hash(_allowedVisibilities));
}

@override
String toString() {
    return 'ContentPermissionsDto(canEdit: $canEdit, canDelete: $canDelete, indexable: $indexable, canRegister: $canRegister, canComment: $canComment, canSeeParticipants: $canSeeParticipants, allowedVisibilities: $allowedVisibilities)';
}


}

/// @nodoc
abstract mixin class _$ContentPermissionsDtoCopyWith<$Res> implements $ContentPermissionsDtoCopyWith<$Res> {
  factory _$ContentPermissionsDtoCopyWith(_ContentPermissionsDto value, $Res Function(_ContentPermissionsDto) _then) = __$ContentPermissionsDtoCopyWithImpl;
@override @useResult
$Res call({
 bool canEdit, bool canDelete, bool indexable, bool? canRegister, bool? canComment, bool? canSeeParticipants, List<Visibility>? allowedVisibilities
});




}
/// @nodoc
class __$ContentPermissionsDtoCopyWithImpl<$Res>
    implements _$ContentPermissionsDtoCopyWith<$Res> {
  __$ContentPermissionsDtoCopyWithImpl(this._self, this._then);

  final _ContentPermissionsDto _self;
  final $Res Function(_ContentPermissionsDto) _then;

/// Create a copy of ContentPermissionsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? canEdit = null,Object? canDelete = null,Object? indexable = null,Object? canRegister = freezed,Object? canComment = freezed,Object? canSeeParticipants = freezed,Object? allowedVisibilities = freezed,}) {
  return _then(_ContentPermissionsDto(
canEdit: null == canEdit ? _self.canEdit : canEdit // ignore: cast_nullable_to_non_nullable
as bool,canDelete: null == canDelete ? _self.canDelete : canDelete // ignore: cast_nullable_to_non_nullable
as bool,indexable: null == indexable ? _self.indexable : indexable // ignore: cast_nullable_to_non_nullable
as bool,canRegister: freezed == canRegister ? _self.canRegister : canRegister // ignore: cast_nullable_to_non_nullable
as bool?,canComment: freezed == canComment ? _self.canComment : canComment // ignore: cast_nullable_to_non_nullable
as bool?,canSeeParticipants: freezed == canSeeParticipants ? _self.canSeeParticipants : canSeeParticipants // ignore: cast_nullable_to_non_nullable
as bool?,allowedVisibilities: freezed == allowedVisibilities ? _self._allowedVisibilities : allowedVisibilities // ignore: cast_nullable_to_non_nullable
as List<Visibility>?,
  ));
}


}

// dart format on
