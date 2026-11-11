package fr.pedalons.service.common;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Every row of the table of docs/LEDGER_*.md API-176 (plan §4.2), without a container. */
class ContentVisibilityRulesTest {

  private static final List<EntityType> CONTENT =
      List.of(
          EntityType.RIDE,
          EntityType.ROUTE,
          EntityType.POST,
          EntityType.TRIP,
          EntityType.TRIP_STAGE,
          EntityType.TEAM_PAGE,
          EntityType.RIDE_TEMPLATE);

  private static final List<Visibility> ALL =
      List.of(Visibility.TEAM, Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC);

  private final ContentVisibilityRules rules = new ContentVisibilityRules();

  private static Team team(Visibility visibility, boolean publicContentAllowed) {
    Team team = new Team();
    team.setVisibility(visibility);
    team.setPublicContentAllowed(publicContentAllowed);
    return team;
  }

  @Test
  void anOpenTeam_acceptsAllThree_withOrWithoutTheFlag() {
    for (Visibility teamVisibility : List.of(Visibility.PUBLIC, Visibility.PUBLIC_UNLISTED)) {
      for (boolean flag : List.of(false, true)) {
        Team team = team(teamVisibility, flag);
        for (EntityType type : CONTENT) {
          assertEquals(ALL, rules.allowedVisibilities(team, type), teamVisibility + " " + type);
        }
      }
    }
  }

  @Test
  void aPrivateTeamWithTheFlag_acceptsAllThree() {
    Team team = team(Visibility.TEAM, true);
    for (EntityType type : CONTENT) {
      assertEquals(ALL, rules.allowedVisibilities(team, type), type.name());
      for (Visibility visibility : ALL) {
        assertDoesNotThrow(() -> rules.requireAllowed(team, type, visibility));
      }
    }
  }

  @Test
  void aPrivateTeamWithoutTheFlag_acceptsTeamOnly_andRefusesTheRestAsInvalidVisibility() {
    Team team = team(Visibility.TEAM, false);
    for (EntityType type : CONTENT) {
      assertEquals(List.of(Visibility.TEAM), rules.allowedVisibilities(team, type), type.name());
      assertDoesNotThrow(() -> rules.requireAllowed(team, type, Visibility.TEAM));
      for (Visibility visibility : List.of(Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC)) {
        BusinessException ex =
            assertThrows(
                BusinessException.class, () -> rules.requireAllowed(team, type, visibility));
        assertEquals("INVALID_VISIBILITY", ex.getMessage());
      }
    }
  }

  @Test
  void anAd_isTeamOnly_inEveryTeam() {
    for (Visibility teamVisibility : Visibility.values()) {
      for (boolean flag : List.of(false, true)) {
        Team team = team(teamVisibility, flag);
        assertEquals(List.of(Visibility.TEAM), rules.allowedVisibilities(team, EntityType.AD));
        assertThrows(
            BusinessException.class,
            () -> rules.requireAllowed(team, EntityType.AD, Visibility.PUBLIC_UNLISTED));
      }
    }
  }

  @Test
  void aTypeWithoutVisibility_isAProgrammingError() {
    Team team = team(Visibility.PUBLIC, false);
    assertThrows(
        IllegalArgumentException.class, () -> rules.allowedVisibilities(team, EntityType.COMMENT));
  }
}
