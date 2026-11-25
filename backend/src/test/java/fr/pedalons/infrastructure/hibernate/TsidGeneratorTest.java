package fr.pedalons.infrastructure.hibernate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.hypersistence.tsid.TSID;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.hibernate.generator.EventType;
import org.hibernate.generator.EventTypeSets;
import org.junit.jupiter.api.Test;

class TsidGeneratorTest {

  private final TsidGenerator generator = new TsidGenerator();

  private long next() {
    Object id = generator.generate(null, null, null, EventType.INSERT);
    return assertInstanceOf(Long.class, id);
  }

  @Test
  void idsAreStrictlyIncreasingInOneThread() {
    long previous = next();
    for (int i = 0; i < 10_000; i++) {
      long current = next();
      assertTrue(current > previous);
      previous = current;
    }
  }

  @Test
  void idsFromSeveralThreadsAreDistinctAndShareOneNode() throws Exception {
    int threads = 4;
    int perThread = 50_000;
    ExecutorService pool = Executors.newFixedThreadPool(threads);
    try {
      List<Future<long[]>> futures = new ArrayList<>();
      for (int t = 0; t < threads; t++) {
        Callable<long[]> task =
            () -> {
              long[] ids = new long[perThread];
              for (int i = 0; i < perThread; i++) {
                ids[i] = next();
              }
              return ids;
            };
        futures.add(pool.submit(task));
      }
      Set<Long> all = new HashSet<>();
      Set<Long> nodes = new HashSet<>();
      for (Future<long[]> future : futures) {
        for (long id : future.get()) {
          assertTrue(all.add(id), "duplicate id " + id);
          nodes.add((id >>> 12) & 0x3FF);
        }
      }
      assertEquals(threads * perThread, all.size());
      assertEquals(1, nodes.size(), "one factory per JVM means one node");
    } finally {
      pool.shutdownNow();
    }
  }

  @Test
  void idEncodesTheCurrentTime() {
    Instant instant = TSID.from(next()).getInstant();
    assertTrue(Duration.between(instant, Instant.now()).abs().getSeconds() < 2);
  }

  @Test
  void generatesOnInsertOnly() {
    assertEquals(EventTypeSets.INSERT_ONLY, generator.getEventTypes());
  }
}
