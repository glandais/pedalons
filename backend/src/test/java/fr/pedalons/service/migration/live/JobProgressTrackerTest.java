package fr.pedalons.service.migration.live;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.time.Duration;
import java.time.Instant;
import java.util.function.BiConsumer;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * The heartbeat of a download: at most one write a minute, a job no longer ours stops the download,
 * and any other failure to write does not.
 */
class JobProgressTrackerTest {

  private final ObjectMapper mapper = new ObjectMapper();
  private Instant now = Instant.parse("2026-09-24T10:00:00Z");
  private int writes;
  private RuntimeException failWith;

  private JobProgressTracker tracker() {
    BiConsumer<JsonNode, JsonNode> sink =
        (progress, result) -> {
          if (failWith != null) {
            throw failWith;
          }
          writes++;
        };
    return new JobProgressTracker(sink, mapper::valueToTree, () -> now);
  }

  @Test
  void heartbeat_writesAtMostOnceAMinute() {
    JobProgressTracker tracker = tracker();
    tracker.flush();
    assertEquals(1, writes);

    for (int i = 0; i < 59; i++) {
      now = now.plusSeconds(1);
      tracker.heartbeat();
    }
    assertEquals(1, writes, "59 s of data: no write yet");

    now = now.plusSeconds(1);
    tracker.heartbeat();
    assertEquals(2, writes, "a minute after the last write");

    now = now.plusSeconds(30);
    tracker.heartbeat();
    assertEquals(2, writes);

    now = now.plus(JobProgressTracker.HEARTBEAT_EVERY);
    tracker.heartbeat();
    assertEquals(3, writes);
  }

  @Test
  void aWriteBeforeAnElement_countsAsTheHeartbeat() {
    JobProgressTracker tracker = tracker();
    tracker.flush();
    now = now.plusSeconds(50);
    tracker.beforeItem();
    assertEquals(2, writes);

    now = now.plusSeconds(50);
    tracker.heartbeat();
    assertEquals(2, writes, "50 s after the write before the element");
  }

  @Test
  void heartbeat_ofAJobNoLongerOurs_stopsTheDownload() {
    JobProgressTracker tracker = tracker();
    failWith = new BiketeamJobLostException("requeued");
    assertThrows(BiketeamJobLostException.class, tracker::heartbeat);
  }

  @Test
  void heartbeat_thatFailsOtherwise_isOnlyLogged_andNotRetriedAtEachRead() {
    JobProgressTracker tracker = tracker();
    failWith = new IllegalStateException("database away");
    assertDoesNotThrow(tracker::heartbeat);

    failWith = null;
    now = now.plusSeconds(10);
    tracker.heartbeat();
    assertEquals(0, writes, "the next try waits a minute too");
    now = now.plus(Duration.ofMinutes(1));
    tracker.heartbeat();
    assertEquals(1, writes);
  }
}
