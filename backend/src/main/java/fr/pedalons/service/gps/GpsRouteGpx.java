package fr.pedalons.service.gps;

import fr.pedalons.common.exception.InternalException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.service.asset.AssetService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.IOException;
import java.io.InputStream;
import java.util.Comparator;
import java.util.Optional;

/**
 * The GPX a route is sent to a GPS service from: the filtered GPX, failing that the original — the
 * newest of its kind, so that every caller (manual upload, route sync, its planner's fingerprint)
 * picks the same one.
 */
@ApplicationScoped
public class GpsRouteGpx {

  @Inject AssetService assetService;

  public static Optional<Asset> pick(Route route) {
    return newest(route, AssetType.ROUTE_FILTERED_GPX)
        .or(() -> newest(route, AssetType.ROUTE_ORIGINAL_GPX));
  }

  private static Optional<Asset> newest(Route route, AssetType type) {
    return route.getAssets().stream()
        .filter(a -> a.getType() == type)
        .max(Comparator.comparing(Asset::getId));
  }

  public byte[] read(Asset asset) {
    try (InputStream is = assetService.getAssetContent(asset)) {
      return is.readAllBytes();
    } catch (IOException e) {
      throw new InternalException(ErrorCode.GPX_FAILURE, e);
    }
  }
}
