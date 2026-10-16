package fr.pedalons.service.gps.sync;

import fr.pedalons.repository.gps.GpsRouteSyncRepository;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.AutoRow;
import fr.pedalons.repository.ride.GpsSyncTargetRow;
import fr.pedalons.repository.ride.RideParticipationRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * Decides which route each GPS service connection should hold, never calling a service
 * (docs/LEDGER_*.md API-120 §3.4, §4.1).
 *
 * <p>Every minute, domain by domain, in one short transaction each: the registrations whose group
 * leaves between {@code now − retention} and {@code now + horizon}, paired with the registered
 * member's connections that asked for the sync ({@link RideParticipationRepository
 * #findGpsSyncTargets}), give the desired state of each (connection, ride) — the group's effective
 * route, its GPX asset, the name to show. It is upserted on the tracking rows, desired columns only;
 * every other automatic row of the domain is told to disappear from its service. That one
 * reconciliation covers, without a single hook in the business code: registration, leaving a group
 * or switching to another, a ride cancelled or deleted, a group removed (orphanRemoval), a route
 * changed, deleted or given a new GPX, a ride passed, the switch turned off, the registrations an
 * account erasure forgets.
 *
 * <p>A connection waiting for a reconnection is not planned at all: its rows stay as they are, or
 * they would swing to "delete" and back.
 *
 * <p>Deterministic in the data and the clock, and writing nothing for an unchanged row: a tick
 * replayed, or run by both backends of a rolling deploy, writes the same thing once.
 */
@ApplicationScoped
public class GpsRouteSyncPlanner {

  private static final Logger LOG = Logger.getLogger(GpsRouteSyncPlanner.class);

  @ConfigProperty(name = "pedalons.gps-sync.enabled", defaultValue = "false")
  boolean enabled;

  /** How far ahead a ride's route is sent (D5). */
  @ConfigProperty(name = "pedalons.gps-sync.horizon", defaultValue = "P7D")
  Duration horizon;

  /** How long after the group's departure the route stays at the service (D5). */
  @ConfigProperty(name = "pedalons.gps-sync.retention", defaultValue = "P1D")
  Duration retention;

  @Inject RideParticipationRepository participationRepository;
  @Inject GpsRouteSyncRepository syncRepository;

  public boolean isEnabled() {
    return enabled;
  }

  @Scheduled(every = "60s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    if (!enabled) {
      return;
    }
    try {
      int changed = plan(Instant.now());
      if (changed > 0) {
        LOG.debugf("Route sync planner: %d row(s) changed", changed);
      }
    } catch (Exception e) {
      LOG.error("Route sync planning failed", e);
    }
  }

  /**
   * One planning pass over every domain with something to plan. Public for the tests, which run
   * with the scheduler off.
   *
   * @return how many rows were written
   */
  public int plan(Instant now) {
    List<Long> domainIds =
        QuarkusTransaction.requiringNew().call(syncRepository::findDomainsToPlan);
    int changed = 0;
    for (Long domainId : domainIds) {
      try {
        changed += QuarkusTransaction.requiringNew().call(() -> planDomain(domainId, now));
      } catch (RuntimeException e) {
        // One domain failing (a concurrent upsert, a bad row) must not starve the others.
        LOG.errorf(e, "Route sync planning failed for domain %d", domainId);
      }
    }
    return changed;
  }

  private record Key(Long connectionId, Long rideId) {}

  private record Desired(
      Long userId, Long groupId, Long routeId, String hash, String name, Instant groupStartAt) {}

  /** One domain, in the caller's transaction. */
  int planDomain(Long domainId, Instant now) {
    List<GpsSyncTargetRow> targets =
        participationRepository.findGpsSyncTargets(
            domainId, now.minus(retention), now.plus(horizon));

    Set<Long> routeIds = new HashSet<>();
    for (GpsSyncTargetRow target : targets) {
      Long routeId = target.effectiveRouteId();
      if (routeId != null) {
        routeIds.add(routeId);
      }
    }
    Map<Long, Long> gpxAssets = syncRepository.findGpxAssetIds(domainId, routeIds);

    Map<Key, Desired> desired = new LinkedHashMap<>();
    for (GpsSyncTargetRow target : targets) {
      Long routeId = target.effectiveRouteId();
      String routeName = target.effectiveRouteName();
      Long assetId = routeId != null ? gpxAssets.get(routeId) : null;
      if (routeId == null || routeName == null || assetId == null) {
        // The group's route has no GPX: nothing to send. Not its ride's route instead — the
        // organiser chose this one for the group (D2).
        continue;
      }
      String name =
          GpsSyncNames.autoName(
              target.groupStartAt(), target.timezone(), target.groupName(), routeName);
      // A stale double registration: the first group seen (earliest) wins, every tick alike.
      desired.putIfAbsent(
          new Key(target.connectionId(), target.rideId()),
          new Desired(
              target.userId(),
              target.groupId(),
              routeId,
              GpsSyncNames.hash(assetId, name),
              name,
              target.groupStartAt()));
    }

    Map<Key, AutoRow> existing = new HashMap<>();
    List<AutoRow> rows = syncRepository.findAutoRows(domainId);
    for (AutoRow row : rows) {
      existing.put(new Key(row.connectionId(), row.rideId()), row);
    }

    int changed = 0;
    for (Map.Entry<Key, Desired> entry : desired.entrySet()) {
      Key key = entry.getKey();
      Desired d = entry.getValue();
      AutoRow row = existing.get(key);
      if (row != null && unchanged(row, d)) {
        continue;
      }
      syncRepository.upsertDesired(
          domainId,
          d.userId(),
          key.connectionId(),
          key.rideId(),
          d.groupId(),
          d.routeId(),
          d.hash(),
          d.name(),
          d.groupStartAt(),
          now);
      changed++;
    }

    List<Long> toClear = new ArrayList<>();
    for (AutoRow row : rows) {
      if (row.desiredHash() != null
          && !row.reconnectRequired()
          && !desired.containsKey(new Key(row.connectionId(), row.rideId()))) {
        toClear.add(row.id());
      }
    }
    changed += syncRepository.clearDesired(domainId, toClear, now);
    changed += (int) syncRepository.deleteSettled(domainId, now);
    return changed;
  }

  private static boolean unchanged(AutoRow row, Desired d) {
    return Objects.equals(row.desiredHash(), d.hash())
        && Objects.equals(row.desiredRouteId(), d.routeId())
        && Objects.equals(row.rideGroupId(), d.groupId())
        && Objects.equals(row.groupStartAt(), d.groupStartAt());
  }
}
