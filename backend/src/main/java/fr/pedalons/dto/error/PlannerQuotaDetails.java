package fr.pedalons.dto.error;

import fr.pedalons.enums.PlannerQuotaScope;
import java.time.LocalDate;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * A route planner quota is spent (docs/LEDGER_*.md BILL-10): which one, its size, what was counted,
 * when it starts again, and for a team its name — the message says why the limit applies.
 */
@RequiredArgsConstructor
@Getter
public class PlannerQuotaDetails implements ErrorDetails {
  @Schema(description = "Type", required = true)
  final ErrorCode type = ErrorCode.PLANNER_QUOTA_REACHED;

  @Schema(
      description =
          "TEAM: the team is on the free plan and its monthly saves are spent. PERSONAL: the"
              + " caller is a member of no unlocked team and their monthly saves in the GPX tools"
              + " are spent.",
      required = true)
  final PlannerQuotaScope scope;

  @Schema(description = "Saves of a drawn track allowed per calendar month", required = true)
  final int limit;

  @Schema(description = "Saves already counted this month", required = true)
  final long current;

  @Schema(
      description =
          "The day the count starts again: the first day of next month, in the team's zone for"
              + " TEAM, in UTC for PERSONAL",
      required = true)
  final LocalDate resetsOn;

  @Schema(description = "Name of the team, for TEAM only")
  final @Nullable String teamName;
}
