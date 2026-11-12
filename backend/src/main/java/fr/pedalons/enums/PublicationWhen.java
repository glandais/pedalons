package fr.pedalons.enums;

/**
 * Which side of now a dated publication — a ride or a trip — falls on, by its end rather than its
 * start (docs/LEDGER_*.md API-85): an outing that left ten minutes ago, or a trip that began
 * yesterday, is still {@link #UPCOMING}. A post has no end and is never in either.
 */
public enum PublicationWhen {

  /** Not over yet: {@code end >= now}, the ones under way included. Soonest departure first. */
  UPCOMING,

  /** Over: {@code end < now}. Latest departure first. */
  PAST,

  /**
   * No filter, an order: one list in two sections (docs/LEDGER_*.md API-185, rule RL15). First
   * what {@link #UPCOMING} keeps, soonest departure first; then everything else — what {@link
   * #PAST} keeps and the posts, which have no end — latest date first. The page envelope carries
   * {@code upcomingTotal}, the size of the first section, so a client places the boundary on any
   * page.
   */
  UPCOMING_FIRST
}
