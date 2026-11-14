package fr.pedalons.service.route.generator;

import java.util.Arrays;

/**
 * Bridges and 2-edge-connected components of an undirected multigraph, iterative (a recursive
 * version overflows the stack on long chains).
 *
 * <p>Why the generator needs them: without reuse in the middle of a route a bridge can only be
 * crossed once, so the middle of a loop stays inside one component; bridges only matter for the
 * tail from S or E up to its component (design §4.1).
 */
final class BridgeFinder {
  private BridgeFinder() {}

  /**
   * @param bridge per edge
   * @param component per node, ids in discovery order
   * @param componentLength per component: sum of the non-bridge edge lengths; 0 means trivial (a
   *     node on a tree part)
   */
  record Result(boolean[] bridge, int[] component, int componentCount, double[] componentLength) {}

  static Result find(int nodeCount, int[] edgeU, int[] edgeV, double[] edgeLength) {
    int edgeCount = edgeU.length;
    // CSR of (edge) incidences, self-loops skipped.
    int[] off = new int[nodeCount + 1];
    for (int e = 0; e < edgeCount; e++) {
      if (edgeU[e] != edgeV[e]) {
        off[edgeU[e] + 1]++;
        off[edgeV[e] + 1]++;
      }
    }
    for (int i = 0; i < nodeCount; i++) {
      off[i + 1] += off[i];
    }
    int[] fill = Arrays.copyOf(off, nodeCount);
    int[] inc = new int[off[nodeCount]];
    for (int e = 0; e < edgeCount; e++) {
      if (edgeU[e] != edgeV[e]) {
        inc[fill[edgeU[e]]++] = e;
        inc[fill[edgeV[e]]++] = e;
      }
    }

    int[] tin = new int[nodeCount];
    int[] low = new int[nodeCount];
    Arrays.fill(tin, -1);
    boolean[] bridge = new boolean[edgeCount];
    int[] stackNode = new int[nodeCount];
    int[] stackParentEdge = new int[nodeCount];
    int[] stackNext = new int[nodeCount];
    int timer = 0;
    for (int root = 0; root < nodeCount; root++) {
      if (tin[root] != -1) {
        continue;
      }
      int sp = 0;
      stackNode[0] = root;
      stackParentEdge[0] = -1;
      stackNext[0] = off[root];
      tin[root] = low[root] = timer++;
      sp = 1;
      while (sp > 0) {
        int top = sp - 1;
        int node = stackNode[top];
        if (stackNext[top] < off[node + 1]) {
          int e = inc[stackNext[top]++];
          if (e == stackParentEdge[top]) {
            continue;
          }
          int w = edgeU[e] == node ? edgeV[e] : edgeU[e];
          if (tin[w] == -1) {
            tin[w] = low[w] = timer++;
            stackNode[sp] = w;
            stackParentEdge[sp] = e;
            stackNext[sp] = off[w];
            sp++;
          } else {
            low[node] = Math.min(low[node], tin[w]);
          }
        } else {
          sp--;
          int pe = stackParentEdge[top];
          if (pe != -1) {
            int p = edgeU[pe] == node ? edgeV[pe] : edgeU[pe];
            low[p] = Math.min(low[p], low[node]);
            if (low[node] > tin[p]) {
              bridge[pe] = true;
            }
          }
        }
      }
    }

    int[] component = new int[nodeCount];
    Arrays.fill(component, -1);
    int count = 0;
    int[] queue = new int[nodeCount];
    for (int start = 0; start < nodeCount; start++) {
      if (component[start] != -1) {
        continue;
      }
      int head = 0;
      int tail = 0;
      queue[tail++] = start;
      component[start] = count;
      while (head < tail) {
        int node = queue[head++];
        for (int i = off[node]; i < off[node + 1]; i++) {
          int e = inc[i];
          if (bridge[e]) {
            continue;
          }
          int w = edgeU[e] == node ? edgeV[e] : edgeU[e];
          if (component[w] == -1) {
            component[w] = count;
            queue[tail++] = w;
          }
        }
      }
      count++;
    }
    double[] compLen = new double[count];
    for (int e = 0; e < edgeCount; e++) {
      if (!bridge[e] && edgeU[e] != edgeV[e]) {
        compLen[component[edgeU[e]]] += edgeLength[e];
      }
    }
    return new Result(bridge, component, count, compLen);
  }
}
