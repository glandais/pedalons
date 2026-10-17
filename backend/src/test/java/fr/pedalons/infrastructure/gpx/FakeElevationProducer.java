package fr.pedalons.infrastructure.gpx;

import fr.pedalons.enums.ElevationQuality;
import io.github.glandais.elevation.ElevationProvider;
import io.github.glandais.elevation.ElevationProviderConfig;
import io.github.glandais.elevation.ElevationProviderJvm;
import io.github.glandais.elevation.RawTile;
import io.quarkus.test.Mock;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;
import java.util.function.Function;

/**
 * Replaces the two {@code ElevationProvider} beans of {@link VcyclistProducer} in every test, so
 * that no backend test reaches IGN ({@code data.geopf.fr}) or Mapterhorn: they would be slow and
 * flaky offline or in CI, and the pipeline silently falls back to the original elevations when the
 * network fails, so a test could pass without checking anything about altitude.
 *
 * <p>Each tier reads synthetic Terrarium tiles built in memory, <b>flat</b> and <b>different</b>:
 * {@link #FAST_ELEVATION} for {@link ElevationQuality#FAST}, {@link #HD_ELEVATION} for {@link
 * ElevationQuality#HD}. A test can therefore tell which tier computed a profile. No surface model
 * is attached (no bridge decks), and a flat terrain means an ascent of zero.
 */
@ApplicationScoped
public class FakeElevationProducer {

  public static final double FAST_ELEVATION = 100.0;
  public static final double HD_ELEVATION = 200.0;

  /**
   * While true the HD tier's tile fetcher throws, as IGN down does. The provider caches the tiles
   * it already read, so a test using it must ride a track no other test does.
   */
  public static volatile boolean failHd = false;

  /** A power of 2, as vcyclist requires; tiny because every pixel is the same. */
  private static final int TILE_SIZE = 16;

  @Mock
  @Produces
  @Singleton
  @ElevationTier(ElevationQuality.FAST)
  public ElevationProvider fastElevationProvider() {
    return provider(FAST_ELEVATION, false);
  }

  @Mock
  @Produces
  @Singleton
  @ElevationTier(ElevationQuality.HD)
  public ElevationProvider hdElevationProvider() {
    return provider(HD_ELEVATION, true);
  }

  private static ElevationProvider provider(double elevation, boolean hd) {
    ElevationProviderConfig config =
        ElevationProviderJvm.elevationProviderConfig(
            12, 100, "http://fake-elevation.invalid/{z}/{x}/{y}.png", TILE_SIZE);
    RawTile tile = flatTile(elevation);
    Function<String, RawTile> fetcher =
        url -> {
          if (hd && failHd) {
            throw new IllegalStateException("HD elevation source down (test)");
          }
          return tile;
        };
    return ElevationProviderJvm.newElevationProvider(config, fetcher);
  }

  /** A Terrarium tile: {@code elevation = R * 256 + G + B / 256 - 32768}. */
  private static RawTile flatTile(double elevation) {
    int raw = (int) Math.round((elevation + 32768.0) * 256.0);
    byte r = (byte) (raw >> 16);
    byte g = (byte) (raw >> 8);
    byte b = (byte) raw;
    byte[] rgba = new byte[TILE_SIZE * TILE_SIZE * 4];
    for (int i = 0; i < rgba.length; i += 4) {
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = (byte) 0xFF;
    }
    return new RawTile(TILE_SIZE, TILE_SIZE, rgba);
  }
}
