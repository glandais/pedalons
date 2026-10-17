package fr.pedalons.dto.router.request;

import fr.pedalons.common.GeoPoint;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

public record RouterRequest(
    @Schema(required = true) @Valid GeoPoint from,
    @Schema(required = true) @Valid GeoPoint to,
    @Schema(required = true) RouterProfile profile,
    @Schema(
            description =
                "Slug of the team the route is being drawn for. When present, the team must have"
                    + " the route planner enabled and the caller must be allowed to create routes"
                    + " in it. When absent, the domain's GPX planner must be enabled.")
        @Size(max = 250)
        @Nullable String teamSlug) {}
