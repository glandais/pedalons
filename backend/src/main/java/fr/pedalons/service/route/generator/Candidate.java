package fr.pedalons.service.route.generator;

/**
 * A full route on the query graph, as directed states, tagged with the family that found it.
 *
 * <p>Equality is by content, so duplicates found by both families collapse.
 */
record Candidate(int[] states, Family family) {
  enum Family {
    LOOP,
    POLYGON
  }

  @Override
  public boolean equals(Object o) {
    return o instanceof Candidate c && java.util.Arrays.equals(states, c.states);
  }

  @Override
  public int hashCode() {
    return java.util.Arrays.hashCode(states);
  }
}
