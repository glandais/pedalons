package fr.pedalons.repository.common;

import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.Status;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * The JPQL condition that keeps a route only when a team member can download it, shared by the
 * queries that hand routes to a member's devices and GPS services ({@code
 * RideParticipationRepository}, {@code TripParticipationRepository}): one rule, so that a change to
 * it reaches every selection at once.
 */
public final class MemberRouteVisibility {

  private MemberRouteVisibility() {}

  /**
   * The left-join condition that keeps the route aliased {@code alias} only when the team member
   * {@code ut} (a {@code UserTeam} alias of the query) can download it: the same rules as {@code
   * TeamEntityRepository.getPedalonsQuery} for a team's own route — not deleted, and either
   * PUBLISHED/CANCELLED and not hidden by moderation, or seen by a moderator (organizer/admin), who
   * sees drafts and hidden content alike.
   *
   * <p>The query must bind {@code :moderators} (the moderator roles) and {@code :memberStatuses}
   * (PUBLISHED and CANCELLED).
   */
  public static String routeVisible(String alias) {
    return "("
        + alias
        + ".deleted = false and (ut.role in (:moderators) or ("
        + alias
        + ".status in (:memberStatuses) and "
        + alias
        + ".moderationHiddenAt is null)))";
  }

  /**
   * {@link #routeVisible} in Java, for a payload built from rows or entities already loaded: whether
   * the caller, a moderator of the route's team or not, has this route sent to their GPS services —
   * so a DTO reports the route the automatic sync really holds (docs/LEDGER_*.md API-164).
   */
  public static boolean visible(
      boolean deleted,
      @Nullable Status status,
      @Nullable Instant moderationHiddenAt,
      boolean moderator) {
    return !deleted
        && (moderator
            || ((status == Status.PUBLISHED || status == Status.CANCELLED)
                && moderationHiddenAt == null));
  }

  /** {@link #visible(boolean, Status, Instant, boolean)} of a route entity; none is not visible. */
  public static boolean visible(@Nullable Route route, boolean moderator) {
    return route != null
        && visible(route.isDeleted(), route.getStatus(), route.getModerationHiddenAt(), moderator);
  }

  /**
   * The route the automatic sync sends for a ride group: its own when visible to the caller, else
   * its ride's when visible — the rule of {@code RideParticipationRepository#findGpsSyncTargets}.
   */
  public static @Nullable Long syncedRouteId(
      @Nullable Route groupRoute, @Nullable Route rideRoute, boolean moderator) {
    if (visible(groupRoute, moderator)) {
      return groupRoute.getId();
    }
    return visible(rideRoute, moderator) ? rideRoute.getId() : null;
  }
}
