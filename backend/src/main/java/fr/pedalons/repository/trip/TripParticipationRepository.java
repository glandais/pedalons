package fr.pedalons.repository.trip;

import static fr.pedalons.repository.common.MemberRouteVisibility.routeVisible;

import fr.pedalons.domain.trip.TripParticipation;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.common.MemberRouteVisibility;
import fr.pedalons.repository.common.ParticipantPages;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.TypedQuery;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class TripParticipationRepository implements BaseRepository<TripParticipation> {

  public Optional<TripParticipation> findByUserAndTrip(Long userId, Long tripId) {
    return find("user.id = ?1 and trip.id = ?2", userId, tripId).firstResultOptional();
  }

  /**
   * Which of these trips the given user is registered for, in a single query — the bulk counterpart
   * of {@link #findByUserAndTrip}, so a list page costs one query instead of one per row. Served by
   * {@code idx_trip_participations_user_trip} ({@code user_id, trip_id}).
   */
  public Set<Long> findRegisteredTripIds(Long userId, Collection<Long> tripIds) {
    if (tripIds.isEmpty()) {
      return Set.of();
    }
    List<Long> rows =
        getEntityManager()
            .createQuery(
                "select p.trip.id from TripParticipation p "
                    + "where p.user.id = :userId and p.trip.id in (:tripIds)",
                Long.class)
            .setParameter("userId", userId)
            .setParameter("tripIds", tripIds)
            .getResultList();
    return new HashSet<>(rows);
  }

  /** Every trip a user signed up for, for the GDPR data export. */
  public List<TripParticipation> findByUser(Long domainId, Long userId) {
    return list(
        "user.id = ?2 and trip.team.domain.id = ?1 order by registeredAt", domainId, userId);
  }

  /**
   * For the automatic route sync (docs/LEDGER_*.md API-120): every stage leaving within {@code
   * [from, to)} of every trip of the domain someone is registered for, paired with each GPS service
   * connection of the registered user that asked for the sync and does not wait for a reconnection
   * — in a single query, whatever their number.
   *
   * <p>The counterpart of {@code RideParticipationRepository.findGpsSyncTargets}, with the same
   * rules: live teams the user is still a member of (leaving a team does not remove a
   * registration), published, non-deleted trips — hidden by moderation only for the team's
   * moderators — and non-deleted stages whose own route the user can download ({@link
   * MemberRouteVisibility#routeVisible}, shared with the rides). A stage without a route, or with
   * one the member cannot download, gives nothing: never the trip's route instead. The window
   * applies to each stage's own departure, not the trip's.
   *
   * <p>No pinned team: a pin belongs to a host alias, and this runs outside any request.
   */
  public List<GpsSyncStageTargetRow> findGpsSyncStageTargets(
      Long domainId, Instant from, Instant to) {
    return getEntityManager()
        .createQuery(
            "select new fr.pedalons.repository.trip.GpsSyncStageTargetRow("
                + " c.id, c.serviceType, p.user.id, s.id, s.name, s.dateTime, s.timezone,"
                + " tr.name, sr.id)"
                + " from TripParticipation p"
                + " join p.trip tr"
                + " join tr.stages s"
                + " join tr.team t"
                + " join UserTeam ut on ut.team = t and ut.user = p.user"
                + " join GpsServiceConnection c on c.user = p.user"
                + "   and c.autoSync = true and c.syncReconnectRequiredAt is null"
                + " left join s.route sr on "
                + routeVisible("sr")
                + " where t.domain.id = :domainId and t.deleted = false"
                + " and tr.deleted = false and tr.status = :published"
                + " and (tr.moderationHiddenAt is null or ut.role in (:moderators))"
                + " and s.deleted = false"
                + " and s.dateTime >= :from and s.dateTime < :to"
                + " and sr is not null"
                + " order by c.id, s.dateTime, s.id",
            GpsSyncStageTargetRow.class)
        .setParameter("domainId", domainId)
        .setParameter("published", Status.PUBLISHED)
        .setParameter("memberStatuses", List.of(Status.PUBLISHED, Status.CANCELLED))
        .setParameter("moderators", List.of(TeamRole.ORGANIZER, TeamRole.ADMIN))
        .setParameter("from", from)
        .setParameter("to", to)
        .getResultList();
  }

  /**
   * For a device (docs/LEDGER_*.md API-168): the stages leaving within {@code [from, to)} of the
   * trips this user is registered for, earliest first, each with its own route — in a single query,
   * as scalars.
   *
   * <p>The selection is that of {@link #findGpsSyncStageTargets}, for one user and as slugs rather
   * than ids — what a device lists is what the automatic sync sends — <b>plus the stages of a
   * cancelled trip</b>, which the device shows as « Annulé » rather than letting them vanish
   * (docs/LEDGER_*.md API-194) and which the sync never takes: live teams the user is still a
   * member of, published or cancelled, non-deleted trips (hidden by moderation only for the team's
   * moderators), non-deleted stages whose own route the member can download ({@link
   * MemberRouteVisibility#routeVisible}). A stage without such a route is left out — never the
   * trip's route instead. The window applies to each stage's own departure. A change to either
   * selection goes to both.
   *
   * @param pinnedTeamId the team a pinned domain is restricted to; null for none
   */
  public List<RegisteredStageRow> findUpcomingRegisteredStages(
      Long domainId,
      Long userId,
      @Nullable Long pinnedTeamId,
      Instant from,
      Instant to,
      int limit) {
    String jpql =
        "select new fr.pedalons.repository.trip.RegisteredStageRow("
            + " t.slug, tr.slug, tr.name, s.name, s.dateTime, s.timezone,"
            + " sr.id, sr.slug, sr.name, sr.distance, sr.elevationGain, sp.name, ep.name,"
            + " t.name, tr.status, s.endDateTime)"
            + " from TripParticipation p"
            + " join p.trip tr"
            + " join tr.stages s"
            + " join tr.team t"
            + " join UserTeam ut on ut.team = t and ut.user.id = :userId"
            + " left join s.route sr on "
            + routeVisible("sr")
            + " left join s.startPlace sp"
            + " left join s.endPlace ep"
            + " where p.user.id = :userId"
            + " and t.domain.id = :domainId and t.deleted = false"
            + " and tr.deleted = false and tr.status in (:tripStatuses)"
            + " and (tr.moderationHiddenAt is null or ut.role in (:moderators))"
            + " and s.deleted = false"
            + " and s.dateTime >= :from and s.dateTime < :to"
            + " and sr is not null"
            + (pinnedTeamId != null ? " and t.id = :pinnedTeamId" : "")
            + " order by s.dateTime asc, s.sortOrder asc, s.id asc";
    TypedQuery<RegisteredStageRow> query =
        getEntityManager()
            .createQuery(jpql, RegisteredStageRow.class)
            .setParameter("userId", userId)
            .setParameter("domainId", domainId)
            .setParameter("tripStatuses", List.of(Status.PUBLISHED, Status.CANCELLED))
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

  /** The live users registered to a trip who are still members of its team. */
  public List<User> findRegisteredMemberUsers(Long tripId) {
    return getEntityManager()
        .createQuery(
            "select distinct u from TripParticipation p join p.user u"
                + " where p.trip.id = :tripId and u.deleted = false"
                + " and exists (select 1 from UserTeam ut"
                + " where ut.user = u and ut.team = p.trip.team)",
            User.class)
        .setParameter("tripId", tripId)
        .getResultList();
  }

  /**
   * One page of the people registered to a trip, in registration order. Two queries (the page and
   * its count), whatever the size of the trip. docs/LEDGER_*.md API-12.
   *
   * @param search matched against the display name, case-insensitively; blank for no filter
   */
  public PedalonsPage<User> findParticipants(
      Long tripId, @Nullable String search, int page, int size) {
    Map<String, Object> params = new HashMap<>();
    params.put("tripId", tripId);
    return ParticipantPages.find(
        getEntityManager(),
        "TripParticipation",
        new StringBuilder(" where p.trip.id = :tripId"),
        params,
        search,
        page,
        size);
  }
}
