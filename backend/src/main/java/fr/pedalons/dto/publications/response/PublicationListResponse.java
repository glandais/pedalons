package fr.pedalons.dto.publications.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Paginated publication list response")
@ValidateSchema
public record PublicationListResponse(
    @Schema(description = "List of publications", required = true)
        List<PublicationDto> publications,
    @Schema(description = "Total number of publications", required = true) long total,
    @Schema(description = "Current page number", required = true) int page,
    @Schema(description = "Page size", required = true) int size,
    @Nullable
        @Schema(
            description =
                "With when=UPCOMING_FIRST only, null otherwise: how many of the 'total' rows are in"
                    + " the first section, « À venir » (rides and trips not over yet). They are the"
                    + " first upcomingTotal rows of the whole list, so the row at position"
                    + " page * size + i (i its index in 'publications') is « À venir » when that"
                    + " position is below upcomingTotal, « Plus tôt » otherwise; the second"
                    + " section counts total - upcomingTotal. Same filters and same instant as the"
                    + " page.")
        Long upcomingTotal) {

  /** A page with no sections: every list but {@code when=UPCOMING_FIRST}. */
  public PublicationListResponse(
      List<PublicationDto> publications, long total, int page, int size) {
    this(publications, total, page, size, null);
  }
}
