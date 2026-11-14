package fr.pedalons.service.route.edges;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.DistributionSummary;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.concurrent.atomic.AtomicLong;

/**
 * The metrics of the street edges (docs/LEDGER_*.md API-198, lot 1), the first business metrics of
 * the backend, so the list is kept short: documents written, failures, the size of a document and
 * what the backfill still has to do. Exposed on {@code /q/metrics}.
 */
@ApplicationScoped
public class NetworkEdgesMetrics {

  /** Where a document was computed. */
  public enum Source {
    CATCHUP,
    SAVE,
    BACKFILL;

    String tag() {
      return name().toLowerCase(java.util.Locale.ROOT);
    }
  }

  /** Why a track got no document. */
  public enum Failure {
    /** The answer carried no {@code edges} though the service announced them. */
    NO_EDGES,
    /** The answer could not be turned into a document. */
    STITCH,
    /** The edges-only call failed. */
    CALL,
    /** The service announced no edges: the backfill request was put off. */
    POSTPONED;

    String tag() {
      return name().toLowerCase(java.util.Locale.ROOT);
    }
  }

  @Inject MeterRegistry registry;

  private final AtomicLong remaining = new AtomicLong(0);
  private DistributionSummary bytes;

  @PostConstruct
  void register() {
    bytes =
        DistributionSummary.builder("pedalons.network_edges.document.bytes")
            .description("Size of each street edges document written")
            .baseUnit("bytes")
            .register(registry);
    registry.gauge("pedalons.network_edges.backfill.remaining", remaining);
  }

  /** A document is about to be written: counted, and its size observed. Never throws. */
  public void documentWritten(Source source, NetworkEdgesDocument document) {
    try {
      Counter.builder("pedalons.network_edges.documents")
          .tag("source", source.tag())
          .tag("status", document.status())
          .register(registry)
          .increment();
      bytes.record(JsonConfiguration.INSTANCE.getObjectMapperWrapper().toString(document).length());
    } catch (RuntimeException e) {
      // A metric never fails what it measures
    }
  }

  public void failed(Failure reason) {
    Counter.builder("pedalons.network_edges.failures")
        .tag("reason", reason.tag())
        .register(registry)
        .increment();
  }

  /** The routes the backfill still has to do, as each pass saw them. */
  public void remaining(long routes) {
    remaining.set(routes);
  }
}
