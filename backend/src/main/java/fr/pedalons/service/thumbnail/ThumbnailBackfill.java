package fr.pedalons.service.thumbnail;

import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.repository.thumbnail.ThumbnailBackfillRepository;
import fr.pedalons.repository.thumbnail.ThumbnailBackfillRepository.Remaining;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * Redraws the thumbnails (routes, rides, trips) drawn before the current {@link
 * MapThumbnailRenderer#VERSION}, which is recorded per entity in {@code
 * team_entities.thumbnail_version} like {@code elevation_pipeline} is for the GPX (docs/LEDGER_*.md
 * OPS-71, API-223). Every minute, redraws the most recent entities first (what people see), under
 * a cap of {@code pedalons.thumbnails.backfill.per-hour} entities an hour per backend.
 *
 * <p>An entity edited in the last {@link #QUIET} is left for later, its own save may be redrawing
 * it. An entity is redrawn in a transaction of its own ({@link #TIMEOUT}), which first claims its row
 * and its asset rows ({@code for
 * update skip locked}): the two backends of a rolling deploy never draw the same one, and no
 * transaction is held across the others' renders. The cap is per backend: during the minutes of a
 * deploy, when two run, the rate may double. Nothing is held between passes: a restart, a deploy
 * or switching it off and on resumes where it stopped.
 *
 * <p>A restyle is no reason to lose a good thumbnail: a failure (a render, the tileserver, the
 * upload) <b>keeps</b> the existing ones ({@link ThumbnailService#redrawKeepingOnFailure}), counts
 * an attempt, delays the next one (15 minutes, doubled each time, 24 hours at most) and ends the
 * pass: the tileserver may be down, it is not hammered. After {@link #MAX_ATTEMPTS} the entity
 * keeps its old thumbnail and is out of the catch-up (the log reports those); the admin
 * regeneration, which stamps on success, is the way back. Only an entity that has both its light and
 * dark thumbnails is looked at: the catch-up replaces files, it creates no row.
 *
 * <p>Rolling deploy: the previous release redraws on save with the old style and stamps nothing, so
 * an entity it redraws keeps its old stamp. Harmless when null (the catch-up redraws it); for one
 * already stamped with the current version it means a thumbnail in the old style until its next
 * save, which is accepted.
 */
@ApplicationScoped
public class ThumbnailBackfill {

  private static final Logger LOG = Logger.getLogger(ThumbnailBackfill.class);

  /** Failed redraws after which an entity is left with its old thumbnail. */
  public static final int MAX_ATTEMPTS = 5;

  @ConfigProperty(name = "pedalons.thumbnails.backfill.enabled", defaultValue = "true")
  boolean enabled;

  /** Entities redrawn per hour, per backend. */
  @ConfigProperty(name = "pedalons.thumbnails.backfill.per-hour", defaultValue = "300")
  int perHour;

  @Inject ThumbnailBackfillRepository repository;
  @Inject ThumbnailService thumbnailService;
  @Inject EntityManager entityManager;

  /**
   * An entity edited this recently is left for a later pass: its save may be redrawing the same
   * thumbnails, and the two writing the same asset rows would fail one of them (optimistic lock).
   */
  static final Duration QUIET = Duration.ofMinutes(10);

  /**
   * A pair of renders on a cold tile cache can be slow: the transaction holding the claim gets more
   * than the default 60 s, after which it is rolled back and counted as a failure.
   */
  static final Duration TIMEOUT = Duration.ofMinutes(5);

  private Duration quiet = QUIET;

  private volatile boolean foundLastTime;

  /** Whether the scheduled catch-up is switched on. */
  public boolean isEnabled() {
    return enabled;
  }

  /** The cap of entities redrawn per hour, per backend. */
  public int getPerHour() {
    return perHour;
  }

  /** For the tests: the switch and the cap; no quiet period, the test data being just written. */
  public void setForTest(boolean enabled, int perHour) {
    this.enabled = enabled;
    this.perHour = perHour;
    this.quiet = Duration.ZERO;
    this.foundLastTime = false;
  }

  @Scheduled(every = "1m", delayed = "3m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void run() {
    try {
      pass(Instant.now());
    } catch (Exception e) {
      LOG.error("Thumbnail backfill failed", e);
    }
  }

  /** What became of the entity one step tried. */
  private enum Step {
    NONE,
    REDRAWN,
    FAILED
  }

  /**
   * One pass: at most {@code ceil(perHour / 60)} entities, none after a failure. Public for the
   * tests.
   *
   * @return how many were redrawn
   */
  public int pass(Instant now) {
    if (!enabled || perHour <= 0) {
      return 0;
    }
    int budget = (int) Math.ceil(perHour / 60.0);
    int redrawn = 0;
    while (redrawn < budget) {
      Step step = step(now);
      if (step == Step.NONE) {
        break;
      }
      if (step == Step.FAILED) {
        break;
      }
      redrawn++;
    }
    Remaining left =
        QuarkusTransaction.requiringNew().call(() -> repository.remaining(MAX_ATTEMPTS));
    boolean found = left.left() > 0;
    if (found) {
      LOG.infof(
          "Thumbnail backfill: %d redrawn; left %d; given up %d",
          redrawn, left.left(), left.givenUp());
    } else if (foundLastTime) {
      LOG.infof("Thumbnail backfill done: nothing left to redraw, %d given up", left.givenUp());
    }
    foundLastTime = found;
    return redrawn;
  }

  private Step step(Instant now) {
    AtomicReference<Long> claimed = new AtomicReference<>();
    try {
      return QuarkusTransaction.requiringNew()
          .timeout((int) TIMEOUT.toSeconds())
          .call(() -> {
            Long id = repository.claim(now, MAX_ATTEMPTS, quiet);
            if (id == null) {
              return Step.NONE;
            }
            claimed.set(id);
            // Redrawn and stamped in this transaction; on a failure nothing was touched
            if (thumbnailService.redrawKeepingOnFailure(entityManager.find(TeamEntity.class, id))) {
              return Step.REDRAWN;
            }
            repository.recordFailure(id, now);
            return Step.FAILED;
          });
    } catch (RuntimeException e) {
      Long id = claimed.get();
      LOG.warnf(e, "Thumbnail backfill: redrawing %s failed", id);
      if (id == null) {
        throw e;
      }
      // The transaction is rolled back, with the claim: count the failure apart
      QuarkusTransaction.requiringNew().run(() -> repository.recordFailure(id, now));
      return Step.FAILED;
    }
  }
}
