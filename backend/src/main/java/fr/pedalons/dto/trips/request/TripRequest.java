package fr.pedalons.dto.trips.request;

import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.WithVisibility;
import fr.pedalons.dto.validation.AcceptableText;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Trip request")
@ValidateSchema
public record TripRequest(
    @Schema(description = "Trip name", examples = "Summer Alps Tour", required = true)
        @NotBlank
        @Size(min = 1, max = 200)
        @AcceptableText
        String name,
    @Schema(description = "Trip media", required = true) @Valid MediaDto media,
    @Schema(
            description =
                "Trip start date/time: a wall time without offset, read in the trip's zone (first"
                    + " stage, else route, else team).",
            required = true)
        EventDateTime dateTime,
    @Schema(description = "Trip status", required = true) Status status,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Nullable @Schema(description = "Overall route slug for the trip") String routeSlug,
    @Nullable
        @Schema(
            description =
                "Publication time (for scheduled publishing), a wall time in the trip's zone like"
                    + " dateTime.")
        EventDateTime publishAt,
    @Schema(description = "Trip stages to create", required = true)
        List<@Valid StageRequest> stages,
    @Nullable
        @Schema(
            description =
                "IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at"
                    + " most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID,"
                    + " TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a"
                    + " creation, left as they are on an update.")
        List<String> tagIds,
    @Nullable
        @Schema(
            description =
                "When the trip is not TEAM and uses TEAM routes (its own, its stages'), the save is"
                    + " refused with INCOMPATIBLE_VISIBILITY, listing them. Replayed with true, it"
                    + " raises those routes to PUBLIC_UNLISTED in the same transaction, then saves."
                    + " Omitted or false: refused as before.")
        Boolean alignVisibility)
    implements WithVisibility {

  /** Without the alignment: the shape this record had before docs/LEDGER_*.md API-176, lot 3. */
  public TripRequest(
      String name,
      MediaDto media,
      EventDateTime dateTime,
      Status status,
      Visibility visibility,
      @Nullable String routeSlug,
      @Nullable EventDateTime publishAt,
      List<StageRequest> stages,
      @Nullable List<String> tagIds) {
    this(name, media, dateTime, status, visibility, routeSlug, publishAt, stages, tagIds, null);
  }

  /** Whether the TEAM routes of the trip are to be raised rather than refused (API-176). */
  public boolean alignsVisibility() {
    return Boolean.TRUE.equals(alignVisibility);
  }
}
