package fr.pedalons.dto.admin;

/**
 * What a refresh did: answered at once with the plan of a dry run (200), or started a pass in the
 * {@code background} (202). Lives with the DTOs, not in the service, so the resource may read it:
 * {@code ArchitectureTest} only lets the API call service methods that carry an access annotation.
 */
public record RouteGeneratorOverlayRefreshResult(
    RouteGeneratorOverlayRefreshResponse response, boolean background) {}
