package fr.pedalons.repository.common;

import fr.pedalons.service.team.request.MinRole;
import java.time.Instant;
import java.util.Set;
import org.jspecify.annotations.Nullable;

public interface TeamEntityQueryInterface extends PageInterface {
  Long domainId();

  /**
   * Restrict to the teams the current user belongs to with at least this role. Null means no
   * membership restriction, which is what every query that does not offer the filter wants.
   */
  default @Nullable MinRole minRole() {
    return null;
  }

  @Nullable Long id();

  @Nullable Long userId();

  @Nullable Set<Long> teamIds();

  /**
   * The team this site is pinned to, when the request arrived on a domain alias. A site scope, not a
   * user filter: it narrows every query the way {@link #domainId()} does, and it ANDs with {@link
   * #teamIds()} rather than replacing it. Null on a regular domain.
   */
  @Nullable Long pinnedTeamId();

  @Nullable String slug();

  @Nullable String search();

  @Nullable Instant from();

  @Nullable Instant to();

  boolean includeDeleted();

  /**
   * Whether the caller is a platform admin. It lifts the visibility rules only where the admin
   * opens something: a detail ({@code findOne}), or a listing of a single team (an explicit single
   * {@link #teamIds()} or a pinned host) without {@link #minRole()}. Cross-team listings, counts and
   * any query with {@code minRole} apply the caller's real membership instead, and someone else's
   * draft ad never appears in a list (docs/LEDGER_*.md API-137). A personal view that happens to
   * target one team (the agenda of a member of a single team, a one-row page of team cards) must
   * pass {@code false}.
   */
  boolean platformAdmin();
}
