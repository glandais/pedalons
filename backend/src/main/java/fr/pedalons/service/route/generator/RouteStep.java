package fr.pedalons.service.route.generator;

/**
 * One edge of a generated route.
 *
 * @param edgeId edge id on the {@link NetworkGraph}; a piece created by splitting an edge at the
 *     start or the end reports its parent edge
 * @param forward true when the edge is ridden from its {@code u} end to its {@code v} end
 */
public record RouteStep(int edgeId, boolean forward) {}
