package fr.pedalons.util;

import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ride.RideParticipation;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.Status;
import fr.pedalons.infrastructure.security.TokenEncryptionService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * Fixtures of the automatic route sync tests (docs/LEDGER_*.md API-120): connections whose tokens
 * decrypt, tracking rows read back, and the few writes the tests need to set a scene the planner
 * or the worker would take minutes to reach.
 */
@ApplicationScoped
public class GpsSyncTestData {

  public static final String ACCESS_TOKEN = "access-token";
  public static final String REFRESH_TOKEN = "refresh-token";

  @Inject EntityManager em;
  @Inject TokenEncryptionService encryptionService;
  @Inject TestDataService dataService;

  /** A connection with real (decryptable) OAuth 2.0 tokens, valid for an hour. */
  @Transactional
  public GpsServiceConnection connect(User user, GpsServiceType serviceType, boolean autoSync) {
    GpsServiceConnection connection =
        new GpsServiceConnection(em.find(User.class, user.getId()), serviceType);
    connection.setAccessTokenEncrypted(encryptionService.encrypt(ACCESS_TOKEN));
    connection.setRefreshTokenEncrypted(encryptionService.encrypt(REFRESH_TOKEN));
    connection.setTokenExpiresAt(Instant.now().plus(1, ChronoUnit.HOURS));
    connection.setAutoSync(autoSync);
    em.persist(connection);
    em.flush();
    return connection;
  }

  @Transactional
  public GpsServiceConnection connection(Long connectionId) {
    return em.find(GpsServiceConnection.class, connectionId);
  }

  @Transactional
  public void setAutoSync(Long connectionId, boolean autoSync) {
    em.find(GpsServiceConnection.class, connectionId).setAutoSync(autoSync);
  }

  @Transactional
  public void markReconnectRequired(Long connectionId) {
    // A bulk update, as the worker writes it: the entity never writes this column.
    em.createQuery(
            "update GpsServiceConnection c set c.syncReconnectRequiredAt = :now where c.id = :id")
        .setParameter("now", Instant.now())
        .setParameter("id", connectionId)
        .executeUpdate();
  }

  /** A GPX asset on the route — what the planner fingerprints. Its bytes are never read here. */
  public Asset attachGpx(Route route, User user) {
    return dataService.attachAsset(route, user, AssetType.ROUTE_FILTERED_GPX, "route.gpx");
  }

  /** A route with a GPX, in the ride's team. */
  public Route routeWithGpx(Ride ride, User user, String name) {
    Route route = dataService.createRoute(ride.getTeam(), user, name);
    attachGpx(route, user);
    return route;
  }

  @Transactional
  public void setGroupStartAt(RideGroup group, Instant startAt) {
    em.find(RideGroup.class, group.getId()).setStartAt(startAt);
  }

  @Transactional
  public void setGroupRoute(RideGroup group, @Nullable Route route) {
    em.find(RideGroup.class, group.getId())
        .setRoute(route != null ? em.find(Route.class, route.getId()) : null);
  }

  @Transactional
  public void setRouteStatus(Route route, Status status) {
    em.find(Route.class, route.getId()).setStatus(status);
  }

  @Transactional
  public void hideByModeration(Route route) {
    em.find(Route.class, route.getId()).setModerationHiddenAt(Instant.now());
  }

  /** The access token expires within the five minutes that make it refreshed before a call. */
  @Transactional
  public void expireToken(Long connectionId) {
    em.find(GpsServiceConnection.class, connectionId).setTokenExpiresAt(Instant.now());
  }

  @Transactional
  public void setRideStatus(Ride ride, Status status) {
    em.find(Ride.class, ride.getId()).setStatus(status);
  }

  /** Moves a registration to another group of the same ride, as leaving then joining does. */
  @Transactional
  public void moveParticipation(RideParticipation participation, RideGroup to) {
    em.find(RideParticipation.class, participation.getId())
        .setRideGroup(em.find(RideGroup.class, to.getId()));
  }

  @Transactional
  public List<GpsRouteSync> rows(Long connectionId) {
    return em.createQuery(
            "select s from GpsRouteSync s where s.connection.id = :id order by s.createdAt, s.id",
            GpsRouteSync.class)
        .setParameter("id", connectionId)
        .getResultList();
  }

  @Transactional
  public Optional<GpsRouteSync> row(Long connectionId, Long rideId) {
    return em.createQuery(
            "select s from GpsRouteSync s where s.connection.id = :id and s.rideId = :rideId",
            GpsRouteSync.class)
        .setParameter("id", connectionId)
        .setParameter("rideId", rideId)
        .getResultStream()
        .findFirst();
  }

  /** As if the worker had sent the desired state: what is at the service is what is desired. */
  @Transactional
  public void markSynced(Long rowId, String externalId) {
    em.createQuery(
            "update GpsRouteSync s set s.externalRouteId = :ext, s.syncedHash = s.desiredHash,"
                + " s.syncedAt = :now where s.id = :id")
        .setParameter("ext", externalId)
        .setParameter("now", Instant.now())
        .setParameter("id", rowId)
        .executeUpdate();
  }

  @Transactional
  public void setAttempts(Long rowId, int attempts, @Nullable Instant nextAttemptAt) {
    em.createQuery(
            "update GpsRouteSync s set s.attempts = :attempts, s.nextAttemptAt = :next"
                + " where s.id = :id")
        .setParameter("attempts", attempts)
        .setParameter("next", nextAttemptAt)
        .setParameter("id", rowId)
        .executeUpdate();
  }

  /** Changes the desired hash behind the worker's back, as the planner would mid-call. */
  @Transactional
  public void setDesiredHash(Long rowId, String hash) {
    em.createQuery("update GpsRouteSync s set s.desiredHash = :hash where s.id = :id")
        .setParameter("hash", hash)
        .setParameter("id", rowId)
        .executeUpdate();
  }

  @Transactional
  public long countRows() {
    return em.createQuery("select count(s) from GpsRouteSync s", Long.class).getSingleResult();
  }
}
