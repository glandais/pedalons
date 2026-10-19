package fr.pedalons.dto.router.request;

import fr.pedalons.common.GeoPoint;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/** One straight line of the route editor, whose relief the elevation endpoint reads. */
public record StraightLine(
    @Schema(required = true) @NotNull @Valid GeoPoint from,
    @Schema(required = true) @NotNull @Valid GeoPoint to) {}
