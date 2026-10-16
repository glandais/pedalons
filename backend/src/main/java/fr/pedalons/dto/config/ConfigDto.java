package fr.pedalons.dto.config;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Application configuration")
@ValidateSchema
public record ConfigDto(
    @Schema(description = "WebAuthn Relying Party ID (effective host)", required = true)
        String webAuthnRpId,
    @Schema(description = "Application name", required = true) String appName,
    @Schema(description = "Single team mode - team creation disabled", required = true)
        boolean singleTeam,
    @Schema(
            description =
                "Whether the interactive planner is open in the team-independent GPX tools. When"
                    + " false the tools still accept a .gpx upload, only drawing from scratch is"
                    + " closed. Platform-admin only, per domain.",
            required = true)
        boolean enableGpxPlanner,
    @Schema(
            description =
                "Slug of the team the site is pinned to (dedicated hostname / alias). Null on a"
                    + " regular multi-team domain. When set, the app roots on this team.")
        @Nullable String pinnedTeamSlug,
    @Schema(
            description =
                "Basemaps the clients may offer, in switcher order. Served rather than compiled in,"
                    + " so a tile provider can change without a client release.",
            required = true)
        List<MapStyleDto> mapStyles,
    @Schema(
            description =
                "Public base URL of the tile host, for a client that builds its own style, sprite"
                    + " or glyph URLs.",
            required = true)
        String tileServerBaseUrl,
    @Schema(
            description =
                "Where a map opens before it knows what it is showing. On a site rooted on one team"
                    + " this is that team's location; otherwise the deployment default.",
            required = true)
        MapCenterDto defaultCenter,
    @Nullable
        @Schema(
            description =
                "The elevation source the clients may shade the relief with. Null when the"
                    + " deployment configures none — the clients then offer no relief at all rather"
                    + " than falling back to a provider of their own.")
        MapTerrainDto terrain,
    @Nullable
        @Schema(
            description =
                "Oldest mobile build this server still serves, as a semver string. Null when no"
                    + " floor is enforced; a client older than this should tell the user to"
                    + " update.")
        String minSupportedAppVersion,
    @Nullable
        @Schema(
            description =
                "How the site subscribes a browser to push notifications. Null when the push"
                    + " channel is unavailable or the deployment configures no web app — the site"
                    + " then offers no notification on this device.")
        WebPushConfigDto webPush,
    @Nullable
        @Schema(
            description =
                "Where the site counts its page views. Null when the deployment measures no"
                    + " audience — the site then sends nothing. The mobile app ignores it.")
        AnalyticsConfigDto analytics,
    @Schema(
            description =
                "Whether this deployment sends the routes of a member's rides to their GPS services"
                    + " on its own (GpsServiceConnectionDto.autoSync). When false the clients offer"
                    + " no switch: it would promise a sending that never happens.",
            required = true)
        boolean gpsAutoSyncEnabled) {}
