package fr.pedalons.service.migration;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

import fr.pedalons.service.migration.live.BiketeamJobLostException;
import java.io.UncheckedIOException;
import org.junit.jupiter.api.Test;

/**
 * What an element's {@code catch} must not keep as that element's failure: a job lost mid-download
 * (the heartbeat found the row requeued) ends the attempt, however wrapped.
 */
class BiketeamItemFailureTest {

  @Test
  void aJobLostDuringTheElement_endsTheAttempt_evenWrapped() {
    BiketeamJobLostException lost = new BiketeamJobLostException("requeued");
    assertSame(
        lost,
        assertThrows(
            BiketeamJobLostException.class,
            () -> BiketeamMigrationService.rethrowIfExportFailure(lost)));
    assertSame(
        lost,
        assertThrows(
            BiketeamJobLostException.class,
            () ->
                BiketeamMigrationService.rethrowIfExportFailure(
                    new IllegalStateException("wrapped", lost))));
  }

  @Test
  void anyOtherFailure_isTheElementsOwn() {
    assertDoesNotThrow(() ->
        BiketeamMigrationService.rethrowIfExportFailure(
            new UncheckedIOException("gpx", new java.io.IOException("broken"))));
  }
}
