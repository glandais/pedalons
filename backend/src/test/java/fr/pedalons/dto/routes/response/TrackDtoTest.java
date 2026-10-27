package fr.pedalons.dto.routes.response;

import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import java.util.List;
import org.geolatte.geom.G3DM;
import org.junit.jupiter.api.Test;

/** The track as sent (docs/LEDGER_*.md API-145): every coordinate to the decimetre. */
class TrackDtoTest {

  @Test
  void coordinates_areSentToTheDecimetre() {
    TrackDto dto =
        TrackDto.of(
            List.of(
                new TrackPoint(43.7010248, 3.8997867, 111.89320458480073, 75.86732043561545),
                new TrackPoint(43.70020994527183, 3.8992317499, 111.64999, 176.04999)),
            List.of(),
            List.of());

    G3DM first = dto.line().getPositions().getPositionN(0);
    assertEquals(3.899787, first.getLon());
    assertEquals(43.701025, first.getLat());
    assertEquals(111.9, first.getHeight());
    assertEquals(75.9, first.getM());

    G3DM second = dto.line().getPositions().getPositionN(1);
    assertEquals(3.899232, second.getLon());
    assertEquals(43.70021, second.getLat());
    assertEquals(111.6, second.getHeight());
    assertEquals(176.0, second.getM());
  }
}
