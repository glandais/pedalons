package fr.pedalons.service.admin;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.dto.admin.ThumbnailOwnerReport;
import fr.pedalons.dto.admin.ThumbnailOwnerReport.ThumbnailFile;
import fr.pedalons.dto.admin.ThumbnailOwnerReport.ThumbnailOwnerKind;
import fr.pedalons.dto.admin.ThumbnailOwnerReport.ThumbnailRegenerationOutcome;
import fr.pedalons.dto.admin.ThumbnailOwnerReport.ThumbnailRegenerationReason;
import fr.pedalons.dto.admin.ThumbnailRegenerationRequest;
import fr.pedalons.dto.admin.ThumbnailRegenerationResponse;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.asset.AssetRepository.ThumbnailAssetRow;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.annotation.Admin;
import fr.pedalons.service.thumbnail.ThumbnailService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Redraws the map thumbnails of routes, rides and trips from the geometry already in the database,
 * for when the tileserver produced wrong ones (e.g. without their map background). A trip stage
 * has no thumbnail of its own: it shows its route's, so it is covered by redrawing that route.
 *
 * <p>Each entity is redrawn in its own transaction, so one failure neither rolls back nor blocks
 * the others.
 */
@ApplicationScoped
public class ThumbnailRegenerationService {

  private static final Logger LOG = Logger.getLogger(ThumbnailRegenerationService.class);

  private static final int DEFAULT_LIMIT = 100;

  private static final Set<AssetType> THUMBNAIL_TYPES =
      EnumSet.of(
          AssetType.ROUTE_THUMBNAIL_LIGHT,
          AssetType.ROUTE_THUMBNAIL_DARK,
          AssetType.RIDE_THUMBNAIL_LIGHT,
          AssetType.RIDE_THUMBNAIL_DARK,
          AssetType.TRIP_THUMBNAIL_LIGHT,
          AssetType.TRIP_THUMBNAIL_DARK);

  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;
  @Inject ThumbnailService thumbnailService;
  @Inject DomainResolver domainResolver;
  @Inject EntityManager em;

  /** Targets the given domain, or the request's resolved domain when {@code domainId} is null. */
  @Admin
  public ThumbnailRegenerationResponse regenerate(
      @Nullable String domainId, ThumbnailRegenerationRequest request) {
    Long targetDomainId =
        domainId != null ? TsidUtils.toLong(domainId) : domainResolver.getDomainId();
    boolean window = request.renderedFrom() != null || request.renderedTo() != null;
    Integer threshold = request.suspectBelowBytes();
    boolean missing = Boolean.TRUE.equals(request.includeMissing());
    if (!window && threshold == null && !missing) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST);
    }

    Map<Long, EnumSet<ThumbnailRegenerationReason>> selected = new LinkedHashMap<>();
    if (window || threshold != null) {
      for (ThumbnailAssetRow row :
          assetRepository.findThumbnailAssets(
              targetDomainId, request.renderedFrom(), request.renderedTo())) {
        if (threshold != null && sizeOf(row.teamId(), row.fileId()) >= threshold) {
          continue;
        }
        EnumSet<ThumbnailRegenerationReason> reasons =
            selected.computeIfAbsent(
                row.ownerId(), id -> EnumSet.noneOf(ThumbnailRegenerationReason.class));
        if (window) {
          reasons.add(ThumbnailRegenerationReason.RENDERED_IN_WINDOW);
        }
        if (threshold != null) {
          reasons.add(ThumbnailRegenerationReason.SMALL_FILE);
        }
      }
    }
    if (missing) {
      for (Long id : assetRepository.findOwnersMissingThumbnails(targetDomainId)) {
        selected
            .computeIfAbsent(id, i -> EnumSet.noneOf(ThumbnailRegenerationReason.class))
            .add(ThumbnailRegenerationReason.MISSING);
      }
    }

    int limit = request.limit() != null ? request.limit() : DEFAULT_LIMIT;
    List<ThumbnailOwnerReport> reports = new ArrayList<>();
    for (Map.Entry<Long, EnumSet<ThumbnailRegenerationReason>> entry : selected.entrySet()) {
      if (reports.size() >= limit) {
        break;
      }
      reports.add(process(entry.getKey(), List.copyOf(entry.getValue()), request.dryRun()));
    }
    LOG.infov(
        "Thumbnail regeneration (dryRun={0}) in domain {1}: {2} matched, {3} processed",
        request.dryRun(), targetDomainId, selected.size(), reports.size());
    return new ThumbnailRegenerationResponse(request.dryRun(), selected.size(), reports);
  }

  private ThumbnailOwnerReport process(
      Long ownerId, List<ThumbnailRegenerationReason> reasons, boolean dryRun) {
    Snapshot before = QuarkusTransaction.requiringNew().call(() -> snapshot(ownerId));
    if (dryRun) {
      return before.report(reasons, null, ThumbnailRegenerationOutcome.PENDING, null);
    }
    try {
      List<ThumbnailFile> after =
          QuarkusTransaction.requiringNew()
              .call(() -> {
                TeamEntity owner = em.find(TeamEntity.class, ownerId);
                redraw(owner);
                em.flush();
                return thumbnails(owner);
              });
      ThumbnailRegenerationOutcome outcome =
          after.size() == 2 && after.stream().allMatch(f -> f.bytes() > 0)
              ? ThumbnailRegenerationOutcome.REGENERATED
              : ThumbnailRegenerationOutcome.FAILED;
      return before.report(reasons, after, outcome, null);
    } catch (RuntimeException e) {
      LOG.warnv("Thumbnail regeneration failed for {0}: {1}", ownerId, e.getMessage());
      return before.report(reasons, null, ThumbnailRegenerationOutcome.FAILED, e.getMessage());
    }
  }

  private void redraw(TeamEntity owner) {
    switch (owner) {
      case Route route -> thumbnailService.generateRouteThumbnails(route);
      case Ride ride -> thumbnailService.generateRideThumbnails(ride);
      case Trip trip -> thumbnailService.generateTripThumbnails(trip);
      default ->
          throw new IllegalArgumentException(
              "No thumbnail on " + owner.getClass().getSimpleName() + " " + owner.getId());
    }
    // Drawn on the admin's request, but the entity's own thumbnail: keep the admin, possibly from
    // another domain, out of its creator's data export
    owner.getAssets().stream()
        .filter(a -> THUMBNAIL_TYPES.contains(a.getType()))
        .forEach(a -> a.setCreatedBy(owner.getCreatedBy()));
  }

  private Snapshot snapshot(Long ownerId) {
    TeamEntity owner = em.find(TeamEntity.class, ownerId);
    ThumbnailOwnerKind kind =
        switch (owner) {
          case Route ignored -> ThumbnailOwnerKind.ROUTE;
          case Ride ignored -> ThumbnailOwnerKind.RIDE;
          case Trip ignored -> ThumbnailOwnerKind.TRIP;
          default ->
              throw new IllegalStateException(
                  "Thumbnail owned by a " + owner.getClass().getSimpleName());
        };
    return new Snapshot(
        TsidUtils.toString(ownerId),
        kind,
        owner.getTeam().getSlug(),
        owner.getSlug(),
        thumbnails(owner));
  }

  private List<ThumbnailFile> thumbnails(TeamEntity owner) {
    return owner.getAssets().stream()
        .filter(a -> THUMBNAIL_TYPES.contains(a.getType()))
        .sorted(Comparator.comparing(Asset::getType))
        .map(a -> new ThumbnailFile(a.getType().name(), sizeOf(a.getTeam().getId(), a.getFileId())))
        .toList();
  }

  private long sizeOf(Long teamId, Long fileId) {
    return storageService.size(assetService.getAssetKey(teamId, fileId));
  }

  private record Snapshot(
      String id,
      ThumbnailOwnerKind kind,
      String teamSlug,
      String slug,
      List<ThumbnailFile> thumbnails) {
    ThumbnailOwnerReport report(
        List<ThumbnailRegenerationReason> reasons,
        @Nullable List<ThumbnailFile> after,
        ThumbnailRegenerationOutcome outcome,
        @Nullable String error) {
      return new ThumbnailOwnerReport(
          id, kind, teamSlug, slug, reasons, thumbnails, after, outcome, error);
    }
  }
}
