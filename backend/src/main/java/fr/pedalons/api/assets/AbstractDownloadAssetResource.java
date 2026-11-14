package fr.pedalons.api.assets;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.assets.response.DownloadableAsset;
import fr.pedalons.service.asset.AssetService;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.Response;

/**
 * What the three download resources share. The URL's first segment ({@code public}, {@code
 * public_unlisted}, {@code team}) is the visibility the asset had when its URL was built — what a
 * cache may keep, not what decides access: {@code AssetService} checks the caller against the
 * asset itself on every request.
 *
 * <p>The endpoints are declared on each subclass, not inherited from here: the contract names
 * every operation after its method ({@code operationIdStrategy=METHOD}), and three inherited copies
 * of one method would share an operationId (docs/LEDGER_*.md API-199).
 */
public abstract class AbstractDownloadAssetResource {

  static final String ASSET_DESCRIPTION =
      "Streams a file attached to a team's content — a route's GPX or FIT, a document — under the"
          + " URL the API gave for it (AssetDto.url and the like): follow that URL rather than"
          + " build one. Access is checked against the asset on every request, whatever the"
          + " visibility segment of the path.";

  static final String IMAGE_DESCRIPTION =
      "Serves an image attached to a team's content, resized to fit a square of the requested"
          + " size and encoded in the best format the Accept header allows (AVIF, WebP, JPEG)."
          + " Access is checked against the asset on every request, whatever the visibility"
          + " segment of the path.";

  @Inject AssetService assetService;

  protected Response asset(String teamSlug, String assetId) {
    DownloadableAsset downloadableAsset =
        assetService.getDownloadableAsset(teamSlug, TsidUtils.toLong(assetId));

    return UploadedContentHeaders.download(
            Response.ok(downloadableAsset.content()).type(downloadableAsset.contentType()),
            downloadableAsset.contentType(),
            downloadableAsset.fileName())
        .build();
  }

  protected Response image(String accept, String teamSlug, String assetId, int size) {
    return UploadedContentHeaders.image(
            Response.fromResponse(
                assetService.getImage(teamSlug, TsidUtils.toLong(assetId), size, accept)))
        .build();
  }
}
