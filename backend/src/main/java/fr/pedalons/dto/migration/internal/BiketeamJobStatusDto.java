package fr.pedalons.dto.migration.internal;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * M2M: a job as biketeam polls it (docs/plans/2026-09-22-biketeam-live-migration.md §5.2). Every
 * field is always present, {@code null} when it has no value — hence {@code ALWAYS}, against the
 * application-wide {@code NON_NULL}.
 *
 * @param status QUEUED, RUNNING, SUCCEEDED or FAILED
 * @param urlMap only once SUCCEEDED: urlMap key ({@code TEAM}, {@code RIDE}…) → biketeam id →
 *     absolute Pédalons URL
 * @param error only once FAILED: why the job failed for good
 * @param lastAttemptError only while QUEUED or RUNNING after a failed attempt, awaiting or running
 *     the next one: why that attempt failed ({@code EXPORT_UNAVAILABLE}, {@code INTERNAL_ERROR},
 *     {@code WORKER_LOST}); null otherwise — a FAILED job carries its reason in {@code error}
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record BiketeamJobStatusDto(
    String jobId,
    String requestId,
    String teamId,
    String status,
    int attempt,
    @Nullable Instant queuedAt,
    @Nullable Instant startedAt,
    @Nullable Instant finishedAt,
    BiketeamJobProgressDto progress,
    @Nullable BiketeamJobTargetTeamDto targetTeam,
    BiketeamJobCountsDto counts,
    List<BiketeamJobWarningDto> warnings,
    boolean warningsTruncated,
    @Nullable BiketeamJobErrorDto error,
    @Nullable BiketeamJobErrorDto lastAttemptError,
    @Nullable Map<String, Map<String, String>> urlMap) {}
