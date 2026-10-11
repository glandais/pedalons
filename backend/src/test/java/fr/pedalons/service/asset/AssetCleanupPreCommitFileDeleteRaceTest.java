package fr.pedalons.service.asset;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.AssetDto;
import fr.pedalons.dto.common.asset.AssetsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.post.PostRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.UserTransaction;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug: AssetCleanupScheduler deletes the S3 files in {@code AssetRemoveListener.@PreRemove}, i.e.
 * inside {@code em.remove()}, before its transaction commits. An asset attached by a concurrent
 * save while the sweep is still looping keeps its row (the sweep's versioned DELETE matches 0
 * rows, OptimisticLockException, the whole sweep rolls back) but loses its file; every other
 * orphan of the batch is rolled back too and keeps a row without a file.
 *
 * <p>Found by the TLA+/TLC model of the orphan sweep (schedulers subsystem): sweep transaction
 * {remove(a) ⇒ S3 delete now, SQL DELETE at commit} interleaved with a save transaction {read a
 * with teamEntity null, UPDATE ... version+1, commit}. The invariant "an asset row exists ⇒ its
 * file exists" is violated by remove(a) · save(a) commits · sweep commit fails.
 *
 * <p>The interleaving is driven explicitly: the sweep's steps (findOrphanedAssets + delete, exactly
 * what {@link AssetCleanupScheduler#cleanupOrphanedAssets()} does) run in a transaction held open on
 * the test thread, the attach runs and commits on another thread, then the sweep commits. Whatever
 * the fix (file deletion deferred to after commit, or the orphan row locked / re-checked), every
 * asset row left in the database must still have its file.
 */
@QuarkusTest
class AssetCleanupPreCommitFileDeleteRaceTest extends AbstractBaseTest {

  @Inject AssetService assetService;
  @Inject AssetRepository assetRepository;
  @Inject PostRepository postRepository;
  @Inject StorageService storageService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;
  @Inject UserTransaction userTransaction;

  private Domain domain;
  private Team team;
  private Long postId;
  private Asset attached;
  private Asset bystander;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    User admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    Post post = dataService.createPost(team, admin, "Draft", Instant.now(), Visibility.PUBLIC);
    postId = post.getId();

    // Uploaded two days ago, editor still open: an orphan in the sweep's eyes.
    attached = dataService.createAsset(team, admin, AssetType.IMAGE, "kept-open.png");
    dataService.backdateAssetUpdatedAt(attached, Instant.now().minus(2, ChronoUnit.DAYS));
    // Another orphan of the same batch.
    bystander = dataService.createAsset(team, admin, AssetType.IMAGE, "other-orphan.png");
    dataService.backdateAssetUpdatedAt(bystander, Instant.now().minus(2, ChronoUnit.DAYS));

    assertTrue(storageService.exists(key(attached)));
    assertTrue(storageService.exists(key(bystander)));
  }

  @Test
  void assetAttachedDuringSweep_keepsItsFile_andNoRowIsLeftWithoutFile() throws Exception {
    Exception sweepFailure = null;

    // Sweep transaction: the body of cleanupOrphanedAssets, held open before its commit.
    userTransaction.begin();
    try {
      Instant cutoff = Instant.now().minus(1, ChronoUnit.DAYS);
      List<Asset> orphaned = assetRepository.findOrphanedAssets(cutoff);
      assertEquals(2, orphaned.size(), "both backdated uploads are orphans");
      for (Asset asset : orphaned) {
        assetRepository.delete(asset);
      }

      // Meanwhile the member saves the post, attaching the image, in its own transaction.
      CompletableFuture.runAsync(() -> inRequest(this::attachToPost)).get(30, TimeUnit.SECONDS);

      try {
        userTransaction.commit();
      } catch (Exception e) {
        // Today: the versioned DELETE of the attached asset matches 0 rows, the sweep rolls back.
        sweepFailure = e;
      }
    } catch (Throwable t) {
      try {
        userTransaction.rollback();
      } catch (Exception ignored) {
        // already completed
      }
      throw t;
    }

    // The attach committed: the asset row is there and belongs to the post.
    Long attachedTo =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    assetRepository
                        .findByIdOptional(attached.getId())
                        .map(a -> a.getTeamEntity() == null ? null : a.getTeamEntity().getId())
                        .orElse(null));
    assertEquals(postId, attachedTo, "the save attached the image to the post");

    assertTrue(
        storageService.exists(key(attached)),
        "the image attached to the post lost its file to the sweep (sweep outcome: "
            + sweepFailure
            + ")");

    boolean bystanderRowKept =
        QuarkusTransaction.requiringNew()
            .call(() -> assetRepository.findByIdOptional(bystander.getId()).isPresent());
    if (bystanderRowKept) {
      assertTrue(
          storageService.exists(key(bystander)),
          "the rolled-back sweep left an orphan row without its file; a save can still attach it");
    }
  }

  /** What a post save does with its media: attach the uploaded image (AssetService.updateAssets). */
  private void attachToPost() {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Post post = postRepository.findById(postId);
              String imageId = TsidUtils.toString(attached.getId());
              AssetsDto assets =
                  AssetsDto.builder()
                      .images(List.of(AssetDto.builder().id(imageId).build()))
                      .build();
              assetService.updateAssets(
                  post, new MediaDto("::asset{id=\"" + imageId + "\"}", assets));
              postRepository.persist(post);
            });
  }

  private String key(Asset asset) {
    return assetService.getAssetKey(team, asset.getFileId());
  }

  private void inRequest(Runnable body) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      body.run();
    } finally {
      requestContext.terminate();
    }
  }
}
