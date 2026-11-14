package fr.pedalons.service.route.generator;

/** A WGS84 position, decoupled from any API or JSON type. */
public record LatLon(double lat, double lon) {}
