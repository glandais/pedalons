// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'asset_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AssetDto {

/// ID (TSID)
 String get id;/// Filename
 String get fileName;/// Content-Type
 String get contentType;/// Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.
 String get url;/// Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.
 String? get imageUrl;/// image dimensions
 AssetDimensionsDto? get imageDimensions;/// Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.
 int? get size;
/// Create a copy of AssetDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssetDtoCopyWith<AssetDto> get copyWith => _$AssetDtoCopyWithImpl<AssetDto>(this as AssetDto, _$identity);

  /// Serializes this AssetDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AssetDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssetDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.contentType, _this.contentType) || other.contentType == _this.contentType)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.imageDimensions, _this.imageDimensions) || other.imageDimensions == _this.imageDimensions)&&(identical(other.size, _this.size) || other.size == _this.size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AssetDto;
  return Object.hash(runtimeType,_this.id,_this.fileName,_this.contentType,_this.url,_this.imageUrl,_this.imageDimensions,_this.size);
}

@override
String toString() {
  final _this = this as AssetDto;
  return 'AssetDto(id: ${_this.id}, fileName: ${_this.fileName}, contentType: ${_this.contentType}, url: ${_this.url}, imageUrl: ${_this.imageUrl}, imageDimensions: ${_this.imageDimensions}, size: ${_this.size})';
}


}

/// @nodoc
abstract mixin class $AssetDtoCopyWith<$Res>  {
  factory $AssetDtoCopyWith(AssetDto value, $Res Function(AssetDto) _then) = _$AssetDtoCopyWithImpl;
@useResult
$Res call({
 String id, String fileName, String contentType, String url, String? imageUrl, AssetDimensionsDto? imageDimensions, int? size
});


$AssetDimensionsDtoCopyWith<$Res>? get imageDimensions;

}
/// @nodoc
class _$AssetDtoCopyWithImpl<$Res>
    implements $AssetDtoCopyWith<$Res> {
  _$AssetDtoCopyWithImpl(this._self, this._then);

  final AssetDto _self;
  final $Res Function(AssetDto) _then;

/// Create a copy of AssetDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fileName = null,Object? contentType = null,Object? url = null,Object? imageUrl = freezed,Object? imageDimensions = freezed,Object? size = freezed,}) {
  return _then(AssetDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,imageDimensions: freezed == imageDimensions ? _self.imageDimensions : imageDimensions // ignore: cast_nullable_to_non_nullable
as AssetDimensionsDto?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of AssetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssetDimensionsDtoCopyWith<$Res>? get imageDimensions {
    if (_self.imageDimensions == null) {
    return null;
  }

  return $AssetDimensionsDtoCopyWith<$Res>(_self.imageDimensions!, (value) {
    return _then(_self.copyWith(imageDimensions: value));
  });
}
}


/// Adds pattern-matching-related methods to [AssetDto].
extension AssetDtoPatterns on AssetDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssetDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssetDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssetDto value)  $default,){
final _that = this;
switch (_that) {
case _AssetDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssetDto value)?  $default,){
final _that = this;
switch (_that) {
case _AssetDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fileName,  String contentType,  String url,  String? imageUrl,  AssetDimensionsDto? imageDimensions,  int? size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssetDto() when $default != null:
return $default(_that.id,_that.fileName,_that.contentType,_that.url,_that.imageUrl,_that.imageDimensions,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fileName,  String contentType,  String url,  String? imageUrl,  AssetDimensionsDto? imageDimensions,  int? size)  $default,) {final _that = this;
switch (_that) {
case _AssetDto():
return $default(_that.id,_that.fileName,_that.contentType,_that.url,_that.imageUrl,_that.imageDimensions,_that.size);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fileName,  String contentType,  String url,  String? imageUrl,  AssetDimensionsDto? imageDimensions,  int? size)?  $default,) {final _that = this;
switch (_that) {
case _AssetDto() when $default != null:
return $default(_that.id,_that.fileName,_that.contentType,_that.url,_that.imageUrl,_that.imageDimensions,_that.size);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AssetDto implements AssetDto {
  const _AssetDto({required this.id, required this.fileName, required this.contentType, required this.url, this.imageUrl, this.imageDimensions, this.size});
  factory _AssetDto.fromJson(Map<String, dynamic> json) => _$AssetDtoFromJson(json);

/// ID (TSID)
@override final  String id;
/// Filename
@override final  String fileName;
/// Content-Type
@override final  String contentType;
/// Download URL. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); use it as is.
@override final  String url;
/// Image URL template. Opaque: it may carry a query string (a cache-buster that changes when the file is replaced); substitute {size} only.
@override final  String? imageUrl;
/// image dimensions
@override final  AssetDimensionsDto? imageDimensions;
/// Size in bytes of the file a download returns (an image as re-encoded on upload); null while not yet known. Ignored in requests.
@override final  int? size;

/// Create a copy of AssetDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssetDtoCopyWith<_AssetDto> get copyWith => __$AssetDtoCopyWithImpl<_AssetDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssetDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssetDto&&(identical(other.id, id) || other.id == id)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.url, url) || other.url == url)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.imageDimensions, imageDimensions) || other.imageDimensions == imageDimensions)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,fileName,contentType,url,imageUrl,imageDimensions,size);
}

@override
String toString() {
    return 'AssetDto(id: $id, fileName: $fileName, contentType: $contentType, url: $url, imageUrl: $imageUrl, imageDimensions: $imageDimensions, size: $size)';
}


}

/// @nodoc
abstract mixin class _$AssetDtoCopyWith<$Res> implements $AssetDtoCopyWith<$Res> {
  factory _$AssetDtoCopyWith(_AssetDto value, $Res Function(_AssetDto) _then) = __$AssetDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String fileName, String contentType, String url, String? imageUrl, AssetDimensionsDto? imageDimensions, int? size
});


@override $AssetDimensionsDtoCopyWith<$Res>? get imageDimensions;

}
/// @nodoc
class __$AssetDtoCopyWithImpl<$Res>
    implements _$AssetDtoCopyWith<$Res> {
  __$AssetDtoCopyWithImpl(this._self, this._then);

  final _AssetDto _self;
  final $Res Function(_AssetDto) _then;

/// Create a copy of AssetDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fileName = null,Object? contentType = null,Object? url = null,Object? imageUrl = freezed,Object? imageDimensions = freezed,Object? size = freezed,}) {
  return _then(_AssetDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,imageDimensions: freezed == imageDimensions ? _self.imageDimensions : imageDimensions // ignore: cast_nullable_to_non_nullable
as AssetDimensionsDto?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of AssetDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AssetDimensionsDtoCopyWith<$Res>? get imageDimensions {
    if (_self.imageDimensions == null) {
    return null;
  }

  return $AssetDimensionsDtoCopyWith<$Res>(_self.imageDimensions!, (value) {
    return _then(_self.copyWith(imageDimensions: value));
  });
}
}

// dart format on
