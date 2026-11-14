package fr.pedalons.service.route.generator;

import java.util.List;
import org.jspecify.annotations.Nullable;

/** Outcome of {@link RouteGenerator#generate}. */
public sealed interface GeneratorResult {
  GeneratorDiagnostics diagnostics();

  /**
   * @param routes one to {@code maxResults} routes, best first, pairwise different
   * @param networkLengthM length of the road reachable around the start and the end
   * @param familiarityFallback the familiarity of all kinds replaced the one of the requested type
   *     (too few tracks of that type nearby, plan §5.5); admission never changes
   */
  record Success(
      List<GeneratedRoute> routes,
      double networkLengthM,
      boolean familiarityFallback,
      GeneratorDiagnostics diagnostics)
      implements GeneratorResult {}

  /**
   * @param detail machine-readable refinement such as {@code END_UNREACHABLE} or {@code
   *     TAIL_TOO_LONG}, or null
   */
  record Failure(GeneratorFailure reason, @Nullable String detail, GeneratorDiagnostics diagnostics)
      implements GeneratorResult {}
}
