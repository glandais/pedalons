package fr.pedalons.service.route.generator;

import java.util.List;

/**
 * The edges of one team route, in travel order.
 *
 * @param excluded {@code Route.excludedFromGenerator}: the track still shapes node merging but never
 *     counts as support and never opens a direction (plan §10.8)
 * @param kind {@code Route.surfaceType}
 */
public record TrackInput(long trackId, boolean excluded, TrackKind kind, List<TrackEdge> edges) {}
