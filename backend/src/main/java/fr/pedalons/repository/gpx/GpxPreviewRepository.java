package fr.pedalons.repository.gpx;

import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.GpxPreview.PreviewTrack;
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

  /**
   * The dated previews of a user still to leave ({@code departureAt >= from}), the one being saved
   * excluded: what bounds the weather cells one account may ask for.
   */
  public long countUpcomingDated(
      Long domainId, Long userId, Instant from, @Nullable Long exceptId) {
    return count(
        "domain.id = ?1 and createdBy.id = ?2 and departureAt is not null and departureAt >= ?3"
            + " and id <> ?4",
        domainId,
        userId,
        from,
        exceptId == null ? -1L : exceptId);
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

  /** The tracks of a preview with the revision they belong to, read in one query. */
  public record PreviewTracks(long revision, List<PreviewTrack> tracks) {}

  private static final String WEATHER_ROW =
      "select new fr.pedalons.repository.gpx.PreviewWeatherRow("
          + "p.id, p.filesRevision, p.departureAt, p.averageSpeed) from GpxPreview p where ";

  /**
   * The dated previews leaving within {@code [from, to]}, for the weather planner. Across every
   * domain on purpose — the weather cache is global and this feeds no response — but not those of a
   * deleted domain. At most {@code limit}, the soonest first.
   */
  public List<PreviewWeatherRow> findForWeather(Instant from, Instant to, int limit) {
    return getEntityManager()
        .createQuery(
            WEATHER_ROW
                + "p.departureAt is not null and p.departureAt >= :from and p.departureAt <= :to"
                + " and p.domain.deleted = false order by p.departureAt, p.id",
            PreviewWeatherRow.class)
        .setParameter("from", from)
        .setParameter("to", to)
        .setMaxResults(limit)
        .getResultList();
  }

  /** As {@link #findForWeather(Instant, Instant, int)}, for one preview. */
  public Optional<PreviewWeatherRow> findForWeather(Long previewId, Instant from, Instant to) {
    return getEntityManager()
        .createQuery(
            WEATHER_ROW
                + "p.id = :id and p.departureAt is not null and p.departureAt >= :from"
                + " and p.departureAt <= :to and p.domain.deleted = false",
            PreviewWeatherRow.class)
        .setParameter("id", previewId)
        .setParameter("from", from)
        .setParameter("to", to)
        .getResultStream()
        .findFirst();
  }

  /** The weather row of a preview by its public identifier, scoped to a domain. */
  public Optional<PreviewWeatherRow> findWeatherRow(Long domainId, UUID publicId) {
    return getEntityManager()
        .createQuery(
            WEATHER_ROW + "p.domain.id = :domainId and p.publicId = :publicId",
            PreviewWeatherRow.class)
        .setParameter("domainId", domainId)
        .setParameter("publicId", publicId)
        .getResultStream()
        .findFirst();
  }

  /**
   * The tracks of a preview and their revision, from one row in one query, so that the geometry
   * cached under a revision is the one of that revision. Null when the preview is gone.
   */
  public @Nullable PreviewTracks findTracks(Long previewId) {
    List<Object[]> found =
        getEntityManager()
            .createQuery(
                "select p.filesRevision, p.tracks from GpxPreview p where p.id = :id",
                Object[].class)
            .setParameter("id", previewId)
            .getResultList();
    if (found.isEmpty()) {
      return null;
    }
    Long revision = (Long) found.getFirst()[0];
    @SuppressWarnings("unchecked")
    List<PreviewTrack> tracks = (List<PreviewTrack>) found.getFirst()[1];
    return new PreviewTracks(revision == null ? 0 : revision, tracks);
  }
}
