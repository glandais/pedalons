package fr.pedalons.dto.ridetemplates.request;

import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Ride template request")
@ValidateSchema
public record RideTemplateRequest(
    @Schema(description = "Template name", required = true) @NotBlank @Size(min = 1, max = 200)
        String name,
    @Schema(description = "Template description (markdown)", required = true)
        @Size(max = MediaDto.MAX_MARKDOWN_LENGTH)
        String markdown,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Schema(description = "Default status for rides created from this template", required = true)
        Status status,
    @Schema(description = "Template groups", required = true)
        List<@Valid RideTemplateGroupRequest> groups,
    @Nullable
        @Schema(
            description =
                "IDs (TSID) of the team's RIDE tags the template carries (copied onto the rides"
                    + " created from it), replacing the whole set — at most 10, each a tag of this"
                    + " team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list"
                    + " removes them all. Omitted: none on a creation, left as they are on an"
                    + " update.")
        List<String> tagIds,
    @Nullable
        @Min(0)
        @Schema(
            description =
                "The number the next ride created from this template takes: a client titles it"
                    + " « name #nextNumber » and the creation of that ride (RideRequest.templateId)"
                    + " raises it by one. Null: the template numbers nothing.")
        Integer nextNumber) {

  /** Without tags: the shape this record had before API-59 — leaves the tags as they are. */
  public RideTemplateRequest(
      String name,
      String markdown,
      Visibility visibility,
      Status status,
      List<RideTemplateGroupRequest> groups) {
    this(name, markdown, visibility, status, groups, null, null);
  }

  /** Without a number: the shape this record had before API-108 — the template numbers nothing. */
  public RideTemplateRequest(
      String name,
      String markdown,
      Visibility visibility,
      Status status,
      List<RideTemplateGroupRequest> groups,
      @Nullable List<String> tagIds) {
    this(name, markdown, visibility, status, groups, tagIds, null);
  }
}
