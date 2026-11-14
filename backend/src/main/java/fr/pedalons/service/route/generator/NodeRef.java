package fr.pedalons.service.route.generator;

/**
 * One end of an input edge.
 *
 * @param key osm-route-details geometric node id, stable across data updates
 * @param position the junction position
 * @param streetDegree degree in the street graph; kept for diagnostics only, routing uses the team
 *     graph degree (plan §3.1 of docs/plans/2026-11-13-generateur-boucles-equipe-conception-lot2.md)
 */
public record NodeRef(String key, LatLon position, int streetDegree) {}
