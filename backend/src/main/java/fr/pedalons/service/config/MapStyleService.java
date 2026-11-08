package fr.pedalons.service.config;

import fr.pedalons.common.UrlUtils;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.dto.config.MapStyleDto;
import fr.pedalons.service.security.annotation.Public;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Turns the configured basemaps into what the clients consume.
 *
 * <p>A hosted vector style is handed over as its own URL. A raster basemap has no style document
 * anywhere — the providers serve tiles — so this service <em>generates</em> the one-layer MapLibre
 * wrapper and the clients load it from {@code /api/map/styles/{id}.json}. That is what lets a
 * satellite or an OSM fond reach a client that only knows how to take a style URL: the
 * mobile app gained six basemaps without a release, and the web dropped the {@code rasterStyle()}
 * helper it used to hand-write.
 */
@ApplicationScoped
public class MapStyleService {

  @Inject MapConfig mapConfig;

  /**
   * Fails startup on a style that declares both a hosted URL and a raster source, or neither.
   *
   * <p>At runtime such an entry would either be silently dropped from the switcher or served as a
   * style URL that 404s — a basemap that quietly disappears is exactly the kind of configuration
   * mistake nobody notices until a user reports "the map is grey".
   */
  void validate(@Observes StartupEvent event) {
    for (MapConfig.Style style : mapConfig.styles()) {
      if (style.url().isPresent() == style.raster().isPresent()) {
        throw new IllegalStateException(
            "pedalons.map.styles[%s]: declare exactly one of 'url' (hosted style) or 'raster.*'"
                .formatted(style.id()));
      }
    }
  }

  /**
   * The switcher's contents, in configured order.
   *
   * @param baseUrl the site's public base URL — a generated style must be fetched from the host the
   *     client is talking to, and that differs per domain and per environment, so it cannot be
   *     baked into the properties file.
   */
  public List<MapStyleDto> styles(String baseUrl) {
    return mapConfig.styles().stream()
        .map(
            style ->
                new MapStyleDto(
                    style.id(),
                    style.label(),
                    style.group(),
                    style.url().orElseGet(() -> generatedStyleUrl(baseUrl, style.id())),
                    style.darkVariant().filter(url -> !url.isBlank()).orElse(null),
                    style.attribution().filter(text -> !text.isBlank()).orElse(null)))
        .toList();
  }

  /**
   * The MapLibre style document for a raster basemap, as a plain map serialised to JSON.
   *
   * <p>Modelled as a {@code Map} rather than a record tree because the target is the MapLibre style
   * specification, not our API: typing a dozen records against someone else's schema would buy
   * nothing and would have to follow their versions.
   *
   * <p>{@code @Public} for the same reason {@code ConfigService.getConfig()} is: this is deployment
   * configuration, identical for every visitor, and it is fetched by the map engine itself — MapLibre
   * takes a URL and issues its own request, carrying none of our headers.
   */
  @Public
  public Map<String, Object> generatedStyle(String id) {
    MapConfig.Raster raster =
        mapConfig.styles().stream()
            .filter(style -> style.id().equals(id))
            .findFirst()
            .flatMap(MapConfig.Style::raster)
            .orElseThrow(NotFoundException::new);

    Map<String, Object> source = new LinkedHashMap<>();
    source.put("type", "raster");
    source.put("tiles", raster.tiles());
    source.put("tileSize", 256);
    raster.minZoom().ifPresent(minZoom -> source.put("minzoom", minZoom));
    source.put("maxzoom", raster.maxZoom());
    source.put("attribution", raster.attribution());

    Map<String, Object> layer = new LinkedHashMap<>();
    layer.put("id", "raster");
    layer.put("type", "raster");
    layer.put("source", "raster");

    Map<String, Object> style = new LinkedHashMap<>();
    style.put("version", 8);
    style.put("sources", Map.of("raster", source));
    style.put("layers", List.of(layer));
    return style;
  }

  private static String generatedStyleUrl(String baseUrl, String id) {
    return "%s/api/map/styles/%s.json".formatted(UrlUtils.stripTrailingSlash(baseUrl), id);
  }
}
