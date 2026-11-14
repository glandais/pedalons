package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.List;

/**
 * Turns the states of a chosen candidate into the route handed to the caller (design §5.9): the
 * geometry of the edges in travel order, sums of length, ascent and descent, and the metrics.
 */
final class RouteAssembler {
  private RouteAssembler() {}

  static GeneratedRoute assemble(QueryContext ctx, CandidateScorer.Scored scored) {
    QueryGraph g = ctx.g;
    int[] states = scored.candidate().states();
    List<LatLon> points = new ArrayList<>();
    List<RouteStep> steps = new ArrayList<>(states.length);
    double ascent = 0;
    double descent = 0;
    double unpaved = 0;
    double total = 0;
    for (int i = 0; i < states.length; i++) {
      int s = states[i];
      int edge = s >>> 1;
      List<LatLon> geometry = g.geometryLatLon(s);
      // the first point of every state after the first equals the previous last point
      points.addAll(i == 0 ? geometry : geometry.subList(1, geometry.size()));
      steps.add(new RouteStep(g.parentEdge(edge), (s & 1) == 0));
      ascent += g.gain(s);
      descent += g.loss(s);
      double len = g.length(edge);
      total += len;
      if (g.surface(edge) == NetworkGraph.UNPAVED) {
        unpaved += len;
      }
    }
    return new GeneratedRoute(
        points,
        total,
        ascent,
        descent,
        CandidateScorer.bearingDeviation(ctx, states),
        CandidateScorer.meanFamiliarity(g, states, ctx.zSource),
        total <= 0 ? 0 : unpaved / total,
        scored.report().sharedM(),
        scored.report().crossings(),
        steps);
  }
}
