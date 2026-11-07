package fr.pedalons.service.gpx;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.GpxPreview.PreviewTrack;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.gpx.request.PreviewDepartureEdit;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@link PreviewDepartures}: the zone of the start of a track, the wall time read in it, and what a
 * save leaves of the date and of the speed (docs/LEDGER_*.md API-149). The resolver is mocked: its
 * own answers are tested elsewhere.
 */
class PreviewDeparturesTest {

  private static final ZoneId PARIS = ZoneId.of("Europe/Paris");
  private static final ZoneId TOKYO = ZoneId.of("Asia/Tokyo");

  private EventTimezoneResolver resolver;
  private PreviewDepartures departures;

  @BeforeEach
  void setUp() {
    resolver = mock(EventTimezoneResolver.class);
    departures = new PreviewDepartures();
    departures.timezoneResolver = resolver;
    departures.repository = mock(GpxPreviewRepository.class);
    when(resolver.locate(anyDouble(), anyDouble())).thenReturn(Optional.of(PARIS));
  }

  private static List<PreviewTrack> track(double lat, double lng) {
    return List.of(
        new PreviewTrack("t", List.of(new TrackPoint(lat, lng, 0, 0)), List.of(), 0f, 0f, 0f));
  }

  private static GpxPreview preview(List<PreviewTrack> tracks) {
    Domain domain = new Domain();
    domain.setId(1L);
    User user = new User();
    user.setId(2L);
    return new GpxPreview(UUID.randomUUID(), domain, user, "p", 1f, 0f, 0f, 0f, tracks, List.of());
  }

  private static EventDateTime at(String text) {
    return EventDateTime.local(LocalDateTime.parse(text));
  }

  private static PreviewDepartureEdit date(String text) {
    return PreviewDepartureEdit.of(at(text), null);
  }

  @Test
  void zone_isTheOneOfTheFirstPointOfTheFirstNonEmptyTrack() {
    when(resolver.locate(35.0, 139.0)).thenReturn(Optional.of(TOKYO));
    List<PreviewTrack> tracks =
        List.of(
            new PreviewTrack("empty", List.of(), List.of(), 0f, 0f, 0f),
            track(35.0, 139.0).getFirst());

    assertEquals(TOKYO, departures.zone(tracks));
  }

  @Test
  void zone_keepsTheNauticalZoneOfAPointAtSea() {
    when(resolver.locate(anyDouble(), anyDouble())).thenReturn(Optional.of(ZoneId.of("Etc/GMT+3")));

    assertEquals(ZoneId.of("Etc/GMT+3"), departures.zone(track(0, -40)));
  }

  @Test
  void zone_outsideEveryZoneOrWithoutPoints_isParis() {
    when(resolver.locate(anyDouble(), anyDouble())).thenReturn(Optional.empty());

    assertEquals(PARIS, departures.zone(track(95, 0)));
    assertEquals(PARIS, departures.zone(List.of()));
  }

  @Test
  void apply_aWallTimeIsReadInTheZoneOfTheStart() {
    GpxPreview preview = preview(track(45.76, 4.83));

    departures.apply(preview, date("2026-11-10T08:30:00"));

    assertEquals(Instant.parse("2026-11-10T07:30:00Z"), preview.getDepartureAt());
    assertEquals("Europe/Paris", preview.getDepartureZone());
  }

  @Test
  void apply_aTimeInTheSpringGap_isShiftedByTheGap() {
    GpxPreview preview = preview(track(45.76, 4.83));

    departures.apply(preview, date("2027-03-28T02:30:00"));

    // 02:30 does not exist in Paris that day: 03:30 CEST, which is 01:30Z
    assertEquals(Instant.parse("2027-03-28T01:30:00Z"), preview.getDepartureAt());
  }

  @Test
  void apply_aTimeInTheAutumnOverlap_isTheEarlierOffset() {
    GpxPreview preview = preview(track(45.76, 4.83));

    departures.apply(preview, date("2026-10-25T02:30:00"));

    assertEquals(Instant.parse("2026-10-25T00:30:00Z"), preview.getDepartureAt());
  }

  @Test
  void apply_whenTheTrackMovesToAnotherZone_theLocalTimeStaysAndTheInstantFollows() {
    GpxPreview preview = preview(track(45.76, 4.83));
    departures.apply(preview, date("2026-11-10T08:00:00"));
    preview.setTracks(track(35.68, 139.69));
    when(resolver.locate(35.68, 139.69)).thenReturn(Optional.of(TOKYO));

    departures.apply(preview, PreviewDepartureEdit.KEEP);

    assertEquals("Asia/Tokyo", preview.getDepartureZone());
    assertEquals(Instant.parse("2026-11-09T23:00:00Z"), preview.getDepartureAt());
  }

  @Test
  void apply_inTheSameZone_changesNothing() {
    GpxPreview preview = preview(track(45.76, 4.83));
    departures.apply(preview, date("2026-11-10T08:00:00"));
    Instant before = preview.getDepartureAt();
    preview.setTracks(track(48.85, 2.35));

    departures.apply(preview, PreviewDepartureEdit.KEEP);

    assertEquals(before, preview.getDepartureAt());
    assertEquals("Europe/Paris", preview.getDepartureZone());
  }

  @Test
  void apply_withoutADate_leavesTheRowUndated() {
    GpxPreview preview = preview(track(45.76, 4.83));

    departures.apply(preview, PreviewDepartureEdit.KEEP);

    assertNull(preview.getDepartureAt());
    assertNull(preview.getDepartureZone());
  }

  @Test
  void apply_clearDeparture_removesTheDateAndItsZone() {
    GpxPreview preview = preview(track(45.76, 4.83));
    departures.apply(preview, date("2026-11-10T08:00:00"));

    departures.apply(preview, new PreviewDepartureEdit(null, true, null, false));

    assertNull(preview.getDepartureAt());
    assertNull(preview.getDepartureZone());
  }

  @Test
  void apply_theSpeedIsSet_keptByKeep_clearedOnDemand_andIndependentOfTheDate() {
    GpxPreview preview = preview(track(45.76, 4.83));

    departures.apply(preview, PreviewDepartureEdit.of(null, 28.5f));
    assertEquals(28.5f, preview.getAverageSpeed());
    assertNull(preview.getDepartureAt(), "a speed alone does not date the preview");

    departures.apply(preview, PreviewDepartureEdit.KEEP);
    assertEquals(28.5f, preview.getAverageSpeed());

    departures.apply(preview, date("2026-11-10T08:00:00"));
    assertEquals(28.5f, preview.getAverageSpeed(), "a new date leaves the speed");

    departures.apply(preview, new PreviewDepartureEdit(null, true, null, false));
    assertEquals(28.5f, preview.getAverageSpeed(), "clearing the date leaves the speed");

    departures.apply(preview, new PreviewDepartureEdit(null, false, null, true));
    assertNull(preview.getAverageSpeed());
  }

  @Test
  void isContradictory_aValueAndItsRemoval() {
    assertTrue(
        new PreviewDepartureEdit(at("2026-11-10T08:00:00"), true, null, false).isContradictory());
    assertTrue(new PreviewDepartureEdit(null, false, 25f, true).isContradictory());
    assertFalse(new PreviewDepartureEdit(null, true, 25f, false).isContradictory());
    assertFalse(PreviewDepartureEdit.KEEP.isContradictory());
  }
}
