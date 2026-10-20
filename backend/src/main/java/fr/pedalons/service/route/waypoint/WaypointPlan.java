package fr.pedalons.service.route.waypoint;

import java.util.List;

/**
 * Which waypoints a track computation places (docs/LEDGER_*.md WEB-100, C3c): {@code drafts}, and
 * the ones the document being processed carries when {@code withDocumentWaypoints}.
 */
public record WaypointPlan(List<WaypointDraft> drafts, boolean withDocumentWaypoints) {

  /** Only what the file carries: an import, or a drawing (which carries none). */
  public static final WaypointPlan FROM_DOCUMENT = new WaypointPlan(List.of(), true);
}
