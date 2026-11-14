package fr.pedalons.service.route.network;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.repository.route.TeamNetworkRepository;
import fr.pedalons.service.route.generator.NetworkGraph;
import fr.pedalons.service.route.generator.NetworkGraphBuilder;
import fr.pedalons.service.route.generator.NetworkParameters;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.locks.ReentrantLock;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * One graph per team and per instance, built from the street edges documents of its routes
 * (ledger docs/LEDGER_*.md API-198, lot 3 plan §2).
 *
 * <p>No event invalidates it: every lookup reads a {@link Fingerprint} of the team's routes and
 * tracks from the database and compares it with the cached graph's, so a write made by this
 * instance, by the other instance of a rolling deploy or by the previous release is seen the same
 * way. A route-level change (creation, delete, exclusion box, surface type) rebuilds at once; a
 * change of tracks or documents alone, which includes the HD catch-up of a saved route, waits for {@code min-rebuild-interval}, so that the backfill filling
 * documents all day does not rebuild the largest team's graph every few minutes.
 *
 * <p>A team whose routes hold more street edge observations than {@code max-observations} gets no
 * graph: building it would take more heap than the backend has (lot 2 design §13.2), and an
 * OutOfMemoryError there takes the whole instance down, not the generator alone. The read stops at
 * the bound and the refusal is remembered under the same rules as a graph, so that the documents
 * are not read again at every request.
 */
@ApplicationScoped
public class TeamNetworkCache {
  private static final Logger LOG = Logger.getLogger(TeamNetworkCache.class);
  private static final int STRIPES = 64;

  /** The polyline budget of one edge: the planner's own. */
  private static final int MAX_POINTS_PER_EDGE = 20_000;

  @Inject TeamNetworkRepository repository;
  @Inject RouteGeneratorMetrics metrics;

  @ConfigProperty(name = "pedalons.route-generator.cache.max-weight-mb", defaultValue = "192")
  long maxWeightMb;

  @ConfigProperty(
      name = "pedalons.route-generator.cache.expire-after-access",
      defaultValue = "PT2H")
  Duration expireAfterAccess;

  @ConfigProperty(name = "pedalons.route-generator.cache.expire-after-write", defaultValue = "PT6H")
  Duration expireAfterWrite;

  @ConfigProperty(
      name = "pedalons.route-generator.cache.min-rebuild-interval",
      defaultValue = "PT10M")
  Duration minRebuildInterval;

  @ConfigProperty(name = "pedalons.route-generator.build-wait", defaultValue = "PT30S")
  Duration buildWait;

  /**
   * Heap a build may hold per observation when the bound is sized on the heap: its measured peak is
   * about 225 bytes (lot 2 design §13.8), so a build takes at most a quarter of the heap.
   */
  static final long HEAP_BYTES_PER_OBSERVATION = 900;

  /**
   * Street edge observations a team may hold: -1 sizes the bound on the heap of this instance, 0
   * lifts it.
   */
  @ConfigProperty(name = "pedalons.route-generator.max-observations", defaultValue = "-1")
  long maxObservations;

  /** A team refused for its size: what was read of it, and when. */
  private record Refusal(Fingerprint fingerprint, Instant at) {}

  /** Stops the streamed read at the bound; never leaves this class. */
  private static final class TooLargeException extends RuntimeException {
    TooLargeException() {
      super(null, null, false, false);
    }
  }

  private Cache<Long, TeamNetwork> cache;
  private final Map<Long, Refusal> refusals = new ConcurrentHashMap<>();
  private final ReentrantLock[] locks = new ReentrantLock[STRIPES];
  private final Semaphore buildPermits = new Semaphore(1, true);
  private final AtomicLong builds = new AtomicLong();
  private volatile Clock clock = Clock.systemUTC();

  @PostConstruct
  void init() {
    for (int i = 0; i < STRIPES; i++) {
      locks[i] = new ReentrantLock();
    }
    if (maxObservations < 0) {
      maxObservations = boundFor(Runtime.getRuntime().maxMemory());
    }
    LOG.infof(
        "Route generator: a team may hold up to %d street edge observations", maxObservations);
    cache =
        Caffeine.newBuilder()
            .maximumWeight(maxWeightMb * 1024 * 1024)
            .weigher((Long k, TeamNetwork v) -> (int) Math.min(Integer.MAX_VALUE, v.weightBytes()))
            .expireAfterAccess(expireAfterAccess)
            .expireAfterWrite(expireAfterWrite)
            .build();
    metrics.watch(this);
  }

  /** The bound of an instance with that much heap: 1 million for 900 MB. */
  static long boundFor(long heapBytes) {
    return Math.max(1, heapBytes / HEAP_BYTES_PER_OBSERVATION);
  }

  /** The graphs built since the start, for the tests and the metrics. */
  public long builds() {
    return builds.get();
  }

  public long cachedTeams() {
    return cache.estimatedSize();
  }

  public long cachedBytes() {
    return cache.asMap().values().stream().mapToLong(TeamNetwork::weightBytes).sum();
  }

  /** Tests only: the clock the rebuild interval is read on; null goes back to the system clock. */
  public void setClockForTest(@Nullable Clock testClock) {
    this.clock = testClock != null ? testClock : Clock.systemUTC();
  }

  /** Tests only: forgets every graph and every refusal. */
  public void clearForTest() {
    cache.invalidateAll();
    refusals.clear();
  }

  /** Tests only: the bound on a team's observations; returns the previous one. */
  public long setMaxObservationsForTest(long max) {
    long previous = maxObservations;
    maxObservations = max;
    return previous;
  }

  /**
   * The team's graph, current for the rules of the class javadoc: one statement on a hit, one more
   * on a rebuild.
   *
   * @throws ServiceUnavailableException {@code ROUTE_GENERATOR_BUSY}: another build holds the
   *     memory for longer than {@code build-wait}
   * @throws BusinessException {@code GENERATOR_NETWORK_TOO_LARGE}: the team holds more observations
   *     than {@code max-observations}
   */
  public TeamNetwork lookup(long teamId, long domainId) {
    Fingerprint fp = repository.fingerprint(teamId, domainId);
    TeamNetwork cached = cache.getIfPresent(teamId);
    if (cached != null && acceptable(cached, fp)) {
      metrics.cache(
          cached.fingerprint().equals(fp)
              ? RouteGeneratorMetrics.CacheResult.HIT
              : RouteGeneratorMetrics.CacheResult.DEFERRED);
      return cached;
    }
    refuseIfKnownTooLarge(teamId, fp);
    ReentrantLock lock = locks[Math.floorMod(Long.hashCode(teamId), STRIPES)];
    try {
      if (!lock.tryLock(buildWait.toMillis(), TimeUnit.MILLISECONDS)) {
        throw new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
    }
    try {
      // Read again: the one read before the lock may predate the graph another thread just cached.
      fp = repository.fingerprint(teamId, domainId);
      cached = cache.getIfPresent(teamId);
      if (cached != null && acceptable(cached, fp)) {
        metrics.cache(RouteGeneratorMetrics.CacheResult.HIT);
        return cached;
      }
      refuseIfKnownTooLarge(teamId, fp);
      try {
        if (!buildPermits.tryAcquire(buildWait.toMillis(), TimeUnit.MILLISECONDS)) {
          throw new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
        }
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        throw new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
      }
      try {
        metrics.cache(RouteGeneratorMetrics.CacheResult.MISS);
        long started = System.nanoTime();
        TeamNetwork built;
        try {
          built = build(teamId, domainId, fp);
        } catch (RuntimeException e) {
          if (!tooLarge(e)) {
            throw e;
          }
          LOG.warnf(
              "Team network %d holds more than %d street edge observations: no graph is built"
                  + " (pedalons.route-generator.max-observations)",
              teamId, maxObservations);
          refusals.put(teamId, new Refusal(fp, clock.instant()));
          cache.invalidate(teamId);
          metrics.cache(RouteGeneratorMetrics.CacheResult.TOO_LARGE);
          throw new BusinessException(ErrorCode.GENERATOR_NETWORK_TOO_LARGE);
        }
        refusals.remove(teamId);
        metrics.built(Duration.ofNanos(System.nanoTime() - started));
        builds.incrementAndGet();
        long max = maxWeightMb * 1024 * 1024;
        if (built.weightBytes() > max) {
          LOG.warnf(
              "Team network %d estimated at %d MB, over the cache bound of %d MB: it is rebuilt at"
                  + " every request",
              teamId, built.weightBytes() >> 20, maxWeightMb);
        }
        cache.put(teamId, built);
        return built;
      } finally {
        buildPermits.release();
      }
    } finally {
      lock.unlock();
    }
  }

  /**
   * The graph of the fingerprint's own request is current, or only the tracks and documents moved
   * and the graph is younger than the rebuild interval.
   */
  private boolean acceptable(TeamNetwork cached, Fingerprint fp) {
    return acceptable(cached.fingerprint(), cached.builtAt(), fp);
  }

  private boolean acceptable(Fingerprint known, Instant at, Fingerprint fp) {
    if (known.equals(fp)) {
      return true;
    }
    return known.sameRoutes(fp)
        && Duration.between(at, clock.instant()).compareTo(minRebuildInterval) < 0;
  }

  /** A refusal stands as long as a graph would: the documents are not read again to find it out. */
  private void refuseIfKnownTooLarge(long teamId, Fingerprint fp) {
    Refusal refusal = refusals.get(teamId);
    if (refusal != null && acceptable(refusal.fingerprint(), refusal.at(), fp)) {
      metrics.cache(RouteGeneratorMetrics.CacheResult.TOO_LARGE);
      throw new BusinessException(ErrorCode.GENERATOR_NETWORK_TOO_LARGE);
    }
  }

  private static boolean tooLarge(Throwable e) {
    for (Throwable t = e; t != null; t = t.getCause()) {
      if (t instanceof TooLargeException) {
        return true;
      }
    }
    return false;
  }

  private TeamNetwork build(long teamId, long domainId, Fingerprint fp) {
    TrackInputMapper mapper = new TrackInputMapper(MAX_POINTS_PER_EDGE);
    // fed as the rows come: the tracks of a team are never held at once (lot 2 design §13.2)
    NetworkGraphBuilder.Intake intake =
        new NetworkGraphBuilder.Intake(NetworkParameters.defaults());
    TeamNetworkSummary.Tally tally = new TeamNetworkSummary.Tally();
    int[] unreadable = {0};
    long[] observations = {0};
    QuarkusTransaction.requiringNew()
        .run(() ->
            repository.streamTracks(
                teamId,
                domainId,
                row -> {
                  NetworkEdgesDocument doc = parse(row, unreadable);
                  boolean current =
                      doc != null
                          && doc.v() == NetworkEdgesDocument.VERSION
                          && (doc.ok()
                              || NetworkEdgesDocument.STATUS_TOO_SHORT.equals(doc.status()))
                          && row.original() != null
                          && doc.rev() == row.original();
                  tally.track(row.routeId(), row.excluded(), current);
                  if (current) {
                    observations[0] += doc.edges().size();
                    if (maxObservations > 0 && observations[0] > maxObservations) {
                      throw new TooLargeException();
                    }
                    intake.add(
                        mapper.map(
                            row.trackId(),
                            row.excluded(),
                            TrackInputMapper.kindOf(row.surfaceType()),
                            doc));
                  }
                }));
    NetworkGraph graph = intake.build();
    TeamNetworkSummary summary =
        tally.build(graph.stats().totalLengthM(), mapper.droppedEdges() + unreadable[0]);
    return new TeamNetwork(fp, graph, summary, clock.instant(), weigh(graph));
  }

  private static @Nullable NetworkEdgesDocument parse(
      TeamNetworkRepository.TrackRow row, int[] unreadable) {
    if (row.document() == null) {
      return null;
    }
    try {
      return JsonConfiguration.INSTANCE
          .getObjectMapperWrapper()
          .fromString(row.document(), NetworkEdgesDocument.class);
    } catch (RuntimeException e) {
      unreadable[0]++;
      LOG.warnf("Unreadable network edges document of track %d", row.trackId());
      return null;
    }
  }

  /** Estimated bytes held by a graph (design §2.3). */
  static long weigh(NetworkGraph g) {
    long points = 0;
    long support = 0;
    for (int e = 0; e < g.edgeCount(); e++) {
      points += g.geometryX(e).length;
      support += g.support(e);
    }
    return g.nodeCount() * 120L + g.edgeCount() * 400L + points * 48L + support * 8L;
  }
}
