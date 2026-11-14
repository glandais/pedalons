package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * The best routes that are different from each other (design §5.8): exact duplicates collapse, then
 * candidates are taken best first while they share less than {@code diversityMaxShared} of the
 * shorter route with every route already chosen.
 */
final class CandidateSelector {
  private CandidateSelector() {}

  static List<CandidateScorer.Scored> top(QueryContext ctx, List<CandidateScorer.Scored> scored) {
    List<CandidateScorer.Scored> unique = new ArrayList<>();
    Set<Candidate> seen = new HashSet<>();
    for (CandidateScorer.Scored s : scored) {
      if (seen.add(s.candidate())) {
        unique.add(s);
      }
    }
    // stable sort: ties keep the generation order, which is deterministic
    unique.sort((a, b) -> Double.compare(a.score(), b.score()));
    List<CandidateScorer.Scored> chosen = new ArrayList<>();
    List<Set<Integer>> chosenEdges = new ArrayList<>();
    for (CandidateScorer.Scored c : unique) {
      if (chosen.size() >= ctx.p.maxResults()) {
        break;
      }
      Set<Integer> edges = edgeSet(c.candidate().states());
      boolean different = true;
      for (int i = 0; i < chosen.size() && different; i++) {
        double overlap = overlapM(ctx.g, edges, chosenEdges.get(i));
        double shorter = Math.min(c.report().lengthM(), chosen.get(i).report().lengthM());
        if (shorter > 0 && overlap / shorter >= ctx.p.diversityMaxShared()) {
          different = false;
        }
      }
      if (different) {
        chosen.add(c);
        chosenEdges.add(edges);
      }
    }
    return chosen;
  }

  private static Set<Integer> edgeSet(int[] states) {
    Set<Integer> edges = new HashSet<>();
    for (int s : states) {
      edges.add(s >>> 1);
    }
    return edges;
  }

  /** Length of the edges (undirected) present in both routes. */
  static double overlapM(QueryGraph g, Set<Integer> a, Set<Integer> b) {
    Set<Integer> small = a.size() <= b.size() ? a : b;
    Set<Integer> large = small == a ? b : a;
    double total = 0;
    for (int e : small) {
      if (large.contains(e)) {
        total += g.length(e);
      }
    }
    return total;
  }
}
