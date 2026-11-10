package fr.pedalons.repository.trip;

import fr.pedalons.enums.GpsServiceType;
import java.time.Instant;

/**
 * One trip registration's stage whose route a GPS service connection should hold, as ids and
 * scalars: the connection, the stage, its departure and zone, the trip's name and the stage's own
 * route — never the trip's, which a stage without a route does not fall back on. Selected in a
 * single query per domain — see {@link TripParticipationRepository#findGpsSyncStageTargets} — and
 * used by the automatic route sync (docs/LEDGER_*.md API-120), beside the rides' {@code
 * GpsSyncTargetRow}.
 */
public record GpsSyncStageTargetRow(
    Long connectionId,
    GpsServiceType serviceType,
    Long userId,
    Long stageId,
    String stageName,
    Instant stageStartAt,
    String timezone,
    String tripName,
    Long routeId) {}
