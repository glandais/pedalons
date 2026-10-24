package fr.pedalons.dto.weather.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.RelativeWind;
import fr.pedalons.service.weather.WindSegment;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "The wind on the stretch between two checkpoints, as the rider meets it")
@ValidateSchema
public record WindSegmentDto(
    @Schema(
            description =
                "Start of the stretch, equal to its checkpoint's distance: metres from the start of"
                    + " the route, its tracks laid end to end in the order of their ids, without"
                    + " counting the gap between the end of one track and the start of the next"
                    + " (unlike the 4th coordinate of a track geometry, which restarts at 0 on each"
                    + " track).",
            required = true)
        double fromDistance,
    @Schema(
            description =
                "End of the stretch, equal to the next checkpoint's distance: metres from the start"
                    + " of the route, its tracks laid end to end in the order of their ids, without"
                    + " counting the gap between the end of one track and the start of the next"
                    + " (unlike the 4th coordinate of a track geometry, which restarts at 0 on each"
                    + " track).",
            required = true)
        double toDistance,
    @Schema(
            description =
                "HEAD when the head component exceeds half the wind speed, TAIL below minus half,"
                    + " CROSS otherwise. Always shown with its label and an arrow, not by colour"
                    + " alone.",
            required = true)
        RelativeWind relativeWind,
    @Schema(
            description = "Mean head component, km/h, signed: positive against the rider",
            required = true)
        double headwind) {

  public static WindSegmentDto from(WindSegment segment) {
    return new WindSegmentDto(
        segment.fromDistance(), segment.toDistance(), segment.relativeWind(), segment.headwind());
  }
}
