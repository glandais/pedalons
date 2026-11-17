// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_page_summary_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamPageSummaryDto {

/// Page ID (TSID)
 String get id;/// Page title
 String get title;/// Page URL slug
 String get slug;/// Visibility level
 String get visibility;/// Page order
 int get order;/// Whether the page is soft-deleted
 bool get deleted;/// Publication status: a DRAFT is listed only to the team's administrators and the platform admin, who are told it is one (docs/LEDGER_*.md WEB-120)
 String get status;/// Hidden by moderation: listed only to the team's organisers, administrators and the platform admin (docs/LEDGER_*.md WEB-120)
 bool get moderationHidden;
/// Create a copy of TeamPageSummaryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamPageSummaryDtoCopyWith<TeamPageSummaryDto> get copyWith => _$TeamPageSummaryDtoCopyWithImpl<TeamPageSummaryDto>(this as TeamPageSummaryDto, _$identity);

  /// Serializes this TeamPageSummaryDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamPageSummaryDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamPageSummaryDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.order, _this.order) || other.order == _this.order)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.moderationHidden, _this.moderationHidden) || other.moderationHidden == _this.moderationHidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamPageSummaryDto;
  return Object.hash(runtimeType,_this.id,_this.title,_this.slug,_this.visibility,_this.order,_this.deleted,_this.status,_this.moderationHidden);
}

@override
String toString() {
  final _this = this as TeamPageSummaryDto;
  return 'TeamPageSummaryDto(id: ${_this.id}, title: ${_this.title}, slug: ${_this.slug}, visibility: ${_this.visibility}, order: ${_this.order}, deleted: ${_this.deleted}, status: ${_this.status}, moderationHidden: ${_this.moderationHidden})';
}


}

/// @nodoc
abstract mixin class $TeamPageSummaryDtoCopyWith<$Res>  {
  factory $TeamPageSummaryDtoCopyWith(TeamPageSummaryDto value, $Res Function(TeamPageSummaryDto) _then) = _$TeamPageSummaryDtoCopyWithImpl;
@useResult
$Res call({
 String id, String title, String slug, String visibility, int order, bool deleted, String status, bool moderationHidden
});




}
/// @nodoc
class _$TeamPageSummaryDtoCopyWithImpl<$Res>
    implements $TeamPageSummaryDtoCopyWith<$Res> {
  _$TeamPageSummaryDtoCopyWithImpl(this._self, this._then);

  final TeamPageSummaryDto _self;
  final $Res Function(TeamPageSummaryDto) _then;

/// Create a copy of TeamPageSummaryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? slug = null,Object? visibility = null,Object? order = null,Object? deleted = null,Object? status = null,Object? moderationHidden = null,}) {
  return _then(TeamPageSummaryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,moderationHidden: null == moderationHidden ? _self.moderationHidden : moderationHidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TeamPageSummaryDto].
extension TeamPageSummaryDtoPatterns on TeamPageSummaryDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamPageSummaryDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamPageSummaryDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamPageSummaryDto value)  $default,){
final _that = this;
switch (_that) {
case _TeamPageSummaryDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamPageSummaryDto value)?  $default,){
final _that = this;
switch (_that) {
case _TeamPageSummaryDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String slug,  String visibility,  int order,  bool deleted,  String status,  bool moderationHidden)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamPageSummaryDto() when $default != null:
return $default(_that.id,_that.title,_that.slug,_that.visibility,_that.order,_that.deleted,_that.status,_that.moderationHidden);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String slug,  String visibility,  int order,  bool deleted,  String status,  bool moderationHidden)  $default,) {final _that = this;
switch (_that) {
case _TeamPageSummaryDto():
return $default(_that.id,_that.title,_that.slug,_that.visibility,_that.order,_that.deleted,_that.status,_that.moderationHidden);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String slug,  String visibility,  int order,  bool deleted,  String status,  bool moderationHidden)?  $default,) {final _that = this;
switch (_that) {
case _TeamPageSummaryDto() when $default != null:
return $default(_that.id,_that.title,_that.slug,_that.visibility,_that.order,_that.deleted,_that.status,_that.moderationHidden);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamPageSummaryDto implements TeamPageSummaryDto {
  const _TeamPageSummaryDto({required this.id, required this.title, required this.slug, required this.visibility, required this.order, required this.deleted, required this.status, required this.moderationHidden});
  factory _TeamPageSummaryDto.fromJson(Map<String, dynamic> json) => _$TeamPageSummaryDtoFromJson(json);

/// Page ID (TSID)
@override final  String id;
/// Page title
@override final  String title;
/// Page URL slug
@override final  String slug;
/// Visibility level
@override final  String visibility;
/// Page order
@override final  int order;
/// Whether the page is soft-deleted
@override final  bool deleted;
/// Publication status: a DRAFT is listed only to the team's administrators and the platform admin, who are told it is one (docs/LEDGER_*.md WEB-120)
@override final  String status;
/// Hidden by moderation: listed only to the team's organisers, administrators and the platform admin (docs/LEDGER_*.md WEB-120)
@override final  bool moderationHidden;

/// Create a copy of TeamPageSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamPageSummaryDtoCopyWith<_TeamPageSummaryDto> get copyWith => __$TeamPageSummaryDtoCopyWithImpl<_TeamPageSummaryDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamPageSummaryDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamPageSummaryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.order, order) || other.order == order)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.status, status) || other.status == status)&&(identical(other.moderationHidden, moderationHidden) || other.moderationHidden == moderationHidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,slug,visibility,order,deleted,status,moderationHidden);
}

@override
String toString() {
    return 'TeamPageSummaryDto(id: $id, title: $title, slug: $slug, visibility: $visibility, order: $order, deleted: $deleted, status: $status, moderationHidden: $moderationHidden)';
}


}

/// @nodoc
abstract mixin class _$TeamPageSummaryDtoCopyWith<$Res> implements $TeamPageSummaryDtoCopyWith<$Res> {
  factory _$TeamPageSummaryDtoCopyWith(_TeamPageSummaryDto value, $Res Function(_TeamPageSummaryDto) _then) = __$TeamPageSummaryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String slug, String visibility, int order, bool deleted, String status, bool moderationHidden
});




}
/// @nodoc
class __$TeamPageSummaryDtoCopyWithImpl<$Res>
    implements _$TeamPageSummaryDtoCopyWith<$Res> {
  __$TeamPageSummaryDtoCopyWithImpl(this._self, this._then);

  final _TeamPageSummaryDto _self;
  final $Res Function(_TeamPageSummaryDto) _then;

/// Create a copy of TeamPageSummaryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? slug = null,Object? visibility = null,Object? order = null,Object? deleted = null,Object? status = null,Object? moderationHidden = null,}) {
  return _then(_TeamPageSummaryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,moderationHidden: null == moderationHidden ? _self.moderationHidden : moderationHidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
