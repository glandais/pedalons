package fr.pedalons.dto.common;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(name = "GeoJsonLineString")
@ValidateSchema
public record GeoJsonLineString(
    @Schema(
            enumeration = {"LineString"},
            required = true)
        String type,
    @Schema(
            description =
                "Array of [lon, lat] coordinates, followed by the elevation in metres when the line"
                    + " carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line)"
                    + " adds a 4th component, [lon, lat, ele, dist]: the distance in metres from"
                    + " the start of THAT track, monotonic, restarting at 0 on each track of the"
                    + " route; it is not the distance along the whole route.",
            required = true)
        double[][] coordinates) {}
