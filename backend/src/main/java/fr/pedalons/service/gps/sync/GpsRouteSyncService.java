package fr.pedalons.service.gps.sync;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.gps.response.GpsServiceConnectionDto;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.enums.GpsAutoSyncState;
import fr.pedalons.enums.GpsRouteSyncState;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.gps.GpsAuth;
import fr.pedalons.infrastructure.gps.GpsCallResult;
import fr.pedalons.infrastructure.gps.GpsServiceClient;
import fr.pedalons.infrastructure.gps.RouteMeta;
import fr.pedalons.infrastructure.gps.RouteUploadResult;
import fr.pedalons.repository.gps.GpsRouteSyncRepository;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.Claim;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.ConnectionSummary;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.Placed;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.RouteRow;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.gps.DomainGpsCredentialService;
import fr.pedalons.service.gps.GpsConnectionTokens;
import fr.pedalons.service.gps.GpsRouteGpx;
import fr.pedalons.service.gps.sync.GpsRouteSyncExecutor.Outcome;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.Callable;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * What the rest of the backend asks of the route sync (docs/LEDGER_*.md API-120): the state shown
 * on the profile, the per-route state for a list of routes, the manual uploads (which go through
 * the same tracking rows), and the clean-up before a connection goes.
 *
 * <p>Every method takes the domain and the user explicitly, so that the account erasure job, which
 * runs outside any request, can use them too. None is {@code @Transactional}: those that call a
 * service do it between short transactions of their own, the others are single reads that work in
 * the caller's transaction or in an implicit one.
 */
@ApplicationScoped
public class GpsRouteSyncService {

  private static final Logger LOG = Logger.getLogger(GpsRouteSyncService.class);

  @Inject GpsRouteSyncRepository syncRepository;
  @Inject GpsServiceConnectionRepository connectionRepository;
  @Inject RouteRepository routeRepository;
  @Inject DomainGpsCredentialService credentialService;
  @Inject GpsConnectionTokens tokens;
  @Inject GpsRouteGpx routeGpx;
  @Inject GpsRouteSyncExecutor executor;
  @Inject GpsRouteSyncPlanner planner;

  // ------------------------------------------------------------------ profile state

  /**
   * The automatic rows of each of these connections, aggregated: one grouped query for all of
   * them. A connection without any row maps to {@link ConnectionSummary#EMPTY}.
   */
  public Map<Long, ConnectionSummary> summaries(
      Long domainId, Collection<GpsServiceConnection> connections) {
    List<Long> ids = connections.stream().map(GpsServiceConnection::getId).toList();
    Map<Long, ConnectionSummary> found = syncRepository.summarize(domainId, ids);
    Map<Long, ConnectionSummary> result = new HashMap<>();
    for (Long id : ids) {
      result.put(id, found.getOrDefault(id, ConnectionSummary.EMPTY));
    }
    return result;
  }

  /** The connections as the profile shows them, their sync state resolved in one query. */
  public List<GpsServiceConnectionDto> toDtos(
      Long domainId, List<GpsServiceConnection> connections) {
    Map<Long, ConnectionSummary> summaries = summaries(domainId, connections);
    return connections.stream()
        .map(
            c -> {
              ConnectionSummary summary = summaries.get(c.getId());
              return GpsServiceConnectionDto.from(
                  c, state(c, summary), summary.routeCount(), summary.lastSyncedAt());
            })
        .toList();
  }

  /** The state the profile shows for one connection. */
  public static GpsAutoSyncState state(GpsServiceConnection connection, ConnectionSummary summary) {
    if (!connection.isAutoSync()) {
      return GpsAutoSyncState.OFF;
    }
    if (connection.getSyncReconnectRequiredAt() != null) {
      return GpsAutoSyncState.RECONNECT_REQUIRED;
    }
    if (summary.failing()) {
      return GpsAutoSyncState.FAILING;
    }
    if (summary.pending()) {
      return GpsAutoSyncState.PENDING;
    }
    return GpsAutoSyncState.UP_TO_DATE;
  }

  // ------------------------------------------------------------------ per-route state

  /**
   * One route at one service.
   *
   * @param automatic the route sync holds it (at least one of the user's rides uses it); false: a
   *     tracked manual upload only
   * @param externalRouteId its id at the service, null while not sent yet
   * @param syncedAt the last successful send
   */
  public record RouteSyncStatus(
      Long routeId,
      GpsServiceType serviceType,
      boolean automatic,
      GpsRouteSyncState state,
      @Nullable String externalRouteId,
      @Nullable Instant syncedAt) {}

  /**
   * Where each of these routes stands at each of the user's services, in at most two queries
   * whatever the number of routes (the second, the routes' current GPX, only when a manual upload
   * is among the rows or the sync is off) — for a list of rides or routes that shows it ({@code
   * DeviceRegisteredGroupDto.syncStatuses}, docs/LEDGER_*.md API-121) without a query per row. A
   * route that is nowhere is absent; several rows of the same route and service (two rides on the
   * same route, a manual upload) merge into one status: automatic if any is, the worst state, the
   * latest send. See {@link #routeState} for what each row says.
   */
  public Map<Long, List<RouteSyncStatus>> findRouteStatuses(
      Long domainId, Long userId, Collection<Long> routeIds) {
    List<RouteRow> rows = syncRepository.findByUserAndRoutes(domainId, userId, routeIds);
    boolean syncing = planner.isEnabled();
    // The routes' current GPX, for the rows nothing keeps up to date: the manual uploads, and every
    // row while the sync is off. One more query, only when such a row is there.
    List<Long> unmanaged =
        rows.stream()
            .filter(r -> !(syncing && r.automatic()))
            .map(RouteRow::routeId)
            .distinct()
            .toList();
    Map<Long, Long> gpxAssets = syncRepository.findGpxAssetIds(domainId, unmanaged);
    Map<Long, Map<GpsServiceType, RouteSyncStatus>> merged = new HashMap<>();
    for (RouteRow row : rows) {
      GpsRouteSyncState state = routeState(row, syncing, gpxAssets.get(row.routeId()));
      if (state == null) {
        continue;
      }
      RouteSyncStatus status =
          new RouteSyncStatus(
              row.routeId(),
              row.serviceType(),
              row.automatic(),
              state,
              row.externalRouteId(),
              row.syncedAt());
      merged
          .computeIfAbsent(row.routeId(), k -> new EnumMap<>(GpsServiceType.class))
          .merge(row.serviceType(), status, GpsRouteSyncService::merge);
    }
    Map<Long, List<RouteSyncStatus>> result = new HashMap<>();
    merged.forEach((routeId, byService) -> result.put(routeId, List.copyOf(byService.values())));
    return result;
  }

  /**
   * The state of one row, or null when it says nothing reliable about the route at the service.
   *
   * <p>An automatic row while the sync runs: its desired hash is the planner's, kept current every
   * minute, so it is compared as is. Any other row — a manual upload, which nothing ever updates,
   * or an automatic one while the sync is off ({@code pedalons.gps-sync.enabled}, its planner and
   * worker stopped) — promises no update: what was sent is compared with the route's current GPX
   * ({@link GpsSyncNames#hash} of it under the name sent), OUTDATED when they differ, and an
   * automatic row never sent says nothing.
   *
   * @param syncing the sync is on
   * @param currentGpxAssetId the route's current GPX, looked up for unmanaged rows only
   */
  static @Nullable GpsRouteSyncState routeState(
      RouteRow row, boolean syncing, @Nullable Long currentGpxAssetId) {
    if (row.reconnectRequired()) {
      return GpsRouteSyncState.RECONNECT_REQUIRED;
    }
    if (syncing && row.automatic()) {
      if (row.attempts() > 0) {
        return GpsRouteSyncState.FAILING;
      }
      if (row.externalRouteId() == null
          || row.desiredHash() == null
          || !row.desiredHash().equals(row.syncedHash())) {
        return GpsRouteSyncState.PENDING;
      }
      return GpsRouteSyncState.SENT;
    }
    if (row.externalRouteId() == null || row.syncedHash() == null) {
      return null;
    }
    // No GPX left on the route (or no name recorded): nothing to compare with, what was sent
    // stands.
    if (currentGpxAssetId == null || row.desiredName() == null) {
      return GpsRouteSyncState.SENT;
    }
    return GpsSyncNames.hash(currentGpxAssetId, row.desiredName()).equals(row.syncedHash())
        ? GpsRouteSyncState.SENT
        : GpsRouteSyncState.OUTDATED;
  }

  private static RouteSyncStatus merge(RouteSyncStatus a, RouteSyncStatus b) {
    GpsRouteSyncState state = a.state().compareTo(b.state()) >= 0 ? a.state() : b.state();
    Instant syncedAt =
        a.syncedAt() == null
            ? b.syncedAt()
            : b.syncedAt() == null || a.syncedAt().isAfter(b.syncedAt())
                ? a.syncedAt()
                : b.syncedAt();
    String externalId = a.externalRouteId() != null ? a.externalRouteId() : b.externalRouteId();
    return new RouteSyncStatus(
        a.routeId(), a.serviceType(), a.automatic() || b.automatic(), state, externalId, syncedAt);
  }

  // ------------------------------------------------------------------ manual uploads

  /**
   * A manual upload of {@code routeId} to the connection (web, mobile, Karoo — {@code
   * GpsService#uploadRoute}), through the same tracking rows as the sync, so that the same route is
   * never stacked twice at the service:
   *
   * <ol>
   *   <li>an automatic row already desires this route: the worker's own step runs on it now (an
   *       update of the route at the service, or its creation), under the row's lease — and if the
   *       worker holds it at this very moment, nothing is sent: it is on its way;
   *   <li>otherwise the manual upload already recorded for this route is updated in place ({@code
   *       PUT}, created again if the user deleted it at the service), or a new one is created and
   *       recorded.
   * </ol>
   *
   * <p>A recorded manual upload is never placed under automatic management by itself, whatever the
   * opt-in: Pédalons neither updates nor deletes it on its own. Only when the sync is on and a ride
   * the member is registered in uses that route does its row take it over (the worker updates it
   * rather than creating a copy, {@link GpsRouteSyncRepository#takeManual}); from then on it lives
   * and goes with the ride, like any automatic route.
   *
   * <p>No transaction around: the caller resolved the route (access checked) and the connection.
   */
  public RouteUploadResponse uploadManually(
      Long domainId, Long userId, Long connectionId, Long routeId) {
    Optional<Long> automatic =
        tx(
            () ->
                syncRepository
                    .findAutoForRoute(domainId, connectionId, routeId)
                    .map(s -> s.getId()));
    RouteUploadResponse response =
        automatic.isPresent()
            ? syncAutomaticNow(automatic.get())
            : uploadTracked(domainId, userId, connectionId, routeId);
    tx(
        () -> {
          GpsServiceConnection connection = connectionRepository.findById(connectionId);
          if (connection != null) {
            connection.markUsed();
          }
          return null;
        });
    return response;
  }

  private RouteUploadResponse syncAutomaticNow(Long rowId) {
    Instant now = Instant.now();
    Instant lease = GpsRouteSyncExecutor.leaseEnd(now);
    boolean claimed = tx(() -> syncRepository.claimOne(rowId, now, lease));
    List<Claim> claims =
        claimed ? tx(() -> syncRepository.findClaims(List.of(rowId), lease)) : List.of();
    if (claims.isEmpty()) {
      String externalId =
          tx(
              () ->
                  Optional.ofNullable(syncRepository.findById(rowId))
                      .map(s -> s.getExternalRouteId())
                      .orElse(null));
      return new RouteUploadResponse(true, "Automatic sync in progress", externalId);
    }
    Outcome outcome = executor.process(claims.getFirst());
    return outcome.success()
        ? new RouteUploadResponse(true, null, outcome.externalRouteId())
        : new RouteUploadResponse(false, "Upload failed: " + outcome.error(), null);
  }

  private record Manual(
      GpsServiceClient client,
      GpsAuth auth,
      byte[] gpx,
      String name,
      String hash,
      @Nullable String externalId) {}

  private RouteUploadResponse uploadTracked(
      Long domainId, Long userId, Long connectionId, Long routeId) {
    Manual manual = tx(() -> prepareManual(domainId, connectionId, routeId));
    RouteMeta meta = RouteMeta.manual(manual.name());
    GpsCallResult result;
    String externalId = manual.externalId();
    if (externalId != null) {
      result = manual.client().updateRoute(manual.auth(), externalId, manual.gpx(), meta);
      if (result instanceof GpsCallResult.NotFound) {
        result = manual.client().createRoute(manual.auth(), manual.gpx(), meta);
      }
    } else {
      result = manual.client().createRoute(manual.auth(), manual.gpx(), meta);
    }
    if (result instanceof GpsCallResult.Ok ok) {
      String sent = ok.externalId() != null ? ok.externalId() : externalId;
      if (sent != null) {
        tx(
            () -> {
              syncRepository.upsertManual(
                  domainId,
                  userId,
                  connectionId,
                  routeId,
                  manual.name(),
                  manual.hash(),
                  sent,
                  Instant.now());
              return null;
            });
      }
      return new RouteUploadResponse(true, null, sent);
    }
    RouteUploadResult failure = result.toUploadResult();
    return new RouteUploadResponse(false, failure.message(), null);
  }

  private Manual prepareManual(Long domainId, Long connectionId, Long routeId) {
    GpsServiceConnection connection = connectionRepository.findById(connectionId);
    Route route = routeRepository.findById(routeId);
    if (connection == null || route == null) {
      throw new IllegalStateException("Connection or route vanished during the upload");
    }
    DomainGpsCredential credential =
        credentialService
            .getCredentials(domainId, connection.getServiceType())
            .orElseThrow(() -> new BusinessException(ErrorCode.GPS_SERVICE_NOT_CONFIGURED));
    Asset asset =
        GpsRouteGpx.pick(route).orElseThrow(() -> new BusinessException(ErrorCode.GPX_NOT_FOUND));
    String name = route.getName();
    String externalId =
        syncRepository
            .findManual(domainId, connectionId, routeId)
            .map(s -> s.getExternalRouteId())
            .orElse(null);
    return new Manual(
        tokens.client(connection.getServiceType()),
        tokens.auth(connection, credential),
        routeGpx.read(asset),
        name,
        GpsSyncNames.hash(asset.getId(), name),
        externalId);
  }

  // ------------------------------------------------------------------ clean-up

  private record Cleanup(GpsServiceClient client, GpsAuth auth, List<Placed> placed) {}

  /**
   * Removes from the service, as far as it can, the routes the sync placed there for this
   * connection — before the connection goes (disconnection, account erasure), while its tokens are
   * still there (D9). One {@code DELETE} per automatic row, a dozen at most (the 7-day window); a
   * failure is logged and ignored, it never blocks what follows. Manual uploads stay at the
   * service, as they always did. A row a worker holds at this moment is skipped: the accepted race
   * of the plan (§4.6).
   *
   * <p>To be called with no transaction open: it calls the service.
   *
   * @return how many routes were removed
   */
  public int removeAutoSyncedRoutes(Long domainId, Long connectionId) {
    return removeAutoSyncedRoutes(domainId, connectionId, null);
  }

  /**
   * {@link #removeAutoSyncedRoutes(Long, Long)}, giving up on the routes left once {@code deadline}
   * has passed (null for none): an account erasure bounds what it waits for.
   */
  public int removeAutoSyncedRoutes(Long domainId, Long connectionId, @Nullable Instant deadline) {
    Optional<Cleanup> cleanup;
    try {
      cleanup = tx(() -> prepareCleanup(domainId, connectionId));
    } catch (RuntimeException e) {
      LOG.warnf("Route clean-up of connection %d skipped: %s", connectionId, e.getMessage());
      return 0;
    }
    if (cleanup.isEmpty()) {
      return 0;
    }
    int removed = 0;
    for (Placed placed : cleanup.get().placed()) {
      if (deadline != null && Instant.now().isAfter(deadline)) {
        LOG.infof("Route clean-up of connection %d stopped at its deadline", connectionId);
        break;
      }
      try {
        GpsCallResult result =
            cleanup.get().client().deleteRoute(cleanup.get().auth(), placed.externalRouteId());
        if (result instanceof GpsCallResult.Ok || result instanceof GpsCallResult.NotFound) {
          removed++;
        } else {
          LOG.infof(
              "Route %s of connection %d not removed: %s",
              placed.externalRouteId(), connectionId, result);
        }
      } catch (RuntimeException e) {
        LOG.infof(
            "Route %s of connection %d not removed: %s",
            placed.externalRouteId(), connectionId, e.getMessage());
      }
    }
    return removed;
  }

  private Optional<Cleanup> prepareCleanup(Long domainId, Long connectionId) {
    List<Placed> placed =
        new ArrayList<>(
            syncRepository.findPlacedByConnection(domainId, connectionId, Instant.now()));
    if (placed.isEmpty()) {
      return Optional.empty();
    }
    GpsServiceConnection connection = connectionRepository.findById(connectionId);
    if (connection == null) {
      return Optional.empty();
    }
    Optional<DomainGpsCredential> credential =
        credentialService.getCredentials(domainId, connection.getServiceType());
    if (credential.isEmpty() || !GpsConnectionTokens.matches(connection, credential.get())) {
      return Optional.empty();
    }
    return Optional.of(
        new Cleanup(
            tokens.client(connection.getServiceType()),
            tokens.auth(connection, credential.get()),
            placed));
  }

  private static <T> T tx(Callable<T> work) {
    return QuarkusTransaction.requiringNew().call(work);
  }
}
