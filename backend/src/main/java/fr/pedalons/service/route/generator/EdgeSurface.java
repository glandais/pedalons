package fr.pedalons.service.route.generator;

import org.jspecify.annotations.Nullable;

/**
 * Surface of an input edge, only present when homogeneous along the edge.
 *
 * @param detail lowercase raw value (open list); the builder knows 13 values and ignores the rest
 */
public record EdgeSurface(
    SurfaceClass surfaceClass, @Nullable String detail, SurfaceSource source) {}
