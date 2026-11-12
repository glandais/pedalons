package fr.pedalons.enums;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * Sortable columns of a team's member list ({@code GET /api/teams/{teamSlug}/members}). The
 * repository always appends the membership id, so the order is total and pages never overlap.
 */
@RequiredArgsConstructor
@Getter
public enum MemberSortBy {
  /**
   * The member's display name — what both clients show ({@code PublicUserDto.displayName}) —
   * regardless of case, A to Z unless {@code sortDir} says otherwise. The order of the list when
   * {@code sortBy} is omitted.
   */
  NAME("lower(user.displayName)", SortDirection.ASC),
  /** When the member joined the team — the « nouveaux membres » of the administration panel. */
  JOINED_AT("joinedAt", SortDirection.DESC);

  final String field;

  /** The direction an omitted {@code sortDir} stands for. */
  final SortDirection defaultDirection;
}
