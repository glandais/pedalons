// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConfigDto {

/// WebAuthn Relying Party ID (effective host)
 String get webAuthnRpId;/// Application name
 String get appName;/// Single team mode - team creation disabled
 bool get singleTeam;/// Whether the interactive planner is open in the team-independent GPX tools. When false the tools still accept a .gpx upload, only drawing from scratch is closed. Platform-admin only, per domain.
 bool get enableGpxPlanner;/// Basemaps the clients may offer, in switcher order. Served rather than compiled in, so a tile provider can change without a client release.
 List<MapStyleDto> get mapStyles;/// Public base URL of the tile host, for a client that builds its own style, sprite or glyph URLs.
 String get tileServerBaseUrl;/// Where a map opens before it knows what it is showing. On a site rooted on one team this is that team's location; otherwise the deployment default.
 MapCenterDto get defaultCenter;/// Whether this deployment sends the routes of a member's rides to their GPS services on its own (GpsServiceConnectionDto.autoSync). When false the clients offer no switch: it would promise a sending that never happens.
 bool get gpsAutoSyncEnabled;/// Slug of the team the site is pinned to (dedicated hostname / alias). Null on a regular multi-team domain. When set, the app roots on this team.
 String? get pinnedTeamSlug;/// The elevation source the clients may shade the relief with. Null when the deployment configures none — the clients then offer no relief at all rather than falling back to a provider of their own.
 MapTerrainDto? get terrain;/// Oldest mobile build this server still serves, as a semver string. Null when no floor is enforced; a client older than this should tell the user to update.
 String? get minSupportedAppVersion;/// How the site subscribes a browser to push notifications. Null when the push channel is unavailable or the deployment configures no web app — the site then offers no notification on this device.
 WebPushConfigDto? get webPush;/// Where the site counts its page views. Null when the deployment measures no audience — the site then sends nothing. The mobile app ignores it.
 AnalyticsConfigDto? get analytics;
/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConfigDtoCopyWith<ConfigDto> get copyWith => _$ConfigDtoCopyWithImpl<ConfigDto>(this as ConfigDto, _$identity);

  /// Serializes this ConfigDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ConfigDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConfigDto&&(identical(other.webAuthnRpId, _this.webAuthnRpId) || other.webAuthnRpId == _this.webAuthnRpId)&&(identical(other.appName, _this.appName) || other.appName == _this.appName)&&(identical(other.singleTeam, _this.singleTeam) || other.singleTeam == _this.singleTeam)&&(identical(other.enableGpxPlanner, _this.enableGpxPlanner) || other.enableGpxPlanner == _this.enableGpxPlanner)&&const DeepCollectionEquality().equals(other.mapStyles, _this.mapStyles)&&(identical(other.tileServerBaseUrl, _this.tileServerBaseUrl) || other.tileServerBaseUrl == _this.tileServerBaseUrl)&&(identical(other.defaultCenter, _this.defaultCenter) || other.defaultCenter == _this.defaultCenter)&&(identical(other.gpsAutoSyncEnabled, _this.gpsAutoSyncEnabled) || other.gpsAutoSyncEnabled == _this.gpsAutoSyncEnabled)&&(identical(other.pinnedTeamSlug, _this.pinnedTeamSlug) || other.pinnedTeamSlug == _this.pinnedTeamSlug)&&(identical(other.terrain, _this.terrain) || other.terrain == _this.terrain)&&(identical(other.minSupportedAppVersion, _this.minSupportedAppVersion) || other.minSupportedAppVersion == _this.minSupportedAppVersion)&&(identical(other.webPush, _this.webPush) || other.webPush == _this.webPush)&&(identical(other.analytics, _this.analytics) || other.analytics == _this.analytics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ConfigDto;
  return Object.hash(runtimeType,_this.webAuthnRpId,_this.appName,_this.singleTeam,_this.enableGpxPlanner,const DeepCollectionEquality().hash(_this.mapStyles),_this.tileServerBaseUrl,_this.defaultCenter,_this.gpsAutoSyncEnabled,_this.pinnedTeamSlug,_this.terrain,_this.minSupportedAppVersion,_this.webPush,_this.analytics);
}

@override
String toString() {
  final _this = this as ConfigDto;
  return 'ConfigDto(webAuthnRpId: ${_this.webAuthnRpId}, appName: ${_this.appName}, singleTeam: ${_this.singleTeam}, enableGpxPlanner: ${_this.enableGpxPlanner}, mapStyles: ${_this.mapStyles}, tileServerBaseUrl: ${_this.tileServerBaseUrl}, defaultCenter: ${_this.defaultCenter}, gpsAutoSyncEnabled: ${_this.gpsAutoSyncEnabled}, pinnedTeamSlug: ${_this.pinnedTeamSlug}, terrain: ${_this.terrain}, minSupportedAppVersion: ${_this.minSupportedAppVersion}, webPush: ${_this.webPush}, analytics: ${_this.analytics})';
}


}

/// @nodoc
abstract mixin class $ConfigDtoCopyWith<$Res>  {
  factory $ConfigDtoCopyWith(ConfigDto value, $Res Function(ConfigDto) _then) = _$ConfigDtoCopyWithImpl;
@useResult
$Res call({
 String webAuthnRpId, String appName, bool singleTeam, bool enableGpxPlanner, List<MapStyleDto> mapStyles, String tileServerBaseUrl, MapCenterDto defaultCenter, bool gpsAutoSyncEnabled, String? pinnedTeamSlug, MapTerrainDto? terrain, String? minSupportedAppVersion, WebPushConfigDto? webPush, AnalyticsConfigDto? analytics
});


$MapCenterDtoCopyWith<$Res> get defaultCenter;$MapTerrainDtoCopyWith<$Res>? get terrain;$WebPushConfigDtoCopyWith<$Res>? get webPush;$AnalyticsConfigDtoCopyWith<$Res>? get analytics;

}
/// @nodoc
class _$ConfigDtoCopyWithImpl<$Res>
    implements $ConfigDtoCopyWith<$Res> {
  _$ConfigDtoCopyWithImpl(this._self, this._then);

  final ConfigDto _self;
  final $Res Function(ConfigDto) _then;

/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? webAuthnRpId = null,Object? appName = null,Object? singleTeam = null,Object? enableGpxPlanner = null,Object? mapStyles = null,Object? tileServerBaseUrl = null,Object? defaultCenter = null,Object? gpsAutoSyncEnabled = null,Object? pinnedTeamSlug = freezed,Object? terrain = freezed,Object? minSupportedAppVersion = freezed,Object? webPush = freezed,Object? analytics = freezed,}) {
  return _then(ConfigDto(
webAuthnRpId: null == webAuthnRpId ? _self.webAuthnRpId : webAuthnRpId // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,singleTeam: null == singleTeam ? _self.singleTeam : singleTeam // ignore: cast_nullable_to_non_nullable
as bool,enableGpxPlanner: null == enableGpxPlanner ? _self.enableGpxPlanner : enableGpxPlanner // ignore: cast_nullable_to_non_nullable
as bool,mapStyles: null == mapStyles ? _self.mapStyles : mapStyles // ignore: cast_nullable_to_non_nullable
as List<MapStyleDto>,tileServerBaseUrl: null == tileServerBaseUrl ? _self.tileServerBaseUrl : tileServerBaseUrl // ignore: cast_nullable_to_non_nullable
as String,defaultCenter: null == defaultCenter ? _self.defaultCenter : defaultCenter // ignore: cast_nullable_to_non_nullable
as MapCenterDto,gpsAutoSyncEnabled: null == gpsAutoSyncEnabled ? _self.gpsAutoSyncEnabled : gpsAutoSyncEnabled // ignore: cast_nullable_to_non_nullable
as bool,pinnedTeamSlug: freezed == pinnedTeamSlug ? _self.pinnedTeamSlug : pinnedTeamSlug // ignore: cast_nullable_to_non_nullable
as String?,terrain: freezed == terrain ? _self.terrain : terrain // ignore: cast_nullable_to_non_nullable
as MapTerrainDto?,minSupportedAppVersion: freezed == minSupportedAppVersion ? _self.minSupportedAppVersion : minSupportedAppVersion // ignore: cast_nullable_to_non_nullable
as String?,webPush: freezed == webPush ? _self.webPush : webPush // ignore: cast_nullable_to_non_nullable
as WebPushConfigDto?,analytics: freezed == analytics ? _self.analytics : analytics // ignore: cast_nullable_to_non_nullable
as AnalyticsConfigDto?,
  ));
}
/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MapCenterDtoCopyWith<$Res> get defaultCenter {
  
  return $MapCenterDtoCopyWith<$Res>(_self.defaultCenter, (value) {
    return _then(_self.copyWith(defaultCenter: value));
  });
}/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MapTerrainDtoCopyWith<$Res>? get terrain {
    if (_self.terrain == null) {
    return null;
  }

  return $MapTerrainDtoCopyWith<$Res>(_self.terrain!, (value) {
    return _then(_self.copyWith(terrain: value));
  });
}/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WebPushConfigDtoCopyWith<$Res>? get webPush {
    if (_self.webPush == null) {
    return null;
  }

  return $WebPushConfigDtoCopyWith<$Res>(_self.webPush!, (value) {
    return _then(_self.copyWith(webPush: value));
  });
}/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AnalyticsConfigDtoCopyWith<$Res>? get analytics {
    if (_self.analytics == null) {
    return null;
  }

  return $AnalyticsConfigDtoCopyWith<$Res>(_self.analytics!, (value) {
    return _then(_self.copyWith(analytics: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConfigDto].
extension ConfigDtoPatterns on ConfigDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConfigDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConfigDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConfigDto value)  $default,){
final _that = this;
switch (_that) {
case _ConfigDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConfigDto value)?  $default,){
final _that = this;
switch (_that) {
case _ConfigDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String webAuthnRpId,  String appName,  bool singleTeam,  bool enableGpxPlanner,  List<MapStyleDto> mapStyles,  String tileServerBaseUrl,  MapCenterDto defaultCenter,  bool gpsAutoSyncEnabled,  String? pinnedTeamSlug,  MapTerrainDto? terrain,  String? minSupportedAppVersion,  WebPushConfigDto? webPush,  AnalyticsConfigDto? analytics)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConfigDto() when $default != null:
return $default(_that.webAuthnRpId,_that.appName,_that.singleTeam,_that.enableGpxPlanner,_that.mapStyles,_that.tileServerBaseUrl,_that.defaultCenter,_that.gpsAutoSyncEnabled,_that.pinnedTeamSlug,_that.terrain,_that.minSupportedAppVersion,_that.webPush,_that.analytics);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String webAuthnRpId,  String appName,  bool singleTeam,  bool enableGpxPlanner,  List<MapStyleDto> mapStyles,  String tileServerBaseUrl,  MapCenterDto defaultCenter,  bool gpsAutoSyncEnabled,  String? pinnedTeamSlug,  MapTerrainDto? terrain,  String? minSupportedAppVersion,  WebPushConfigDto? webPush,  AnalyticsConfigDto? analytics)  $default,) {final _that = this;
switch (_that) {
case _ConfigDto():
return $default(_that.webAuthnRpId,_that.appName,_that.singleTeam,_that.enableGpxPlanner,_that.mapStyles,_that.tileServerBaseUrl,_that.defaultCenter,_that.gpsAutoSyncEnabled,_that.pinnedTeamSlug,_that.terrain,_that.minSupportedAppVersion,_that.webPush,_that.analytics);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String webAuthnRpId,  String appName,  bool singleTeam,  bool enableGpxPlanner,  List<MapStyleDto> mapStyles,  String tileServerBaseUrl,  MapCenterDto defaultCenter,  bool gpsAutoSyncEnabled,  String? pinnedTeamSlug,  MapTerrainDto? terrain,  String? minSupportedAppVersion,  WebPushConfigDto? webPush,  AnalyticsConfigDto? analytics)?  $default,) {final _that = this;
switch (_that) {
case _ConfigDto() when $default != null:
return $default(_that.webAuthnRpId,_that.appName,_that.singleTeam,_that.enableGpxPlanner,_that.mapStyles,_that.tileServerBaseUrl,_that.defaultCenter,_that.gpsAutoSyncEnabled,_that.pinnedTeamSlug,_that.terrain,_that.minSupportedAppVersion,_that.webPush,_that.analytics);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConfigDto implements ConfigDto {
  const _ConfigDto({required this.webAuthnRpId, required this.appName, required this.singleTeam, required this.enableGpxPlanner, required  List<MapStyleDto> mapStyles, required this.tileServerBaseUrl, required this.defaultCenter, required this.gpsAutoSyncEnabled, this.pinnedTeamSlug, this.terrain, this.minSupportedAppVersion, this.webPush, this.analytics}): _mapStyles = mapStyles;
  factory _ConfigDto.fromJson(Map<String, dynamic> json) => _$ConfigDtoFromJson(json);

/// WebAuthn Relying Party ID (effective host)
@override final  String webAuthnRpId;
/// Application name
@override final  String appName;
/// Single team mode - team creation disabled
@override final  bool singleTeam;
/// Whether the interactive planner is open in the team-independent GPX tools. When false the tools still accept a .gpx upload, only drawing from scratch is closed. Platform-admin only, per domain.
@override final  bool enableGpxPlanner;
/// Basemaps the clients may offer, in switcher order. Served rather than compiled in, so a tile provider can change without a client release.
 final  List<MapStyleDto> _mapStyles;
/// Basemaps the clients may offer, in switcher order. Served rather than compiled in, so a tile provider can change without a client release.
@override List<MapStyleDto> get mapStyles {
  if (_mapStyles is EqualUnmodifiableListView) return _mapStyles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mapStyles);
}

/// Public base URL of the tile host, for a client that builds its own style, sprite or glyph URLs.
@override final  String tileServerBaseUrl;
/// Where a map opens before it knows what it is showing. On a site rooted on one team this is that team's location; otherwise the deployment default.
@override final  MapCenterDto defaultCenter;
/// Whether this deployment sends the routes of a member's rides to their GPS services on its own (GpsServiceConnectionDto.autoSync). When false the clients offer no switch: it would promise a sending that never happens.
@override final  bool gpsAutoSyncEnabled;
/// Slug of the team the site is pinned to (dedicated hostname / alias). Null on a regular multi-team domain. When set, the app roots on this team.
@override final  String? pinnedTeamSlug;
/// The elevation source the clients may shade the relief with. Null when the deployment configures none — the clients then offer no relief at all rather than falling back to a provider of their own.
@override final  MapTerrainDto? terrain;
/// Oldest mobile build this server still serves, as a semver string. Null when no floor is enforced; a client older than this should tell the user to update.
@override final  String? minSupportedAppVersion;
/// How the site subscribes a browser to push notifications. Null when the push channel is unavailable or the deployment configures no web app — the site then offers no notification on this device.
@override final  WebPushConfigDto? webPush;
/// Where the site counts its page views. Null when the deployment measures no audience — the site then sends nothing. The mobile app ignores it.
@override final  AnalyticsConfigDto? analytics;

/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConfigDtoCopyWith<_ConfigDto> get copyWith => __$ConfigDtoCopyWithImpl<_ConfigDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConfigDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConfigDto&&(identical(other.webAuthnRpId, webAuthnRpId) || other.webAuthnRpId == webAuthnRpId)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.singleTeam, singleTeam) || other.singleTeam == singleTeam)&&(identical(other.enableGpxPlanner, enableGpxPlanner) || other.enableGpxPlanner == enableGpxPlanner)&&const DeepCollectionEquality().equals(other.mapStyles, _mapStyles)&&(identical(other.tileServerBaseUrl, tileServerBaseUrl) || other.tileServerBaseUrl == tileServerBaseUrl)&&(identical(other.defaultCenter, defaultCenter) || other.defaultCenter == defaultCenter)&&(identical(other.gpsAutoSyncEnabled, gpsAutoSyncEnabled) || other.gpsAutoSyncEnabled == gpsAutoSyncEnabled)&&(identical(other.pinnedTeamSlug, pinnedTeamSlug) || other.pinnedTeamSlug == pinnedTeamSlug)&&(identical(other.terrain, terrain) || other.terrain == terrain)&&(identical(other.minSupportedAppVersion, minSupportedAppVersion) || other.minSupportedAppVersion == minSupportedAppVersion)&&(identical(other.webPush, webPush) || other.webPush == webPush)&&(identical(other.analytics, analytics) || other.analytics == analytics));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,webAuthnRpId,appName,singleTeam,enableGpxPlanner,const DeepCollectionEquality().hash(_mapStyles),tileServerBaseUrl,defaultCenter,gpsAutoSyncEnabled,pinnedTeamSlug,terrain,minSupportedAppVersion,webPush,analytics);
}

@override
String toString() {
    return 'ConfigDto(webAuthnRpId: $webAuthnRpId, appName: $appName, singleTeam: $singleTeam, enableGpxPlanner: $enableGpxPlanner, mapStyles: $mapStyles, tileServerBaseUrl: $tileServerBaseUrl, defaultCenter: $defaultCenter, gpsAutoSyncEnabled: $gpsAutoSyncEnabled, pinnedTeamSlug: $pinnedTeamSlug, terrain: $terrain, minSupportedAppVersion: $minSupportedAppVersion, webPush: $webPush, analytics: $analytics)';
}


}

/// @nodoc
abstract mixin class _$ConfigDtoCopyWith<$Res> implements $ConfigDtoCopyWith<$Res> {
  factory _$ConfigDtoCopyWith(_ConfigDto value, $Res Function(_ConfigDto) _then) = __$ConfigDtoCopyWithImpl;
@override @useResult
$Res call({
 String webAuthnRpId, String appName, bool singleTeam, bool enableGpxPlanner, List<MapStyleDto> mapStyles, String tileServerBaseUrl, MapCenterDto defaultCenter, bool gpsAutoSyncEnabled, String? pinnedTeamSlug, MapTerrainDto? terrain, String? minSupportedAppVersion, WebPushConfigDto? webPush, AnalyticsConfigDto? analytics
});


@override $MapCenterDtoCopyWith<$Res> get defaultCenter;@override $MapTerrainDtoCopyWith<$Res>? get terrain;@override $WebPushConfigDtoCopyWith<$Res>? get webPush;@override $AnalyticsConfigDtoCopyWith<$Res>? get analytics;

}
/// @nodoc
class __$ConfigDtoCopyWithImpl<$Res>
    implements _$ConfigDtoCopyWith<$Res> {
  __$ConfigDtoCopyWithImpl(this._self, this._then);

  final _ConfigDto _self;
  final $Res Function(_ConfigDto) _then;

/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? webAuthnRpId = null,Object? appName = null,Object? singleTeam = null,Object? enableGpxPlanner = null,Object? mapStyles = null,Object? tileServerBaseUrl = null,Object? defaultCenter = null,Object? gpsAutoSyncEnabled = null,Object? pinnedTeamSlug = freezed,Object? terrain = freezed,Object? minSupportedAppVersion = freezed,Object? webPush = freezed,Object? analytics = freezed,}) {
  return _then(_ConfigDto(
webAuthnRpId: null == webAuthnRpId ? _self.webAuthnRpId : webAuthnRpId // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,singleTeam: null == singleTeam ? _self.singleTeam : singleTeam // ignore: cast_nullable_to_non_nullable
as bool,enableGpxPlanner: null == enableGpxPlanner ? _self.enableGpxPlanner : enableGpxPlanner // ignore: cast_nullable_to_non_nullable
as bool,mapStyles: null == mapStyles ? _self._mapStyles : mapStyles // ignore: cast_nullable_to_non_nullable
as List<MapStyleDto>,tileServerBaseUrl: null == tileServerBaseUrl ? _self.tileServerBaseUrl : tileServerBaseUrl // ignore: cast_nullable_to_non_nullable
as String,defaultCenter: null == defaultCenter ? _self.defaultCenter : defaultCenter // ignore: cast_nullable_to_non_nullable
as MapCenterDto,gpsAutoSyncEnabled: null == gpsAutoSyncEnabled ? _self.gpsAutoSyncEnabled : gpsAutoSyncEnabled // ignore: cast_nullable_to_non_nullable
as bool,pinnedTeamSlug: freezed == pinnedTeamSlug ? _self.pinnedTeamSlug : pinnedTeamSlug // ignore: cast_nullable_to_non_nullable
as String?,terrain: freezed == terrain ? _self.terrain : terrain // ignore: cast_nullable_to_non_nullable
as MapTerrainDto?,minSupportedAppVersion: freezed == minSupportedAppVersion ? _self.minSupportedAppVersion : minSupportedAppVersion // ignore: cast_nullable_to_non_nullable
as String?,webPush: freezed == webPush ? _self.webPush : webPush // ignore: cast_nullable_to_non_nullable
as WebPushConfigDto?,analytics: freezed == analytics ? _self.analytics : analytics // ignore: cast_nullable_to_non_nullable
as AnalyticsConfigDto?,
  ));
}

/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MapCenterDtoCopyWith<$Res> get defaultCenter {
  
  return $MapCenterDtoCopyWith<$Res>(_self.defaultCenter, (value) {
    return _then(_self.copyWith(defaultCenter: value));
  });
}/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MapTerrainDtoCopyWith<$Res>? get terrain {
    if (_self.terrain == null) {
    return null;
  }

  return $MapTerrainDtoCopyWith<$Res>(_self.terrain!, (value) {
    return _then(_self.copyWith(terrain: value));
  });
}/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WebPushConfigDtoCopyWith<$Res>? get webPush {
    if (_self.webPush == null) {
    return null;
  }

  return $WebPushConfigDtoCopyWith<$Res>(_self.webPush!, (value) {
    return _then(_self.copyWith(webPush: value));
  });
}/// Create a copy of ConfigDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AnalyticsConfigDtoCopyWith<$Res>? get analytics {
    if (_self.analytics == null) {
    return null;
  }

  return $AnalyticsConfigDtoCopyWith<$Res>(_self.analytics!, (value) {
    return _then(_self.copyWith(analytics: value));
  });
}
}

// dart format on
