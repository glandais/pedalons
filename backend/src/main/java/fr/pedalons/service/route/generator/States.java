package fr.pedalons.service.route.generator;

/**
 * Directed edge states: {@code state = 2·edge + dir}, dir 0 = u→v, 1 = v→u. The search runs on
 * states so that one-ways and the turn rule are enforced while relaxing, not after.
 */
final class States {
  private States() {}

  static int edge(int state) {
    return state >>> 1;
  }

  static int rev(int state) {
    return state ^ 1;
  }

  static int fwd(int edge) {
    return edge << 1;
  }

  static int bwd(int edge) {
    return (edge << 1) | 1;
  }
}
