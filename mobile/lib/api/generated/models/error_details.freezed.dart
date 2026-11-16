// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
ErrorDetails _$ErrorDetailsFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'VALIDATION':
          return ErrorDetailsValidation.fromJson(
            json
          );
                case 'NOT_FOUND':
          return ErrorDetailsNotFound.fromJson(
            json
          );
                case 'ASSET_NOT_AVAILABLE':
          return ErrorDetailsAssetNotAvailable.fromJson(
            json
          );
                case 'INCOMPATIBLE_VISIBILITY':
          return ErrorDetailsIncompatibleVisibility.fromJson(
            json
          );
                case 'TEAM_MEMBER_LIMIT_REACHED':
          return ErrorDetailsTeamMemberLimitReached.fromJson(
            json
          );
                case 'PLANNER_QUOTA_REACHED':
          return ErrorDetailsPlannerQuotaReached.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ErrorDetails',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ErrorDetails {



  /// Serializes this ErrorDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorDetails);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ErrorDetails()';
}


}

/// @nodoc
class $ErrorDetailsCopyWith<$Res>  {
$ErrorDetailsCopyWith(ErrorDetails _, $Res Function(ErrorDetails) __);
}


/// Adds pattern-matching-related methods to [ErrorDetails].
extension ErrorDetailsPatterns on ErrorDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ErrorDetailsValidation value)?  validation,TResult Function( ErrorDetailsNotFound value)?  notFound,TResult Function( ErrorDetailsAssetNotAvailable value)?  assetNotAvailable,TResult Function( ErrorDetailsIncompatibleVisibility value)?  incompatibleVisibility,TResult Function( ErrorDetailsTeamMemberLimitReached value)?  teamMemberLimitReached,TResult Function( ErrorDetailsPlannerQuotaReached value)?  plannerQuotaReached,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ErrorDetailsValidation() when validation != null:
return validation(_that);case ErrorDetailsNotFound() when notFound != null:
return notFound(_that);case ErrorDetailsAssetNotAvailable() when assetNotAvailable != null:
return assetNotAvailable(_that);case ErrorDetailsIncompatibleVisibility() when incompatibleVisibility != null:
return incompatibleVisibility(_that);case ErrorDetailsTeamMemberLimitReached() when teamMemberLimitReached != null:
return teamMemberLimitReached(_that);case ErrorDetailsPlannerQuotaReached() when plannerQuotaReached != null:
return plannerQuotaReached(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ErrorDetailsValidation value)  validation,required TResult Function( ErrorDetailsNotFound value)  notFound,required TResult Function( ErrorDetailsAssetNotAvailable value)  assetNotAvailable,required TResult Function( ErrorDetailsIncompatibleVisibility value)  incompatibleVisibility,required TResult Function( ErrorDetailsTeamMemberLimitReached value)  teamMemberLimitReached,required TResult Function( ErrorDetailsPlannerQuotaReached value)  plannerQuotaReached,}){
final _that = this;
switch (_that) {
case ErrorDetailsValidation():
return validation(_that);case ErrorDetailsNotFound():
return notFound(_that);case ErrorDetailsAssetNotAvailable():
return assetNotAvailable(_that);case ErrorDetailsIncompatibleVisibility():
return incompatibleVisibility(_that);case ErrorDetailsTeamMemberLimitReached():
return teamMemberLimitReached(_that);case ErrorDetailsPlannerQuotaReached():
return plannerQuotaReached(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ErrorDetailsValidation value)?  validation,TResult? Function( ErrorDetailsNotFound value)?  notFound,TResult? Function( ErrorDetailsAssetNotAvailable value)?  assetNotAvailable,TResult? Function( ErrorDetailsIncompatibleVisibility value)?  incompatibleVisibility,TResult? Function( ErrorDetailsTeamMemberLimitReached value)?  teamMemberLimitReached,TResult? Function( ErrorDetailsPlannerQuotaReached value)?  plannerQuotaReached,}){
final _that = this;
switch (_that) {
case ErrorDetailsValidation() when validation != null:
return validation(_that);case ErrorDetailsNotFound() when notFound != null:
return notFound(_that);case ErrorDetailsAssetNotAvailable() when assetNotAvailable != null:
return assetNotAvailable(_that);case ErrorDetailsIncompatibleVisibility() when incompatibleVisibility != null:
return incompatibleVisibility(_that);case ErrorDetailsTeamMemberLimitReached() when teamMemberLimitReached != null:
return teamMemberLimitReached(_that);case ErrorDetailsPlannerQuotaReached() when plannerQuotaReached != null:
return plannerQuotaReached(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<FieldError> fieldErrors)?  validation,TResult Function( String entityType,  String searchedBy,  String id)?  notFound,TResult Function( String assetId)?  assetNotAvailable,TResult Function( List<IncompatibleRouteDto> routes,  List<IncompatibleRouteUsageDto> usages)?  incompatibleVisibility,TResult Function( int limit,  int current)?  teamMemberLimitReached,TResult Function( String scope,  int limit,  int current,  String resetsOn,  String? teamName)?  plannerQuotaReached,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ErrorDetailsValidation() when validation != null:
return validation(_that.fieldErrors);case ErrorDetailsNotFound() when notFound != null:
return notFound(_that.entityType,_that.searchedBy,_that.id);case ErrorDetailsAssetNotAvailable() when assetNotAvailable != null:
return assetNotAvailable(_that.assetId);case ErrorDetailsIncompatibleVisibility() when incompatibleVisibility != null:
return incompatibleVisibility(_that.routes,_that.usages);case ErrorDetailsTeamMemberLimitReached() when teamMemberLimitReached != null:
return teamMemberLimitReached(_that.limit,_that.current);case ErrorDetailsPlannerQuotaReached() when plannerQuotaReached != null:
return plannerQuotaReached(_that.scope,_that.limit,_that.current,_that.resetsOn,_that.teamName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<FieldError> fieldErrors)  validation,required TResult Function( String entityType,  String searchedBy,  String id)  notFound,required TResult Function( String assetId)  assetNotAvailable,required TResult Function( List<IncompatibleRouteDto> routes,  List<IncompatibleRouteUsageDto> usages)  incompatibleVisibility,required TResult Function( int limit,  int current)  teamMemberLimitReached,required TResult Function( String scope,  int limit,  int current,  String resetsOn,  String? teamName)  plannerQuotaReached,}) {final _that = this;
switch (_that) {
case ErrorDetailsValidation():
return validation(_that.fieldErrors);case ErrorDetailsNotFound():
return notFound(_that.entityType,_that.searchedBy,_that.id);case ErrorDetailsAssetNotAvailable():
return assetNotAvailable(_that.assetId);case ErrorDetailsIncompatibleVisibility():
return incompatibleVisibility(_that.routes,_that.usages);case ErrorDetailsTeamMemberLimitReached():
return teamMemberLimitReached(_that.limit,_that.current);case ErrorDetailsPlannerQuotaReached():
return plannerQuotaReached(_that.scope,_that.limit,_that.current,_that.resetsOn,_that.teamName);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<FieldError> fieldErrors)?  validation,TResult? Function( String entityType,  String searchedBy,  String id)?  notFound,TResult? Function( String assetId)?  assetNotAvailable,TResult? Function( List<IncompatibleRouteDto> routes,  List<IncompatibleRouteUsageDto> usages)?  incompatibleVisibility,TResult? Function( int limit,  int current)?  teamMemberLimitReached,TResult? Function( String scope,  int limit,  int current,  String resetsOn,  String? teamName)?  plannerQuotaReached,}) {final _that = this;
switch (_that) {
case ErrorDetailsValidation() when validation != null:
return validation(_that.fieldErrors);case ErrorDetailsNotFound() when notFound != null:
return notFound(_that.entityType,_that.searchedBy,_that.id);case ErrorDetailsAssetNotAvailable() when assetNotAvailable != null:
return assetNotAvailable(_that.assetId);case ErrorDetailsIncompatibleVisibility() when incompatibleVisibility != null:
return incompatibleVisibility(_that.routes,_that.usages);case ErrorDetailsTeamMemberLimitReached() when teamMemberLimitReached != null:
return teamMemberLimitReached(_that.limit,_that.current);case ErrorDetailsPlannerQuotaReached() when plannerQuotaReached != null:
return plannerQuotaReached(_that.scope,_that.limit,_that.current,_that.resetsOn,_that.teamName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class ErrorDetailsValidation implements ErrorDetails {
  const ErrorDetailsValidation({required  List<FieldError> fieldErrors,  String? $type}): _fieldErrors = fieldErrors,$type = $type ?? 'VALIDATION';
  factory ErrorDetailsValidation.fromJson(Map<String, dynamic> json) => _$ErrorDetailsValidationFromJson(json);

/// Field Errors
 final  List<FieldError> _fieldErrors;
/// Field Errors
 List<FieldError> get fieldErrors {
  if (_fieldErrors is EqualUnmodifiableListView) return _fieldErrors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fieldErrors);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorDetailsValidationCopyWith<ErrorDetailsValidation> get copyWith => _$ErrorDetailsValidationCopyWithImpl<ErrorDetailsValidation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorDetailsValidationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorDetailsValidation&&const DeepCollectionEquality().equals(other.fieldErrors, _fieldErrors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_fieldErrors));
}

@override
String toString() {
    return 'ErrorDetails.validation(fieldErrors: $fieldErrors)';
}


}

/// @nodoc
abstract mixin class $ErrorDetailsValidationCopyWith<$Res> implements $ErrorDetailsCopyWith<$Res> {
  factory $ErrorDetailsValidationCopyWith(ErrorDetailsValidation value, $Res Function(ErrorDetailsValidation) _then) = _$ErrorDetailsValidationCopyWithImpl;
@useResult
$Res call({
 List<FieldError> fieldErrors
});




}
/// @nodoc
class _$ErrorDetailsValidationCopyWithImpl<$Res>
    implements $ErrorDetailsValidationCopyWith<$Res> {
  _$ErrorDetailsValidationCopyWithImpl(this._self, this._then);

  final ErrorDetailsValidation _self;
  final $Res Function(ErrorDetailsValidation) _then;

/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fieldErrors = null,}) {
  return _then(ErrorDetailsValidation(
fieldErrors: null == fieldErrors ? _self._fieldErrors : fieldErrors // ignore: cast_nullable_to_non_nullable
as List<FieldError>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ErrorDetailsNotFound implements ErrorDetails {
  const ErrorDetailsNotFound({required this.entityType, required this.searchedBy, required this.id,  String? $type}): $type = $type ?? 'NOT_FOUND';
  factory ErrorDetailsNotFound.fromJson(Map<String, dynamic> json) => _$ErrorDetailsNotFoundFromJson(json);

/// Entity type
 final  String entityType;
/// Search type
 final  String searchedBy;
/// id/slug
 final  String id;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorDetailsNotFoundCopyWith<ErrorDetailsNotFound> get copyWith => _$ErrorDetailsNotFoundCopyWithImpl<ErrorDetailsNotFound>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorDetailsNotFoundToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorDetailsNotFound&&(identical(other.entityType, entityType) || other.entityType == entityType)&&(identical(other.searchedBy, searchedBy) || other.searchedBy == searchedBy)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,entityType,searchedBy,id);
}

@override
String toString() {
    return 'ErrorDetails.notFound(entityType: $entityType, searchedBy: $searchedBy, id: $id)';
}


}

/// @nodoc
abstract mixin class $ErrorDetailsNotFoundCopyWith<$Res> implements $ErrorDetailsCopyWith<$Res> {
  factory $ErrorDetailsNotFoundCopyWith(ErrorDetailsNotFound value, $Res Function(ErrorDetailsNotFound) _then) = _$ErrorDetailsNotFoundCopyWithImpl;
@useResult
$Res call({
 String entityType, String searchedBy, String id
});




}
/// @nodoc
class _$ErrorDetailsNotFoundCopyWithImpl<$Res>
    implements $ErrorDetailsNotFoundCopyWith<$Res> {
  _$ErrorDetailsNotFoundCopyWithImpl(this._self, this._then);

  final ErrorDetailsNotFound _self;
  final $Res Function(ErrorDetailsNotFound) _then;

/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entityType = null,Object? searchedBy = null,Object? id = null,}) {
  return _then(ErrorDetailsNotFound(
entityType: null == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String,searchedBy: null == searchedBy ? _self.searchedBy : searchedBy // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ErrorDetailsAssetNotAvailable implements ErrorDetails {
  const ErrorDetailsAssetNotAvailable({required this.assetId,  String? $type}): $type = $type ?? 'ASSET_NOT_AVAILABLE';
  factory ErrorDetailsAssetNotAvailable.fromJson(Map<String, dynamic> json) => _$ErrorDetailsAssetNotAvailableFromJson(json);

/// Id of the asset, as the request cited it
 final  String assetId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorDetailsAssetNotAvailableCopyWith<ErrorDetailsAssetNotAvailable> get copyWith => _$ErrorDetailsAssetNotAvailableCopyWithImpl<ErrorDetailsAssetNotAvailable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorDetailsAssetNotAvailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorDetailsAssetNotAvailable&&(identical(other.assetId, assetId) || other.assetId == assetId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,assetId);
}

@override
String toString() {
    return 'ErrorDetails.assetNotAvailable(assetId: $assetId)';
}


}

/// @nodoc
abstract mixin class $ErrorDetailsAssetNotAvailableCopyWith<$Res> implements $ErrorDetailsCopyWith<$Res> {
  factory $ErrorDetailsAssetNotAvailableCopyWith(ErrorDetailsAssetNotAvailable value, $Res Function(ErrorDetailsAssetNotAvailable) _then) = _$ErrorDetailsAssetNotAvailableCopyWithImpl;
@useResult
$Res call({
 String assetId
});




}
/// @nodoc
class _$ErrorDetailsAssetNotAvailableCopyWithImpl<$Res>
    implements $ErrorDetailsAssetNotAvailableCopyWith<$Res> {
  _$ErrorDetailsAssetNotAvailableCopyWithImpl(this._self, this._then);

  final ErrorDetailsAssetNotAvailable _self;
  final $Res Function(ErrorDetailsAssetNotAvailable) _then;

/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? assetId = null,}) {
  return _then(ErrorDetailsAssetNotAvailable(
assetId: null == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ErrorDetailsIncompatibleVisibility implements ErrorDetails {
  const ErrorDetailsIncompatibleVisibility({required  List<IncompatibleRouteDto> routes, required  List<IncompatibleRouteUsageDto> usages,  String? $type}): _routes = routes,_usages = usages,$type = $type ?? 'INCOMPATIBLE_VISIBILITY';
  factory ErrorDetailsIncompatibleVisibility.fromJson(Map<String, dynamic> json) => _$ErrorDetailsIncompatibleVisibilityFromJson(json);

/// Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved.
 final  List<IncompatibleRouteDto> _routes;
/// Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its groups' or its stages'. Replaying the creation or the update with alignVisibility = true raises each to its proposedVisibility in the same transaction. Empty when a route was saved.
 List<IncompatibleRouteDto> get routes {
  if (_routes is EqualUnmodifiableListView) return _routes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_routes);
}

/// Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved.
 final  List<IncompatibleRouteUsageDto> _usages;
/// Saving a route as TEAM: the rides and trips visible outside the team that use it — directly, through a group or through a stage — drafts included, deleted ones left out. There is no alignment in this direction: change them first. Empty when a ride or a trip was saved.
 List<IncompatibleRouteUsageDto> get usages {
  if (_usages is EqualUnmodifiableListView) return _usages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usages);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorDetailsIncompatibleVisibilityCopyWith<ErrorDetailsIncompatibleVisibility> get copyWith => _$ErrorDetailsIncompatibleVisibilityCopyWithImpl<ErrorDetailsIncompatibleVisibility>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorDetailsIncompatibleVisibilityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorDetailsIncompatibleVisibility&&const DeepCollectionEquality().equals(other.routes, _routes)&&const DeepCollectionEquality().equals(other.usages, _usages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_routes),const DeepCollectionEquality().hash(_usages));
}

@override
String toString() {
    return 'ErrorDetails.incompatibleVisibility(routes: $routes, usages: $usages)';
}


}

/// @nodoc
abstract mixin class $ErrorDetailsIncompatibleVisibilityCopyWith<$Res> implements $ErrorDetailsCopyWith<$Res> {
  factory $ErrorDetailsIncompatibleVisibilityCopyWith(ErrorDetailsIncompatibleVisibility value, $Res Function(ErrorDetailsIncompatibleVisibility) _then) = _$ErrorDetailsIncompatibleVisibilityCopyWithImpl;
@useResult
$Res call({
 List<IncompatibleRouteDto> routes, List<IncompatibleRouteUsageDto> usages
});




}
/// @nodoc
class _$ErrorDetailsIncompatibleVisibilityCopyWithImpl<$Res>
    implements $ErrorDetailsIncompatibleVisibilityCopyWith<$Res> {
  _$ErrorDetailsIncompatibleVisibilityCopyWithImpl(this._self, this._then);

  final ErrorDetailsIncompatibleVisibility _self;
  final $Res Function(ErrorDetailsIncompatibleVisibility) _then;

/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? routes = null,Object? usages = null,}) {
  return _then(ErrorDetailsIncompatibleVisibility(
routes: null == routes ? _self._routes : routes // ignore: cast_nullable_to_non_nullable
as List<IncompatibleRouteDto>,usages: null == usages ? _self._usages : usages // ignore: cast_nullable_to_non_nullable
as List<IncompatibleRouteUsageDto>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ErrorDetailsTeamMemberLimitReached implements ErrorDetails {
  const ErrorDetailsTeamMemberLimitReached({required this.limit, required this.current,  String? $type}): $type = $type ?? 'TEAM_MEMBER_LIMIT_REACHED';
  factory ErrorDetailsTeamMemberLimitReached.fromJson(Map<String, dynamic> json) => _$ErrorDetailsTeamMemberLimitReachedFromJson(json);

/// Member cap of the team's tier
 final  int limit;
/// What was counted against the cap: active members, plus pending invitations when sending one
 final  int current;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorDetailsTeamMemberLimitReachedCopyWith<ErrorDetailsTeamMemberLimitReached> get copyWith => _$ErrorDetailsTeamMemberLimitReachedCopyWithImpl<ErrorDetailsTeamMemberLimitReached>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorDetailsTeamMemberLimitReachedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorDetailsTeamMemberLimitReached&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,limit,current);
}

@override
String toString() {
    return 'ErrorDetails.teamMemberLimitReached(limit: $limit, current: $current)';
}


}

/// @nodoc
abstract mixin class $ErrorDetailsTeamMemberLimitReachedCopyWith<$Res> implements $ErrorDetailsCopyWith<$Res> {
  factory $ErrorDetailsTeamMemberLimitReachedCopyWith(ErrorDetailsTeamMemberLimitReached value, $Res Function(ErrorDetailsTeamMemberLimitReached) _then) = _$ErrorDetailsTeamMemberLimitReachedCopyWithImpl;
@useResult
$Res call({
 int limit, int current
});




}
/// @nodoc
class _$ErrorDetailsTeamMemberLimitReachedCopyWithImpl<$Res>
    implements $ErrorDetailsTeamMemberLimitReachedCopyWith<$Res> {
  _$ErrorDetailsTeamMemberLimitReachedCopyWithImpl(this._self, this._then);

  final ErrorDetailsTeamMemberLimitReached _self;
  final $Res Function(ErrorDetailsTeamMemberLimitReached) _then;

/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? limit = null,Object? current = null,}) {
  return _then(ErrorDetailsTeamMemberLimitReached(
limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ErrorDetailsPlannerQuotaReached implements ErrorDetails {
  const ErrorDetailsPlannerQuotaReached({required this.scope, required this.limit, required this.current, required this.resetsOn, this.teamName,  String? $type}): $type = $type ?? 'PLANNER_QUOTA_REACHED';
  factory ErrorDetailsPlannerQuotaReached.fromJson(Map<String, dynamic> json) => _$ErrorDetailsPlannerQuotaReachedFromJson(json);

/// TEAM: the team is on the free plan and its monthly saves are spent. PERSONAL: the caller is a member of no unlocked team and their monthly saves in the GPX tools are spent.
 final  String scope;
/// Saves of a drawn track allowed per calendar month
 final  int limit;
/// Saves already counted this month
 final  int current;
/// The day the count starts again: the first day of next month, in the team's zone for TEAM, in UTC for PERSONAL
 final  String resetsOn;
/// Name of the team, for TEAM only
 final  String? teamName;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorDetailsPlannerQuotaReachedCopyWith<ErrorDetailsPlannerQuotaReached> get copyWith => _$ErrorDetailsPlannerQuotaReachedCopyWithImpl<ErrorDetailsPlannerQuotaReached>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorDetailsPlannerQuotaReachedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorDetailsPlannerQuotaReached&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.current, current) || other.current == current)&&(identical(other.resetsOn, resetsOn) || other.resetsOn == resetsOn)&&(identical(other.teamName, teamName) || other.teamName == teamName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,scope,limit,current,resetsOn,teamName);
}

@override
String toString() {
    return 'ErrorDetails.plannerQuotaReached(scope: $scope, limit: $limit, current: $current, resetsOn: $resetsOn, teamName: $teamName)';
}


}

/// @nodoc
abstract mixin class $ErrorDetailsPlannerQuotaReachedCopyWith<$Res> implements $ErrorDetailsCopyWith<$Res> {
  factory $ErrorDetailsPlannerQuotaReachedCopyWith(ErrorDetailsPlannerQuotaReached value, $Res Function(ErrorDetailsPlannerQuotaReached) _then) = _$ErrorDetailsPlannerQuotaReachedCopyWithImpl;
@useResult
$Res call({
 String scope, int limit, int current, String resetsOn, String? teamName
});




}
/// @nodoc
class _$ErrorDetailsPlannerQuotaReachedCopyWithImpl<$Res>
    implements $ErrorDetailsPlannerQuotaReachedCopyWith<$Res> {
  _$ErrorDetailsPlannerQuotaReachedCopyWithImpl(this._self, this._then);

  final ErrorDetailsPlannerQuotaReached _self;
  final $Res Function(ErrorDetailsPlannerQuotaReached) _then;

/// Create a copy of ErrorDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? scope = null,Object? limit = null,Object? current = null,Object? resetsOn = null,Object? teamName = freezed,}) {
  return _then(ErrorDetailsPlannerQuotaReached(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as int,resetsOn: null == resetsOn ? _self.resetsOn : resetsOn // ignore: cast_nullable_to_non_nullable
as String,teamName: freezed == teamName ? _self.teamName : teamName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
