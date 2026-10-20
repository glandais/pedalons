package fr.pedalons.service.route.waypoint;

import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.dto.routes.request.WaypointRequest;
import fr.pedalons.enums.WaypointType;
import java.util.List;
import org.junit.jupiter.api.Test;

class WaypointDraftsTest {

  @Test
  void editorPosition_isRoundedTo7Decimals() {
    WaypointRequest request =
        new WaypointRequest(
            null,
            new GeoPoint(-1.4699977283367236, 47.14956329182145),
            WaypointType.CAFE,
            "Pause",
            null,
            null,
            null);

    WaypointDraft draft = WaypointDrafts.fromRequest(List.of(request), List.of(), null).getFirst();

    assertEquals(47.1495633, draft.lat());
    assertEquals(-1.4699977, draft.lng());
  }
}
