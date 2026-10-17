package fr.pedalons.util;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.Team;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Set;
import java.util.TreeSet;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.S3Object;

/**
 * What a team has in the bucket, key by key — for the tests that must prove a failed or replaced
 * upload left nothing behind (docs/LEDGER_*.md API-128). {@code StorageService} has no listing.
 */
@ApplicationScoped
public class StoredObjects {

  @Inject S3Client s3Client;

  @ConfigProperty(name = "storage.bucket", defaultValue = "pedalons")
  String bucket;

  /** Every asset key of the team, as {@code AssetService.getAssetKey} spells them. */
  public Set<String> assetKeys(Team team) {
    return keysUnder("assets/" + TsidUtils.toString(team.getId()) + "/");
  }

  /** Every object of a GPX-tool preview, thumbnail and all revisions of its track files. */
  public Set<String> previewKeys(java.util.UUID publicId) {
    return keysUnder("gpx-previews/" + publicId + "/");
  }

  private Set<String> keysUnder(String prefix) {
    Set<String> keys = new TreeSet<>();
    for (S3Object object :
        s3Client
            .listObjectsV2Paginator(
                ListObjectsV2Request.builder().bucket(bucket).prefix(prefix).build())
            .contents()) {
      keys.add(object.key());
    }
    return keys;
  }
}
