package fr.pedalons.dto.teams.response;

import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.common.ContentVisibilityRules;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * The visibilities a team accepts for each type of content — {@link ContentVisibilityRules}, the
 * rule its writes are validated against, so what a form offers and what the server accepts cannot
 * diverge (docs/LEDGER_*.md API-176). Trip stages have their trip's visibility and are not listed.
 */
@Schema(
    description =
        "The visibilities the team accepts for each type of content, in the order of the"
            + " Visibility enum. What a creation form offers; an editor hides its selector when a"
            + " list has a single value. Never empty: TEAM is always accepted.")
@ValidateSchema
public record ContentVisibilitiesDto(
    @Schema(required = true) List<Visibility> ride,
    @Schema(required = true) List<Visibility> rideTemplate,
    @Schema(required = true) List<Visibility> route,
    @Schema(required = true) List<Visibility> post,
    @Schema(required = true) List<Visibility> trip,
    @Schema(required = true) List<Visibility> teamPage,
    @Schema(description = "Always [TEAM]: ads are members-only in every team.", required = true)
        List<Visibility> ad) {

  public static ContentVisibilitiesDto of(Team team) {
    return new ContentVisibilitiesDto(
        ContentVisibilityRules.accepted(team, EntityType.RIDE),
        ContentVisibilityRules.accepted(team, EntityType.RIDE_TEMPLATE),
        ContentVisibilityRules.accepted(team, EntityType.ROUTE),
        ContentVisibilityRules.accepted(team, EntityType.POST),
        ContentVisibilityRules.accepted(team, EntityType.TRIP),
        ContentVisibilityRules.accepted(team, EntityType.TEAM_PAGE),
        ContentVisibilityRules.accepted(team, EntityType.AD));
  }
}
