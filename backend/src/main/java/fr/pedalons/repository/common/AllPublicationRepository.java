package fr.pedalons.repository.common;

import fr.pedalons.domain.common.Publication;
import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamEntityType;
import fr.pedalons.repository.query.PedalonsQuery;
import fr.pedalons.repository.tag.TagFilter;
import fr.pedalons.service.publication.PublicationEndCalculator;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AllPublicationRepository
    implements TeamEntityRepository<Publication, PublicationQuery> {
  @Override
  public TeamEntityType getEntityType() {
    return TeamEntityType.PUBLICATION;
  }

  @Override
  public EntityType getAllEntityType() {
    return EntityType.PUBLICATION;
  }

  /**
   * Find publications that should be auto-published (DRAFT status with publishAt in the past).
   */
  public List<Publication> findPublicationsToAutoPublish() {
    return find(
            "status = ?1 and publishAt is not null and publishAt <= ?2 and deleted = false",
            Status.DRAFT,
            Instant.now())
        .list();
  }

  /**
   * Compare-and-set of a publication found by {@link #findPublicationsToAutoPublish} from DRAFT to
   * PUBLISHED, on the version it was read at. True if this caller won the row; false if another
   * backend published it first — two run side by side during a rolling update — or if someone
   * edited it since. A bulk update, so the loaded entity is stale afterwards: refresh it.
   */
  public boolean claimAutoPublish(Publication publication, Instant dateTime, Instant now) {
    return update(
            "status = ?1, publishAt = null, dateTime = ?2, updatedAt = ?3, version = version + 1"
                + " where id = ?4 and version = ?5 and status = ?6",
            Status.PUBLISHED,
            dateTime,
            now,
            publication.getId(),
            publication.getVersion(),
            Status.DRAFT)
        == 1;
  }

  /**
   * Correlated EXISTS over both participation tables — a ride is joined through its groups, a trip
   * directly. Written as an EXISTS rather than a join so a publication is never duplicated and the
   * page count stays right; {@code idx_ride_participations_user_group (user_id, ride_group_id)} and
   * {@code idx_trip_participations_user_trip (user_id, trip_id)} both lead on {@code user_id}, which
   * is the selective column here.
   */
  private static final String PARTICIPATING_CLAUSE =
      "(exists (select 1 from RideParticipation rp "
          + "where rp.rideGroup.ride.id = te.id and rp.user.id = :participatingUserId) "
          + "or exists (select 1 from TripParticipation tp "
          + "where tp.trip.id = te.id and tp.user.id = :participatingUserId))";

  /**
   * A ride routed nowhere: neither the ride nor any of its groups points at a route. Subqueries on
   * {@code Ride} rather than a path through {@code te}, whose static type is the {@code Publication}
   * root and carries no {@code route}.
   */
  private static final String WITHOUT_ROUTE_CLAUSE =
      "(TYPE(te) = Ride"
          + " and not exists (select 1 from Ride r where r.id = te.id and r.route is not null)"
          + " and not exists (select 1 from RideGroup g where g.ride.id = te.id"
          + " and g.route is not null))";

  /** A ride with at least one capped group whose registrations have reached the cap. */
  private static final String WITH_FULL_GROUP_CLAUSE =
      "(TYPE(te) = Ride and exists (select 1 from RideGroup g where g.ride.id = te.id"
          + " and g.maxParticipants is not null"
          + " and g.maxParticipants <= (select count(p.id) from RideParticipation p"
          + " where p.rideGroup.id = g.id)))";

  /**
   * The end of a ride or a trip, as every list reads it: the stored one, else the departure plus
   * {@link PublicationEndCalculator#DEFAULT_DURATION} — the rows an older backend wrote during a
   * start-first deploy, or not yet reached by {@code PublicationEndBackfill}. Spelt as two branches
   * rather than a {@code coalesce} with interval arithmetic, so the bound is a plain parameter on
   * each column ({@code :x} and {@code :x} minus the default duration) and the indexes stay usable.
   */
  private static String endClause(String operator, String param) {
    return "(TYPE(te) IN (Ride, Trip) AND (te.endDateTime "
        + operator
        + " :"
        + param
        + " OR (te.endDateTime IS NULL AND te.dateTime "
        + operator
        + " :"
        + param
        + "Start)))";
  }

  private static PedalonsQuery andEnd(
      PedalonsQuery pedalonsQuery, String operator, String param, Instant at) {
    return pedalonsQuery.and(
        endClause(operator, param),
        Map.of(param, at, param + "Start", at.minus(PublicationEndCalculator.DEFAULT_DURATION)));
  }

  @Override
  public PedalonsQuery andSpecific(PedalonsQuery pedalonsQuery, PublicationQuery query) {
    PublicationType publicationType = query.type();
    if (publicationType != null) {
      pedalonsQuery =
          pedalonsQuery.and("TYPE(te) = :type", Map.of("type", publicationType.getType()));
    }
    Status status = query.status();
    if (status != null) {
      // ANDed with the visibility rules already in place: a status filter narrows what the caller
      // may see, it never unlocks a status they are not allowed to see.
      pedalonsQuery =
          pedalonsQuery.and("te.status = :statusFilter", Map.of("statusFilter", status));
    }
    if (query.participating()) {
      Long userId = query.userId();
      if (userId == null) {
        // Nobody is registered when nobody is logged in. Same rule as minRole: yield nothing rather
        // than ignore the filter.
        pedalonsQuery = pedalonsQuery.and("te.id IS NULL", Map.of());
      } else {
        pedalonsQuery =
            pedalonsQuery.and(PARTICIPATING_CLAUSE, Map.of("participatingUserId", userId));
      }
    }
    if (query.withoutRoute()) {
      pedalonsQuery = pedalonsQuery.and(WITHOUT_ROUTE_CLAUSE, Map.of());
    }
    if (query.withFullGroup()) {
      pedalonsQuery = pedalonsQuery.and(WITH_FULL_GROUP_CLAUSE, Map.of());
    }
    Set<Long> tagIds = query.tagIds();
    if (tagIds != null) {
      pedalonsQuery = TagFilter.andTaggedWithAny(pedalonsQuery, "te", tagIds);
    }
    Instant notEndedAt = query.notEndedAt();
    if (notEndedAt != null) {
      pedalonsQuery = andEnd(pedalonsQuery, ">=", "notEndedAt", notEndedAt);
    }
    Instant endedBefore = query.endedBefore();
    if (endedBefore != null) {
      pedalonsQuery = andEnd(pedalonsQuery, "<", "endedBefore", endedBefore);
    }
    Instant upcomingFirstAt = query.upcomingFirstAt();
    if (upcomingFirstAt != null) {
      pedalonsQuery = orderUpcomingFirst(pedalonsQuery, upcomingFirstAt);
    } else if (query.ascending()) {
      // getPedalonsQuery set the default ordering before calling us; order() replaces it.
      // The id ends the key, in the same direction, so a tie on the date keeps one fixed order.
      pedalonsQuery = pedalonsQuery.order("te.dateTime asc, te.id asc");
    }
    return pedalonsQuery;
  }

  /**
   * One list in two sections (docs/LEDGER_*.md API-185, rule RL15): the rides and trips not over at
   * {@code at} — the very clause of {@code notEndedAt}, so a section and the {@code when=UPCOMING}
   * list it mirrors can never disagree — soonest departure first, then every other row, latest
   * first. A total order: the id ends each section's key, in the section's direction.
   *
   * <p>Within the first section the second key sorts the departures and the third ties; within the
   * second, the second key is null everywhere and the third sorts. The ids follow the same pattern.
   * Bound parameters in the {@code ORDER BY}, held by the ordering itself ({@link
   * PedalonsQuery#order(String, Map)}): {@code countMatching} drops both together.
   */
  private static PedalonsQuery orderUpcomingFirst(PedalonsQuery pedalonsQuery, Instant at) {
    String upcoming = endClause(">=", "upcomingFirstAt");
    return pedalonsQuery.order(
        "case when "
            + upcoming
            + " then 0 else 1 end asc, case when "
            + upcoming
            + " then te.dateTime end asc, te.dateTime desc, case when "
            + upcoming
            + " then te.id end asc, te.id desc",
        Map.of(
            "upcomingFirstAt",
            at,
            "upcomingFirstAtStart",
            at.minus(PublicationEndCalculator.DEFAULT_DURATION)));
  }

  @Override
  public PublicationQuery getQuerySlug(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      String slug,
      boolean includeDeleted,
      boolean platformAdmin) {
    return PublicationQuery.builder()
        .domainId(domainId)
        .teamIds(Set.of(teamId))
        .userId(userId)
        .slug(slug)
        .includeDeleted(includeDeleted)
        .platformAdmin(platformAdmin)
        .build();
  }

  @Override
  public PublicationQuery getQueryId(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      Long id,
      boolean includeDeleted,
      boolean platformAdmin) {
    return PublicationQuery.builder()
        .domainId(domainId)
        .teamIds(Set.of(teamId))
        .userId(userId)
        .id(id)
        .includeDeleted(includeDeleted)
        .platformAdmin(platformAdmin)
        .build();
  }

  /**
   * Rides, posts and trips a user authored, for the GDPR data export. Single-table inheritance means
   * one query covers all three.
   */
  public List<Publication> findByCreator(Long domainId, Long userId) {
    return list("createdBy.id = ?2 and team.domain.id = ?1 order by createdAt", domainId, userId);
  }
}
