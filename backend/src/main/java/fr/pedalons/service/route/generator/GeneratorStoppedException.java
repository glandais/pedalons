package fr.pedalons.service.route.generator;

/**
 * Thrown by {@link RouteGenerator#generate(NetworkGraph, GeneratorRequest,
 * java.util.function.BooleanSupplier)} when its stop signal fired (the caller's time budget is
 * spent). A stopped run returns nothing: partial candidates would depend on the speed of the
 * machine and break "the same seed gives the same routes".
 */
public final class GeneratorStoppedException extends RuntimeException {
  public GeneratorStoppedException() {
    super("generator stopped", null, false, false);
  }
}
