package fr.pedalons.service.route.network;

import fr.pedalons.service.route.generator.NetworkGraph;
import java.time.Instant;

/**
 * A team's graph as cached: what it was built from ({@code fingerprint}), when, and an estimate of
 * its memory for the cache bound.
 */
public record TeamNetwork(
    Fingerprint fingerprint,
    NetworkGraph graph,
    TeamNetworkSummary summary,
    Instant builtAt,
    long weightBytes) {}
