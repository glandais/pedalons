package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import fr.pedalons.enums.GpsRouteSyncState;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.RouteRow;
import java.time.Instant;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;

/**
 * What one tracking row says of its route at the service ({@link GpsRouteSyncService#routeState},
 * docs/LEDGER_*.md API-121) — in particular with the sync off, which the Quarkus tests never run
 * (their profile turns it on), and for a manual upload once the route's GPX has changed.
 */
class GpsRouteSyncRouteStateTest {

  private static final Long ROUTE = 1L;
  private static final Long SENT_GPX = 10L;
  private static final Long NEW_GPX = 11L;
  private static final String NAME = "Boucle";
  private static final String SENT_HASH = GpsSyncNames.hash(SENT_GPX, NAME);

  private static RouteRow row(
      boolean automatic,
      @Nullable String externalId,
      @Nullable String desiredHash,
      @Nullable String syncedHash,
      int attempts,
      boolean reconnect) {
    return new RouteRow(
        ROUTE,
        GpsServiceType.HAMMERHEAD,
        automatic,
        externalId,
        desiredHash,
        NAME,
        syncedHash,
        syncedHash != null ? Instant.now() : null,
        attempts,
        reconnect);
  }

  @Test
  void manualUpload_ofTheCurrentGpx_isSent() {
    RouteRow manual = row(false, "ext", SENT_HASH, SENT_HASH, 0, false);

    assertEquals(GpsRouteSyncState.SENT, GpsRouteSyncService.routeState(manual, true, SENT_GPX));
  }

  @Test
  void manualUpload_thenGpxReplaced_isOutdated() {
    RouteRow manual = row(false, "ext", SENT_HASH, SENT_HASH, 0, false);

    assertEquals(GpsRouteSyncState.OUTDATED, GpsRouteSyncService.routeState(manual, true, NEW_GPX));
  }

  /**
   * docs/LEDGER_*.md API-128: a track edit replaces the file under the same asset row, so the
   * asset id is the same and only the content revision tells it from what was sent.
   */
  @Test
  void manualUpload_thenGpxReplacedInPlace_isOutdated() {
    RouteRow manual = row(false, "ext", SENT_HASH, SENT_HASH, 0, false);
    Long replacedInPlace = GpsSyncNames.contentKey(SENT_GPX, 99L);

    assertEquals(
        GpsRouteSyncState.OUTDATED, GpsRouteSyncService.routeState(manual, true, replacedInPlace));
  }

  @Test
  void automaticRow_syncOff_thenGpxReplacedInPlace_isOutdated() {
    RouteRow automatic = row(true, "ext", SENT_HASH, SENT_HASH, 0, false);

    assertEquals(
        GpsRouteSyncState.OUTDATED,
        GpsRouteSyncService.routeState(automatic, false, GpsSyncNames.contentKey(SENT_GPX, 99L)));
    // Never replaced (revision null): the key is the asset id and the row stays SENT.
    assertEquals(
        GpsRouteSyncState.SENT,
        GpsRouteSyncService.routeState(automatic, false, GpsSyncNames.contentKey(SENT_GPX, null)));
  }

  @Test
  void manualUpload_ofARouteWithoutGpxAnyMore_standsAsSent() {
    RouteRow manual = row(false, "ext", SENT_HASH, SENT_HASH, 0, false);

    assertEquals(GpsRouteSyncState.SENT, GpsRouteSyncService.routeState(manual, true, null));
  }

  @Test
  void automaticRow_syncOn_followsThePlannersHash() {
    String desired = GpsSyncNames.hash(NEW_GPX, NAME);

    assertEquals(
        GpsRouteSyncState.PENDING,
        GpsRouteSyncService.routeState(row(true, "ext", desired, SENT_HASH, 0, false), true, null));
    assertEquals(
        GpsRouteSyncState.FAILING,
        GpsRouteSyncService.routeState(row(true, "ext", desired, SENT_HASH, 8, false), true, null));
    assertEquals(
        GpsRouteSyncState.SENT,
        GpsRouteSyncService.routeState(row(true, "ext", desired, desired, 0, false), true, null));
  }

  @Test
  void automaticRow_syncOff_promisesNoUpdate() {
    String desired = GpsSyncNames.hash(NEW_GPX, NAME);

    // Never sent: nothing at the service, and nothing will send it.
    assertNull(
        GpsRouteSyncService.routeState(row(true, null, desired, null, 0, false), false, NEW_GPX));
    // Sent, then the GPX changed: an older version stays there — neither pending nor failing.
    assertEquals(
        GpsRouteSyncState.OUTDATED,
        GpsRouteSyncService.routeState(
            row(true, "ext", desired, SENT_HASH, 3, false), false, NEW_GPX));
    // Sent and still current.
    assertEquals(
        GpsRouteSyncState.SENT,
        GpsRouteSyncService.routeState(
            row(true, "ext", SENT_HASH, SENT_HASH, 0, false), false, SENT_GPX));
  }

  @Test
  void reconnectRequired_winsWhateverTheRow() {
    assertEquals(
        GpsRouteSyncState.RECONNECT_REQUIRED,
        GpsRouteSyncService.routeState(
            row(false, "ext", SENT_HASH, SENT_HASH, 0, true), false, NEW_GPX));
  }
}
