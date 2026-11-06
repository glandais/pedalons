package fr.pedalons.service.route;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.route.RawTrackBackfillSkip.Reason;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.GpxTrackRepository.TrackSize;
import fr.pedalons.repository.route.RawTrackBackfillRepository;
import fr.pedalons.repository.route.RawTrackBackfillRepository.Candidate;
import fr.pedalons.service.asset.AssetService;
import io.agroal.api.AgroalDataSource;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.geolatte.geom.G2D;
import org.geolatte.geom.LineString;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;

/**
 * The catch-up of the raw line of the tracks saved before it existed (docs/LEDGER_*.md API-149,
 * phase D), biketeam ones included: every five minutes, takes a batch of routes with a track
 * without {@code raw_geometry} (most recent first), reads each one's current original GPX again
 * and writes its tracks as {@link GpxProcessingService#rawTracks} extracts them (same sanitizing,
 * tracks under two points dropped), 2D — what a save writes since phase A. No elevation, no
 * pipeline, no file rewritten.
 *
 * <p>Per route, three phases like the surface worker: the candidates in a short transaction, the
 * read and the parse outside any, the write in a short transaction that locks the route and writes
 * only if its original is still the one read and it has as many tracks as the file, and then only
 * the rows still without a line. A route that cannot be caught up (original missing or unreadable,
 * another number of tracks) is given up in {@code raw_track_backfill_skip} and never picked again;
 * one saved in between is left to the next pass, or leaves the candidates by itself (a save writes
 * the line). Idempotent: a second pass over the same route writes nothing.
 *
 * <p>Only a cause that the next read would meet again gives a route up. When the bucket or the
 * database fails (unreachable, a timeout, a lock), nothing is marked and the pass ends there: the
 * next one starts again from the same route, so an outage costs passes, not routes. A route whose
 * write fails {@link #MAX_WRITE_FAILURES} passes in a row is given up all the same ({@code ERROR}),
 * so that a write that always fails cannot hold the catch-up for good.
 *
 * <p>A pass holds a session advisory lock on a connection of its own (taken without waiting: a
 * backend that does not get it skips the pass), so the two backends of a rolling deploy never read
 * the same originals at once, while the reads stay outside any transaction.
 *
 * <p>It queues nothing: a recompute of a track reads its original again, so a line denser than the
 * stored points needs no follow-up here ({@code RouteDetailsBackfill}, docs/LEDGER_*.md API-150).
 */
@ApplicationScoped
public class RawTrackBackfill {

  private static final Logger LOG = Logger.getLogger(RawTrackBackfill.class);

  /** Passes in a row whose write of the same route failed before it is given up. */
  static final int MAX_WRITE_FAILURES = 3;

  @ConfigProperty(name = "pedalons.raw-backfill.enabled", defaultValue = "true")
  boolean enabled;

  /** Routes read by one pass. */
  @ConfigProperty(name = "pedalons.raw-backfill.batch", defaultValue = "50")
  int batch;

  @Inject AgroalDataSource dataSource;
  @Inject EntityManager entityManager;
  @Inject RawTrackBackfillRepository backfillRepository;
  @Inject GpxTrackRepository gpxTrackRepository;
  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;
  @Inject GpxProcessingService gpxProcessingService;

  private volatile boolean foundLastTime;

  /** Failed writes in a row, per route; in memory, so a restart starts the count again. */
  private final Map<Long, Integer> writeFailures = new ConcurrentHashMap<>();

  /** For the tests: the switch and the batch. */
  public void setForTest(boolean enabled, int batch) {
    this.enabled = enabled;
    this.batch = batch;
    this.foundLastTime = false;
    this.writeFailures.clear();
  }

  /** What one pass did: routes given their raw line, and given up. */
  public record Report(int filled, int skipped) {}

  /** What happened to one route. */
  public enum Outcome {
    /** Its tracks got their raw line (or had it by now). */
    FILLED,
    /** Given up: never picked again. */
    SKIPPED,
    /** Saved between the read and the write: left to the next pass. */
    CHANGED,
    /** Deleted meanwhile. */
    GONE
  }

  /**
   * What the read of an original gave: the raw line of each of its tracks, or why there is none.
   */
  public record Read(@Nullable List<LineString<G2D>> lines, @Nullable Reason failure) {
    static Read of(List<LineString<G2D>> lines) {
      return new Read(lines, null);
    }

    static Read failed(Reason reason) {
      return new Read(null, reason);
    }
  }

  @Scheduled(every = "5m", delayed = "4m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void run() {
    try {
      runOnce(Instant.now());
    } catch (Exception e) {
      LOG.error("Raw line catch-up failed", e);
    }
  }

  /**
   * One pass, under the lock. Public for the tests.
   *
   * @return what it did; nothing when off or when another backend holds the lock
   */
  public Report runOnce(Instant now) {
    if (!enabled || batch <= 0) {
      return new Report(0, 0);
    }
    try (Connection connection = dataSource.getConnection()) {
      if (!lock(connection, "pg_try_advisory_lock")) {
        LOG.debug("Raw line catch-up: another backend runs it");
        return new Report(0, 0);
      }
      try {
        return pass(now);
      } finally {
        lock(connection, "pg_advisory_unlock");
      }
    } catch (SQLException e) {
      throw new IllegalStateException("Raw line catch-up: lock failed", e);
    }
  }

  /** {@code function} is one of two constants of this class, never user input. */
  private static boolean lock(Connection connection, String function) throws SQLException {
    try (PreparedStatement statement =
        connection.prepareStatement(
            "select " + function + "(hashtextextended('raw-track-backfill', 0))")) {
      try (ResultSet rs = statement.executeQuery()) {
        return rs.next() && rs.getBoolean(1);
      }
    }
  }

  private Report pass(Instant now) {
    List<Candidate> candidates = candidates(batch);
    int filled = 0;
    int skipped = 0;
    for (Candidate candidate : candidates) {
      Outcome outcome = handle(candidate, now);
      if (outcome == null) {
        // The bucket or the database failed: the next pass starts again from this route
        break;
      }
      switch (outcome) {
        case FILLED -> filled++;
        case SKIPPED -> skipped++;
        default -> {}
      }
    }
    boolean found = !candidates.isEmpty();
    if (!found && foundLastTime) {
      LOG.info("Raw line catch-up done: no track left without a raw line");
    }
    foundLastTime = found;
    if (found) {
      LOG.infof("Raw line catch-up: %d route(s) filled, %d given up", filled, skipped);
    }
    return new Report(filled, skipped);
  }

  /** Phase 1, a short transaction. Public for the tests. */
  public List<Candidate> candidates(int limit) {
    return QuarkusTransaction.requiringNew().call(() -> backfillRepository.findCandidates(limit));
  }

  /**
   * The three phases for one route. A cause the next read would meet again gives it up; a failure
   * of the bucket or the database returns null, nothing marked, and the pass ends.
   */
  private @Nullable Outcome handle(Candidate candidate, Instant now) {
    String route = TsidUtils.toString(candidate.routeId());
    Read read;
    try {
      read = read(candidate);
    } catch (Exception e) {
      LOG.warnf(
          "Raw line catch-up: reading the original of route %s failed, pass ended: %s", route, e);
      return null;
    }
    if (read.failure() != null) {
      skip(candidate.routeId(), read.failure(), now);
      return Outcome.SKIPPED;
    }
    try {
      Outcome outcome = write(candidate, read.lines(), now);
      writeFailures.remove(candidate.routeId());
      return outcome;
    } catch (Exception e) {
      int failures = writeFailures.merge(candidate.routeId(), 1, Integer::sum);
      if (failures < MAX_WRITE_FAILURES) {
        LOG.warnf("Raw line catch-up: writing route %s failed, pass ended: %s", route, e);
        return null;
      }
      LOG.errorf(e, "Raw line catch-up: writing route %s failed %d times", route, failures);
      writeFailures.remove(candidate.routeId());
      skip(candidate.routeId(), Reason.ERROR, now);
      return Outcome.SKIPPED;
    }
  }

  private void skip(Long routeId, Reason reason, Instant now) {
    LOG.warnf("Raw line catch-up gave up route %s: %s", TsidUtils.toString(routeId), reason);
    QuarkusTransaction.requiringNew().run(() -> backfillRepository.skip(routeId, reason, now));
  }

  /**
   * Phase 2, no transaction: reads the original the candidate points at and extracts its tracks as
   * a save does. A failure of the bucket is thrown; one of the parse, which the next read would meet
   * again, is a {@link Read#failed}. Public for the tests.
   */
  public Read read(Candidate candidate) throws IOException {
    Long fileId = candidate.originalFileId();
    if (fileId == null) {
      return Read.failed(Reason.MISSING_ORIGINAL);
    }
    String key = assetService.getAssetKey(candidate.teamId(), fileId);
    Path temp = Files.createTempFile("raw-backfill-", ".gpx");
    try {
      try (InputStream in = storageService.retrieve(key)) {
        Files.copy(in, temp, StandardCopyOption.REPLACE_EXISTING);
      } catch (NoSuchKeyException e) {
        return Read.failed(Reason.MISSING_ORIGINAL);
      }
      try {
        return Read.of(
            GpxProcessingService.rawLines(
                gpxProcessingService.rawTracks(gpxProcessingService.parseGpx(temp))));
      } catch (BusinessException e) {
        return Read.failed(Reason.UNREADABLE);
      } catch (RuntimeException e) {
        LOG.errorf(
            e,
            "Raw line catch-up: the original of route %s broke the parse",
            TsidUtils.toString(candidate.routeId()));
        return Read.failed(Reason.ERROR);
      }
    } finally {
      Files.deleteIfExists(temp);
    }
  }

  /**
   * Phase 3, a short transaction: locks the route, then writes only if its original is still the
   * one read and its tracks (in id order, as everywhere) are as many as the file's, and then only
   * the rows still without a line. Another number of tracks gives the route up. Public for the
   * tests.
   */
  public Outcome write(Candidate candidate, List<LineString<G2D>> lines, Instant now) {
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              Route route =
                  entityManager.find(
                      Route.class, candidate.routeId(), LockModeType.PESSIMISTIC_WRITE);
              if (route == null) {
                return Outcome.GONE;
              }
              Long current =
                  assetRepository.findCurrentFileId(
                      candidate.routeId(), AssetType.ROUTE_ORIGINAL_GPX);
              if (current == null || !current.equals(candidate.originalFileId())) {
                return Outcome.CHANGED;
              }
              List<TrackSize> tracks = gpxTrackRepository.findSizes(candidate.routeId());
              if (tracks.size() != lines.size()) {
                LOG.warnf(
                    "Raw line catch-up: route %s has %d track(s), its original %d",
                    TsidUtils.toString(candidate.routeId()), tracks.size(), lines.size());
                backfillRepository.skip(candidate.routeId(), Reason.TRACK_COUNT, now);
                return Outcome.SKIPPED;
              }
              for (int i = 0; i < tracks.size(); i++) {
                gpxTrackRepository.fillRawGeometry(tracks.get(i).trackId(), lines.get(i));
              }
              return Outcome.FILLED;
            });
  }
}
