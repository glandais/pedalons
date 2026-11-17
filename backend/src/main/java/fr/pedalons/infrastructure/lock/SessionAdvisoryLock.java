package fr.pedalons.infrastructure.lock;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Duration;
import javax.sql.DataSource;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * A PostgreSQL session advisory lock held on a connection of its own for the length of a job pass,
 * so that the two backends of a rolling deploy never run the same pass together (docs/LEDGER_*.md
 * API-210).
 *
 * <p>The connection does nothing while the pass works on others, and in production the backend
 * reaches postgres through a Swarm overlay network, whose IPVS load balancer forgets a TCP
 * connection idle for 900 s: the next statement then meets « An I/O error occurred while sending to
 * the backend », and the lock has silently gone with the session. A heartbeat therefore checks the
 * connection every {@link #DEFAULT_HEARTBEAT} — well under 900 s — which keeps it busy enough not to
 * be forgotten, and notices when it died anyway: {@link #held()} then turns false, for the pass to
 * stop at its next step rather than run on unguarded beside a second backend that may now hold the
 * lock.
 *
 * <p>{@link #close()} never throws: a pass that did its work is not a failed pass because its
 * unlock failed — the lock went with the connection.
 */
public final class SessionAdvisoryLock implements AutoCloseable {

  private static final Logger LOG = Logger.getLogger(SessionAdvisoryLock.class);

  /** Between two checks of the lock's connection: well under the 900 s of the Swarm IPVS. */
  public static final Duration DEFAULT_HEARTBEAT = Duration.ofMinutes(5);

  /** Seconds a heartbeat check may take before the connection counts as dead. */
  private static final int CHECK_TIMEOUT_SECONDS = 30;

  private final Connection connection;
  private final String key;
  private final String label;
  private final Thread heartbeat;
  private volatile boolean lost;
  private volatile boolean closing;

  private SessionAdvisoryLock(Connection connection, String key, String label, Duration every) {
    this.connection = connection;
    this.key = key;
    this.label = label;
    this.heartbeat =
        Thread.ofVirtual().name(label + "-lock-heartbeat").unstarted(() -> beat(every));
  }

  /**
   * Takes the lock without waiting.
   *
   * @param key the lock's name, hashed by postgres; a constant of the caller, never user input
   * @param label names the job in the logs
   * @return the lock, or null when another session holds it
   * @throws SQLException when no connection could be had or the lock could not be asked for
   */
  public static @Nullable SessionAdvisoryLock tryAcquire(
      DataSource dataSource, String key, String label) throws SQLException {
    return tryAcquire(dataSource, key, label, DEFAULT_HEARTBEAT);
  }

  /** {@link #tryAcquire(DataSource, String, String)} with another heartbeat, for the tests. */
  public static @Nullable SessionAdvisoryLock tryAcquire(
      DataSource dataSource, String key, String label, Duration heartbeat) throws SQLException {
    Connection connection = dataSource.getConnection();
    try {
      if (!call(connection, "pg_try_advisory_lock", key)) {
        connection.close();
        return null;
      }
    } catch (SQLException | RuntimeException e) {
      closeQuietly(connection);
      throw e;
    }
    SessionAdvisoryLock lock = new SessionAdvisoryLock(connection, key, label, heartbeat);
    lock.heartbeat.start();
    return lock;
  }

  /** False once the heartbeat found the connection dead: the lock may now be someone else's. */
  public boolean held() {
    return !lost;
  }

  /** Stops the heartbeat, releases the lock and gives the connection back; never throws. */
  @Override
  public void close() {
    closing = true;
    heartbeat.interrupt();
    try {
      heartbeat.join(Duration.ofSeconds(CHECK_TIMEOUT_SECONDS + 5L));
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
    boolean dead = lost;
    if (!dead) {
      try {
        call(connection, "pg_advisory_unlock", key);
      } catch (SQLException | RuntimeException e) {
        dead = true;
        LOG.warnf(
            "%s: the advisory lock could not be released (%s); it went with its connection",
            label, e.getMessage());
      }
    }
    if (dead) {
      abortQuietly(connection);
    } else {
      closeQuietly(connection);
    }
  }

  private void beat(Duration every) {
    while (!closing) {
      try {
        Thread.sleep(every);
      } catch (InterruptedException e) {
        return;
      }
      if (closing) {
        return;
      }
      boolean alive;
      try {
        alive = connection.isValid(CHECK_TIMEOUT_SECONDS);
      } catch (SQLException | RuntimeException e) {
        alive = false;
      }
      if (!alive) {
        if (!closing) {
          lost = true;
          LOG.warnf(
              "%s: the connection holding the advisory lock died; the pass stops at its next step",
              label);
        }
        return;
      }
    }
  }

  /** {@code function} is one of two constants of this class, never user input. */
  private static boolean call(Connection connection, String function, String key)
      throws SQLException {
    try (PreparedStatement statement =
        connection.prepareStatement("select " + function + "(hashtextextended(?, 0))")) {
      statement.setString(1, key);
      try (ResultSet rs = statement.executeQuery()) {
        return rs.next() && rs.getBoolean(1);
      }
    }
  }

  /** A dead connection is thrown away, never handed back to the pool for another caller. */
  private static void abortQuietly(Connection connection) {
    try {
      connection.abort(Runnable::run);
    } catch (SQLException | RuntimeException e) {
      closeQuietly(connection);
    }
  }

  private static void closeQuietly(Connection connection) {
    try {
      connection.close();
    } catch (SQLException | RuntimeException e) {
      LOG.debugf("Closing an advisory lock's connection failed: %s", e.getMessage());
    }
  }
}
