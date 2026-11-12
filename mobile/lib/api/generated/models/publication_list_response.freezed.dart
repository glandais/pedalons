// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'publication_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicationListResponse {

/// List of publications
 List<PublicationDto> get publications;/// Total number of publications
 int get total;/// Current page number
 int get page;/// Page size
 int get size;/// With when=UPCOMING_FIRST only, null otherwise: how many of the 'total' rows are in the first section, « À venir » (rides and trips not over yet). They are the first upcomingTotal rows of the whole list, so the row at position page * size + i (i its index in 'publications') is « À venir » when that position is below upcomingTotal, « Plus tôt » otherwise; the second section counts total - upcomingTotal. Same filters and same instant as the page.
 int? get upcomingTotal;
/// Create a copy of PublicationListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicationListResponseCopyWith<PublicationListResponse> get copyWith => _$PublicationListResponseCopyWithImpl<PublicationListResponse>(this as PublicationListResponse, _$identity);

  /// Serializes this PublicationListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PublicationListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicationListResponse&&const DeepCollectionEquality().equals(other.publications, _this.publications)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.size, _this.size) || other.size == _this.size)&&(identical(other.upcomingTotal, _this.upcomingTotal) || other.upcomingTotal == _this.upcomingTotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PublicationListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.publications),_this.total,_this.page,_this.size,_this.upcomingTotal);
}

@override
String toString() {
  final _this = this as PublicationListResponse;
  return 'PublicationListResponse(publications: ${_this.publications}, total: ${_this.total}, page: ${_this.page}, size: ${_this.size}, upcomingTotal: ${_this.upcomingTotal})';
}


}

/// @nodoc
abstract mixin class $PublicationListResponseCopyWith<$Res>  {
  factory $PublicationListResponseCopyWith(PublicationListResponse value, $Res Function(PublicationListResponse) _then) = _$PublicationListResponseCopyWithImpl;
@useResult
$Res call({
 List<PublicationDto> publications, int total, int page, int size, int? upcomingTotal
});




}
/// @nodoc
class _$PublicationListResponseCopyWithImpl<$Res>
    implements $PublicationListResponseCopyWith<$Res> {
  _$PublicationListResponseCopyWithImpl(this._self, this._then);

  final PublicationListResponse _self;
  final $Res Function(PublicationListResponse) _then;

/// Create a copy of PublicationListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? publications = null,Object? total = null,Object? page = null,Object? size = null,Object? upcomingTotal = freezed,}) {
  return _then(PublicationListResponse(
publications: null == publications ? _self.publications : publications // ignore: cast_nullable_to_non_nullable
as List<PublicationDto>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,upcomingTotal: freezed == upcomingTotal ? _self.upcomingTotal : upcomingTotal // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicationListResponse].
extension PublicationListResponsePatterns on PublicationListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicationListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicationListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicationListResponse value)  $default,){
final _that = this;
switch (_that) {
case _PublicationListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicationListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _PublicationListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PublicationDto> publications,  int total,  int page,  int size,  int? upcomingTotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicationListResponse() when $default != null:
return $default(_that.publications,_that.total,_that.page,_that.size,_that.upcomingTotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PublicationDto> publications,  int total,  int page,  int size,  int? upcomingTotal)  $default,) {final _that = this;
switch (_that) {
case _PublicationListResponse():
return $default(_that.publications,_that.total,_that.page,_that.size,_that.upcomingTotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PublicationDto> publications,  int total,  int page,  int size,  int? upcomingTotal)?  $default,) {final _that = this;
switch (_that) {
case _PublicationListResponse() when $default != null:
return $default(_that.publications,_that.total,_that.page,_that.size,_that.upcomingTotal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicationListResponse implements PublicationListResponse {
  const _PublicationListResponse({required  List<PublicationDto> publications, required this.total, required this.page, required this.size, this.upcomingTotal}): _publications = publications;
  factory _PublicationListResponse.fromJson(Map<String, dynamic> json) => _$PublicationListResponseFromJson(json);

/// List of publications
 final  List<PublicationDto> _publications;
/// List of publications
@override List<PublicationDto> get publications {
  if (_publications is EqualUnmodifiableListView) return _publications;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_publications);
}

/// Total number of publications
@override final  int total;
/// Current page number
@override final  int page;
/// Page size
@override final  int size;
/// With when=UPCOMING_FIRST only, null otherwise: how many of the 'total' rows are in the first section, « À venir » (rides and trips not over yet). They are the first upcomingTotal rows of the whole list, so the row at position page * size + i (i its index in 'publications') is « À venir » when that position is below upcomingTotal, « Plus tôt » otherwise; the second section counts total - upcomingTotal. Same filters and same instant as the page.
@override final  int? upcomingTotal;

/// Create a copy of PublicationListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicationListResponseCopyWith<_PublicationListResponse> get copyWith => __$PublicationListResponseCopyWithImpl<_PublicationListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicationListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicationListResponse&&const DeepCollectionEquality().equals(other.publications, _publications)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.size, size) || other.size == size)&&(identical(other.upcomingTotal, upcomingTotal) || other.upcomingTotal == upcomingTotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_publications),total,page,size,upcomingTotal);
}

@override
String toString() {
    return 'PublicationListResponse(publications: $publications, total: $total, page: $page, size: $size, upcomingTotal: $upcomingTotal)';
}


}

/// @nodoc
abstract mixin class _$PublicationListResponseCopyWith<$Res> implements $PublicationListResponseCopyWith<$Res> {
  factory _$PublicationListResponseCopyWith(_PublicationListResponse value, $Res Function(_PublicationListResponse) _then) = __$PublicationListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<PublicationDto> publications, int total, int page, int size, int? upcomingTotal
});




}
/// @nodoc
class __$PublicationListResponseCopyWithImpl<$Res>
    implements _$PublicationListResponseCopyWith<$Res> {
  __$PublicationListResponseCopyWithImpl(this._self, this._then);

  final _PublicationListResponse _self;
  final $Res Function(_PublicationListResponse) _then;

/// Create a copy of PublicationListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? publications = null,Object? total = null,Object? page = null,Object? size = null,Object? upcomingTotal = freezed,}) {
  return _then(_PublicationListResponse(
publications: null == publications ? _self._publications : publications // ignore: cast_nullable_to_non_nullable
as List<PublicationDto>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,upcomingTotal: freezed == upcomingTotal ? _self.upcomingTotal : upcomingTotal // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
