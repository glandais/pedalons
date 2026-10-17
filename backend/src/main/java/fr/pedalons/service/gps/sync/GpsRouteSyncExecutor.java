package fr.pedalons.service.gps.sync;

import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.GpsSyncError;
import fr.pedalons.infrastructure.gps.GpsAuth;
import fr.pedalons.infrastructure.gps.GpsCallResult;
import fr.pedalons.infrastructure.gps.GpsServiceClient;
import fr.pedalons.infrastructure.gps.GpsTokenRefusedException;
import fr.pedalons.infrastructure.gps.RouteMeta;
import fr.pedalons.repository.gps.GpsRouteSyncRepository;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.Claim;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.gps.DomainGpsCredentialService;
import fr.pedalons.service.gps.GpsConnectionTokens;
import fr.pedalons.service.gps.GpsRouteGpx;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.concurrent.Callable;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * One step of the route sync on one leased row (docs/LEDGER_*.md API-120 §4.2-4.4): create, update
 * or delete the route at the service, then write the outcome — under the lease, so that a lease
 * lost meanwhile (expired and taken, or the row deleted by a disconnection) writes nothing.
 *
 * <p>No {@code @Transactional}: the reads happen in one short transaction, the token is refreshed
 * if needed in a second one of its own (committed at once, the connection locked meanwhile — {@link
 * GpsConnectionTokens}), the service is called outside any, the outcome is written in a last one.
 * Shared by {@link GpsRouteSyncWorker} and by the manual upload of a route the sync already tracks
 * ({@link GpsRouteSyncService#uploadManually}).
 *
 * <table>
 *   <caption>What a result does</caption>
 *   <tr><th>Result</th><th>Create / update</th><th>Delete</th></tr>
 *   <tr><td>Ok</td><td>external id and hash stored</td><td>row removed</td></tr>
 *   <tr><td>NotFound</td><td>an update creates the route again, in the same step</td>
 *       <td>success</td></tr>
 *   <tr><td>Unauthorized</td><td colspan="2">one token refresh and a replay; then the connection
 *       waits for a reconnection</td></tr>
 *   <tr><td>PermissionRevoked</td><td colspan="2">the connection waits for a reconnection</td></tr>
 *   <tr><td>RateLimited</td><td colspan="2">the connection is paused, the row given back</td></tr>
 *   <tr><td>Failed</td><td colspan="2">backoff of 1 min · 2^n, at most 6 h, {@value #MAX_ATTEMPTS}
 *       attempts until the desired state changes</td></tr>
 * </table>
 */
@ApplicationScoped
public class GpsRouteSyncExecutor {

  private static final Logger LOG = Logger.getLogger(GpsRouteSyncExecutor.class);

  /** After that many failures a row waits for its desired state to change. */
  public static final int MAX_ATTEMPTS = 8;

  /**
   * Longer than the worst step: two token refreshes and three calls, each bounded by its 30 s
   * timeout (150 s), plus the GPX read and the writes. A lease that runs out while its step is
   * still going lets another worker take the row and create the route a second time — Hammerhead
   * and Garmin deduplicate nothing.
   */
  static final Duration LEASE = Duration.ofMinutes(5);

  static final Duration BACKOFF_BASE = Duration.ofMinutes(1);
  static final Duration BACKOFF_MAX = Duration.ofHours(6);

  @Inject GpsRouteSyncRepository syncRepository;
  @Inject GpsServiceConnectionRepository connectionRepository;
  @Inject RouteRepository routeRepository;
  @Inject DomainGpsCredentialService credentialService;
  @Inject GpsConnectionTokens tokens;
  @Inject GpsRouteGpx routeGpx;

  /**
   * What one step did.
   *
   * @param externalRouteId the route's id at the service after a successful creation or update
   * @param connectionStopped the connection was paused or needs a reconnection: the rest of the
   *     tick skips it
   * @param calls the calls made to the service, for the tick's budget
   */
  public record Outcome(
      boolean success,
      @Nullable String externalRouteId,
      @Nullable GpsSyncError error,
      boolean connectionStopped,
      int calls) {}

  enum Op {
    CREATE,
    UPDATE,
    DELETE
  }

  private sealed interface Prepared {}

  /** Nothing to do at the service: the row only has to go. */
  private record Nothing() implements Prepared {}

  private record Fail(GpsSyncError error) implements Prepared {}

  private record Reconnect(GpsSyncError error) implements Prepared {}

  private record Ready(
      Op op,
      GpsServiceClient client,
      @Nullable String externalId,
      byte @Nullable [] gpx,
      @Nullable String hash,
      @Nullable RouteMeta meta)
      implements Prepared {}

  /** The authorization for the calls, and the access token it carries (to recognise a refresh). */
  private record Authorized(GpsAuth auth, byte[] usedToken) {}

  /** Millisecond precision, so that the conditional writes match it exactly once stored. */
  static Instant leaseEnd(Instant now) {
    return now.plus(LEASE).truncatedTo(ChronoUnit.MILLIS);
  }

  static Duration backoff(int attempts) {
    int exponent = Math.max(0, Math.min(attempts - 1, 20));
    Duration delay = BACKOFF_BASE.multipliedBy(1L << exponent);
    return delay.compareTo(BACKOFF_MAX) > 0 ? BACKOFF_MAX : delay;
  }

  /** One step on a row the caller leased ({@code claim.lease()}). */
  public Outcome process(Claim claim) {
    Prepared prepared;
    try {
      prepared = tx(() -> prepare(claim));
    } catch (RuntimeException e) {
      LOG.warnf(e, "Route sync %d: could not prepare the call", claim.id());
      return fail(claim, GpsSyncError.SERVICE_ERROR, 0);
    }
    return switch (prepared) {
      case Nothing n -> {
        tx(() -> syncRepository.markRemoved(claim.id(), claim.lease(), Instant.now()));
        yield new Outcome(true, null, null, false, 0);
      }
      case Fail f -> fail(claim, f.error(), 0);
      case Reconnect r -> reconnect(claim, r.error(), 0);
      case Ready ready -> authorizeAndExecute(claim, ready);
    };
  }

  private Outcome authorizeAndExecute(Claim claim, Ready ready) {
    Authorized authorized;
    try {
      authorized = tx(() -> authorize(claim));
    } catch (RuntimeException e) {
      if (GpsTokenRefusedException.isCausedBy(e)) {
        // Access revoked at the service, or a refresh token no longer valid: retrying cannot help.
        LOG.infof("Route sync %d: token refresh refused (%s)", claim.id(), e.getMessage());
        return reconnect(claim, GpsSyncError.UNAUTHORIZED, 0);
      }
      LOG.warnf(e, "Route sync %d: could not refresh the token", claim.id());
      return fail(claim, GpsSyncError.SERVICE_ERROR, 0);
    }
    if (authorized == null) {
      return fail(claim, GpsSyncError.NOT_CONFIGURED, 0);
    }
    return execute(claim, ready, authorized);
  }

  /**
   * The authorization for the calls, the token refreshed first if it expires — in a transaction of
   * its own that does nothing else, so that a refreshed token is stored as soon as it is obtained
   * and never lost to a rollback of unrelated work. Null when the connection or the credential has
   * gone meanwhile.
   */
  private @Nullable Authorized authorize(Claim claim) {
    GpsServiceConnection connection = connectionRepository.findById(claim.connectionId());
    if (connection == null) {
      return null;
    }
    Optional<DomainGpsCredential> credential =
        credentialService.getCredentials(claim.domainId(), claim.serviceType());
    if (credential.isEmpty()) {
      return null;
    }
    GpsAuth auth = tokens.auth(connection, credential.get());
    return new Authorized(auth, connection.getAccessTokenEncrypted());
  }

  private Prepared prepare(Claim claim) {
    GpsServiceConnection connection = connectionRepository.findById(claim.connectionId());
    if (connection == null || (claim.desiredHash() == null && claim.externalRouteId() == null)) {
      return new Nothing();
    }
    Optional<DomainGpsCredential> credential =
        credentialService.getCredentials(claim.domainId(), claim.serviceType());
    if (credential.isEmpty()) {
      return new Fail(GpsSyncError.NOT_CONFIGURED);
    }
    if (!GpsConnectionTokens.matches(connection, credential.get())) {
      return new Reconnect(GpsSyncError.UNAUTHORIZED);
    }
    GpsServiceClient client = tokens.client(claim.serviceType());

    String externalId = claim.externalRouteId();
    if (claim.desiredHash() == null) {
      return new Ready(Op.DELETE, client, externalId, null, null, null);
    }

    Long routeId = claim.desiredRouteId();
    Route route = routeId != null ? routeRepository.findById(routeId) : null;
    if (route == null
        || route.isDeleted()
        || !route.getTeam().getDomain().getId().equals(claim.domainId())) {
      return new Fail(GpsSyncError.ROUTE_UNAVAILABLE);
    }
    Optional<Asset> asset = GpsRouteGpx.pick(route);
    if (asset.isEmpty()) {
      return new Fail(GpsSyncError.ROUTE_UNAVAILABLE);
    }
    String name = claim.desiredName() != null ? claim.desiredName() : route.getName();
    byte[] gpx = routeGpx.read(asset.get());
    // The hash of what is read now, not the planner's: what reaches the service is this.
    String hash =
        GpsSyncNames.hash(
            GpsSyncNames.contentKey(asset.get().getId(), asset.get().getContentRevision()), name);
    RouteMeta meta =
        new RouteMeta(
            name,
            claim.rideId() != null
                ? GpsSyncNames.wahooExternalId(claim.domainId(), claim.rideId())
                : null);
    if (externalId == null) {
      // A manual upload of the same route becomes this row's: updated, not copied (§3.6). Its id
      // is written onto this row in this very transaction, so a failed call cannot lose it.
      externalId =
          syncRepository
              .takeManual(claim.id(), claim.lease(), claim.connectionId(), route.getId())
              .orElse(null);
    }
    return new Ready(
        externalId == null ? Op.CREATE : Op.UPDATE, client, externalId, gpx, hash, meta);
  }

  private Outcome execute(Claim claim, Ready ready, Authorized authorized) {
    int calls = 0;
    Op op = ready.op();
    GpsCallResult result = call(ready, authorized.auth(), op);
    calls++;

    if (result instanceof GpsCallResult.Unauthorized) {
      GpsAuth refreshed = refreshAfter401(claim, authorized);
      if (refreshed == null) {
        return reconnect(claim, GpsSyncError.UNAUTHORIZED, calls);
      }
      result = call(ready, refreshed, op);
      calls++;
      if (result instanceof GpsCallResult.NotFound && op == Op.UPDATE) {
        op = Op.CREATE;
        result = call(ready, refreshed, op);
        calls++;
      }
    } else if (result instanceof GpsCallResult.NotFound && op == Op.UPDATE) {
      // The user deleted it at the service: sent again, under a new id.
      op = Op.CREATE;
      result = call(ready, authorized.auth(), op);
      calls++;
    }
    return record(claim, ready, op, result, calls);
  }

  private GpsCallResult call(Ready ready, GpsAuth auth, Op op) {
    try {
      return switch (op) {
        case CREATE ->
            ready.client().createRoute(auth, nonNull(ready.gpx()), nonNull(ready.meta()));
        case UPDATE ->
            ready
                .client()
                .updateRoute(
                    auth, nonNull(ready.externalId()), nonNull(ready.gpx()), nonNull(ready.meta()));
        case DELETE -> ready.client().deleteRoute(auth, nonNull(ready.externalId()));
      };
    } catch (RuntimeException e) {
      LOG.warnf(e, "Route sync call %s failed", op);
      return new GpsCallResult.Failed(0, e.getMessage() != null ? e.getMessage() : "error");
    }
  }

  private @Nullable GpsAuth refreshAfter401(Claim claim, Authorized authorized) {
    try {
      return tx(
          () -> {
            GpsServiceConnection connection = connectionRepository.findById(claim.connectionId());
            if (connection == null) {
              return null;
            }
            Optional<DomainGpsCredential> credential =
                credentialService.getCredentials(claim.domainId(), claim.serviceType());
            return credential.isEmpty()
                ? null
                : tokens.forceRefresh(connection, credential.get(), authorized.usedToken());
          });
    } catch (RuntimeException e) {
      LOG.infof("Route sync %d: token refresh refused (%s)", claim.id(), e.getMessage());
      return null;
    }
  }

  private Outcome record(Claim claim, Ready ready, Op op, GpsCallResult result, int calls) {
    Instant now = Instant.now();
    return switch (result) {
      case GpsCallResult.Ok ok -> {
        if (op == Op.DELETE) {
          tx(() -> syncRepository.markRemoved(claim.id(), claim.lease(), now));
          yield new Outcome(true, null, null, false, calls);
        }
        String externalId = ok.externalId() != null ? ok.externalId() : ready.externalId();
        if (externalId == null) {
          // Nothing to track it by: retrying would only stack copies at the service.
          LOG.errorf(
              "Route sync %d: %s answered no route id; given up", claim.id(), claim.serviceType());
          tx(
              () ->
                  syncRepository.markFailed(
                      claim.id(),
                      claim.lease(),
                      MAX_ATTEMPTS,
                      null,
                      GpsSyncError.SERVICE_ERROR,
                      now));
          yield new Outcome(false, null, GpsSyncError.SERVICE_ERROR, false, calls);
        }
        String hash = nonNull(ready.hash());
        int written =
            tx(() -> syncRepository.markSynced(claim.id(), claim.lease(), externalId, hash, now));
        if (written == 0) {
          // Lease lost: the row was deleted by a disconnection, or taken by another worker after
          // the lease expired. The plan's accepted race (§4.6): this route may stay at the service.
          LOG.warnf(
              "Route sync %d: lease lost, route %s on %s left untracked",
              claim.id(), externalId, claim.serviceType());
        }
        yield new Outcome(true, externalId, null, false, calls);
      }
      case GpsCallResult.NotFound n -> {
        if (op == Op.DELETE) {
          tx(() -> syncRepository.markRemoved(claim.id(), claim.lease(), now));
          yield new Outcome(true, null, null, false, calls);
        }
        yield fail(claim, GpsSyncError.SERVICE_ERROR, calls);
      }
      case GpsCallResult.Unauthorized u -> reconnect(claim, GpsSyncError.UNAUTHORIZED, calls);
      case GpsCallResult.PermissionRevoked p ->
          reconnect(claim, GpsSyncError.PERMISSION_REVOKED, calls);
      case GpsCallResult.RateLimited rl -> {
        tx(
            () -> {
              connectionRepository.pauseSync(claim.connectionId(), rl.retryAt());
              return syncRepository.release(
                  claim.id(), claim.lease(), GpsSyncError.RATE_LIMITED, now);
            });
        LOG.infof(
            "Route sync paused for connection %d until %s (429)",
            claim.connectionId(), rl.retryAt());
        yield new Outcome(false, null, GpsSyncError.RATE_LIMITED, true, calls);
      }
      case GpsCallResult.Failed f -> {
        LOG.infof("Route sync %d: %s %s failed (%s)", claim.id(), claim.serviceType(), op, f);
        yield fail(claim, GpsSyncError.SERVICE_ERROR, calls);
      }
    };
  }

  private Outcome fail(Claim claim, GpsSyncError error, int calls) {
    Instant now = Instant.now();
    int attempts = claim.attempts() + 1;
    Instant next = now.plus(backoff(attempts));
    tx(() -> syncRepository.markFailed(claim.id(), claim.lease(), attempts, next, error, now));
    return new Outcome(false, null, error, false, calls);
  }

  private Outcome reconnect(Claim claim, GpsSyncError error, int calls) {
    Instant now = Instant.now();
    tx(
        () -> {
          connectionRepository.markSyncReconnectRequired(claim.connectionId(), now);
          return syncRepository.release(claim.id(), claim.lease(), error, now);
        });
    LOG.infof(
        "Route sync stopped for connection %d: reconnection required (%s)",
        claim.connectionId(), error);
    return new Outcome(false, null, error, true, calls);
  }

  private static <T> T nonNull(@Nullable T value) {
    if (value == null) {
      throw new IllegalStateException("Missing value for a route sync call");
    }
    return value;
  }

  private static <T> T tx(Callable<T> work) {
    return QuarkusTransaction.requiringNew().call(work);
  }
}
