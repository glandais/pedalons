package fr.pedalons.repository.common;

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
}
