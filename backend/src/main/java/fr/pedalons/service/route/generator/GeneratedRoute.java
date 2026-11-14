package fr.pedalons.service.route.generator;

import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * A route proposed by the generator, every metre of it on a team edge (plan §5.4).
 *
 * @param points concatenated geometry in travel order, joints once
 * @param distanceM sum of the edge lengths
 * @param ascentM sum of the gain of each state in its direction
 * @param bearingDeviationDeg null when the bearing did not apply
 * @param familiarity mean normalised familiarity, 0..1, weighted by length
 * @param unpavedShare unpaved length over distance (unknown surface counts as paved)
 * @param sharedM length of the edges ridden twice, each counted once
 * @param crossings revisited junctions outside the tails
 * @param steps parent edge ids and directions, in order
 */
public record GeneratedRoute(
    List<LatLon> points,
    double distanceM,
    double ascentM,
    double descentM,
    @Nullable Double bearingDeviationDeg,
    double familiarity,
    double unpavedShare,
    double sharedM,
    int crossings,
    List<RouteStep> steps) {}
