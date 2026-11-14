package fr.pedalons.service.route.network;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.repository.route.TeamNetworkRepository;
import fr.pedalons.service.route.generator.NetworkGraph;
import fr.pedalons.service.route.generator.NetworkGraphBuilder;
import fr.pedalons.service.route.generator.NetworkParameters;
import fr.pedalons.service.route.generator.TrackInput;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
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

  private Cache<Long, TeamNetwork> cache;
  private final ReentrantLock[] locks = new ReentrantLock[STRIPES];
  private final Semaphore buildPermits = new Semaphore(1, true);
  private final AtomicLong builds = new AtomicLong();
  private volatile Clock clock = Clock.systemUTC();

  @PostConstruct
  void init() {
    for (int i = 0; i < STRIPES; i++) {
      locks[i] = new ReentrantLock();
    }
    cache =
        Caffeine.newBuilder()
            .maximumWeight(maxWeightMb * 1024 * 1024)
            .weigher((Long k, TeamNetwork v) -> (int) Math.min(Integer.MAX_VALUE, v.weightBytes()))
            .expireAfterAccess(expireAfterAccess)
            .expireAfterWrite(expireAfterWrite)
            .build();
    metrics.watch(this);
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

  /** Tests only: forgets every graph. */
  public void clearForTest() {
    cache.invalidateAll();
  }

  /**
   * The team's graph, current for the rules of the class javadoc: one statement on a hit, one more
   * on a rebuild.
   *
   * @throws ServiceUnavailableException {@code ROUTE_GENERATOR_BUSY}: another build holds the
   *     memory for longer than {@code build-wait}
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
        TeamNetwork built = build(teamId, domainId, fp);
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
    if (cached.fingerprint().equals(fp)) {
      return true;
    }
    return cached.fingerprint().sameRoutes(fp)
        && Duration.between(cached.builtAt(), clock.instant()).compareTo(minRebuildInterval) < 0;
  }

  private TeamNetwork build(long teamId, long domainId, Fingerprint fp) {
    TrackInputMapper mapper = new TrackInputMapper(MAX_POINTS_PER_EDGE);
    List<TrackInput> tracks = new ArrayList<>();
    TeamNetworkSummary.Tally tally = new TeamNetworkSummary.Tally();
    int[] unreadable = {0};
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
                    tracks.add(
                        mapper.map(
                            row.trackId(),
                            row.excluded(),
                            TrackInputMapper.kindOf(row.surfaceType()),
                            doc));
                  }
                }));
    NetworkGraph graph = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    tracks.clear();
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
