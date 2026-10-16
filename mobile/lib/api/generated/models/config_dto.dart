// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'analytics_config_dto.dart';
import 'map_center_dto.dart';
import 'map_style_dto.dart';
import 'map_terrain_dto.dart';
import 'web_push_config_dto.dart';

part 'config_dto.freezed.dart';
part 'config_dto.g.dart';

/// Application configuration
@Freezed()
abstract class ConfigDto with _$ConfigDto {
  const factory ConfigDto({
    /// WebAuthn Relying Party ID (effective host)
    required String webAuthnRpId,

    /// Application name
    required String appName,

    /// Single team mode - team creation disabled
    required bool singleTeam,

    /// Whether the interactive planner is open in the team-independent GPX tools. When false the tools still accept a .gpx upload, only drawing from scratch is closed. Platform-admin only, per domain.
    required bool enableGpxPlanner,

    /// Basemaps the clients may offer, in switcher order. Served rather than compiled in, so a tile provider can change without a client release.
    required List<MapStyleDto> mapStyles,

    /// Public base URL of the tile host, for a client that builds its own style, sprite or glyph URLs.
    required String tileServerBaseUrl,

    /// Where a map opens before it knows what it is showing. On a site rooted on one team this is that team's location; otherwise the deployment default.
    required MapCenterDto defaultCenter,

    /// Whether this deployment sends the routes of a member's rides to their GPS services on its own (GpsServiceConnectionDto.autoSync). When false the clients offer no switch: it would promise a sending that never happens.
    required bool gpsAutoSyncEnabled,

    /// Slug of the team the site is pinned to (dedicated hostname / alias). Null on a regular multi-team domain. When set, the app roots on this team.
    String? pinnedTeamSlug,

    /// The elevation source the clients may shade the relief with. Null when the deployment configures none — the clients then offer no relief at all rather than falling back to a provider of their own.
    MapTerrainDto? terrain,

    /// Oldest mobile build this server still serves, as a semver string. Null when no floor is enforced; a client older than this should tell the user to update.
    String? minSupportedAppVersion,

    /// How the site subscribes a browser to push notifications. Null when the push channel is unavailable or the deployment configures no web app — the site then offers no notification on this device.
    WebPushConfigDto? webPush,

    /// Where the site counts its page views. Null when the deployment measures no audience — the site then sends nothing. The mobile app ignores it.
    AnalyticsConfigDto? analytics,
  }) = _ConfigDto;

  factory ConfigDto.fromJson(Map<String, Object?> json) =>
      _$ConfigDtoFromJson(json);
}
