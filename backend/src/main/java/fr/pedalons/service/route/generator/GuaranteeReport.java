package fr.pedalons.service.route.generator;

import java.util.EnumSet;

/**
 * Outcome of {@link RouteGuarantees#check}.
 *
 * @param sharedM total length of the edges ridden twice, each counted once
 * @param crossings revisited junctions in the core of the route, closing a loop excluded
 */
public record GuaranteeReport(
    EnumSet<Violation> violations, double lengthM, double sharedM, int crossings) {
  public boolean ok() {
    return violations.isEmpty();
  }
}
