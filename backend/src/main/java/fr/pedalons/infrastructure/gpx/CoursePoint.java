package fr.pedalons.infrastructure.gpx;

import fr.pedalons.enums.WaypointType;

/**
 * A waypoint as the devices receive it: a distance along the route, a type and a name that went
 * through {@link WaypointFormats#fitName} already (docs/LEDGER_*.md WEB-100, C3c).
 *
 * @param distanceM metres from the start, cumulated over the tracks in order
 */
public record CoursePoint(double distanceM, WaypointType type, String name) {}
