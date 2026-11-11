package fr.pedalons.service.common;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;

/**
 * The one rule deciding which visibilities a team accepts for a kind of content
 * (docs/LEDGER_*.md API-176). Every write path that takes a visibility asks it, and nothing else
 * re-derives the rule from {@code team.visibility}; the computed fields the clients will read are
 * meant to come from it too, so that validation and what a client offers cannot diverge.
 *
 * <table>
 *   <caption>Accepted visibilities</caption>
 *   <tr><th>Team</th><th>Ride, route, post, trip, stage, template, page</th><th>Ad</th></tr>
 *   <tr><td>{@code PUBLIC}, {@code PUBLIC_UNLISTED}</td><td>all three</td><td>{@code TEAM}</td></tr>
 *   <tr><td>{@code TEAM} with {@code publicContentAllowed}</td><td>all three</td>
 *       <td>{@code TEAM}</td></tr>
 *   <tr><td>{@code TEAM} otherwise</td><td>{@code TEAM}</td><td>{@code TEAM}</td></tr>
 * </table>
 *
 * <p>In a private team, {@code PUBLIC} and {@code PUBLIC_UNLISTED} both mean "readable by link
 * only": the listings and the sitemap keep their own team clause in {@code TeamEntityRepository}.
 * Ads are members-only whatever the team ({@code AdAccessChecker}). A template follows the common
 * rule: its visibility is the one of the rides it creates.
 *
 * <p>Withdrawing the flag leaves existing public content readable by link; it only stops anything
 * new from being saved as non-{@code TEAM}.
 */
@ApplicationScoped
public class ContentVisibilityRules {

  private static final List<Visibility> TEAM_ONLY = List.of(Visibility.TEAM);

  private static final List<Visibility> ALL = List.of(Visibility.values());

  /**
   * The visibilities {@code team} accepts for content of {@code contentType}, in the order of
   * {@link Visibility}. Never empty: {@code TEAM} is always accepted.
   *
   * @throws IllegalArgumentException for a type that carries no visibility (a team, a comment…)
   */
  public List<Visibility> allowedVisibilities(Team team, EntityType contentType) {
    return accepted(team, contentType);
  }

  /**
   * {@link #allowedVisibilities}, for the DTO factories, which are not beans: the computed fields
   * of {@code TeamDetailDto} and of the entities' permissions block read the rule here, so that
   * what a client offers and what a write accepts cannot diverge.
   */
  public static List<Visibility> accepted(Team team, EntityType contentType) {
    return switch (contentType) {
      case AD -> TEAM_ONLY;
      case RIDE, ROUTE, POST, TRIP, TRIP_STAGE, TEAM_PAGE, RIDE_TEMPLATE ->
          team.getVisibility() != Visibility.TEAM || team.isPublicContentAllowed()
              ? ALL
              : TEAM_ONLY;
      default -> throw new IllegalArgumentException(contentType + " content carries no visibility");
    };
  }

  /**
   * The visibility a creation form starts from: the team's own. A private team starts its content
   * as {@code TEAM} whether or not it has {@code publicContentAllowed} — publishing by link is a
   * decision taken item by item (docs/LEDGER_*.md API-176, decision D1). Accepted for every type
   * but ads, whose request carries no visibility and which are always {@code TEAM}.
   */
  public static Visibility defaultVisibility(Team team) {
    return team.getVisibility();
  }

  /**
   * Whether anyone, member or not, may download the logo of {@code team}, which otherwise follows
   * its about page — {@code TEAM} in a private team (docs/LEDGER_*.md API-176). True for a private
   * team exactly when it has {@code publicContentAllowed}: its content read by link embeds the
   * team's logo ({@code TeamPublicationDto}), and nothing else of the about page is opened. Read
   * off the team alone, never off its content: a private team whose flag was withdrawn keeps its
   * logo closed, even while content published before still reads by link. Public and unlisted
   * teams answer false: their logo follows the about page, as before.
   */
  public static boolean privateTeamLogoIsPublic(Team team) {
    return team.getVisibility() == Visibility.TEAM && team.isPublicContentAllowed();
  }

  /** Whether {@code team} accepts {@code visibility} for content of {@code contentType}. */
  public boolean isAllowed(Team team, EntityType contentType, Visibility visibility) {
    return allowedVisibilities(team, contentType).contains(visibility);
  }

  /**
   * Refuses a visibility the team does not accept for this content.
   *
   * @throws BusinessException {@link ErrorCode#INVALID_VISIBILITY}
   */
  public void requireAllowed(Team team, EntityType contentType, Visibility visibility) {
    if (!isAllowed(team, contentType, visibility)) {
      throw new BusinessException(ErrorCode.INVALID_VISIBILITY);
    }
  }
}
