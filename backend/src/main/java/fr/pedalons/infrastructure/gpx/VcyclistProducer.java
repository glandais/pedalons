package fr.pedalons.infrastructure.gpx;

import io.github.glandais.elevation.ElevationProvider;
import io.github.glandais.elevation.ElevationProviderJvm;
import io.github.glandais.map.MapFactoriesJvm;
import io.github.glandais.map.MissingTilePolicy;
import io.github.glandais.map.TileMapProducer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;
import java.io.File;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * The CDI seam with vcyclist.
 *
 * <p>vcyclist exposes Kotlin {@code object}s, not beans: the only two pieces carrying state are the
 * elevation provider (its tile LRU) and the tile map producer (its carto disk cache), and both are
 * built here from {@code pedalons.data.cache}. Everything else in the library is stateless and
 * called statically, which is why the seven library {@code @Inject}s that {@code
 * GpxProcessingService} used to carry — and those of {@code RouterService} and {@code
 * ThumbnailService} — are gone rather than moved.
 *
 * <p>This class is also the only reader of {@code pedalons.data.cache} since the gpx2web
 * {@code CacheFolderProvider} SPI it used to implement no longer exists.
 */
@ApplicationScoped
public class VcyclistProducer {

  @ConfigProperty(name = "pedalons.data.cache", defaultValue = "cache")
  File cacheFolder;

  /**
   * Renders map thumbnails. Its own disk cache is keyed on the whole tile source — since vcyclist
   * 5.1.1, {@code {cache}/tileserver_8080/styles/colorful/256/{z}/{x}/{y}.png}, so the light and
   * dark styles no longer share tiles. A different layout from gpx2web's: carto tiles get
   * downloaded once more; DEM tiles do not (see {@link DemTileFetcher}).
   *
   * <p>{@link MissingTilePolicy#FAIL}: by default vcyclist paints a tile it cannot get in grey and
   * carries on, and a thumbnail with holes is what the tileserver outage of September 2026 produced
   * (black ones, then). Here the render throws instead, and {@code MapThumbnailRenderer} leaves no
   * image behind.
   */
  @Produces
  @Singleton
  public TileMapProducer tileMapProducer() {
    return MapFactoriesJvm.tileMapProducer(
        cacheFolder, MapFactoriesJvm.httpTileFetcher(), MissingTilePolicy.FAIL);
  }

  /**
   * Elevation lookups against mapterhorn, with the defaults gpx2web used (zoom 12, 100-tile memory
   * LRU, 512 px tiles) and our own disk-backed fetcher in front of the network.
   */
  @Produces
  @Singleton
  public ElevationProvider elevationProvider() {
    return ElevationProviderJvm.newElevationProvider(
        ElevationProviderJvm.elevationProviderConfig(), new DemTileFetcher(cacheFolder));
  }
}
