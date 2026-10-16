package fr.pedalons.infrastructure.gps;

import org.jspecify.annotations.Nullable;

/**
 * What a route is sent with besides its GPX.
 *
 * @param name the name the service shows (Hammerhead takes it from the file name)
 * @param externalId Wahoo's {@code external_id}: stable for a route Pédalons keeps in sync ({@code
 *     pedalons-{domainId}-{rideId}}, docs/LEDGER_*.md API-120 D10); null for a manual upload, which
 *     keeps the SHA-256 of the GPX. Ignored by the other services, and by Wahoo's {@code PUT}, which
 *     cannot change it.
 */
public record RouteMeta(String name, @Nullable String externalId) {

  public static RouteMeta manual(String name) {
    return new RouteMeta(name, null);
  }
}
