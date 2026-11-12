package fr.pedalons.dto.limits.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.LocalDate;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * Where a route planner quota stands this month (docs/LEDGER_*.md BILL-10). Clients show no counter:
 * they only close the entry point to the planner when {@code used >= limit} already.
 */
@Schema(description = "Saves of a drawn track this calendar month, against the plan's quota")
@ValidateSchema
public record PlannerQuotaDto(
    @Nullable
        @Schema(
            description = "Saves of a drawn track allowed per calendar month; null when unlimited",
            examples = "20")
        Integer limit,
    @Schema(description = "Saves of a drawn track counted this month", required = true) int used,
    @Schema(
            description =
                "The day the count starts again: the first day of next month, in the team's zone"
                    + " for a team, in UTC for the personal quota",
            required = true)
        LocalDate resetsOn) {

  /** Whether the quota is already spent: the planner's entry points are then closed. */
  public boolean reached() {
    return limit != null && used >= limit;
  }
}
