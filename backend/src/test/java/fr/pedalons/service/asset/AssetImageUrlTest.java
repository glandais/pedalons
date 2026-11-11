package fr.pedalons.service.asset;

import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.Visibility;
import org.junit.jupiter.api.Test;

/**
 * The prefix of an image URL decides whether {@code ApiNoIndexFilter} lets it be indexed: only
 * {@code /api/download/public/images/} is spared. The public content of a private team is readable
 * by link only, never indexed (docs/LEDGER_*.md API-176, decision D1).
 */
class AssetImageUrlTest {

  private static String url(Visibility team, Visibility entity) {
    return AssetService.buildImageUrl("team", team, entity, 1L, 2L);
  }

  @Test
  void publicContentOfAPrivateTeam_getsTheUnlistedPrefix() {
    assertTrue(
        url(Visibility.TEAM, Visibility.PUBLIC)
            .startsWith("/api/download/public_unlisted/images/"));
  }

  @Test
  void publicContentOfAnOpenTeam_keepsThePublicPrefix() {
    assertTrue(
        url(Visibility.PUBLIC, Visibility.PUBLIC).startsWith("/api/download/public/images/"));
    assertTrue(
        url(Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC)
            .startsWith("/api/download/public/images/"));
  }

  @Test
  void otherVisibilities_keepTheirOwnPrefix() {
    assertTrue(
        url(Visibility.TEAM, Visibility.PUBLIC_UNLISTED)
            .startsWith("/api/download/public_unlisted/images/"));
    assertTrue(url(Visibility.TEAM, Visibility.TEAM).startsWith("/api/download/team/images/"));
  }
}
