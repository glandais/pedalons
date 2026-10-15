package fr.pedalons.dto.ridetemplates.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ridetemplate.RideTemplate;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.dto.tags.response.TagDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Ride template response")
@ValidateSchema
public record RideTemplateDto(
    @Schema(description = "Team", required = true) TeamPublicationDto team,
    @Schema(description = "Template ID (TSID)", required = true) String id,
    @Schema(description = "Template slug", required = true) String slug,
    @Schema(description = "Template name", required = true) String name,
    @Schema(description = "Template description (markdown)", required = true) String markdown,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Schema(description = "Default status", required = true) Status status,
    @Schema(description = "Creation timestamp", required = true) Instant createdAt,
    @Schema(description = "Last update timestamp", required = true) Instant updatedAt,
    @Schema(description = "Number of groups", required = true) int groupCount,
    @Schema(description = "Template groups", required = true) List<RideTemplateGroupDto> groups,
    @Schema(
            description =
                "The team's RIDE tags of the template, sorted by label. Copied onto a ride created"
                    + " from it: a client prefills the ride's tagIds with them, editable before and"
                    + " after.",
            required = true)
        List<TagDto> tags,
    @Nullable
        @Schema(
            description =
                "The number the next ride created from this template takes: a client prefills the"
                    + " ride's name with « name #nextNumber » and sends RideRequest.templateId,"
                    + " which raises it by one. Null: the template numbers nothing.")
        Integer nextNumber) {

  /**
   * @param tags the tags of this whole page of templates, resolved in one query by {@code
   *     TagLookup}
   */
  public static RideTemplateDto from(RideTemplate template, ContentTags tags) {
    List<RideTemplateGroupDto> groupDtos =
        template.getGroups().stream().map(RideTemplateGroupDto::from).toList();

    return new RideTemplateDto(
        TeamPublicationDto.from(template.getTeam()),
        TsidUtils.toString(template.getId()),
        template.getSlug(),
        template.getName(),
        template.getMarkdown(),
        template.getVisibility(),
        template.getStatus(),
        template.getCreatedAt(),
        template.getUpdatedAt(),
        groupDtos.size(),
        groupDtos,
        tags.forContent(template.getId()),
        template.getNextNumber());
  }
}
