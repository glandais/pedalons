package fr.pedalons.service.route.waypoint;

import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import org.jspecify.annotations.Nullable;

/**
 * A waypoint to place on a track (docs/LEDGER_*.md WEB-100, C3c): where its author wants it, what
 * it is, and what is known of where it used to be.
 *
 * @param id the id of the stored row it stands for, null for a new point
 * @param previousDistance where it sat on the previous track, or the distance the editor sent;
 *     null when nothing is known (the first passage is then taken)
 * @param previousTotal the length of that previous track, to rescale {@code previousDistance} onto
 *     a track of another length; null when {@code previousDistance} is to be used as it is
 */
public record WaypointDraft(
    @Nullable Long id,
    double lat,
    double lng,
    String name,
    @Nullable String description,
    WaypointType type,
    WaypointOrigin origin,
    @Nullable Double previousDistance,
    @Nullable Double previousTotal) {}
