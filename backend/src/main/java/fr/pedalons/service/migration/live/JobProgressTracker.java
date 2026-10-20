package fr.pedalons.service.migration.live;

import fr.pedalons.dto.migration.internal.BiketeamJobCountDto;
import fr.pedalons.dto.migration.internal.BiketeamJobCountsDto;
import fr.pedalons.dto.migration.internal.BiketeamJobProgressDto;
import fr.pedalons.dto.migration.internal.BiketeamJobWarningDto;
import fr.pedalons.service.migration.BiketeamMigrationProgress;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.function.BiConsumer;
import java.util.function.Supplier;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;

/**
 * Turns what {@code BiketeamMigrationService} reports into the job row: phase and progress, counts,
 * up to {@value #MAX_WARNINGS} warnings, and the heartbeat that tells a live job from a crashed one.
 *
 * <p>Written in its own short transaction on every phase change and otherwise at most every {@link
 * #FLUSH_EVERY}, checked before each element. A download from the export can outlast that — up to
 * 120 s for the headers (the snapshot's: {@code export-snapshot-timeout}), then {@code
 * export-transfer-timeout} for the body — so the body's reads also call {@link #heartbeat()},
 * which writes at most every {@link #HEARTBEAT_EVERY}, outside any element's transaction. The
 * longest silence is thus one header wait, one idle read and one element transaction, which {@code
 * BiketeamLiveMigrationConfig} checks at startup to be under {@code stuck-after}.
 */
public class JobProgressTracker implements BiketeamMigrationProgress {

  static final int MAX_WARNINGS = 500;
  static final Duration FLUSH_EVERY = Duration.ofSeconds(5);

  /** How often a download in progress may write the heartbeat. */
  static final Duration HEARTBEAT_EVERY = Duration.ofMinutes(1);

  private static final Logger LOG = Logger.getLogger(JobProgressTracker.class);

  /** Persists {@code (progress, result)} — the job service, or a stub in tests. */
  private final BiConsumer<JsonNode, JsonNode> sink;

  private final java.util.function.Function<Object, JsonNode> toJson;

  private Phase phase = Phase.QUEUED;
  private int done;
  private int total;
  private final Map<Counter, int[]> counts = new EnumMap<>(Counter.class);
  private final List<BiketeamJobWarningDto> warnings = new ArrayList<>();
  private boolean warningsTruncated;
  private Instant lastFlush = Instant.EPOCH;
  private final Supplier<Instant> clock;

  public JobProgressTracker(
      BiConsumer<JsonNode, JsonNode> sink, java.util.function.Function<Object, JsonNode> toJson) {
    this(sink, toJson, Instant::now);
  }

  /** With the clock supplied — what the tests drive. */
  JobProgressTracker(
      BiConsumer<JsonNode, JsonNode> sink,
      java.util.function.Function<Object, JsonNode> toJson,
      Supplier<Instant> clock) {
    this.sink = sink;
    this.toJson = toJson;
    this.clock = clock;
    for (Counter c : Counter.values()) {
      counts.put(c, new int[3]);
    }
  }

  @Override
  public void phase(Phase phase, int total) {
    this.phase = phase;
    this.done = 0;
    this.total = total;
    flush();
  }

  @Override
  public void beforeItem() {
    if (Duration.between(lastFlush, clock.get()).compareTo(FLUSH_EVERY) >= 0) {
      flush();
    }
  }

  /**
   * Proof of life from a long download, called on the worker's thread by the body's reads: writes
   * the row when the last write is {@link #HEARTBEAT_EVERY} old, and otherwise does nothing.
   *
   * <p>A job this run no longer owns stops the download ({@link BiketeamJobLostException}); any
   * other failure to write is only logged — the download is not the place to fail the job, and the
   * next write will try again.
   */
  public void heartbeat() {
    if (Duration.between(lastFlush, clock.get()).compareTo(HEARTBEAT_EVERY) < 0) {
      return;
    }
    try {
      flush();
    } catch (BiketeamJobLostException e) {
      throw e;
    } catch (RuntimeException e) {
      lastFlush = clock.get();
      LOG.warnf("Biketeam migration heartbeat not written: %s", e.toString());
    }
  }

  @Override
  public void tick() {
    done++;
  }

  @Override
  public void count(Counter counter, Outcome outcome) {
    counts.get(counter)[outcome.ordinal()]++;
  }

  @Override
  public void warning(String entityType, String biketeamId, String code, String message) {
    if (warnings.size() >= MAX_WARNINGS) {
      warningsTruncated = true;
      return;
    }
    warnings.add(new BiketeamJobWarningDto(entityType, biketeamId, code, message));
  }

  /** Writes the current state to the row now. */
  public void flush() {
    sink.accept(progressJson(), resultJson(null));
    lastFlush = clock.get();
  }

  public JsonNode progressJson() {
    return toJson.apply(new BiketeamJobProgressDto(phase.name(), done, total));
  }

  /** The result document, with the URL table once there is one. */
  public JsonNode resultJson(@Nullable Map<String, Map<String, String>> urlMap) {
    return toJson.apply(
        new BiketeamJobResult(counts(), List.copyOf(warnings), warningsTruncated, urlMap));
  }

  public BiketeamJobCountsDto counts() {
    return new BiketeamJobCountsDto(
        count(Counter.TEAM_PAGES),
        count(Counter.PLACES),
        count(Counter.ROUTES),
        count(Counter.RIDE_TEMPLATES),
        count(Counter.PUBLICATIONS),
        count(Counter.RIDES),
        count(Counter.TRIPS),
        count(Counter.TRIP_STAGES),
        count(Counter.IMAGES));
  }

  public List<BiketeamJobWarningDto> warnings() {
    return List.copyOf(warnings);
  }

  private BiketeamJobCountDto count(Counter counter) {
    int[] c = counts.get(counter);
    int migrated = c[Outcome.MIGRATED.ordinal()];
    int skipped = c[Outcome.SKIPPED.ordinal()];
    int failed = c[Outcome.FAILED.ordinal()];
    return new BiketeamJobCountDto(migrated + skipped + failed, migrated, skipped, failed);
  }
}
