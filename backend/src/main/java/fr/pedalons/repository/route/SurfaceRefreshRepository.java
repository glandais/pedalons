package fr.pedalons.repository.route;

import fr.pedalons.domain.route.SurfaceRefresh;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;

/**
 * What is left of the queue of the former surface worker (docs/LEDGER_*.md API-150), until phase
 * F: nothing writes a request here nor reads one. A previous release still can,
 * during the minute of a rolling deploy or after a rollback, so the writes of a surface drop the
 * request of their target: otherwise that release would later claim it and replace the document
 * with its own.
 */
@ApplicationScoped
public class SurfaceRefreshRepository implements PanacheRepository<SurfaceRefresh> {

  /**
   * Removes the request of a route, whatever its state: the HD catch-up or an HD save has just
   * written the surface, in the caller's transaction, with the route locked (docs/LEDGER_*.md
   * API-150).
   */
  public void dropForRoute(Long routeId) {
    delete("route.id = ?1", routeId);
  }

  /** As {@link #dropForRoute}, for a preview. */
  public void dropForPreview(Long previewId) {
    delete("preview.id = ?1", previewId);
  }
}
