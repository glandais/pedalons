package fr.pedalons.repository.gpx;

import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.dto.common.PedalonsPage;
import io.quarkus.hibernate.orm.panache.PanacheQuery;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import io.quarkus.panache.common.Page;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class GpxPreviewRepository implements PanacheRepository<GpxPreview> {

  /**
   * Previews created by a user, most recent first, restricted to those still within the retention
   * window ({@code createdAt >= cutoff}) so the list matches what the purge job leaves behind.
   */
  public PedalonsPage<GpxPreview> findByCreator(
      Long domainId, Long userId, Instant cutoff, int page, int size) {
    PanacheQuery<GpxPreview> query =
        find(
            "domain.id = ?1 and createdBy.id = ?2 and createdAt >= ?3 order by createdAt desc",
            domainId,
            userId,
            cutoff);
    long total = query.count();
    List<GpxPreview> items = query.page(Page.of(page, size)).list();
    return new PedalonsPage<>(items, total);
  }

  /**
   * Looks up a preview by its public identifier, scoped to a domain.
   *
   * <p>{@code publicId} is globally unique, so the domain filter is redundant for correctness — it
   * is there so that a leaked identifier cannot cross a tenant boundary.
   */
  public Optional<GpxPreview> findByPublicId(Long domainId, UUID publicId) {
    return find("domain.id = ?1 and publicId = ?2", domainId, publicId).firstResultOptional();
  }

  /**
   * Every preview a user created, for the GDPR data export.
   *
   * <p>Distinct from {@link #findByCreator} — that one is paginated and hides anything past the
   * retention window, which is right for a listing page and wrong for an export.
   */
  public List<GpxPreview> findAllByCreator(Long domainId, Long userId) {
    return list("domain.id = ?1 and createdBy.id = ?2 order by createdAt", domainId, userId);
  }

  /** Previews created before the cutoff, for the retention job. */
  public List<GpxPreview> findExpired(Instant cutoff) {
    return list("createdAt < ?1", cutoff);
  }

  /**
   * The surface document of a preview, a projection so the planner state stays unread (docs/LEDGER_*.md
   * WEB-100, C1b). Null when there is none.
   */
  public @Nullable PreviewSurfacesDocument findSurfaces(Long previewId) {
    List<PreviewSurfacesDocument> found =
        getEntityManager()
            .createQuery(
                "select p.surfaces from GpxPreview p where p.id = :id",
                PreviewSurfacesDocument.class)
            .setParameter("id", previewId)
            .getResultList();
    return found.isEmpty() ? null : found.getFirst();
  }
}
