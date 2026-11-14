package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Proposes routes made only of the roads a team already rides (plan
 * docs/plans/2026-11-13-generateur-boucles-equipe.md §5, ledger docs/LEDGER_*.md API-198).
 *
 * <p>Pipeline (design §5.2): snap the start and the end onto the network, check that the request
 * is feasible, plan the tails at both ends, search candidates with two families (out by one side
 * and back by the other, polygon with a blacklist), keep those that {@link RouteGuarantees}
 * accepts, score them and return the best ones that differ from each other.
 *
 * <p>No route is ever returned that {@link RouteGuarantees} did not accept: the checker is
 * independent of the search, so a disagreement is a bug of the search. Stateless and thread-safe:
 * everything mutable lives in a per-call {@link QueryContext}; the {@link NetworkGraph} is
 * immutable. The seed fully determines the output.
 */
public final class RouteGenerator {
  private final GeneratorParameters parameters;

  public RouteGenerator(GeneratorParameters parameters) {
    this.parameters = parameters;
  }

  public RouteGenerator() {
    this(GeneratorParameters.defaults());
  }

  public GeneratorResult generate(NetworkGraph graph, GeneratorRequest request) {
    GeneratorParameters p = parameters;
    if (p.maxTurnDeg() < graph.parameters().contractionMaxTurnDeg()) {
      // a contracted turn must always be legal (design §12.2)
      throw new IllegalArgumentException(
          "maxTurnDeg " + p.maxTurnDeg() + " < contractionMaxTurnDeg of the graph");
    }
    QueryGraph plain = QueryGraph.of(graph);
    java.util.function.IntPredicate admitted = e -> EdgeWeights.admitted(plain, e, request.type());
    Snap snapStart = Snapper.snap(graph, request.start(), p.snapMaxM(), admitted);
    if (snapStart == null) {
      return failure(GeneratorFailure.START_TOO_FAR, null);
    }
    List<Snap> snaps = new ArrayList<>();
    snaps.add(snapStart);
    if (request.end() != null) {
      Snap snapEnd = Snapper.snap(graph, request.end(), p.snapMaxM(), admitted);
      if (snapEnd == null) {
        return failure(GeneratorFailure.END_TOO_FAR, null);
      }
      snaps.add(snapEnd);
    }
    QueryGraph qg = QueryGraph.create(graph, snaps, p.snapToNodeM());
    int start = qg.snapNode(0);
    int end = request.end() == null ? start : qg.snapNode(1);
    QueryContext ctx = new QueryContext(qg, p, request, start, end);
    double d = request.distanceM();

    // feasibility
    if (!ctx.loop) {
      EdgeDijkstra.Result direct =
          ctx.dijkstra.search(
              ctx.forward(
                  ctx.statesLeaving(start, ctx.banned),
                  s -> qg.head(s) == end,
                  ctx.lengths,
                  ctx.banned,
                  null,
                  Double.POSITIVE_INFINITY,
                  end,
                  qg.base().aStarScale()));
      if (!direct.found()) {
        return failure(GeneratorFailure.NO_ROUTE, "END_UNREACHABLE");
      }
      if (d < p.distanceTooShortFactor() * direct.targetMetres()) {
        return failure(GeneratorFailure.DISTANCE_TOO_SHORT, null);
      }
    }
    double[] near = roadNear(ctx);
    double roadNear = near[0];
    if (roadNear < p.networkTooSmallFactor() * d) {
      return failure(GeneratorFailure.NETWORK_TOO_SMALL, null);
    }
    // too few tracks of the requested type nearby: the familiarity of all kinds replaces it
    if (primaryTracks(graph, request.type()) < p.familiarityMinTracks()
        || near[1] < p.familiarityMinNearShare() * d) {
      ctx.useFamiliarityFallback();
    }

    List<AnchorPair> pairs = TailPlanner.plan(ctx);
    if (pairs.isEmpty()) {
      boolean approach =
          !ctx.loop && (TailPlanner.trivial(ctx, start) || TailPlanner.trivial(ctx, end));
      return failure(GeneratorFailure.NO_ROUTE, approach ? "NO_APPROACH" : "TAIL_TOO_LONG");
    }

    // candidates, each family with a budget shared evenly between the anchor pairs
    List<Candidate> pool = new ArrayList<>();
    int loopBudget = Math.max(1, p.turningPoints() / pairs.size());
    int polygonBudget = Math.max(1, p.polygonEvaluations() / pairs.size());
    for (AnchorPair pair : pairs) {
      pool.addAll(LoopFamily.candidates(ctx, pair, loopBudget));
      pool.addAll(PolygonFamily.candidates(ctx, pair, polygonBudget));
    }

    // every candidate goes through the independent checker
    List<CandidateScorer.Scored> scored = new ArrayList<>();
    for (Candidate c : pool) {
      GuaranteeReport report = RouteGuarantees.check(qg, start, end, d, c.states(), p);
      if (!report.ok()) {
        ctx.reject(report.violations());
        continue;
      }
      if (c.family() == Candidate.Family.LOOP) {
        ctx.validLoop++;
      } else {
        ctx.validPolygon++;
      }
      scored.add(CandidateScorer.score(ctx, c, report));
    }
    List<CandidateScorer.Scored> selected = CandidateSelector.top(ctx, scored);
    if (selected.isEmpty()) {
      return new GeneratorResult.Failure(GeneratorFailure.NO_ROUTE, null, ctx.diagnostics());
    }
    List<GeneratedRoute> routes = new ArrayList<>(selected.size());
    for (CandidateScorer.Scored s : selected) {
      routes.add(RouteAssembler.assemble(ctx, s));
    }
    return new GeneratorResult.Success(
        routes, roadNear, ctx.familiarityFallback, ctx.diagnostics());
  }

  private static int primaryTracks(NetworkGraph g, RideType type) {
    var by = g.stats().liveTracksByKind();
    int road = by.getOrDefault(TrackKind.ROAD, 0);
    int gravel = by.getOrDefault(TrackKind.GRAVEL, 0);
    int mtb = by.getOrDefault(TrackKind.MTB, 0);
    int mixed = by.getOrDefault(TrackKind.MIXED, 0);
    return switch (type) {
      case ROAD -> road + mixed;
      case GRAVEL -> gravel + mixed;
      case MTB -> mtb;
    };
  }

  private static GeneratorResult failure(GeneratorFailure reason, @Nullable String detail) {
    return new GeneratorResult.Failure(reason, detail, GeneratorDiagnostics.empty());
  }

  /**
   * Length of the road, bridges and tails included, that the search can reach from the start and
   * whose middle lies within D/2 of the start or the end (design §5.2 step 6).
   */
  private static double[] roadNear(QueryContext ctx) {
    QueryGraph g = ctx.g;
    EdgeDijkstra.Result reach =
        ctx.dijkstra.search(
            ctx.forward(
                ctx.statesLeaving(ctx.start, ctx.banned),
                null,
                ctx.lengths,
                ctx.banned,
                null,
                ctx.distanceM,
                -1,
                0));
    EdgeDijkstra.Tree tree = reach.tree();
    double radius = ctx.distanceM / 2;
    double total = 0;
    double primary = 0;
    for (int e = 0; e < g.edgeCount(); e++) {
      if (!tree.reached(2 * e) && !tree.reached(2 * e + 1)) {
        continue;
      }
      double mx = (g.nodeX(g.edgeU(e)) + g.nodeX(g.edgeV(e))) / 2;
      double my = (g.nodeY(g.edgeU(e)) + g.nodeY(g.edgeV(e))) / 2;
      boolean near =
          Math.hypot(mx - g.nodeX(ctx.start), my - g.nodeY(ctx.start)) <= radius
              || Math.hypot(mx - g.nodeX(ctx.end), my - g.nodeY(ctx.end)) <= radius;
      if (near) {
        total += g.length(e);
        if (EdgeWeights.primary(g, e, ctx.type)) {
          primary += g.length(e);
        }
      }
    }
    return new double[] {total, primary};
  }
}
