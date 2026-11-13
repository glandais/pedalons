package fr.pedalons.repository.trip;

import fr.pedalons.enums.Status;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * One stage of a trip a user is registered for, as scalars: the stage, its trip, its own route and
 * the names of its two places. Selected in a single query so nothing enters the persistence context
 * — see {@link TripParticipationRepository#findUpcomingRegisteredStages}. The counterpart of the
 * rides' {@code RegisteredGroupRow} (docs/LEDGER_*.md API-168).
 */
public record RegisteredStageRow(
    String teamSlug,
    String tripSlug,
    String tripName,
    String stageName,
    Instant stageStartAt,
    String timezone,
    Long routeId,
    String routeSlug,
    String routeName,
    @Nullable Float routeDistance,
    @Nullable Float routeElevationGain,
    @Nullable String startPlaceName,
    @Nullable String endPlaceName,
    String teamName,
    Status tripStatus,
    @Nullable Instant stageEndAt) {}
