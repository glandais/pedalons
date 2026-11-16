package fr.pedalons.service.route.network;

import fr.pedalons.infrastructure.routedetails.RouteDetailsGateway;
import fr.pedalons.infrastructure.routedetails.RouteDetailsOptions;
import fr.pedalons.infrastructure.routedetails.RouteDetailsProfile;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import fr.pedalons.infrastructure.routedetails.RouteDetailsSection;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The ascent and descent of the proposed routes (lot 3b plan §5): the engine has no elevation, so
 * one {@code fast} call of osm-route-details per route, all in parallel, within a budget for the
 * whole set. A call that fails, is paused ({@code FAST_PAUSE}) or is late leaves {@code null} for
 * that route alone: the editor computes the real profile when the route is opened. No quota, no
 * paid provider.
 */
@ApplicationScoped
public class GeneratedRouteAscent {

  private static final Logger LOG = Logger.getLogger(GeneratedRouteAscent.class);

  @ConfigProperty(name = "pedalons.route-generator.ascent-budget", defaultValue = "PT2.5S")
  Duration budget;

  @Inject RouteDetailsGateway routeDetails;
  @Inject RouteGeneratorMetrics metrics;

  /** Elevation gain and loss in metres. */
  public record Gain(double ascentM, double descentM) {}

  /**
   * One entry per polyline, in order; {@code null} where the gain could not be had in time.
   * Never throws.
   */
  public List<@Nullable Gain> compute(List<String> polylines) {
    List<@Nullable Gain> out = new ArrayList<>(polylines.size());
    if (polylines.isEmpty()) {
      return out;
    }
    long deadline = System.nanoTime() + budget.toNanos();
    try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
      List<Future<@Nullable Gain>> futures = new ArrayList<>(polylines.size());
      for (String polyline : polylines) {
        futures.add(executor.submit(() -> one(polyline)));
      }
      for (Future<@Nullable Gain> future : futures) {
        Gain gain = null;
        String outcome = "ok";
        try {
          gain = future.get(Math.max(0, deadline - System.nanoTime()), TimeUnit.NANOSECONDS);
          if (gain == null) {
            outcome = "failed";
          }
        } catch (TimeoutException e) {
          future.cancel(true);
          outcome = "late";
        } catch (ExecutionException e) {
          outcome = "failed";
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          future.cancel(true);
          outcome = "failed";
        }
        metrics.ascent(outcome);
        out.add(gain);
      }
    }
    return out;
  }

  private @Nullable Gain one(String polyline) {
    List<double[]> points = GeneratedRouteSanity.decode(polyline);
    if (points == null) {
      return null;
    }
    double[] lat = new double[points.size()];
    double[] lon = new double[points.size()];
    for (int i = 0; i < lat.length; i++) {
      lon[i] = points.get(i)[0];
      lat[i] = points.get(i)[1];
    }
    try {
      RouteDetailsOptions options =
          RouteDetailsOptions.of(RouteDetailsProfile.FAST, false)
              .withSections(List.of(RouteDetailsSection.SUMMARY));
      RouteDetailsResponse response = routeDetails.details(lat, lon, options);
      if (response.isPartial() || response.summary() == null) {
        return null;
      }
      return new Gain(response.summary().gainM(), response.summary().lossM());
    } catch (RuntimeException e) {
      LOG.debugf("Route generator ascent: fast profile failed: %s", e.getClass().getSimpleName());
      return null;
    }
  }
}
