package fr.pedalons.infrastructure.lock;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import io.agroal.api.AgroalDataSource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Duration;
import org.junit.jupiter.api.Test;

/**
 * The session advisory lock of the nightly jobs (docs/LEDGER_*.md API-210): one holder at a time,
 * released on close, and a connection that dies under it is noticed and never fails the close.
 */
@QuarkusTest
class SessionAdvisoryLockTest extends AbstractBaseTest {

  private static final String KEY = "session-advisory-lock-test";

  @Inject AgroalDataSource dataSource;

  @Test
  void oneHolderAtATime_releasedOnClose() throws Exception {
    try (SessionAdvisoryLock first = SessionAdvisoryLock.tryAcquire(dataSource, KEY, "test")) {
      assertNotNull(first);
      assertTrue(first.held());
      assertNull(SessionAdvisoryLock.tryAcquire(dataSource, KEY, "test"));
    }
    try (SessionAdvisoryLock again = SessionAdvisoryLock.tryAcquire(dataSource, KEY, "test")) {
      assertNotNull(again);
    }
  }

  @Test
  void theHeartbeatKeepsALiveConnection() throws Exception {
    try (SessionAdvisoryLock lock =
        SessionAdvisoryLock.tryAcquire(dataSource, KEY, "test", Duration.ofMillis(50))) {
      assertNotNull(lock);
      Thread.sleep(300);
      assertTrue(lock.held());
      assertNull(SessionAdvisoryLock.tryAcquire(dataSource, KEY, "test"));
    }
  }

  @Test
  void aDeadConnectionIsNoticed_andTheCloseDoesNotThrow() throws Exception {
    SessionAdvisoryLock lock =
        SessionAdvisoryLock.tryAcquire(dataSource, KEY, "test", Duration.ofMillis(50));
    assertNotNull(lock);
    assertEquals(1, terminateHolder());
    long deadline = System.nanoTime() + Duration.ofSeconds(10).toNanos();
    while (lock.held() && System.nanoTime() < deadline) {
      Thread.sleep(50);
    }
    assertFalse(lock.held());
    assertDoesNotThrow(lock::close);
    // The lock went with the session: someone else may take it.
    try (SessionAdvisoryLock next = SessionAdvisoryLock.tryAcquire(dataSource, KEY, "test")) {
      assertNotNull(next);
    }
  }

  /** Kills the backend holding {@link #KEY}, as the overlay network does to an idle connection. */
  private int terminateHolder() throws Exception {
    try (Connection other = dataSource.getConnection();
        PreparedStatement statement =
            other.prepareStatement(
                "select count(pg_terminate_backend(l.pid)) from pg_locks l"
                    + " where l.locktype = 'advisory' and l.granted"
                    + " and ((l.classid::bigint << 32) | l.objid::bigint)"
                    + " = hashtextextended(?, 0)");
        ResultSet rs = bind(statement).executeQuery()) {
      assertTrue(rs.next());
      return rs.getInt(1);
    }
  }

  private static PreparedStatement bind(PreparedStatement statement) throws Exception {
    statement.setString(1, KEY);
    return statement;
  }
}
