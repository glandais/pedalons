package fr.pedalons.service.asset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.Visibility;
import org.junit.jupiter.api.Test;

/**
 * The prefix of an image URL decides whether {@code ApiNoIndexFilter} lets it be indexed: only
 * {@code /api/download/public/images/} is spared. The public content of a private team is readable
 * by link only, never indexed (docs/LEDGER_*.md API-176, decision D1); so is the public content of
 * an unlisted team, which the sitemap leaves out too. Only entity PUBLIC and team PUBLIC get the
 * indexable prefix.
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
  void publicContentOfAnUnlistedTeam_getsTheUnlistedPrefix() {
    // Not in the sitemap either: the indexable prefix follows the same rule
    // (TeamEntityRepository.isIndexableVisibility).
    assertTrue(
        url(Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC)
            .startsWith("/api/download/public_unlisted/images/"));
  }

  @Test
  void publicContentOfAPublicTeam_keepsThePublicPrefix() {
    assertTrue(
        url(Visibility.PUBLIC, Visibility.PUBLIC).startsWith("/api/download/public/images/"));
  }

  @Test
  void theFileUrl_followsTheSameRule() {
    assertEquals("public", AssetService.urlPrefix(Visibility.PUBLIC, Visibility.PUBLIC));
    assertEquals(
        "public_unlisted", AssetService.urlPrefix(Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC));
    assertEquals("public_unlisted", AssetService.urlPrefix(Visibility.TEAM, Visibility.PUBLIC));
    assertEquals(
        "public_unlisted", AssetService.urlPrefix(Visibility.PUBLIC, Visibility.PUBLIC_UNLISTED));
    assertEquals("team", AssetService.urlPrefix(Visibility.PUBLIC, Visibility.TEAM));
  }

  @Test
  void otherVisibilities_keepTheirOwnPrefix() {
    assertTrue(
        url(Visibility.PUBLIC, Visibility.PUBLIC_UNLISTED)
            .startsWith("/api/download/public_unlisted/images/"));
    assertTrue(url(Visibility.PUBLIC, Visibility.TEAM).startsWith("/api/download/team/images/"));
    assertTrue(
        url(Visibility.TEAM, Visibility.PUBLIC_UNLISTED)
            .startsWith("/api/download/public_unlisted/images/"));
    assertTrue(url(Visibility.TEAM, Visibility.TEAM).startsWith("/api/download/team/images/"));
  }
}
