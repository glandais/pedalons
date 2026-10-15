package fr.pedalons.dto.rides.request;

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

@Schema(description = "Ride request")
@ValidateSchema
public record RideRequest(
    @Schema(description = "Ride name", examples = "Sunday Morning Ride", required = true)
        @NotBlank
        @Size(min = 3, max = 200)
        @AcceptableText
        String name,
    @Schema(description = "Ride media", required = true) @Valid MediaDto media,
    @Schema(
            description =
                "Ride date/time: a wall time without offset, read in the ride's zone (start place,"
                    + " else route, else team).",
            required = true)
        EventDateTime dateTime,
    @Schema(description = "Ride status", required = true) Status status,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Nullable @Schema(description = "Route slug") String routeSlug,
    @Nullable @Schema(description = "Start place ID (TSID)") String startPlaceId,
    @Nullable @Schema(description = "End place ID (TSID)") String endPlaceId,
    @Nullable
        @Schema(
            description =
                "Publication time (for scheduled publishing), a wall time in the ride's zone like"
                    + " dateTime.")
        EventDateTime publishAt,
    @Schema(description = "Ride groups to create", required = true)
        List<@Valid GroupRequest> groups,
    @Nullable
        @Schema(
            description =
                "IDs (TSID) of the team's RIDE tags the ride carries, replacing the whole set — at"
                    + " most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID,"
                    + " TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a"
                    + " creation, left as they are on an update.")
        List<String> tagIds,
    @Nullable
        @Schema(
            description =
                "ID (TSID) of the team's template the ride is created from. On a creation, raises"
                    + " the template's nextNumber by one when it has one; ignored on an update, and"
                    + " when the template no longer exists.")
        String templateId)
    implements WithVisibility {

  /** Without a template: the shape this record had before API-108. */
  public RideRequest(
      String name,
      MediaDto media,
      EventDateTime dateTime,
      Status status,
      Visibility visibility,
      @Nullable String routeSlug,
      @Nullable String startPlaceId,
      @Nullable String endPlaceId,
      @Nullable EventDateTime publishAt,
      List<GroupRequest> groups,
      @Nullable List<String> tagIds) {
    this(
        name,
        media,
        dateTime,
        status,
        visibility,
        routeSlug,
        startPlaceId,
        endPlaceId,
        publishAt,
        groups,
        tagIds,
        null);
  }
}
