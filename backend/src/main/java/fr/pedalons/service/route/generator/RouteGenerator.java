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
  /**
   * A loop needs at least this share of D in road it can ride out and back: its core alone, which
   * rides no edge twice, is half of D ({@link TailPlanner}).
   */
  private static final double ROUND_TRIP_MIN_SHARE = 0.5;

  private final GeneratorParameters parameters;

  public RouteGenerator(GeneratorParameters parameters) {
    this.parameters = parameters;
  }

  public RouteGenerator() {
    this(GeneratorParameters.defaults());
  }

  public GeneratorResult generate(NetworkGraph graph, GeneratorRequest request) {
    return generate(graph, request, () -> false);
  }

  /**
   * As {@link #generate(NetworkGraph, GeneratorRequest)}, with a stop signal polled once per turning
   * point, per polygon evaluation and per checked candidate: nothing else bounds the CPU time of a
   * request (lot 3, plan §3.6). A run that is not stopped is the same computation, so its result is
   * the same.
   *
   * @throws GeneratorStoppedException when {@code stop} returned true; no partial result
   */
  public GeneratorResult generate(
      NetworkGraph graph, GeneratorRequest request, java.util.function.BooleanSupplier stop) {
    GeneratorParameters p = parameters;
    if (p.maxTurnDeg() < graph.parameters().contractionMaxTurnDeg()) {
      // a contracted turn must always be legal (design §12.2)
      throw new IllegalArgumentException(
          "maxTurnDeg " + p.maxTurnDeg() + " < contractionMaxTurnDeg of the graph");
    }
    QueryGraph plain = QueryGraph.of(graph);
    java.util.function.IntPredicate admitted = e -> EdgeWeights.admitted(plain, e, request.type());
    // a piece of admitted road shorter than this is refused as too small whatever happens next
    java.util.function.IntPredicate leadingOn =
        EdgeWeights.leadingOn(
            plain, request.type(), p.networkTooSmallFactor() * request.distanceM());
    Snap snapStart = Snapper.snap(graph, request.start(), p.snapMaxM(), leadingOn, admitted);
    if (snapStart == null) {
      return failure(GeneratorFailure.START_TOO_FAR, null);
    }
    List<Snap> snaps = new ArrayList<>();
    snaps.add(snapStart);
    if (request.end() != null) {
      Snap snapEnd = Snapper.snap(graph, request.end(), p.snapMaxM(), leadingOn, admitted);
      if (snapEnd == null) {
        return failure(GeneratorFailure.END_TOO_FAR, null);
      }
      snaps.add(snapEnd);
    }
    QueryGraph qg = QueryGraph.create(graph, snaps, p.snapToNodeM());
    int start = qg.snapNode(0);
    int end = request.end() == null ? start : qg.snapNode(1);
    QueryContext ctx = new QueryContext(qg, p, request, start, end);
    ctx.stopWhen(stop);
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
    EdgeDijkstra.Tree reach = reach(ctx, false);
    double[] near = roadNear(ctx, reach);
    double roadNear = near[0];
    if (roadNear < p.networkTooSmallFactor() * d) {
      return failure(GeneratorFailure.NETWORK_TOO_SMALL, null);
    }
    // a loop comes back: the road it can ride is the one reached from the start from which the
    // start is reached too, one-ways and the ride type included. The components of the graph know
    // neither, so a start in a pocket left by a one-way would search for seconds to find nothing
    if (ctx.loop && roundTripM(ctx, reach) < ROUND_TRIP_MIN_SHARE * d) {
      return failure(GeneratorFailure.NO_ROUTE, "NO_WAY_BACK");
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
      ctx.checkStop();
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

  /**
   * The states within D of the start: reached from it, or, backward, from which it is reached.
   * Metres as weights, the bans of the ride type, one-ways and turns as the search rides them.
   */
  private static EdgeDijkstra.Tree reach(QueryContext ctx, boolean backward) {
    QueryGraph g = ctx.g;
    IntList sources;
    if (backward) {
      sources = new IntList();
      int n = g.outCount(ctx.start);
      for (int i = 0; i < n; i++) {
        int s = g.outState(ctx.start, i) ^ 1;
        if (g.allowed(s) && !ctx.banned.get(s >>> 1)) {
          sources.add(s);
        }
      }
    } else {
      sources = ctx.statesLeaving(ctx.start, ctx.banned);
    }
    EdgeDijkstra.Request f =
        ctx.forward(sources, null, ctx.lengths, ctx.banned, null, ctx.distanceM, -1, 0);
    EdgeDijkstra.Request r =
        new EdgeDijkstra.Request(
            backward,
            f.sourceStates(),
            f.sourceCosts(),
            f.sourceMetres(),
            null,
            ctx.lengths,
            ctx.banned,
            null,
            ctx.distanceM,
            -1,
            0);
    return java.util.Objects.requireNonNull(ctx.dijkstra.search(r).tree());
  }

  /**
   * Length of the road a loop can ride: the edges with a direction that is both reached from the
   * start and leads back to it. An upper bound of what any loop uses, tails included.
   */
  private static double roundTripM(QueryContext ctx, EdgeDijkstra.Tree out) {
    QueryGraph g = ctx.g;
    EdgeDijkstra.Tree back = reach(ctx, true);
    double total = 0;
    for (int e = 0; e < g.edgeCount(); e++) {
      if ((out.reached(2 * e) && back.reached(2 * e))
          || (out.reached(2 * e + 1) && back.reached(2 * e + 1))) {
        total += g.length(e);
      }
    }
    return total;
  }

  private static GeneratorResult failure(GeneratorFailure reason, @Nullable String detail) {
    return new GeneratorResult.Failure(reason, detail, GeneratorDiagnostics.empty());
  }

  /**
   * Length of the road, bridges and tails included, that the search can reach from the start and
   * whose middle lies within D/2 of the start or the end (design §5.2 step 6).
   */
  private static double[] roadNear(QueryContext ctx, EdgeDijkstra.Tree tree) {
    QueryGraph g = ctx.g;
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
