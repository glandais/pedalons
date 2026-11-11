package fr.pedalons.dto.error;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * A team on a capped tier refused one more member (docs/LEDGER_*.md BILL-10): the cap, and the
 * count it was compared to — members only for a join, an addition or an acceptance; members plus
 * pending invitations for a new invitation.
 */
@RequiredArgsConstructor
@Getter
public class TeamMemberLimitDetails implements ErrorDetails {
  @Schema(description = "Type", required = true)
  final ErrorCode type = ErrorCode.TEAM_MEMBER_LIMIT_REACHED;

  @Schema(description = "Member cap of the team's tier", required = true)
  final int limit;

  @Schema(
      description =
          "What was counted against the cap: active members, plus pending invitations when"
              + " sending one",
      required = true)
  final long current;
}
