package fr.pedalons.service.asset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.asset.AssetSizeBackfill.BatchResult;
import fr.pedalons.service.asset.AssetSizeBackfill.Outcome;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-7: the assets stored before their size was recorded get it from the bucket.
 */
@QuarkusTest
class AssetSizeBackfillTest extends AbstractBaseTest {

  @Inject AssetSizeBackfill backfill;
  @Inject AssetService assetService;
  @Inject AssetRepository assetRepository;
  @Inject StorageService storageService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  private Team team;
  private User admin;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
  }

  /** Written straight to the database and the bucket, as a release before API-7 left it. */
  private Asset legacyAsset(String fileName) {
    return dataService.createAsset(team, admin, AssetType.ATTACHMENT, fileName);
  }

  private String key(Asset asset) {
    return assetService.getAssetKey(team, asset.getFileId());
  }

  private @Nullable Long fileSize(Asset asset) {
    return QuarkusTransaction.requiringNew()
        .call(() -> assetRepository.findById(asset.getId()).getFileSize());
  }

  @Test
  void recordsTheSizeOfTheStoredFile() {
    Asset asset = legacyAsset("notes.txt");
    assertNull(fileSize(asset));

    BatchResult result = backfill.processBatch(0, 10);

    assertEquals(1, result.outcomes().get(Outcome.RECORDED));
    assertEquals(storageService.size(key(asset)), fileSize(asset));
    assertEquals(0, backfill.processBatch(0, 10).processed());
  }

  @Test
  void leavesAMissingFileUnknown() {
    Asset asset = legacyAsset("gone.pdf");
    storageService.delete(key(asset));

    BatchResult result = backfill.processBatch(0, 10);

    assertEquals(1, result.outcomes().get(Outcome.MISSING));
    assertNull(fileSize(asset));
  }

  @Test
  void neverOverwritesASizeRecordedMeanwhile() {
    Asset asset = legacyAsset("notes.txt");
    QuarkusTransaction.requiringNew()
        .run(() -> assetRepository.updateSize(asset.getId(), asset.getFileId(), 42L));

    QuarkusTransaction.requiringNew()
        .run(() -> assetRepository.recordSizeIfUnknown(asset.getId(), asset.getFileId(), 7L));

    assertEquals(42L, fileSize(asset));
  }

  @Test
  void resumesAfterTheCursor() {
    Asset first = legacyAsset("a.txt");
    Asset second = legacyAsset("b.txt");

    BatchResult result = backfill.processBatch(first.getId(), 10);

    assertEquals(1, result.processed());
    assertEquals(second.getId(), result.lastId());
    assertNull(fileSize(first));
    assertEquals(storageService.size(key(second)), fileSize(second));
  }

  @Test
  void theMappedDtoCarriesTheSize() {
    Asset asset = legacyAsset("notes.txt");
    backfill.processBatch(0, 10);

    Long size =
        QuarkusTransaction.requiringNew()
            .call(() -> assetService.map(assetRepository.findById(asset.getId())).size());

    assertEquals(storageService.size(key(asset)), size);
  }
}
