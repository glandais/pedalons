package fr.pedalons.dto.common;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Visibility;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * What the caller may do with one entity, computed by the server (docs/LEDGER_*.md API-176,
 * decision D7): a client shows a control when the field says so and never re-derives the rule from
 * the team's visibility or the caller's role. Built by {@code ContentPermissions} from the same
 * rules the access checkers apply.
 *
 * <p>Carries no name, member id or role: only what the caller can do.
 */
@Schema(
    description =
        "What the caller may do with this entity, computed by the server from the rules that guard"
            + " the matching endpoints. A client shows or hides its controls from these fields"
            + " alone, and never derives them from the team's visibility or the caller's role.")
@ValidateSchema
public record ContentPermissionsDto(
    @Schema(
            description =
                "Whether the caller may edit this entity (the update endpoints would accept it)."
                    + " For a trip stage, whether they may edit its trip, which a stage is written"
                    + " through. For the team's about page, whether they may edit it through the"
                    + " team update, the only way it is written.",
            required = true)
        boolean canEdit,
    @Schema(
            description =
                "Whether the caller may delete this entity. For a trip stage, whether they may"
                    + " delete its trip.",
            required = true)
        boolean canDelete,
    @Nullable
        @Schema(
            description =
                "Rides and trips only: whether the caller may register — a member of the team"
                    + " (or a platform admin), the entity published. On a detail it is exact about"
                    + " timing too: false once every group of the ride has left or the trip is"
                    + " finished, as the join endpoints answer. On list rows it does not look at"
                    + " timing, so it may be true on a row and false on the detail of the same"
                    + " entity. Never counts capacity: a full group still refuses. Absent on the"
                    + " other types.")
        Boolean canRegister,
    @Nullable
        @Schema(
            description =
                "Whether the caller may read and write the comment thread: a member of the team"
                    + " or a platform admin, whatever the entity's visibility. Absent on the types"
                    + " that carry no comments (team pages, ads).")
        Boolean canComment,
    @Nullable
        @Schema(
            description =
                "Rides and trips only: whether the caller may see who takes part (names, the"
                    + " participants endpoints). Same rule as canComment. When false, only the"
                    + " counts are sent. Absent on the other types.")
        Boolean canSeeParticipants,
    @Nullable
        @Schema(
            description =
                "The visibilities this entity may be saved with, in the order of the Visibility"
                    + " enum; an editor hides its selector when there is only one. For a route used"
                    + " by a ride or a trip that is not TEAM (drafts included, deleted ones not),"
                    + " TEAM is left out: saving it as TEAM is refused with"
                    + " INCOMPATIBLE_VISIBILITY. That can leave the list empty, when the team"
                    + " accepts nothing but TEAM any more: the route cannot be saved until those"
                    + " usages go TEAM. Present on a detail only: absent on list rows, on embedded"
                    + " summaries, on the types without a visibility of their own (trip stages) and"
                    + " on the team's about page, whose visibility no endpoint sets. Clients that"
                    + " create read TeamDetailDto.allowedContentVisibilities instead.")
        List<Visibility> allowedVisibilities,
    @Schema(
            description =
                "Whether search engines may index the entity's page: the rule of the sitemap —"
                    + " entity PUBLIC, team PUBLIC, published or cancelled, not hidden by"
                    + " moderation. False means the page must carry noindex. A trip stage carries"
                    + " its trip's answer.",
            required = true)
        boolean indexable) {}
