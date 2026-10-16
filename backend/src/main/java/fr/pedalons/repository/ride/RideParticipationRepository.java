package fr.pedalons.repository.ride;

import fr.pedalons.domain.ride.RideParticipation;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.common.ParticipantPages;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.TypedQuery;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class RideParticipationRepository implements BaseRepository<RideParticipation> {

  public Optional<RideParticipation> findByUserAndGroup(Long userId, Long groupId) {
    return find("user.id = ?1 and rideGroup.id = ?2", userId, groupId).firstResultOptional();
  }

  /**
   * The group each of these rides has the given user registered in, in a single query.
   *
   * <p>This is the bulk form the list path needs. Resolving "am I registered?" row by row with
   * {@link #findByUserAndRide} costs one query per ride, so a page of 20 rides costs 20 queries;
   * here the whole page costs one, and it is served by {@code idx_ride_participations_user_group}
   * ({@code user_id, ride_group_id}).
   *
   * <p>Rides the user is not registered in are simply absent from the map. Scalars are selected
   * rather than entities so nothing enters the persistence context.
   *
   * @return ride id → group id; only for the ride ids that were asked for
   */
  public Map<Long, Long> findRegisteredGroupIdsByRideIds(Long userId, Collection<Long> rideIds) {
    if (rideIds.isEmpty()) {
      return Map.of();
    }
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select p.rideGroup.ride.id, p.rideGroup.id from RideParticipation p "
                    + "where p.user.id = :userId and p.rideGroup.ride.id in (:rideIds)",
                Object[].class)
            .setParameter("userId", userId)
            .setParameter("rideIds", rideIds)
            .getResultList();
    Map<Long, Long> byRide = new HashMap<>();
    for (Object[] row : rows) {
      // joinGroup forbids a second group on the same ride, but a stale row must not decide which
      // group wins arbitrarily on every request: the first one seen stays.
      byRide.putIfAbsent((Long) row[0], (Long) row[1]);
    }
    return byRide;
  }

  /**
   * The ride groups a user is registered in that leave within {@code [from, to)}, earliest first,
   * at most {@code limit} of them — in a single query, whatever their number.
   *
   * <p>Only on the given domain, on live teams the user is still a member of (leaving a team does
   * not remove a registration), on published, non-deleted rides — hidden by moderation only for
   * the team's moderators — and only groups that have something to load: their own route or,
   * failing that, their ride's, as long as the user can download it. A route the device download
   * ({@code DeviceRouteService.findRouteBySlug}) would refuse — deleted, DRAFT for a plain member,
   * hidden by moderation for a plain member — comes back as null (see {@link #routeVisible}), so
   * the caller only has to pick the first non-null one and never lists a slug that 404s.
   *
   * @param pinnedTeamId the team a pinned domain is restricted to; null for none
   */
  public List<RegisteredGroupRow> findUpcomingRegisteredGroups(
      Long domainId,
      Long userId,
      @Nullable Long pinnedTeamId,
      Instant from,
      Instant to,
      int limit) {
    String jpql =
        "select new fr.pedalons.repository.ride.RegisteredGroupRow("
            + " t.slug, r.slug, r.name, g.name, g.startAt, r.dateTime, r.timezone,"
            + " gr.id, gr.slug, gr.name, gr.distance, gr.elevationGain,"
            + " rr.id, rr.slug, rr.name, rr.distance, rr.elevationGain)"
            + " from RideParticipation p"
            + " join p.rideGroup g"
            + " join g.ride r"
            + " join r.team t"
            + " join UserTeam ut on ut.team = t and ut.user.id = :userId"
            + " left join g.route gr on "
            + routeVisible("gr")
            + " left join r.route rr on "
            + routeVisible("rr")
            + " where p.user.id = :userId"
            + " and t.domain.id = :domainId and t.deleted = false"
            + " and r.deleted = false and r.status = :published"
            + " and (r.moderationHiddenAt is null or ut.role in (:moderators))"
            + " and g.startAt >= :from and g.startAt < :to"
            + " and (gr is not null or rr is not null)"
            + (pinnedTeamId != null ? " and t.id = :pinnedTeamId" : "")
            + " order by g.startAt asc, g.sortOrder asc, g.id asc";
    TypedQuery<RegisteredGroupRow> query =
        getEntityManager()
            .createQuery(jpql, RegisteredGroupRow.class)
            .setParameter("userId", userId)
            .setParameter("domainId", domainId)
            .setParameter("published", Status.PUBLISHED)
            .setParameter("memberStatuses", List.of(Status.PUBLISHED, Status.CANCELLED))
            .setParameter("moderators", List.of(TeamRole.ORGANIZER, TeamRole.ADMIN))
            .setParameter("from", from)
            .setParameter("to", to)
            .setMaxResults(limit);
    if (pinnedTeamId != null) {
      query.setParameter("pinnedTeamId", pinnedTeamId);
    }
    return query.getResultList();
  }

  /**
   * The left-join condition that keeps a route only when its team member {@code ut} can download
   * it: the same rules as {@code TeamEntityRepository.getPedalonsQuery} for a team's own route —
   * not deleted, and either PUBLISHED/CANCELLED and not hidden by moderation, or seen by a
   * moderator (organizer/admin), who sees drafts and hidden content alike.
   */
  private static String routeVisible(String alias) {
    return "("
        + alias
        + ".deleted = false and (ut.role in (:moderators) or ("
        + alias
        + ".status in (:memberStatuses) and "
        + alias
        + ".moderationHiddenAt is null)))";
  }

  public Optional<RideParticipation> findByUserAndRide(Long userId, Long rideId) {
    return find("user.id = ?1 and rideGroup.ride.id = ?2", userId, rideId).firstResultOptional();
  }

  /**
   * For the automatic route sync (docs/LEDGER_*.md API-120): every registration of the domain whose
   * group leaves within {@code [from, to)}, paired with each GPS service connection of the
   * registered user that asked for the sync and does not wait for a reconnection — in a single
   * query, whatever their number.
   *
   * <p>The selection is <b>exactly that of {@link #findUpcomingRegisteredGroups}</b> (the upcoming
   * groups a device loads), only across all the users of the domain and as ids rather than slugs:
   * live teams the user is still a member of (leaving a team does not remove a registration),
   * published, non-deleted rides — hidden by moderation only for the team's moderators — and groups
   * that have a route the user can download of their own or, failing that, on their ride. Both
   * share {@link #routeVisible}: a route deleted, DRAFT or hidden by moderation for a plain member
   * comes back as null, so it is never sent to that member's service — and one that becomes so is
   * removed from it. The caller takes the first non-null one ({@link
   * GpsSyncTargetRow#effectiveRouteId}). A change to either selection goes to both.
   *
   * <p>No pinned team: a pin belongs to a host alias, and this runs outside any request.
   */
  public List<GpsSyncTargetRow> findGpsSyncTargets(Long domainId, Instant from, Instant to) {
    return getEntityManager()
        .createQuery(
            "select new fr.pedalons.repository.ride.GpsSyncTargetRow("
                + " c.id, c.serviceType, p.user.id, r.id, g.id, g.name, g.startAt, r.timezone,"
                + " gr.id, gr.name, rr.id, rr.name)"
                + " from RideParticipation p"
                + " join p.rideGroup g"
                + " join g.ride r"
                + " join r.team t"
                + " join UserTeam ut on ut.team = t and ut.user = p.user"
                + " join GpsServiceConnection c on c.user = p.user"
                + "   and c.autoSync = true and c.syncReconnectRequiredAt is null"
                + " left join g.route gr on "
                + routeVisible("gr")
                + " left join r.route rr on "
                + routeVisible("rr")
                + " where t.domain.id = :domainId and t.deleted = false"
                + " and r.deleted = false and r.status = :published"
                + " and (r.moderationHiddenAt is null or ut.role in (:moderators))"
                + " and g.startAt >= :from and g.startAt < :to"
                + " and (gr is not null or rr is not null)"
                + " order by c.id, g.startAt, r.id",
            GpsSyncTargetRow.class)
        .setParameter("domainId", domainId)
        .setParameter("published", Status.PUBLISHED)
        .setParameter("memberStatuses", List.of(Status.PUBLISHED, Status.CANCELLED))
        .setParameter("moderators", List.of(TeamRole.ORGANIZER, TeamRole.ADMIN))
        .setParameter("from", from)
        .setParameter("to", to)
        .getResultList();
  }

  /** Every ride a user signed up for, for the GDPR data export. */
  public List<RideParticipation> findByUser(Long domainId, Long userId) {
    return list(
        "user.id = ?2 and rideGroup.ride.team.domain.id = ?1 order by registeredAt",
        domainId,
        userId);
  }

  /**
   * The live users registered to any group of a ride who are still members of its team. Leaving
   * the team does not remove a registration, but it does end the right to hear about the ride.
   */
  public List<User> findRegisteredMemberUsers(Long rideId) {
    return getEntityManager()
        .createQuery(
            "select distinct u from RideParticipation p join p.user u"
                + " where p.rideGroup.ride.id = :rideId and u.deleted = false"
                + " and exists (select 1 from UserTeam ut"
                + " where ut.user = u and ut.team = p.rideGroup.ride.team)",
            User.class)
        .setParameter("rideId", rideId)
        .getResultList();
  }

  /**
   * One page of the people registered to a ride, or to one of its groups, in registration order.
   * Two queries (the page and its count), whatever the size of the ride. docs/LEDGER_*.md API-12.
   *
   * @param groupId {@code null} for every group of the ride
   * @param search matched against the display name, case-insensitively; blank for no filter
   */
  public PedalonsPage<User> findParticipants(
      Long rideId, @Nullable Long groupId, @Nullable String search, int page, int size) {
    StringBuilder where = new StringBuilder(" where p.rideGroup.ride.id = :rideId");
    Map<String, Object> params = new HashMap<>();
    params.put("rideId", rideId);
    if (groupId != null) {
      where.append(" and p.rideGroup.id = :groupId");
      params.put("groupId", groupId);
    }
    return ParticipantPages.find(
        getEntityManager(), "RideParticipation", where, params, search, page, size);
  }
}
