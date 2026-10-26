package fr.pedalons.service.common;

import fr.pedalons.domain.user.User;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.repository.user.UserRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.stream.Collectors;

/**
 * The participant count and the first few participants of a set of ride groups, or of a trip, in
 * two queries whatever the number of groups or of participants.
 *
 * <p>The ride and trip details used to embed every participant, which on a large team meant
 * hydrating hundreds of registrations and users to draw five avatars. They now carry a {@link
 * #PREVIEW_SIZE}-long preview and the count; the full list is paginated and searched by the {@code
 * …/participants} endpoints (docs/LEDGER_*.md API-12). Reading {@code group.getParticipations()} to
 * count or preview would hydrate the whole collection again: go through here instead.
 *
 * <p><b>Tenancy:</b> answers only about the ids it is handed, which come from a ride or trip already
 * resolved under the request's domain.
 */
@ApplicationScoped
public class ParticipantPreviewLookup {

  /** How many participants a ride group or a trip embeds, earliest registrations first. */
  public static final int PREVIEW_SIZE = 8;

  @Inject UserRepository userRepository;

  /** One participant of a preview, with when they registered — to merge the previews of a ride. */
  public record PreviewedParticipant(PublicUserDto user, Instant registeredAt) {}

  /**
   * @param count every participant, not only the previewed ones
   * @param first the first {@link #PREVIEW_SIZE} participants, in registration order
   */
  public record ParticipantPreview(int count, List<PreviewedParticipant> first) {

    public static final ParticipantPreview EMPTY = new ParticipantPreview(0, List.of());

    public List<PublicUserDto> users() {
      return first.stream().map(PreviewedParticipant::user).toList();
    }
  }

  /**
   * Group id → preview; a group nobody joined maps to {@link ParticipantPreview#EMPTY}.
   *
   * @param withNames {@code false} for a caller who is not a member of the team: the counts only,
   *     no name, and the users are not even loaded (docs/LEDGER_*.md API-144)
   */
  public Map<Long, ParticipantPreview> forRideGroups(Collection<Long> groupIds, boolean withNames) {
    return previews("ride_participations", "ride_group_id", groupIds, id -> withNames);
  }

  /**
   * Same, for groups whose team differs (a list page): only the groups in {@code namedGroupIds}
   * get their first participants, every other keeps its count alone.
   */
  public Map<Long, ParticipantPreview> forRideGroups(
      Collection<Long> groupIds, Set<Long> namedGroupIds) {
    return previews("ride_participations", "ride_group_id", groupIds, namedGroupIds::contains);
  }

  /** The trip's preview; {@code withNames} as for {@link #forRideGroups}. */
  public ParticipantPreview forTrip(Long tripId, boolean withNames) {
    return previews("trip_participations", "trip_id", List.of(tripId), id -> withNames).get(tripId);
  }

  private Map<Long, ParticipantPreview> previews(
      String table, String ownerColumn, Collection<Long> ownerIds, Predicate<Long> withNames) {
    Map<Long, ParticipantPreview> byOwner = new HashMap<>();
    if (ownerIds.isEmpty()) {
      return byOwner;
    }
    // Window functions: the count and the first rows of every owner in a single scan, rather than
    // a count and a limited select per group.
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        userRepository
            .getEntityManager()
            .createNativeQuery(
                "select x.owner_id, x.user_id, x.registered_at, x.cnt from ("
                    + " select p."
                    + ownerColumn
                    + " as owner_id, p.user_id, p.registered_at,"
                    + " count(*) over (partition by p."
                    + ownerColumn
                    + ") as cnt,"
                    + " row_number() over (partition by p."
                    + ownerColumn
                    + " order by p.registered_at, p.id) as rn"
                    + " from "
                    + table
                    + " p where p."
                    + ownerColumn
                    + " in (:ownerIds)) x"
                    + " where x.rn <= :limit order by x.owner_id, x.rn")
            .setParameter("ownerIds", ownerIds)
            .setParameter("limit", PREVIEW_SIZE)
            .getResultList();

    Set<Long> userIds = new LinkedHashSet<>();
    for (Object[] row : rows) {
      if (withNames.test(((Number) row[0]).longValue())) {
        userIds.add(((Number) row[1]).longValue());
      }
    }
    Map<Long, User> users =
        userIds.isEmpty()
            ? Map.of()
            : userRepository.list("id in ?1", userIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

    Map<Long, Integer> counts = new HashMap<>();
    Map<Long, List<PreviewedParticipant>> firsts = new HashMap<>();
    for (Object[] row : rows) {
      Long ownerId = ((Number) row[0]).longValue();
      User user = users.get(((Number) row[1]).longValue());
      counts.put(ownerId, ((Number) row[3]).intValue());
      if (user != null && withNames.test(ownerId)) {
        firsts
            .computeIfAbsent(ownerId, k -> new ArrayList<>())
            .add(new PreviewedParticipant(PublicUserDto.from(user), toInstant(row[2])));
      }
    }
    for (Long ownerId : ownerIds) {
      byOwner.put(
          ownerId,
          counts.containsKey(ownerId)
              ? new ParticipantPreview(
                  counts.get(ownerId), List.copyOf(firsts.getOrDefault(ownerId, List.of())))
              : ParticipantPreview.EMPTY);
    }
    return byOwner;
  }

  private static Instant toInstant(Object value) {
    return switch (value) {
      case Instant instant -> instant;
      case Timestamp timestamp -> timestamp.toInstant();
      case java.time.OffsetDateTime offset -> offset.toInstant();
      default -> throw new IllegalStateException("Unexpected registered_at type " + value);
    };
  }
}
