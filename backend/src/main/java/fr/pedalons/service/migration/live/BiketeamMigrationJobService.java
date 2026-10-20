package fr.pedalons.service.migration.live;

import fr.pedalons.common.PersistenceErrors;
import fr.pedalons.common.TokenUtils;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.BiketeamMigrationRunningException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.migration.BiketeamMigrationJob;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.migration.internal.BiketeamJobCountsDto;
import fr.pedalons.dto.migration.internal.BiketeamJobCreatedDto;
import fr.pedalons.dto.migration.internal.BiketeamJobErrorDto;
import fr.pedalons.dto.migration.internal.BiketeamJobProgressDto;
import fr.pedalons.dto.migration.internal.BiketeamJobStatusDto;
import fr.pedalons.dto.migration.internal.BiketeamJobTargetTeamDto;
import fr.pedalons.dto.migration.internal.BiketeamJobTriggerRequest;
import fr.pedalons.dto.migration.internal.BiketeamJobTriggerResult;
import fr.pedalons.enums.BiketeamMigrationStatus;
import fr.pedalons.enums.BiketeamMigrationTargetState;
import fr.pedalons.repository.migration.BiketeamMigrationJobRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.service.migration.BiketeamMigrationProgress.Phase;
import fr.pedalons.service.security.annotation.Public;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * The job side of the biketeam live migration: biketeam's M2M trigger and status poll (§5), and the
 * row transitions the worker makes (§7.1) — claim, progress, success, failure, retry, recovery of
 * stuck jobs, expiry of unredeemed grants.
 *
 * <p>Nothing here depends on the request's {@code Host}: the M2M calls come from biketeam's server, and the
 * target domain is the one stored on the row at confirmation.
 */
@ApplicationScoped
public class BiketeamMigrationJobService {

  private static final Logger LOG = Logger.getLogger(BiketeamMigrationJobService.class);

  /** Job error codes that are not {@code ErrorCode}s — they only exist in the M2M status. */
  public static final String WORKER_LOST = "WORKER_LOST";

  public static final String INTERNAL_ERROR = "INTERNAL_ERROR";

  @Inject BiketeamLiveMigrationConfig config;
  @Inject BiketeamMigrationJobRepository jobRepository;
  @Inject TeamRepository teamRepository;
  @Inject BiketeamTargetResolver targetResolver;
  @Inject ObjectMapper objectMapper;

  private enum TriggerOutcome {
    CREATED,
    REPLAYED,
    INVALID,
    EXPIRED,
    RUNNING
  }

  /**
   * @param targetTeamSlug the slug the job lands (or landed) on, for CREATED and REPLAYED
   */
  private record TriggerDecision(
      TriggerOutcome outcome, @Nullable BiketeamMigrationJob job, @Nullable String targetTeamSlug) {
    TriggerDecision(TriggerOutcome outcome) {
      this(outcome, null, null);
    }
  }

  // ------------------------------------------------------------------ M2M

  /**
   * Redeems a grant: the row goes GRANTED → QUEUED. Every field of the request must equal the row's.
   * Replaying a trigger whose grant this very job already consumed — biketeam lost the response —
   * answers the same job again.
   *
   * <p>{@code @Public} for the architecture rule: the caller was authenticated by {@code
   * BiketeamM2MFilter} before the resource ran.
   */
  @Public
  public BiketeamJobTriggerResult trigger(BiketeamJobTriggerRequest request) {
    ensureEnabled();
    String grantHash = TokenUtils.hashToken(Objects.requireNonNull(request.grant()));
    TriggerDecision decision;
    try {
      decision = QuarkusTransaction.requiringNew().call(() -> decide(request, grantHash));
    } catch (RuntimeException e) {
      // uk_biketeam_migrations_active: another trigger for the same biketeam team won the race.
      if (PersistenceErrors.isUniqueViolation(e)) {
        throw new BiketeamMigrationRunningException(activeJobId(request.teamId()));
      }
      throw e;
    }
    BiketeamMigrationJob job = decision.job();
    return switch (decision.outcome()) {
      case CREATED -> new BiketeamJobTriggerResult(created(decision), true);
      case REPLAYED -> new BiketeamJobTriggerResult(created(decision), false);
      case INVALID -> throw new ForbiddenException(ErrorCode.BIKETEAM_GRANT_INVALID);
      case EXPIRED -> throw new BadRequestException(ErrorCode.BIKETEAM_GRANT_EXPIRED);
      case RUNNING -> throw new BiketeamMigrationRunningException(activeJobId(request.teamId()));
    };
  }

  private TriggerDecision decide(BiketeamJobTriggerRequest request, String grantHash) {
    BiketeamMigrationJob job = jobRepository.findByGrantHash(grantHash).orElse(null);
    if (job == null
        || !job.getRequestId().equals(request.requestId())
        || !job.getBiketeamTeamId().equals(request.teamId())
        || job.isDryRun() != Boolean.TRUE.equals(request.dryRun())
        || job.isReset() != Boolean.TRUE.equals(request.reset())) {
      return new TriggerDecision(TriggerOutcome.INVALID);
    }
    Instant now = Instant.now();
    switch (job.getStatus()) {
      case EXPIRED -> {
        return new TriggerDecision(TriggerOutcome.EXPIRED);
      }
      case GRANTED -> {
        if (job.getGrantExpiresAt().isBefore(now)) {
          // Committed with the refusal: the grant is dead either way.
          job.setStatus(BiketeamMigrationStatus.EXPIRED);
          return new TriggerDecision(TriggerOutcome.EXPIRED);
        }
        Optional<BiketeamMigrationJob> active =
            jobRepository.findActiveByBiketeamTeamId(job.getBiketeamTeamId());
        if (active.isPresent() && !active.get().getId().equals(job.getId())) {
          return new TriggerDecision(TriggerOutcome.RUNNING);
        }
        job.setStatus(BiketeamMigrationStatus.QUEUED);
        job.setQueuedAt(now);
        job.setNextAttemptAt(now);
        job.setProgress(toJson(new BiketeamJobProgressDto(Phase.QUEUED.name(), 0, 0)));
        // Flushed here so that uk_biketeam_migrations_active answers inside this call.
        jobRepository.flush();
        LOG.infof(
            "Biketeam migration job %s queued for team '%s' (dryRun=%s, reset=%s)",
            TsidUtils.toString(job.getId()),
            job.getBiketeamTeamId(),
            job.isDryRun(),
            job.isReset());
        return new TriggerDecision(TriggerOutcome.CREATED, job, targetTeamSlug(job));
      }
      default -> {
        return new TriggerDecision(TriggerOutcome.REPLAYED, job, targetTeamSlug(job));
      }
    }
  }

  private static BiketeamJobCreatedDto created(TriggerDecision decision) {
    BiketeamMigrationJob job = Objects.requireNonNull(decision.job());
    return new BiketeamJobCreatedDto(
        TsidUtils.toString(job.getId()),
        job.getStatus().name(),
        Objects.requireNonNull(decision.targetTeamSlug()));
  }

  /**
   * The slug the job lands on — not the biketeam id, which may not even be a Pédalons slug
   * ({@code club_x}): the team the job already wrote to; else the migrated team a replay reuses,
   * wherever it was renamed to; else — new team, or reset — the normalised {@link
   * BiketeamTargetResolver#targetSlug}. As of now: the job re-evaluates when it runs.
   */
  private String targetTeamSlug(BiketeamMigrationJob job) {
    if (job.getTargetTeamId() != null) {
      Optional<Team> team = teamRepository.findByIdOptional(job.getTargetTeamId());
      if (team.isPresent() && !team.get().isDeleted()) {
        return team.get().getSlug();
      }
    }
    BiketeamTargetResolver.Target target =
        targetResolver.evaluate(job.getDomain().getId(), job.getBiketeamTeamId(), job.isReset());
    if (target.state() == BiketeamMigrationTargetState.EXISTING_MIGRATED && !job.isReset()) {
      return target.slug();
    }
    return BiketeamTargetResolver.targetSlug(job.getBiketeamTeamId());
  }

  private @Nullable String activeJobId(@Nullable String biketeamTeamId) {
    if (biketeamTeamId == null) {
      return null;
    }
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                jobRepository
                    .findActiveByBiketeamTeamId(biketeamTeamId)
                    .map(j -> TsidUtils.toString(j.getId()))
                    .orElse(null));
  }

  /**
   * A job as biketeam polls it. An unknown or malformed id, or a row that was never triggered (not a
   * job), is a {@code 404 BIKETEAM_JOB_NOT_FOUND} — the one answer biketeam reads as the job lost.
   */
  @Public
  @Transactional
  public BiketeamJobStatusDto status(String jobId) {
    ensureEnabled();
    long id;
    try {
      id = TsidUtils.toLong(jobId);
    } catch (RuntimeException e) {
      throw new NotFoundException(ErrorCode.BIKETEAM_JOB_NOT_FOUND);
    }
    BiketeamMigrationJob job =
        jobRepository
            .findByIdOptional(id)
            .filter(j -> j.getStatus().isJob())
            .orElseThrow(() -> new NotFoundException(ErrorCode.BIKETEAM_JOB_NOT_FOUND));
    return toStatusDto(job);
  }

  BiketeamJobStatusDto toStatusDto(BiketeamMigrationJob job) {
    BiketeamJobProgressDto progress =
        job.getProgress() == null
            ? new BiketeamJobProgressDto(Phase.QUEUED.name(), 0, 0)
            : fromJson(job.getProgress(), BiketeamJobProgressDto.class);
    BiketeamJobResult result =
        job.getResult() == null ? null : fromJson(job.getResult(), BiketeamJobResult.class);
    BiketeamJobTargetTeamDto targetTeam = null;
    if (job.getTargetTeamId() != null) {
      Team team = teamRepository.findByIdOptional(job.getTargetTeamId()).orElse(null);
      if (team != null) {
        targetTeam =
            new BiketeamJobTargetTeamDto(
                team.getSlug(),
                team.getName(),
                BiketeamMigrationUrls.teamUrl(job.getBaseUrl(), team.getSlug()));
      }
    }
    boolean succeeded = job.getStatus() == BiketeamMigrationStatus.SUCCEEDED;
    return new BiketeamJobStatusDto(
        TsidUtils.toString(job.getId()),
        job.getRequestId(),
        job.getBiketeamTeamId(),
        job.isDryRun(),
        job.isReset(),
        job.getStatus().name(),
        job.getAttempts(),
        job.getQueuedAt(),
        job.getStartedAt(),
        job.getFinishedAt(),
        progress,
        targetTeam,
        result == null || result.counts() == null ? BiketeamJobCountsDto.zero() : result.counts(),
        result == null || result.warnings() == null ? List.of() : result.warnings(),
        result != null && result.warningsTruncated(),
        job.getStatus() == BiketeamMigrationStatus.FAILED ? errorOf(job) : null,
        job.getStatus() == BiketeamMigrationStatus.QUEUED
                || job.getStatus() == BiketeamMigrationStatus.RUNNING
            ? errorOf(job)
            : null,
        succeeded && result != null ? result.urlMap() : null);
  }

  /**
   * The error stored on the row: the final one of a FAILED job, or — QUEUED/RUNNING — that of the
   * last failed attempt, written by {@link #retryOrFail} and {@link #recoverStuck}.
   */
  private static @Nullable BiketeamJobErrorDto errorOf(BiketeamMigrationJob job) {
    return job.getErrorCode() == null
        ? null
        : new BiketeamJobErrorDto(
            job.getErrorCode(), job.getErrorMessage() == null ? "" : job.getErrorMessage());
  }

  // ------------------------------------------------------------------ worker

  /** Moves the head of the queue to RUNNING, in its own short transaction. */
  public Optional<Long> claimNext() {
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              Instant now = Instant.now();
              Long id = jobRepository.findNextQueuedIdSkipLocked(now);
              if (id == null) {
                return Optional.<Long>empty();
              }
              return jobRepository.claim(id, now) ? Optional.of(id) : Optional.<Long>empty();
            });
  }

  /** The claimed job, as plain values. */
  public LiveJobContext loadContext(long jobId) {
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              BiketeamMigrationJob job = jobRepository.findById(jobId);
              if (job == null) {
                throw new IllegalStateException("Claimed job vanished: " + jobId);
              }
              return new LiveJobContext(
                  job.getId(),
                  TsidUtils.toString(job.getId()),
                  job.getDomain().getId(),
                  job.getUser().getId(),
                  job.getBiketeamTeamId(),
                  job.getRequestId(),
                  job.isDryRun(),
                  job.isReset(),
                  job.getBaseUrl(),
                  job.getAttempts(),
                  job.getTargetTeamId());
            });
  }

  /**
   * Writes progress, counts so far and the heartbeat. Refuses — {@link BiketeamJobLostException} —
   * when this run no longer owns the row.
   */
  public void recordProgress(LiveJobContext ctx, JsonNode progress, JsonNode result) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              BiketeamMigrationJob job = owned(ctx);
              job.setProgress(progress);
              job.setResult(result);
              job.setHeartbeatAt(Instant.now());
            });
  }

  public void setTargetTeam(LiveJobContext ctx, long teamId) {
    QuarkusTransaction.requiringNew().run(() -> owned(ctx).setTargetTeamId(teamId));
  }

  public void succeed(LiveJobContext ctx, JsonNode progress, JsonNode result) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              BiketeamMigrationJob job = owned(ctx);
              Instant now = Instant.now();
              job.setStatus(BiketeamMigrationStatus.SUCCEEDED);
              job.setProgress(progress);
              job.setResult(result);
              job.setHeartbeatAt(now);
              job.setFinishedAt(now);
              job.setErrorCode(null);
              job.setErrorMessage(null);
            });
  }

  /** FAILED for good — a business failure, or the last attempt. */
  public void fail(LiveJobContext ctx, String code, String message) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              BiketeamMigrationJob job = owned(ctx);
              markFailed(job, code, message);
            });
  }

  /**
   * A transient failure: back on the queue with an exponential delay ({@code 2^attempts} minutes)
   * while attempts remain, FAILED with {@code finalCode} otherwise. Requeued, the row keeps {@code
   * finalCode} and the message as the last attempt's error ({@code lastAttemptError} of the status);
   * a later success clears them.
   */
  public void retryOrFail(LiveJobContext ctx, String finalCode, String message) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              BiketeamMigrationJob job = owned(ctx);
              if (job.getAttempts() >= config.maxAttempts()) {
                markFailed(job, finalCode, message);
                return;
              }
              job.setStatus(BiketeamMigrationStatus.QUEUED);
              job.setNextAttemptAt(
                  Instant.now().plus(Duration.ofMinutes(1L << Math.min(job.getAttempts(), 10))));
              job.setErrorCode(truncateCode(finalCode));
              job.setErrorMessage(truncate(message));
              LOG.warnf(
                  "Biketeam migration job %s: attempt %d failed (%s), retrying",
                  ctx.jobTsid(), job.getAttempts(), message);
            });
  }

  private void markFailed(BiketeamMigrationJob job, String code, String message) {
    job.setStatus(BiketeamMigrationStatus.FAILED);
    job.setErrorCode(truncateCode(code));
    job.setErrorMessage(truncate(message));
    job.setFinishedAt(Instant.now());
    LOG.warnf(
        "Biketeam migration job %s failed: %s — %s",
        TsidUtils.toString(job.getId()), code, message);
  }

  /**
   * The row, locked for this short transaction, if this run still owns it. The lock orders the
   * write after a concurrent {@link #recoverStuck()}: this run then sees QUEUED and stops, or the
   * recovery sees the fresh heartbeat and leaves the job alone.
   */
  private BiketeamMigrationJob owned(LiveJobContext ctx) {
    BiketeamMigrationJob job = jobRepository.findById(ctx.jobId(), LockModeType.PESSIMISTIC_WRITE);
    if (job == null
        || job.getStatus() != BiketeamMigrationStatus.RUNNING
        || job.getAttempts() != ctx.attempt()) {
      throw new BiketeamJobLostException(
          "Job " + ctx.jobTsid() + " is no longer run by this worker");
    }
    return job;
  }

  /**
   * RUNNING jobs silent for longer than {@code stuck-after} — a crash, or a pod killed mid-run. The
   * migration is idempotent, so starting over is correct and, thanks to the GPX fingerprints, quick.
   *
   * <p>Two conditional bulk updates, never entities: a worker writing its heartbeat at the same
   * moment must neither roll the recovery of the other jobs back (optimistic lock) nor be requeued
   * once its heartbeat is committed — the condition is re-read on the locked row.
   *
   * @return how many jobs were requeued or failed
   */
  @Transactional
  public int recoverStuck() {
    Instant now = Instant.now();
    Instant cutoff = now.minus(config.stuckAfter());
    int failed =
        jobRepository.failStuck(
            cutoff,
            config.maxAttempts(),
            now,
            WORKER_LOST,
            "No heartbeat for more than " + config.stuckAfter() + " on the last attempt");
    int requeued =
        jobRepository.requeueStuck(
            cutoff,
            config.maxAttempts(),
            now,
            WORKER_LOST,
            "No heartbeat for more than " + config.stuckAfter() + ", requeued");
    if (failed + requeued > 0) {
      LOG.warnf(
          "Biketeam migration: %d stuck job(s) requeued, %d failed (%s) — no heartbeat since %s",
          requeued, failed, WORKER_LOST, cutoff);
    }
    return failed + requeued;
  }

  /**
   * GRANTED rows whose grant lapsed become EXPIRED. They stay as the team's migration history until
   * {@link BiketeamMigrationRetentionScheduler} purges them.
   */
  @Transactional
  public int expireGrants() {
    return jobRepository.expireGrants(Instant.now());
  }

  // ------------------------------------------------------------------ helpers

  private void ensureEnabled() {
    if (!config.isEnabled()) {
      throw new NotFoundException();
    }
  }

  /** Serialises a job document with the application's mapper. */
  public JsonNode toJson(Object value) {
    return objectMapper.valueToTree(value);
  }

  private <T> T fromJson(JsonNode node, Class<T> type) {
    try {
      return objectMapper.treeToValue(node, type);
    } catch (JacksonException e) {
      throw new IllegalStateException("Unreadable job document", e);
    }
  }

  private static String truncateCode(String code) {
    return code.length() <= 60 ? code : code.substring(0, 60);
  }

  private static String truncate(String message) {
    return message.length() <= 1000 ? message : message.substring(0, 1000);
  }
}
