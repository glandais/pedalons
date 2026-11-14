package fr.pedalons.service.route.generator;

/**
 * The nearest point of the network to a position.
 *
 * @param offsetM metres along the edge from its {@code u} end, in the same metres as the edge length
 */
public record Snap(int edge, double offsetM, LatLon point, double distanceM) {}
