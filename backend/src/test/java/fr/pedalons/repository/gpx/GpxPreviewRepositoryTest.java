package fr.pedalons.repository.gpx;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class GpxPreviewRepositoryTest extends AbstractBaseTest {

  @Inject GpxPreviewRepository gpxPreviewRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  private Domain domain;
  private Domain otherDomain;
  private User user;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    otherDomain = dataService.createDomain("other.example.com", "Other", "http://other");
    user = dataService.createUser("owner@example.com", "Owner");
  }

  private GpxPreview persistPreview(Domain owningDomain, UUID publicId) {
    return dataService.createGpxPreview(owningDomain, user, publicId);
  }

  @Test
  void findByPublicId_shouldReturnPreviewOfTheGivenDomain() {
    UUID publicId = UUID.randomUUID();
    persistPreview(domain, publicId);

    assertTrue(gpxPreviewRepository.findByPublicId(domain.getId(), publicId).isPresent());
  }

  @Test
  void findByPublicId_shouldNotReturnPreviewOfAnotherDomain() {
    UUID publicId = UUID.randomUUID();
    persistPreview(otherDomain, publicId);

    assertTrue(gpxPreviewRepository.findByPublicId(domain.getId(), publicId).isEmpty());
  }

  @Test
  void findByPublicId_shouldReturnEmptyForUnknownId() {
    assertTrue(gpxPreviewRepository.findByPublicId(domain.getId(), UUID.randomUUID()).isEmpty());
  }

  @Test
  void findExpired_shouldOnlyReturnPreviewsCreatedBeforeTheCutoff() {
    GpxPreview fresh = persistPreview(domain, UUID.randomUUID());

    List<GpxPreview> expired =
        gpxPreviewRepository.findExpired(Instant.now().minus(1, ChronoUnit.DAYS));
    assertTrue(expired.isEmpty());

    dataService.backdateGpxPreview(fresh, 2);
    expired = gpxPreviewRepository.findExpired(Instant.now().minus(1, ChronoUnit.DAYS));
    assertEquals(1, expired.size());
    assertEquals(fresh.getId(), expired.getFirst().getId());
  }

  // ------------------------------------------------------------------ weather (API-153)

  private GpxPreview dated(Domain owner, Instant departure, Float speed) {
    return dataService.createGpxPreview(
        owner,
        user,
        UUID.randomUUID(),
        fr.pedalons.service.weather.WeatherTestFixtures.northbound(45.0, 4.0, 5, 100),
        4L,
        departure,
        "Europe/Paris",
        speed);
  }

  @Test
  void findForWeather_boundsAreIncluded_andTheSpeedIsRead() {
    Instant from = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    Instant to = from.plus(7, ChronoUnit.DAYS);
    GpxPreview atFrom = dated(domain, from, 30f);
    GpxPreview atTo = dated(domain, to, null);
    dated(domain, from.minusSeconds(1), null);
    dated(domain, to.plusSeconds(1), null);
    dated(domain, null, 20f);

    List<PreviewWeatherRow> rows = gpxPreviewRepository.findForWeather(from, to, 100);

    assertEquals(2, rows.size());
    PreviewWeatherRow first =
        rows.stream().filter(r -> r.id().equals(atFrom.getId())).findFirst().orElseThrow();
    assertEquals(30f, first.averageSpeed());
    assertEquals(4L, first.revision());
    assertTrue(rows.stream().anyMatch(r -> r.id().equals(atTo.getId())));
  }

  @Test
  void findForWeather_stopsAtTheLimit_soonestFirst() {
    Instant from = Instant.now();
    GpxPreview later = dated(domain, from.plusSeconds(300), null);
    GpxPreview sooner = dated(domain, from.plusSeconds(60), null);
    dated(domain, from.plusSeconds(600), null);

    List<PreviewWeatherRow> rows =
        gpxPreviewRepository.findForWeather(from, from.plus(1, ChronoUnit.DAYS), 2);

    assertEquals(
        List.of(sooner.getId(), later.getId()), rows.stream().map(PreviewWeatherRow::id).toList());
  }

  @Test
  void findForWeather_spansTheDomains_butNotADeletedOne() {
    Instant from = Instant.now();
    GpxPreview mine = dated(domain, from.plusSeconds(60), null);
    GpxPreview theirs = dated(otherDomain, from.plusSeconds(60), null);
    GpxPreview gone = dated(otherDomain, from.plusSeconds(60), null);
    dataService.deleteDomain(otherDomain);

    List<Long> ids =
        gpxPreviewRepository.findForWeather(from, from.plus(1, ChronoUnit.DAYS), 100).stream()
            .map(PreviewWeatherRow::id)
            .toList();

    assertTrue(ids.contains(mine.getId()));
    assertFalse(ids.contains(theirs.getId()));
    assertFalse(ids.contains(gone.getId()));
  }

  @Test
  void findForWeather_ofOnePreview_isEmptyOutsideTheWindow() {
    Instant now = Instant.now();
    GpxPreview inside = dated(domain, now.plus(1, ChronoUnit.DAYS), null);
    GpxPreview outside = dated(domain, now.plus(9, ChronoUnit.DAYS), null);
    Instant until = now.plus(7, ChronoUnit.DAYS);

    assertTrue(gpxPreviewRepository.findForWeather(inside.getId(), now, until).isPresent());
    assertTrue(gpxPreviewRepository.findForWeather(outside.getId(), now, until).isEmpty());
  }

  @Test
  void findWeatherRow_isScopedToTheDomain() {
    GpxPreview preview = dated(domain, Instant.now().plus(1, ChronoUnit.DAYS), 26f);

    assertEquals(
        26f,
        gpxPreviewRepository
            .findWeatherRow(domain.getId(), preview.getPublicId())
            .orElseThrow()
            .averageSpeed());
    assertTrue(
        gpxPreviewRepository.findWeatherRow(otherDomain.getId(), preview.getPublicId()).isEmpty());
  }

  @Test
  void findTracks_returnsTheRevisionAndTheTracksOfOneRow() {
    GpxPreview preview = dated(domain, null, null);

    GpxPreviewRepository.PreviewTracks tracks = gpxPreviewRepository.findTracks(preview.getId());

    assertNotNull(tracks);
    assertEquals(4L, tracks.revision());
    assertEquals(1, tracks.tracks().size());
    assertEquals(
        preview.getTracks().getFirst().trackPoints().size(),
        tracks.tracks().getFirst().trackPoints().size());
    assertNull(gpxPreviewRepository.findTracks(-1L));
  }
}
