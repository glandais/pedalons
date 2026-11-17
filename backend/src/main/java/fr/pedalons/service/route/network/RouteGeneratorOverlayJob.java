package fr.pedalons.service.route.network;

import fr.pedalons.common.Crons;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.infrastructure.lock.SessionAdvisoryLock;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.DepositReport;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.OverlayStatus;
import fr.pedalons.repository.route.GeneratorSourceRepository;
import fr.pedalons.repository.route.GeneratorSourceRepository.TeamRow;
import io.agroal.api.AgroalDataSource;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.UncheckedIOException;
import java.sql.SQLException;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The nightly preparation of the teams' roads for the route generator (docs/LEDGER_*.md API-198,
 * lot 3b plan §6): for each team, compares the digest of its tracks with the {@code source_digest}
 * of the overlay the engine holds, and deposits it again when it differs, is absent or stale, or
 * expires within {@code refresh-before-expiry}; deletes the overlay of a team that is deleted, has
 * its planner off or sits in an inactive domain.
 *
 * <p>Teams one at a time. One instance at a time: a session advisory lock on a connection of its
 * own, taken without waiting and kept alive by a heartbeat ({@link SessionAdvisoryLock}), so the two backends of a rolling
 * deploy never both run it (and the engine refuses a second deposit of an environment anyway).
 * Idempotent and writing nothing to the database: the state is the engine's, the teams are the
 * database's. No failure deletes an overlay: the old one serves until it expires, seven nights
 * later.
 *
 * <p>Logs and metrics never carry the key, the digest, a coordinate or a name.
 */
@ApplicationScoped
public class RouteGeneratorOverlayJob {

  private static final Logger LOG = Logger.getLogger(RouteGeneratorOverlayJob.class);

  /** Seconds, at most, a transaction that streams one team's tracks may last. */
  static final int STREAM_TRANSACTION_SECONDS = 1000;

  /** The advisory lock's name: one pass at a time across the backends. */
  static final String LOCK_KEY = "route-generator-overlays";

  static final int MAX_DEPOSIT_ATTEMPTS = 3;
  static final Duration DEFAULT_RETRY_AFTER = Duration.ofSeconds(10);

  @ConfigProperty(name = "pedalons.route-generator.overlay.enabled", defaultValue = "true")
  boolean enabled;

  @ConfigProperty(
      name = "pedalons.route-generator.overlay.refresh-before-expiry",
      defaultValue = "P7D")
  Duration refreshBeforeExpiry;

  @Inject AgroalDataSource dataSource;
  @Inject GeneratorSourceRepository repository;
  @Inject RouteGeneratorGateway gateway;
  @Inject RouteGeneratorMetrics metrics;

  private final AtomicBoolean running = new AtomicBoolean();
  private volatile Consumer<Duration> sleeper = JobSleep::sleep;

  /** What to do with a team. */
  public enum Action {
    DEPOSIT,
    DELETE,
    KEEP
  }

  /** Why. */
  public enum Reason {
    ABSENT,
    STALE,
    CHANGED,
    EXPIRING,
    FORCED,
    CURRENT,
    TEAM_GONE,
    PLANNER_OFF
  }

  /**
   * @param teamId only this team (null: all of them)
   * @param force deposit every served team, whatever its overlay
   * @param dryRun decide and report, send and delete nothing
   */
  public record Options(@Nullable Long teamId, boolean force, boolean dryRun) {
    public static Options nightly() {
      return new Options(null, false, false);
    }
  }

  /** One team of a pass. */
  public record Item(
      long teamId,
      String teamSlug,
      Action action,
      Reason reason,
      @Nullable String state,
      @Nullable Instant depositedAt,
      @Nullable Instant expiresAt) {}

  /**
   * What a pass did. {@code ran} is false when it did not start (off, no key, engine off, another
   * pass running here or on another backend).
   */
  public record Report(boolean ran, @Nullable String graphId, List<Item> items, Counts counts) {
    static Report skipped() {
      return new Report(false, null, List.of(), new Counts(0, 0, 0, 0, 0));
    }
  }

  /** The outcome of a pass, by team. */
  public record Counts(int teams, int deposited, int deleted, int kept, int failed) {}

  /** The end of a pass: an outage that would fail every team. */
  private static final class PassEnded extends Exception {
    PassEnded(String message) {
      super(message, null, false, false);
    }
  }

  /** For the tests: no real sleep between two attempts. */
  public void setSleeperForTest(@Nullable Consumer<Duration> sleeper) {
    this.sleeper = sleeper == null ? JobSleep::sleep : sleeper;
  }

  @Scheduled(
      cron = "{pedalons.route-generator.overlay.cron}",
      timeZone = Crons.ZONE,
      concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void run() {
    try {
      runOnce(Instant.now(), Options.nightly());
    } catch (RuntimeException e) {
      LOG.error("Route generator overlay pass failed", e);
    }
  }

  /**
   * Starts a pass on a thread of its own, for the manual trigger.
   *
   * @return false when nothing started: the pass is off, the key or the engine is not there, or a
   *     pass already runs on this instance. The advisory lock of another backend is only known on
   *     the thread: that pass then ends at once and is logged.
   */
  public boolean startInBackground(Options options) {
    RouteGeneratorGateway.Availability availability = preflight();
    if (availability == null || !running.compareAndSet(false, true)) {
      return false;
    }
    try {
      Thread thread =
          new Thread(
              () -> {
                try {
                  lockedPass(Instant.now(), options, availability);
                } catch (RuntimeException e) {
                  LOG.error("Route generator overlay pass failed", e);
                } finally {
                  running.set(false);
                }
              },
              "route-generator-overlays");
      thread.setDaemon(true);
      thread.start();
    } catch (RuntimeException e) {
      running.set(false);
      throw e;
    }
    return true;
  }

  /** The engine's availability, or null (and a log line) when there is nothing to do. */
  private RouteGeneratorGateway.@Nullable Availability preflight() {
    if (!enabled) {
      LOG.info("Route generator overlays: switched off");
      return null;
    }
    if (!gateway.configured()) {
      LOG.info("Route generator overlays: no namespace key configured, nothing to do");
      return null;
    }
    RouteGeneratorGateway.Availability availability = gateway.availability(true);
    if (!availability.usable()) {
      LOG.info("Route generator overlays: the engine does not serve the generator, nothing to do");
      return null;
    }
    return availability;
  }

  /**
   * One pass. Public for the tests and the manual trigger. A dry run writes nothing, takes no lock
   * and does not hold the {@code running} flag: it never makes a nightly pass skip.
   *
   * @return what it did; {@code ran = false} when it did not start
   */
  public Report runOnce(Instant now, Options options) {
    RouteGeneratorGateway.Availability availability = preflight();
    if (availability == null) {
      return Report.skipped();
    }
    if (options.dryRun()) {
      return pass(now, options, availability, () -> true);
    }
    if (!running.compareAndSet(false, true)) {
      LOG.info("Route generator overlays: a pass is already running here");
      return Report.skipped();
    }
    try {
      return lockedPass(now, options, availability);
    } finally {
      running.set(false);
    }
  }

  private Report lockedPass(
      Instant now, Options options, RouteGeneratorGateway.Availability availability) {
    SessionAdvisoryLock lock;
    try {
      lock = SessionAdvisoryLock.tryAcquire(dataSource, LOCK_KEY, "Route generator overlays");
    } catch (SQLException e) {
      throw new IllegalStateException("Route generator overlays: lock failed", e);
    }
    if (lock == null) {
      LOG.info("Route generator overlays: another backend runs the pass");
      return Report.skipped();
    }
    try (lock) {
      return pass(now, options, availability, lock::held);
    }
  }

  /**
   * @param held false once the advisory lock is lost (docs/LEDGER_*.md API-210): the pass then
   *     stops before its next team, a second backend may run it now
   */
  private Report pass(
      Instant now,
      Options options,
      RouteGeneratorGateway.Availability availability,
      BooleanSupplier held) {
    long started = System.nanoTime();
    List<TeamRow> teams =
        QuarkusTransaction.requiringNew().call(() -> repository.listTeams()).stream()
            .filter(t -> options.teamId() == null || t.id() == options.teamId())
            .toList();
    List<Item> items = new ArrayList<>();
    int deposited = 0;
    int deleted = 0;
    int kept = 0;
    int failed = 0;
    boolean cut = false;
    for (TeamRow team : teams) {
      if (!held.getAsBoolean()) {
        LOG.warn("Route generator overlays: pass ended early: the advisory lock was lost");
        cut = true;
        break;
      }
      try {
        Item item = handle(team, now, options, availability);
        if (item == null) {
          continue;
        }
        items.add(item);
        switch (item.action()) {
          case DEPOSIT -> deposited++;
          case DELETE -> deleted++;
          case KEEP -> kept++;
        }
      } catch (TeamFailed e) {
        failed++;
      } catch (PassEnded e) {
        LOG.warnf("Route generator overlays: pass ended early: %s", e.getMessage());
        cut = true;
        break;
      }
    }
    Duration took = Duration.ofNanos(System.nanoTime() - started);
    Counts counts = new Counts(teams.size(), deposited, deleted, kept, failed);
    if (!options.dryRun()) {
      metrics.passTime(took);
      if (!cut) {
        metrics.passSucceeded(now);
      }
    }
    LOG.infof(
        "Route generator overlays: %s%d team(s), %d deposited, %d deleted, %d kept, %d failed,"
            + " %d s, graph %s",
        options.dryRun() ? "dry run, " : "",
        counts.teams(),
        counts.deposited(),
        counts.deleted(),
        counts.kept(),
        counts.failed(),
        took.toSeconds(),
        availability.graphId());
    return new Report(true, availability.graphId(), items, counts);
  }

  /** A team whose deposit failed in a way that concerns it alone. */
  private static final class TeamFailed extends Exception {
    TeamFailed() {
      super(null, null, false, false);
    }
  }

  private @Nullable Item handle(
      TeamRow team, Instant now, Options options, RouteGeneratorGateway.Availability availability)
      throws TeamFailed, PassEnded {
    String ref = TsidUtils.toString(team.id());
    OverlayStatus status = status(ref);
    if (!team.served()) {
      if ("absent".equals(status.state())) {
        return null;
      }
      Reason why = team.gone() ? Reason.TEAM_GONE : Reason.PLANNER_OFF;
      if (!options.dryRun()) {
        delete(ref);
        LOG.infof("Route generator overlays: team %s, overlay deleted (%s)", ref, why);
      }
      return item(team, Action.DELETE, why, status);
    }
    String digest =
        OverlayDigest.of(
            QuarkusTransaction.requiringNew()
                .call(() -> repository.fingerprint(team.id(), team.domainId())));
    Reason why = reason(status, digest, now, options.force());
    if (why == Reason.CURRENT) {
      return item(team, Action.KEEP, why, status);
    }
    if (!options.dryRun()) {
      deposit(team, ref, digest, why, availability);
    }
    return item(team, Action.DEPOSIT, why, status);
  }

  private Reason reason(OverlayStatus status, String digest, Instant now, boolean force) {
    if (force) {
      return Reason.FORCED;
    }
    return switch (status.state()) {
      case "ready" -> {
        if (!digest.equals(status.sourceDigest())) {
          yield Reason.CHANGED;
        }
        Instant expires = status.expiresInstant();
        yield expires == null || expires.isBefore(now.plus(refreshBeforeExpiry))
            ? Reason.EXPIRING
            : Reason.CURRENT;
      }
      case "stale" -> Reason.STALE;
      default -> Reason.ABSENT;
    };
  }

  private static Item item(TeamRow team, Action action, Reason reason, OverlayStatus status) {
    return new Item(
        team.id(),
        team.slug(),
        action,
        reason,
        status.state(),
        status.depositedInstant(),
        status.expiresInstant());
  }

  private OverlayStatus status(String ref) throws PassEnded {
    try {
      return gateway.status(ref);
    } catch (RouteGeneratorException e) {
      throw endOf("status", e);
    }
  }

  private void delete(String ref) throws PassEnded {
    try {
      gateway.delete(ref);
    } catch (RouteGeneratorException e) {
      if (e.kind() == RouteGeneratorException.Kind.DEPOSIT_IN_PROGRESS) {
        return;
      }
      throw endOf("delete", e);
    }
  }

  private PassEnded endOf(String what, RouteGeneratorException e) {
    return new PassEnded(what + " failed: " + e.getMessage());
  }

  private void deposit(
      TeamRow team,
      String ref,
      String digest,
      Reason why,
      RouteGeneratorGateway.Availability availability)
      throws TeamFailed, PassEnded {
    for (int attempt = 1; ; attempt++) {
      long started = System.nanoTime();
      AtomicReference<OverlayNdjsonWriter.Stats> sent = new AtomicReference<>();
      try {
        DepositReport report =
            gateway.deposit(
                ref,
                digest,
                out -> {
                  OverlayNdjsonWriter writer =
                      new OverlayNdjsonWriter(out, availability.maxDocumentBytes());
                  QuarkusTransaction.requiringNew()
                      .timeout(STREAM_TRANSACTION_SECONDS)
                      .run(() ->
                          repository.streamTracks(
                              team.id(),
                              team.domainId(),
                              row -> {
                                try {
                                  writer.track(row);
                                } catch (java.io.IOException e) {
                                  throw new UncheckedIOException(e);
                                }
                              }));
                  writer.finish();
                  sent.set(writer.stats());
                });
        Duration took = Duration.ofNanos(System.nanoTime() - started);
        metrics.deposit("ok");
        metrics.depositTime(took);
        OverlayNdjsonWriter.Stats stats = sent.get();
        LOG.infof(
            "Route generator overlays: team %s deposited (%s), %d track(s) read, %d excluded,"
                + " %d not current, %d edge(s), %.1f km matched, %.1f MB sent, %d s",
            ref,
            why,
            stats == null ? report.tracks() : stats.tracks(),
            report.tracksExcluded(),
            report.tracksUnreadable(),
            report.edges(),
            report.km() == null ? 0.0 : report.km().matched(),
            stats == null ? 0.0 : stats.bytes() / 1_000_000.0,
            took.toSeconds());
        return;
      } catch (RouteGeneratorException e) {
        switch (e.kind()) {
          case OVERLOADED -> {
            if (attempt >= MAX_DEPOSIT_ATTEMPTS) {
              metrics.deposit("overloaded");
              LOG.warnf("Route generator overlays: team %s skipped, the engine stays busy", ref);
              throw new TeamFailed();
            }
            Duration wait = e.retryAfter() == null ? DEFAULT_RETRY_AFTER : e.retryAfter();
            sleeper.accept(wait);
          }
          case DEPOSIT_IN_PROGRESS, TIMEOUT, READ_TIMEOUT -> {
            metrics.deposit(e.kind().name().toLowerCase());
            LOG.warnf("Route generator overlays: team %s skipped (%s)", ref, e.kind());
            throw new TeamFailed();
          }
          case INSUFFICIENT_STORAGE -> {
            metrics.deposit("insufficient_storage");
            LOG.errorf("Route generator overlays: the engine's storage quota is reached");
            throw new PassEnded("storage quota reached");
          }
          case DATA_UNAVAILABLE, NO_ANSWER, NOT_CONFIGURED -> {
            metrics.deposit(e.kind().name().toLowerCase());
            throw new PassEnded("deposit: " + e.kind());
          }
          default -> {
            metrics.deposit("rejected");
            LOG.errorf(
                "Route generator overlays: team %s skipped, the engine refused the deposit: %s",
                ref, e.getMessage());
            throw new TeamFailed();
          }
        }
      } catch (RuntimeException e) {
        // The database failed while streaming: nothing would work for the next team either
        metrics.deposit("source_failed");
        throw new PassEnded("reading the tracks failed: " + e.getClass().getSimpleName());
      }
    }
  }

  /** The default pause between two attempts; replaced in the tests. */
  static final class JobSleep {
    static void sleep(Duration d) {
      try {
        Thread.sleep(d.toMillis());
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
      }
    }
  }
}
