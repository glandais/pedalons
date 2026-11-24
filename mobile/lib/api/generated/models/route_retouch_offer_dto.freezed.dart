// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_retouch_offer_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteRetouchOfferDto {

/// The retouch can be asked for now
 bool get available;/// The operations offered; empty when not available
 List<RouteRetouchOperation> get operations;/// Why not. NOT_ALLOWED and ENGINE_UNAVAILABLE: show nothing. NOT_READY: the route is still being analysed (show the action disabled). UNSUPPORTED: show nothing. Absent when available
 String? get unavailableReason;/// Length of the route's raw track in metres. Absent when not available
 double? get originalDistanceM;/// Smallest total distance of a RESIZE, in kilometres, rounded inwards to the tenth
 double? get minDistanceKm;/// Largest total distance of a RESIZE, in kilometres, rounded inwards to the tenth
 double? get maxDistanceKm;/// Smallest change of a RESIZE, in kilometres, above or below the route's length
 double? get minChangeKm;/// Largest change of a RESIZE as a share of the route's length, 0 to 1
 double? get maxChangeShare;/// How far from a way of the ride type the new finish may be, in metres
 double? get endSnapM;/// Proposals returned at most
 int? get proposalsMax;/// The ride type the engine is asked for, from the route's surface type
 String? get rideType;
/// Create a copy of RouteRetouchOfferDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteRetouchOfferDtoCopyWith<RouteRetouchOfferDto> get copyWith => _$RouteRetouchOfferDtoCopyWithImpl<RouteRetouchOfferDto>(this as RouteRetouchOfferDto, _$identity);

  /// Serializes this RouteRetouchOfferDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteRetouchOfferDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteRetouchOfferDto&&(identical(other.available, _this.available) || other.available == _this.available)&&const DeepCollectionEquality().equals(other.operations, _this.operations)&&(identical(other.unavailableReason, _this.unavailableReason) || other.unavailableReason == _this.unavailableReason)&&(identical(other.originalDistanceM, _this.originalDistanceM) || other.originalDistanceM == _this.originalDistanceM)&&(identical(other.minDistanceKm, _this.minDistanceKm) || other.minDistanceKm == _this.minDistanceKm)&&(identical(other.maxDistanceKm, _this.maxDistanceKm) || other.maxDistanceKm == _this.maxDistanceKm)&&(identical(other.minChangeKm, _this.minChangeKm) || other.minChangeKm == _this.minChangeKm)&&(identical(other.maxChangeShare, _this.maxChangeShare) || other.maxChangeShare == _this.maxChangeShare)&&(identical(other.endSnapM, _this.endSnapM) || other.endSnapM == _this.endSnapM)&&(identical(other.proposalsMax, _this.proposalsMax) || other.proposalsMax == _this.proposalsMax)&&(identical(other.rideType, _this.rideType) || other.rideType == _this.rideType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteRetouchOfferDto;
  return Object.hash(runtimeType,_this.available,const DeepCollectionEquality().hash(_this.operations),_this.unavailableReason,_this.originalDistanceM,_this.minDistanceKm,_this.maxDistanceKm,_this.minChangeKm,_this.maxChangeShare,_this.endSnapM,_this.proposalsMax,_this.rideType);
}

@override
String toString() {
  final _this = this as RouteRetouchOfferDto;
  return 'RouteRetouchOfferDto(available: ${_this.available}, operations: ${_this.operations}, unavailableReason: ${_this.unavailableReason}, originalDistanceM: ${_this.originalDistanceM}, minDistanceKm: ${_this.minDistanceKm}, maxDistanceKm: ${_this.maxDistanceKm}, minChangeKm: ${_this.minChangeKm}, maxChangeShare: ${_this.maxChangeShare}, endSnapM: ${_this.endSnapM}, proposalsMax: ${_this.proposalsMax}, rideType: ${_this.rideType})';
}


}

/// @nodoc
abstract mixin class $RouteRetouchOfferDtoCopyWith<$Res>  {
  factory $RouteRetouchOfferDtoCopyWith(RouteRetouchOfferDto value, $Res Function(RouteRetouchOfferDto) _then) = _$RouteRetouchOfferDtoCopyWithImpl;
@useResult
$Res call({
 bool available, List<RouteRetouchOperation> operations, String? unavailableReason, double? originalDistanceM, double? minDistanceKm, double? maxDistanceKm, double? minChangeKm, double? maxChangeShare, double? endSnapM, int? proposalsMax, String? rideType
});




}
/// @nodoc
class _$RouteRetouchOfferDtoCopyWithImpl<$Res>
    implements $RouteRetouchOfferDtoCopyWith<$Res> {
  _$RouteRetouchOfferDtoCopyWithImpl(this._self, this._then);

  final RouteRetouchOfferDto _self;
  final $Res Function(RouteRetouchOfferDto) _then;

/// Create a copy of RouteRetouchOfferDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? available = null,Object? operations = null,Object? unavailableReason = freezed,Object? originalDistanceM = freezed,Object? minDistanceKm = freezed,Object? maxDistanceKm = freezed,Object? minChangeKm = freezed,Object? maxChangeShare = freezed,Object? endSnapM = freezed,Object? proposalsMax = freezed,Object? rideType = freezed,}) {
  return _then(RouteRetouchOfferDto(
available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,operations: null == operations ? _self.operations : operations // ignore: cast_nullable_to_non_nullable
as List<RouteRetouchOperation>,unavailableReason: freezed == unavailableReason ? _self.unavailableReason : unavailableReason // ignore: cast_nullable_to_non_nullable
as String?,originalDistanceM: freezed == originalDistanceM ? _self.originalDistanceM : originalDistanceM // ignore: cast_nullable_to_non_nullable
as double?,minDistanceKm: freezed == minDistanceKm ? _self.minDistanceKm : minDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,maxDistanceKm: freezed == maxDistanceKm ? _self.maxDistanceKm : maxDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,minChangeKm: freezed == minChangeKm ? _self.minChangeKm : minChangeKm // ignore: cast_nullable_to_non_nullable
as double?,maxChangeShare: freezed == maxChangeShare ? _self.maxChangeShare : maxChangeShare // ignore: cast_nullable_to_non_nullable
as double?,endSnapM: freezed == endSnapM ? _self.endSnapM : endSnapM // ignore: cast_nullable_to_non_nullable
as double?,proposalsMax: freezed == proposalsMax ? _self.proposalsMax : proposalsMax // ignore: cast_nullable_to_non_nullable
as int?,rideType: freezed == rideType ? _self.rideType : rideType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteRetouchOfferDto].
extension RouteRetouchOfferDtoPatterns on RouteRetouchOfferDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteRetouchOfferDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteRetouchOfferDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteRetouchOfferDto value)  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchOfferDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteRetouchOfferDto value)?  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchOfferDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool available,  List<RouteRetouchOperation> operations,  String? unavailableReason,  double? originalDistanceM,  double? minDistanceKm,  double? maxDistanceKm,  double? minChangeKm,  double? maxChangeShare,  double? endSnapM,  int? proposalsMax,  String? rideType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteRetouchOfferDto() when $default != null:
return $default(_that.available,_that.operations,_that.unavailableReason,_that.originalDistanceM,_that.minDistanceKm,_that.maxDistanceKm,_that.minChangeKm,_that.maxChangeShare,_that.endSnapM,_that.proposalsMax,_that.rideType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool available,  List<RouteRetouchOperation> operations,  String? unavailableReason,  double? originalDistanceM,  double? minDistanceKm,  double? maxDistanceKm,  double? minChangeKm,  double? maxChangeShare,  double? endSnapM,  int? proposalsMax,  String? rideType)  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchOfferDto():
return $default(_that.available,_that.operations,_that.unavailableReason,_that.originalDistanceM,_that.minDistanceKm,_that.maxDistanceKm,_that.minChangeKm,_that.maxChangeShare,_that.endSnapM,_that.proposalsMax,_that.rideType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool available,  List<RouteRetouchOperation> operations,  String? unavailableReason,  double? originalDistanceM,  double? minDistanceKm,  double? maxDistanceKm,  double? minChangeKm,  double? maxChangeShare,  double? endSnapM,  int? proposalsMax,  String? rideType)?  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchOfferDto() when $default != null:
return $default(_that.available,_that.operations,_that.unavailableReason,_that.originalDistanceM,_that.minDistanceKm,_that.maxDistanceKm,_that.minChangeKm,_that.maxChangeShare,_that.endSnapM,_that.proposalsMax,_that.rideType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteRetouchOfferDto implements RouteRetouchOfferDto {
  const _RouteRetouchOfferDto({required this.available, required  List<RouteRetouchOperation> operations, this.unavailableReason, this.originalDistanceM, this.minDistanceKm, this.maxDistanceKm, this.minChangeKm, this.maxChangeShare, this.endSnapM, this.proposalsMax, this.rideType}): _operations = operations;
  factory _RouteRetouchOfferDto.fromJson(Map<String, dynamic> json) => _$RouteRetouchOfferDtoFromJson(json);

/// The retouch can be asked for now
@override final  bool available;
/// The operations offered; empty when not available
 final  List<RouteRetouchOperation> _operations;
/// The operations offered; empty when not available
@override List<RouteRetouchOperation> get operations {
  if (_operations is EqualUnmodifiableListView) return _operations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_operations);
}

/// Why not. NOT_ALLOWED and ENGINE_UNAVAILABLE: show nothing. NOT_READY: the route is still being analysed (show the action disabled). UNSUPPORTED: show nothing. Absent when available
@override final  String? unavailableReason;
/// Length of the route's raw track in metres. Absent when not available
@override final  double? originalDistanceM;
/// Smallest total distance of a RESIZE, in kilometres, rounded inwards to the tenth
@override final  double? minDistanceKm;
/// Largest total distance of a RESIZE, in kilometres, rounded inwards to the tenth
@override final  double? maxDistanceKm;
/// Smallest change of a RESIZE, in kilometres, above or below the route's length
@override final  double? minChangeKm;
/// Largest change of a RESIZE as a share of the route's length, 0 to 1
@override final  double? maxChangeShare;
/// How far from a way of the ride type the new finish may be, in metres
@override final  double? endSnapM;
/// Proposals returned at most
@override final  int? proposalsMax;
/// The ride type the engine is asked for, from the route's surface type
@override final  String? rideType;

/// Create a copy of RouteRetouchOfferDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteRetouchOfferDtoCopyWith<_RouteRetouchOfferDto> get copyWith => __$RouteRetouchOfferDtoCopyWithImpl<_RouteRetouchOfferDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteRetouchOfferDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteRetouchOfferDto&&(identical(other.available, available) || other.available == available)&&const DeepCollectionEquality().equals(other.operations, _operations)&&(identical(other.unavailableReason, unavailableReason) || other.unavailableReason == unavailableReason)&&(identical(other.originalDistanceM, originalDistanceM) || other.originalDistanceM == originalDistanceM)&&(identical(other.minDistanceKm, minDistanceKm) || other.minDistanceKm == minDistanceKm)&&(identical(other.maxDistanceKm, maxDistanceKm) || other.maxDistanceKm == maxDistanceKm)&&(identical(other.minChangeKm, minChangeKm) || other.minChangeKm == minChangeKm)&&(identical(other.maxChangeShare, maxChangeShare) || other.maxChangeShare == maxChangeShare)&&(identical(other.endSnapM, endSnapM) || other.endSnapM == endSnapM)&&(identical(other.proposalsMax, proposalsMax) || other.proposalsMax == proposalsMax)&&(identical(other.rideType, rideType) || other.rideType == rideType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,available,const DeepCollectionEquality().hash(_operations),unavailableReason,originalDistanceM,minDistanceKm,maxDistanceKm,minChangeKm,maxChangeShare,endSnapM,proposalsMax,rideType);
}

@override
String toString() {
    return 'RouteRetouchOfferDto(available: $available, operations: $operations, unavailableReason: $unavailableReason, originalDistanceM: $originalDistanceM, minDistanceKm: $minDistanceKm, maxDistanceKm: $maxDistanceKm, minChangeKm: $minChangeKm, maxChangeShare: $maxChangeShare, endSnapM: $endSnapM, proposalsMax: $proposalsMax, rideType: $rideType)';
}


}

/// @nodoc
abstract mixin class _$RouteRetouchOfferDtoCopyWith<$Res> implements $RouteRetouchOfferDtoCopyWith<$Res> {
  factory _$RouteRetouchOfferDtoCopyWith(_RouteRetouchOfferDto value, $Res Function(_RouteRetouchOfferDto) _then) = __$RouteRetouchOfferDtoCopyWithImpl;
@override @useResult
$Res call({
 bool available, List<RouteRetouchOperation> operations, String? unavailableReason, double? originalDistanceM, double? minDistanceKm, double? maxDistanceKm, double? minChangeKm, double? maxChangeShare, double? endSnapM, int? proposalsMax, String? rideType
});




}
/// @nodoc
class __$RouteRetouchOfferDtoCopyWithImpl<$Res>
    implements _$RouteRetouchOfferDtoCopyWith<$Res> {
  __$RouteRetouchOfferDtoCopyWithImpl(this._self, this._then);

  final _RouteRetouchOfferDto _self;
  final $Res Function(_RouteRetouchOfferDto) _then;

/// Create a copy of RouteRetouchOfferDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? available = null,Object? operations = null,Object? unavailableReason = freezed,Object? originalDistanceM = freezed,Object? minDistanceKm = freezed,Object? maxDistanceKm = freezed,Object? minChangeKm = freezed,Object? maxChangeShare = freezed,Object? endSnapM = freezed,Object? proposalsMax = freezed,Object? rideType = freezed,}) {
  return _then(_RouteRetouchOfferDto(
available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,operations: null == operations ? _self._operations : operations // ignore: cast_nullable_to_non_nullable
as List<RouteRetouchOperation>,unavailableReason: freezed == unavailableReason ? _self.unavailableReason : unavailableReason // ignore: cast_nullable_to_non_nullable
as String?,originalDistanceM: freezed == originalDistanceM ? _self.originalDistanceM : originalDistanceM // ignore: cast_nullable_to_non_nullable
as double?,minDistanceKm: freezed == minDistanceKm ? _self.minDistanceKm : minDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,maxDistanceKm: freezed == maxDistanceKm ? _self.maxDistanceKm : maxDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,minChangeKm: freezed == minChangeKm ? _self.minChangeKm : minChangeKm // ignore: cast_nullable_to_non_nullable
as double?,maxChangeShare: freezed == maxChangeShare ? _self.maxChangeShare : maxChangeShare // ignore: cast_nullable_to_non_nullable
as double?,endSnapM: freezed == endSnapM ? _self.endSnapM : endSnapM // ignore: cast_nullable_to_non_nullable
as double?,proposalsMax: freezed == proposalsMax ? _self.proposalsMax : proposalsMax // ignore: cast_nullable_to_non_nullable
as int?,rideType: freezed == rideType ? _self.rideType : rideType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
