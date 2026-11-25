package fr.pedalons.dto.routes.request;

import fr.pedalons.enums.*;
import fr.pedalons.service.team.request.MinRole;
import java.util.List;
import lombok.Builder;
import org.jspecify.annotations.Nullable;

/**
 * @param view how much of each row to render. Not a filter — it changes nothing about which routes
 *     match, only how much of each one is written out, so the tile, the bounding box and the count
 *     leave it null.
 * @param excludeDeleted leave out the soft-deleted routes even for a caller who would otherwise
 *     see them (a team administrator): a picker must not offer a deleted route.
 */
@Builder
public record RouteSearchParams(
    @Nullable String search,
    int page,
    int size,
    @Nullable MinRole minRole,
    @Nullable Float minDistance,
    @Nullable Float maxDistance,
    @Nullable Float minElevationGain,
    @Nullable Float maxElevationGain,
    @Nullable Hilliness hilliness,
    @Nullable SurfaceType surfaceType,
    @Nullable WindDirection windDirection,
    @Nullable Double nearLat,
    @Nullable Double nearLon,
    @Nullable Double nearRadius,
    @Nullable NearType nearType,
    @Nullable RouteSortBy sortBy,
    @Nullable SortDirection sortDir,
    @Nullable ListViewMode view,
    // The ?tags= filter, raw — team-scoped endpoints only (docs/plans/archive/2026-10-01-tags.md
    // D7).
    @Nullable List<String> tags,
    boolean excludeDeleted) {}
