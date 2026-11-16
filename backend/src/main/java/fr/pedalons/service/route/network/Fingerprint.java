package fr.pedalons.service.route.network;

import java.math.BigInteger;

/**
 * What a team's routes, tracks and street edges documents add up to, read by one cheap statement
 * per team (ledger docs/LEDGER_*.md API-198, lot 3 plan §2.2; lot 3b plan §6.2). {@link
 * OverlayDigest} hashes it: two equal fingerprints mean the overlay the engine holds is still the
 * team's. Computed by the database, so that the writes of another instance, or of the previous
 * release during a rolling deploy, are seen the same way as ours.
 *
 * @param routes routes of the team, deleted ones included
 * @param routeState sum of a hash of each route's {@code deleted}, {@code excluded_from_generator}
 *     and {@code surface_type}: the only route columns the overlay depends on, so that a save of
 *     other fields (the HD catch-up's elevation) does not count as a route-level change
 * @param tracks tracks of those routes
 * @param trackIds sum of the track ids (a replaced track gets a new id)
 * @param trackVersions sum of the tracks' {@code @Version}
 * @param documents tracks that have a street edges document
 * @param documentBytes sum of the stored sizes of those documents
 */
public record Fingerprint(
    long routes,
    long routeState,
    long tracks,
    BigInteger trackIds,
    long trackVersions,
    long documents,
    long documentBytes) {}
