package fr.pedalons;

import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.util.MinioTestResource;
import fr.pedalons.util.TileserverTestResource;
import io.quarkus.test.common.TestResourceScope;
import io.quarkus.test.common.WithTestResource;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;

// GLOBAL scope: with the default MATCHING_RESOURCES, Quarkus restarts (app + containers,
// ~15s) between classes with different resource sets — Surefire's dynamic fork dispatch
// interleaves them constantly. GLOBAL starts the resources once per JVM, no restarts.
@WithTestResource(value = MinioTestResource.class, scope = TestResourceScope.GLOBAL)
@WithTestResource(value = TileserverTestResource.class, scope = TestResourceScope.GLOBAL)
public abstract class AbstractBaseTest {

  /**
   * The fake's switches and recorded requests are static, and every pipeline run records its
   * requests: cleared ahead of each subclass's own setUp, and again afterwards for the
   * {@code @QuarkusTest} classes that do not extend this one, so that none leaks from one test to
   * the next (docs/LEDGER_*.md API-150).
   */
  @BeforeEach
  public void resetRouteDetailsFake() {
    FakeRouteDetailsClient.reset();
  }

  @AfterEach
  public void clearRouteDetailsFake() {
    FakeRouteDetailsClient.reset();
  }
}
