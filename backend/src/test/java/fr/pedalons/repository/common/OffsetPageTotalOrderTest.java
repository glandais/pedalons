package fr.pedalons.repository.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AdSortBy;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.InvitationStatus;
import fr.pedalons.enums.RouteSortBy;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.repository.ad.AdQuery;
import fr.pedalons.repository.ad.AdRepository;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ridetemplate.RideTemplateRepository;
import fr.pedalons.repository.route.RouteQuery;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.repository.team.TeamInvitationRepository;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;
import java.util.function.IntFunction;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Every offset-paginated list ends its sort key with the id, in the same direction: rows tied on
 * the key (rides imported together share a date, two routes the same distance) come back in one
 * fixed order on every page, so paging one row at a time neither repeats nor skips one.
 *
 * <p>Each test builds rows tied on the key and reads them one page of one row at a time. Without
 * the id at the end of the key, PostgreSQL is free to return the tied rows in any order on each
 * page (a top-N sort is not stable), and it typically returns them in heap order. The rows are
 * inserted in id order, so a descending key is checked as is; for an ascending key the first row
 * is rewritten first ({@link #moveToHeapEnd}), which puts its tuple last in the heap and the heap
 * order against the expected one.
 */
@QuarkusTest
class OffsetPageTotalOrderTest extends AbstractBaseTest {

  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject EntityManager em;
  @Inject AllPublicationRepository publicationRepository;
  @Inject RouteRepository routeRepository;
  @Inject AdRepository adRepository;
  @Inject RideTemplateRepository templateRepository;
  @Inject PlaceRepository placeRepository;
  @Inject TeamInvitationRepository invitationRepository;
  @Inject GpxPreviewRepository previewRepository;

  private Domain domain;
  private User user;
  private Team team;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    user = dataService.createUser("tri@example.com", "Tri User");
    team = dataService.createTeam(user, "Tri Team", "tri-team", Visibility.PUBLIC);
  }

  /** The feed, the agenda and the team lists: {@code dateTime desc}, then the id descending. */
  @Test
  void publications_tiedOnDate_defaultDescending_isTotalAcrossPages() {
    Instant at = Instant.now().plus(3, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      ids.add(dataService.createRide(team, user, "Sortie " + i, "sortie-" + i, at).getId());
    }

    List<Long> paged =
        pageThrough(
            ids.size(),
            page ->
                ids(
                    publicationRepository
                        .find(
                            PublicationQuery.builder()
                                .domainId(domain.getId())
                                .page(page)
                                .size(1)
                                .build())
                        .items()));

    assertEquals(descending(ids), paged);
  }

  /** « Mes prochaines sorties » and the other ascending listings: the id ascending too. */
  @Test
  void publications_tiedOnDate_ascending_isTotalAcrossPages() {
    Instant at = Instant.now().plus(3, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      ids.add(dataService.createRide(team, user, "Sortie " + i, "sortie-" + i, at).getId());
    }
    moveToHeapEnd("team_entities", ids.getFirst());

    List<Long> paged =
        pageThrough(
            ids.size(),
            page ->
                ids(
                    publicationRepository
                        .find(
                            PublicationQuery.builder()
                                .domainId(domain.getId())
                                .ascending(true)
                                .page(page)
                                .size(1)
                                .build())
                        .items()));

    assertEquals(ascending(ids), paged);
  }

  @Test
  void routes_tiedOnDistance_isTotalAcrossPagesInBothDirections() {
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      ids.add(route("Parcours " + i).getId());
    }

    assertEquals(descending(ids), routePages(ids.size(), SortDirection.DESC));
    moveToHeapEnd("team_entities", ids.getFirst());
    assertEquals(ascending(ids), routePages(ids.size(), SortDirection.ASC));
  }

  @Test
  void ads_tiedOnPrice_isTotalAcrossPagesInBothDirections() {
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      Ad ad = dataService.createAd(team, user, "Annonce " + i, AdType.SALE);
      dataService.setAdDetails(ad, new BigDecimal("100"), null, null, null);
      ids.add(ad.getId());
    }

    assertEquals(descending(ids), adPages(ids.size(), SortDirection.DESC));
    moveToHeapEnd("team_entities", ids.getFirst());
    assertEquals(ascending(ids), adPages(ids.size(), SortDirection.ASC));
  }

  @Test
  void rideTemplates_tiedOnName_isTotalAcrossPages() {
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      ids.add(dataService.createRideTemplate(team, user, "Modèle", "modele-" + i).getId());
    }
    moveToHeapEnd("ride_templates", ids.getFirst());

    List<Long> paged =
        pageThrough(
            ids.size(),
            page -> ids(templateRepository.findByTeam(team.getId(), null, page, 1).items()));

    assertEquals(ascending(ids), paged);
  }

  /** Places had no ORDER BY at all; they now read in name order, then id. */
  @Test
  void places_tiedOnName_isTotalAcrossPages() {
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      ids.add(dataService.createPlace(team, user, "Gare").getId());
    }
    Long first = dataService.createPlace(team, user, "Abbaye").getId();
    moveToHeapEnd("places", ids.getFirst());

    List<Long> paged =
        pageThrough(
            ids.size() + 1,
            page ->
                ids(placeRepository.findByTeam(team.getId(), page, 1, null, false, false).items()));

    List<Long> expected = new ArrayList<>(List.of(first));
    expected.addAll(ascending(ids));
    assertEquals(expected, paged);
  }

  @Test
  void invitations_tiedOnCreation_isTotalAcrossPages() {
    for (int i = 0; i < 4; i++) {
      dataService.createPendingInvitation(team, user, "invite" + i + "@example.com");
    }
    sameCreatedAt("team_invitations");

    List<Long> all =
        ids(invitationRepository.findByTeam(team.getId(), 0, 50, InvitationStatus.PENDING).items());
    assertEquals(4, all.size());

    List<Long> paged =
        pageThrough(
            all.size(),
            page ->
                ids(
                    invitationRepository
                        .findByTeam(team.getId(), page, 1, InvitationStatus.PENDING)
                        .items()));

    assertEquals(descending(all), paged);
  }

  @Test
  void gpxPreviews_tiedOnCreation_isTotalAcrossPages() {
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      ids.add(dataService.createGpxPreview(domain, user, UUID.randomUUID()).getId());
    }
    sameCreatedAt("gpx_previews");
    Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);

    List<Long> paged =
        pageThrough(
            ids.size(),
            page ->
                previewRepository
                    .findByCreator(domain.getId(), user.getId(), cutoff, page, 1)
                    .items()
                    .stream()
                    .map(p -> p.getId())
                    .toList());

    assertEquals(descending(ids), paged);
  }

  // ------------------------------------------------------------------ helpers

  private Route route(String name) {
    return dataService.createRouteWithProperties(
        team,
        user,
        name,
        Visibility.PUBLIC,
        50000,
        500,
        SurfaceType.ROAD,
        WindDirection.NORTH,
        45.0,
        6.0,
        45.5,
        6.5);
  }

  private List<Long> routePages(int count, SortDirection dir) {
    return pageThrough(
        count,
        page ->
            ids(
                routeRepository
                    .find(
                        RouteQuery.builder()
                            .domainId(domain.getId())
                            .sortBy(RouteSortBy.DISTANCE)
                            .sortDir(dir)
                            .page(page)
                            .size(1)
                            .build())
                    .items()));
  }

  private List<Long> adPages(int count, SortDirection dir) {
    return pageThrough(
        count,
        page ->
            ids(
                adRepository
                    .find(
                        AdQuery.builder()
                            .domainId(domain.getId())
                            .userId(user.getId())
                            .sortBy(AdSortBy.PRICE)
                            .sortDir(dir)
                            .page(page)
                            .size(1)
                            .build())
                    .items()));
  }

  /** Reads pages of one row, {@code count} of them, and checks that no row came twice. */
  private static List<Long> pageThrough(int count, IntFunction<List<Long>> page) {
    List<Long> paged = new ArrayList<>();
    for (int i = 0; i < count; i++) {
      List<Long> rows = page.apply(i);
      assertEquals(1, rows.size(), "page " + i);
      paged.addAll(rows);
    }
    assertEquals(count, new HashSet<>(paged).size(), "a row came back twice: " + paged);
    assertTrue(page.apply(count).isEmpty(), "a row was skipped");
    return paged;
  }

  private static List<Long> ids(List<? extends BaseEntity> rows) {
    return rows.stream().map(BaseEntity::getId).toList();
  }

  private static List<Long> ascending(List<Long> ids) {
    return ids.stream().sorted().toList();
  }

  private static List<Long> descending(List<Long> ids) {
    return ids.stream().sorted(Comparator.reverseOrder()).toList();
  }

  /**
   * Rewrites one row unchanged. PostgreSQL writes a new tuple for it, after the others, so a scan
   * without an id tie-break no longer meets the rows in id order.
   */
  private void moveToHeapEnd(String table, Long id) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery("update " + table + " set id = id where id = :id")
                .setParameter("id", id)
                .executeUpdate());
  }

  /** Every row of the table created at the same instant — what a bulk import leaves behind. */
  private void sameCreatedAt(String table) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery("update " + table + " set created_at = :at")
                .setParameter("at", Instant.now().minus(1, ChronoUnit.HOURS))
                .executeUpdate());
  }
}
