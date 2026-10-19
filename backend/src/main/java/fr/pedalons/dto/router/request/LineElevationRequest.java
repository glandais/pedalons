package fr.pedalons.dto.router.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

public record LineElevationRequest(
    @Schema(
            description =
                "Slug of the team the route is being drawn for. When present, the team must have"
                    + " the route planner enabled and the caller must be allowed to create routes"
                    + " in it. When absent, the domain's GPX planner must be enabled.")
        @Size(max = 250)
        @Nullable String teamSlug,
    @Schema(
            description =
                "Straight lines to read the relief of, 1 to 50, at most 100 km each and 200 km"
                    + " together",
            required = true)
        @NotEmpty
        @Size(max = 50)
        List<@Valid @NotNull StraightLine> lines) {}
