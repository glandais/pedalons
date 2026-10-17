package fr.pedalons.service.geocode;

import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.geocode.GeocodeResultDto;
import fr.pedalons.infrastructure.i18n.LanguageResolver;
import fr.pedalons.infrastructure.stadiamaps.GeocodingFeature;
import fr.pedalons.infrastructure.stadiamaps.GeocodingLookup;
import fr.pedalons.service.security.annotation.Public;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Objects;
import java.util.regex.Pattern;
import org.jspecify.annotations.Nullable;

/**
 * Address lookup for the forms, served from our host (docs/LEDGER_*.md OPS-49).
 *
 * <p>The indirection outlived the provider it was built for. With Stadia Maps it still buys two
 * things: the API key stays on the server (the map search bar, which calls Stadia Maps from the
 * browser, authenticates by domain instead — see {@code WEB-99}), and the result cache is shared
 * across users, so a shared instance pays once for a town name everyone types.
 *
 * <p>{@code @Public} because there is no entity to authorise: the data is the provider's and
 * identical for every caller. The endpoint is nonetheless behind a login — see {@code
 * GeocodeResource} for why.
 *
 * <p>Two steps since API-129: {@link #search} answers suggestions that usually have no position
 * yet (the v2 autocomplete is 1 credit a request and gives none), {@link #place} resolves the one
 * the user picks (20 credits). Never the five suggestions at once — that is 100 credits a
 * keystroke.
 *
 * <p>The credit itself is not this service's job — it is a visible one, rendered next to the results
 * by each client: « Stadia Maps, © OpenStreetMap contributors & others ».
 */
@ApplicationScoped
public class GeocodeService {

  /** Longer than any GID we have seen by far; a bound before the pattern even runs. */
  static final int MAX_ID_LENGTH = 200;

  /**
   * The shape of a GID — {@code source:layer:id}, e.g. {@code whosonfirst:locality:101750851} or
   * {@code openstreetmap:venue:node/1}. Strict on purpose: the id is user input forwarded to a
   * billed API, so anything else is refused before a call is spent on it.
   */
  static final Pattern GID = Pattern.compile("^[a-z_]+:[a-z_]+:[A-Za-z0-9_.:/-]+$");

  @Inject GeocodingLookup geocodingLookup;

  @Inject LanguageResolver languageResolver;

  /**
   * The places matching {@code query}, in the language of the current request.
   *
   * <p>A query shorter than three characters is answered without asking upstream: the clients
   * already gate on it, and a prefix that matches half of France is a billed call for nothing.
   *
   * <p>A provider failure is an empty list, never an error: the position is an optional form field,
   * so an outage upstream (or a spent quota) must not stop someone from saving the rest of the
   * form. The conversion is here, outside the cache, on purpose: {@link GeocodingLookup#search}
   * throws, so the failure is not stored and the next query reaches the provider again (API-130).
   */
  @Public
  public List<GeocodeResultDto> search(String query) {
    String normalized = GeocodingLookup.normalize(query);
    if (normalized.length() < 3) {
      return List.of();
    }
    List<GeocodingFeature> features;
    try {
      features = geocodingLookup.search(normalized, languageResolver.getLanguage());
    } catch (ServiceUnavailableException e) {
      // Already logged, once, by the lookup.
      return List.of();
    }
    return features.stream().map(GeocodeService::toDto).filter(Objects::nonNull).toList();
  }

  /**
   * The place {@code id} — a suggestion's {@link GeocodeResultDto#id()} — with its position.
   *
   * <p>The id is checked before anything is spent: an id longer than {@value #MAX_ID_LENGTH} or not
   * shaped like a GID is a 404, exactly like a place the provider does not know, and never reaches
   * Stadia Maps. The answer keeps the id asked for (the provider may answer another GID for the
   * same place) so a client can match it to its suggestion.
   *
   * @throws NotFoundException for a malformed id or a place the provider does not know
   * @throws fr.pedalons.common.exception.ServiceUnavailableException when the provider fails
   */
  @Public
  public GeocodeResultDto place(@Nullable String id) {
    if (!isValidId(id)) {
      throw new NotFoundException(ErrorCode.NOT_FOUND);
    }
    GeocodingFeature feature =
        geocodingLookup
            .place(id, languageResolver.getLanguage())
            .orElseThrow(() -> new NotFoundException(ErrorCode.NOT_FOUND));
    String displayName = feature.displayName();
    return new GeocodeResultDto(
        id, displayName == null ? id : displayName, feature.lat(), feature.lon());
  }

  /** Whether {@code id} is worth a billed call: bounded, and shaped like a GID. */
  static boolean isValidId(@Nullable String id) {
    return id != null && id.length() <= MAX_ID_LENGTH && GID.matcher(id).matches();
  }

  /**
   * {@code null} for a hit with nothing to show (no name), or with neither a position nor a GID to
   * resolve one later — there would be nothing to place on a map. A position stays {@code null}
   * when the provider gave none: the client resolves it with {@link #place} once picked.
   */
  private static @Nullable GeocodeResultDto toDto(GeocodingFeature feature) {
    String displayName = feature.displayName();
    if (displayName == null) {
      return null;
    }
    String gid = feature.gid();
    Double lat = feature.lat();
    Double lon = feature.lon();
    boolean hasPosition = lat != null && lon != null;
    if (gid == null && !hasPosition) {
      return null;
    }
    return new GeocodeResultDto(
        gid == null ? displayName : gid,
        displayName,
        hasPosition ? lat : null,
        hasPosition ? lon : null);
  }
}
