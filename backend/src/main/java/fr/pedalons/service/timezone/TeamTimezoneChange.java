package fr.pedalons.service.timezone;

import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.service.publication.PublicationEndCalculator;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * What a change of a team's zone does to its content (docs/LEDGER_*.md API-60, plan §9): every
 * ride, trip, stage and post whose stored zone is the old team zone and whose chain finds no point
 * moves to the new zone, so that its stored zone stays the resolved one. Left behind, the next save
 * of the entity, even for a typo, would read its wall times in another zone than the one they were
 * shown in, and move it without anyone asking.
 *
 * <p>The instants still to come keep their <em>wall time</em> — a team's zone changes to correct a
 * wrong setting, and their times were typed in front of the old zone's label. The past keeps its
 * <em>instants</em>: a stage already ridden, a trip under way or a past ride is relabelled at
 * constant instant, its groups' times rewritten in the new zone so that their departures stay put.
 * An entity located by a place or a route keeps everything. Each rewritten ride or trip goes through
 * {@link PublicationEndCalculator}, the only writer of the stored end.
 */
@ApplicationScoped
public class TeamTimezoneChange {

  @Inject EntityManager entityManager;

  @Inject EventTimezoneResolver resolver;

  @Inject PublicationEndCalculator publicationEndCalculator;

  /**
   * The team's place-less content stored in {@code from}: what {@link #apply} rewrites, in the order
   * it rewrites it — read-only, so that the settings screen can preview the change (plan §9) with
   * the very selection the change will use. A trip's stages come before the trip itself.
   */
  public List<TeamEntity> plan(Team team, ZoneId from, ZoneId to) {
    if (from.equals(to)) {
      return List.of();
    }
    // Trips whatever their stored zone: their stages may be stored in another one.
    List<TeamEntity> candidates =
        entityManager
            .createQuery(
                "select te from TeamEntity te where te.team.id = :teamId and te.deleted = false"
                    + " and TYPE(te) in (Ride, Trip, Post)"
                    + " and (TYPE(te) = Trip or te.timezone = :from)",
                TeamEntity.class)
            .setParameter("teamId", team.getId())
            .setParameter("from", from.getId())
            .getResultList();
    List<TeamEntity> plan = new ArrayList<>();
    for (TeamEntity entity : candidates) {
      switch (entity) {
        case Ride ride -> {
          if (ride.zone().equals(from)
              && resolver.locateRide(ride.getStart(), ride.getRoute()).isEmpty()) {
            plan.add(ride);
          }
        }
        case Trip trip -> {
          Map<TripStage, Optional<ZoneId>> stages = resolver.locateStages(trip);
          for (Map.Entry<TripStage, Optional<ZoneId>> stage : stages.entrySet()) {
            if (stage.getValue().isEmpty() && stage.getKey().zone().equals(from)) {
              plan.add(stage.getKey());
            }
          }
          Optional<ZoneId> located =
              resolver.locateTrip(List.copyOf(stages.values()), trip.getRoute());
          if (located.isEmpty() && trip.zone().equals(from)) {
            plan.add(trip);
          }
        }
        case Post post -> {
          if (post.zone().equals(from)) {
            plan.add(post);
          }
        }
        default -> {}
      }
    }
    return plan;
  }

  /**
   * Rewrites the team's place-less content, in the caller's transaction. Call it before the team's
   * own zone is changed.
   *
   * @return how many entities were rewritten
   */
  public int apply(Team team, ZoneId from, ZoneId to) {
    List<TeamEntity> plan = plan(team, from, to);
    Instant now = Instant.now();
    Set<Trip> changedTrips = new LinkedHashSet<>();
    for (TeamEntity entity : plan) {
      switch (entity) {
        case Ride ride -> {
          rewriteRide(ride, from, to, now);
          publicationEndCalculator.refresh(ride);
        }
        case TripStage stage -> {
          rewrite(stage, from, to, now);
          changedTrips.add(stage.getTrip());
        }
        case Trip trip -> {
          rewrite(trip, from, to, now);
          changedTrips.add(trip);
        }
        default -> rewrite(entity, from, to, now);
      }
    }
    changedTrips.forEach(publicationEndCalculator::refresh);
    return plan.size();
  }

  /**
   * A ride and its groups. Upcoming, the ride keeps its wall time and so does each group's own
   * time; past or under way, the ride and its groups keep their instants — which may leave a group
   * on another local date than its ride, a day offset that its next save keeps
   * (docs/LEDGER_*.md API-101).
   */
  private static void rewriteRide(Ride ride, ZoneId from, ZoneId to, Instant now) {
    Instant previousDateTime = ride.getDateTime();
    boolean upcoming = !previousDateTime.isBefore(now);
    rewrite(ride, from, to, now);
    if (!upcoming) {
      return;
    }
    for (RideGroup group : ride.getGroups()) {
      LocalTime own = EventTimezoneResolver.ownTime(previousDateTime, group.getStartAt(), from);
      long days = EventTimezoneResolver.dayOffset(previousDateTime, group.getStartAt(), from);
      EventTimezoneResolver.setStart(group, ride.getDateTime(), own, to, days);
    }
  }

  /**
   * Moves an entity stored in {@code from} to {@code to}: its instants still to come at constant
   * wall time, the past ones at constant instant.
   */
  private static void rewrite(TeamEntity entity, ZoneId from, ZoneId to, Instant now) {
    if (!entity.getDateTime().isBefore(now)) {
      entity.setDateTime(EventTimezoneResolver.sameWallTime(entity.getDateTime(), from, to));
    }
    Instant publishAt = entity.getPublishAt();
    if (publishAt != null && !publishAt.isBefore(now)) {
      entity.setPublishAt(EventTimezoneResolver.sameWallTime(publishAt, from, to));
    }
    entity.setTimezone(to.getId());
  }
}
