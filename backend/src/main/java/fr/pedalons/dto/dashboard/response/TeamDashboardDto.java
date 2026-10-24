package fr.pedalons.dto.dashboard.response;

import fr.pedalons.dto.ads.response.AdListResponse;
import fr.pedalons.dto.publications.response.PublicationListResponse;
import fr.pedalons.dto.routes.response.RouteListResponse;
import fr.pedalons.dto.teams.response.TeamDetailDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.TeamRole;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * A team's « Tableau de bord », for one of its members or for a visitor, in one response.
 *
 * <p>Every section is a short page (five rows at most) built by the same services and per-page
 * lookups as the lists it previews, so its rows are the rows those lists show and its {@code total}
 * is what « Voir tout » opens. A section is null when the team has turned its module off; the
 * organizer and admin blocks are null below their role. A visitor (null role) gets the public
 * sections only — docs/LEDGER_*.md API-86.
 */
@Schema(
    description =
        "A team's dashboard for one of its members, or its public part for a visitor. Each section"
            + " is a short page (at most 5 rows) of the matching list, compact rows, deleted"
            + " content left out; its total is what the full list holds. A section is null when its"
            + " module is disabled for the team. The organizer block is null for a MEMBER, the"
            + " admin block null below ADMIN. For a visitor (role null) only team, upcomingRides,"
            + " latestPosts and newRoutes are filled.")
@ValidateSchema
public record TeamDashboardDto(
    @Schema(
            description =
                "The team, as GET /api/teams/{teamSlug} returns it — header, feature flags,"
                    + " memberCount; memberCountByRole is filled for an administrator.",
            required = true)
        TeamDetailDto team,
    @Nullable
        @Schema(
            description =
                "The caller's real role in the team; null for a visitor, anonymous or not a"
                    + " member — a platform admin who is not a member included. The organizer and"
                    + " admin blocks are what a platform admin's rights add.")
        TeamRole role,
    @Nullable
        @Schema(
            description =
                "« Vos prochaines sorties »: the team's rides and trips starting from now that the"
                    + " caller is registered to, soonest first (at most 3). A ride row's"
                    + " registeredGroup is the group joined, with its pace. Null when both rides"
                    + " and trips are disabled, and for a visitor.")
        PublicationListResponse myUpcoming,
    @Nullable
        @Schema(
            description =
                "« Sorties à venir »: the team's published rides starting from now, soonest first"
                    + " (at most 3). Each row carries groupSummaries (fill per group), distance,"
                    + " elevationGain, surfaceType, registered and commentCount. Null when rides"
                    + " are disabled.")
        PublicationListResponse upcomingRides,
    @Nullable
        @Schema(
            description =
                "« Dernières publications »: the team's latest published posts, newest first (at"
                    + " most 3). Null when posts are disabled.")
        PublicationListResponse latestPosts,
    @Nullable
        @Schema(
            description =
                "« Nouveaux parcours »: the team's latest routes, newest first (at most 3). Null"
                    + " when routes are disabled.")
        RouteListResponse newRoutes,
    @Nullable
        @Schema(
            description =
                "« Annonces »: the team's latest ads, newest first (at most 3). A null price reads"
                    + " « Prix à négocier »; the place is locationDescription, a sector — never a"
                    + " pin. Null when ads are disabled, and for a visitor.")
        AdListResponse latestAds,
    @Nullable
        @Schema(
            description =
                "What organizers and administrators see on top. Null for a MEMBER and a visitor;"
                    + " filled for a platform admin, member or not.")
        TeamDashboardOrganizerDto organizer,
    @Nullable
        @Schema(
            description =
                "The administration panel. Null below ADMIN, and for a visitor; filled for a"
                    + " platform admin, member or not.")
        TeamDashboardAdminDto admin) {}
