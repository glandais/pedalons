package fr.pedalons.service.geocode;

import fr.pedalons.dto.geocode.GeocodeResultDto;
import fr.pedalons.infrastructure.i18n.LanguageResolver;
import fr.pedalons.infrastructure.stadiamaps.GeocodingFeature;
import fr.pedalons.infrastructure.stadiamaps.GeocodingLookup;
import fr.pedalons.service.security.annotation.Public;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Objects;
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
 * <p>The credit itself is not this service's job — it is a visible one, rendered next to the results
 * by each client: « Stadia Maps, © OpenStreetMap contributors & others ».
 */
@ApplicationScoped
public class GeocodeService {

  @Inject GeocodingLookup geocodingLookup;

  @Inject LanguageResolver languageResolver;

  /**
   * The places matching {@code query}, in the language of the current request.
   *
   * <p>A query shorter than three characters is answered without asking upstream: the clients
   * already gate on it, and a prefix that matches half of France is a billed call for nothing.
   */
  @Public
  public List<GeocodeResultDto> search(String query) {
    String normalized = GeocodingLookup.normalize(query);
    if (normalized.length() < 3) {
      return List.of();
    }
    List<GeocodingFeature> features =
        geocodingLookup.search(normalized, languageResolver.getLanguage());
    return features.stream().map(GeocodeService::toDto).filter(Objects::nonNull).toList();
  }

  /** {@code null} for a hit missing a label or a coordinate — there is nothing to place on a map. */
  private static @Nullable GeocodeResultDto toDto(GeocodingFeature feature) {
    String label = feature.label();
    Double lat = feature.lat();
    Double lon = feature.lon();
    if (label == null || lat == null || lon == null) {
      return null;
    }
    String gid = feature.gid();
    return new GeocodeResultDto(gid == null ? label : gid, label, lat, lon);
  }
}
