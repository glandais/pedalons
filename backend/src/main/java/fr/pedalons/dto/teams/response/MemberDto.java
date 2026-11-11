package fr.pedalons.dto.teams.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.TeamRole;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Team member information")
@ValidateSchema
public record MemberDto(
    @Schema(description = "Team", required = true) TeamPublicationDto team,
    @Schema(description = "Membership ID (TSID)", required = true) String id,
    @Schema(description = "User", required = true) PublicUserDto user,
    @Nullable
        @Schema(
            description =
                "Member role. Null when the caller is not entitled to it: an organiser reading the"
                    + " roster of a team that has not opened its member directory gets the names"
                    + " and nothing else.")
        TeamRole role,
    @Nullable @Schema(description = "When the user joined the team") Instant joinedAt) {
  public static MemberDto from(UserTeam userTeam) {
    return from(userTeam, true);
  }

  /**
   * @param full whether the caller may see the membership's role and join date. False strips them
   *     rather than dropping the row: who is on the team is the answer being given, how long they
   *     have been on it and in what capacity is not.
   */
  public static MemberDto from(UserTeam userTeam, boolean full) {
    return new MemberDto(
        // A roster or a membership of one's own: served to a member of the team, or to a platform
        // admin (docs/LEDGER_*.md API-176).
        TeamPublicationDto.ofMember(userTeam.getTeam()),
        TsidUtils.toString(userTeam.getId()),
        PublicUserDto.from(userTeam.getUser()),
        full ? userTeam.getRole() : null,
        full ? userTeam.getJoinedAt() : null);
  }
}
