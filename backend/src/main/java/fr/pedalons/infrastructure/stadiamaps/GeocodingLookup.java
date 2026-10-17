package fr.pedalons.infrastructure.stadiamaps;

import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import io.quarkus.cache.CacheResult;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;

/**
 * The cached calls to the geocoder: the autocomplete, and the place lookup that resolves the
 * position of the one result picked.
 *
 * <p>Its own bean rather than a method of {@code GeocodeService} because {@code @CacheResult} is an
 * interceptor: a call from a sibling method of the same bean bypasses the CDI proxy and the cache
 * silently never fires. Resolving the request's language and caching the lookup therefore cannot
 * live in one class. The cache is not an optimisation either: every entry that hits is a billed
 * call the Stadia Maps quota does not see.
 */
@ApplicationScoped
public class GeocodingLookup {

  private static final Logger LOG = Logger.getLogger(GeocodingLookup.class);

  /** What the autocomplete shows. Asking for more would be requesting work nobody reads. */
  private static final int LIMIT = 5;

  @Inject @RestClient StadiaMapsGeocodingClient geocodingClient;

  /**
   * The features matching {@code query}, at most {@value #LIMIT} of them.
   *
   * <p>Cached on the <em>normalised</em> query and the language: an autocomplete sends every prefix
   * of what is being typed, and several users of the same instance type the same town names.
   * Normalising before the key is computed is what makes it hit — {@code "Lyon "} and {@code "lyon"}
   * are one entry. No focus point in the request, on purpose: it would have to be part of the key,
   * and a per-deployment constant buys little against a 24-hour shared cache.
   *
   * <p>Returns an empty list rather than failing when the provider is unreachable (or the quota is
   * spent: 429): the position is an optional form field, so an outage upstream should not stop
   * someone from saving the rest of the form. That empty list is cached like any answer — for 24
   * hours, for every query typed during the outage (docs/LEDGER_*.md API-130).
   */
  @CacheResult(cacheName = "geocode-search")
  public List<GeocodingFeature> search(String normalizedQuery, String language) {
    try {
      return geocodingClient.autocomplete(normalizedQuery, LIMIT, language).featuresOrEmpty();
    } catch (RuntimeException e) {
      LOG.warnv("Geocoding failed for \"{0}\": {1}", normalizedQuery, e.getMessage());
      return List.of();
    }
  }

  /**
   * The position of the place {@code gid}, from {@code place_details} — the first feature that
   * carries a point, or empty when the provider knows no such place.
   *
   * <p>Billed 20 credits per id, which is why it runs only when a user picks a suggestion, never
   * for the suggestions themselves. Cached on the id and the language for the same reason as
   * {@link #search}; an empty answer is cached too (a GID that resolves to nothing today will not
   * tomorrow), a failure is not — the exception leaves the interceptor before anything is stored.
   *
   * <p>Unlike {@link #search}, a failure is not swallowed: the user has picked a place and is
   * waiting for its position, so they must be told it did not come. An upstream 400 or 404 is an id
   * the provider rejects — empty, like an unknown place; anything else (unreachable, timeout, 429
   * when the quota is spent, 5xx, 401 on a bad key) is a 503. Only the status is logged: the URL and
   * the headers carry the API key.
   *
   * @param gid an id already checked by the caller against the shape of a GID
   */
  @CacheResult(cacheName = "geocode-place")
  public Optional<GeocodingFeature> place(String gid, String language) {
    GeocodingResponse response;
    try {
      response = geocodingClient.placeDetails(gid, language);
    } catch (WebApplicationException e) {
      int status = e.getResponse().getStatus();
      if (status == 400 || status == 404) {
        return Optional.empty();
      }
      LOG.warnv("Stadia Maps place lookup failed with status {0}", status);
      throw new ServiceUnavailableException(ErrorCode.GEOCODING_UNAVAILABLE);
    } catch (ProcessingException e) {
      LOG.warnv("Stadia Maps place lookup unreachable: {0}", e.getClass().getSimpleName());
      throw new ServiceUnavailableException(ErrorCode.GEOCODING_UNAVAILABLE);
    }
    if (response == null) {
      return Optional.empty();
    }
    return response.featuresOrEmpty().stream()
        .filter(f -> f.lat() != null && f.lon() != null)
        .findFirst();
  }

  /** Lowercased and whitespace-collapsed, so near-identical queries share one cache entry. */
  public static String normalize(String query) {
    return query.trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
  }
}
