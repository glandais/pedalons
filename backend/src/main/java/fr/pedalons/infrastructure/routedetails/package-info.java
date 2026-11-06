/**
 * The osm-route-details client (github.com/glandais/osm-route-details, api 1.6, in the shared
 * stack): elevation profile, bridges and tunnels, and surface along a track, in one call. Phase A of
 * docs/plans/2026-11-05-osm-route-details.md (docs/LEDGER_*.md API-150): the requests, the subset of
 * the answer Pédalons reads, the error classification, the slicing of a long route ({@link
 * fr.pedalons.infrastructure.routedetails.RouteSlicer}) and the stitching of its answers ({@link
 * fr.pedalons.infrastructure.routedetails.RouteDetailsStitcher}), and {@link
 * fr.pedalons.infrastructure.routedetails.RouteDetailsGateway}, which the rest of the backend and
 * the tests go through. Nothing calls it yet.
 */
@NullMarked
package fr.pedalons.infrastructure.routedetails;

import org.jspecify.annotations.NullMarked;
