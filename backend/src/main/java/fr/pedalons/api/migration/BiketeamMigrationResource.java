package fr.pedalons.api.migration;

import fr.pedalons.dto.migration.BiketeamMigrationTokenRequest;
import fr.pedalons.service.migration.live.BiketeamMigrationGrantService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;

/**
 * Where a biketeam team admin, sent here by biketeam with a signed request, previews and confirms
 * moving their team to Pédalons. See docs/plans/2026-09-22-biketeam-live-migration.md §4.
 *
 * <p>Hidden from the OpenAPI contract, like {@link BiketeamMigrationInternalResource}: a one-off
 * feature that only the web page calls, so it stays out of the generated clients (the frontend
 * calls it through {@code pages/biketeamMigration/biketeamMigrationApi.ts}, whose types mirror
 * {@code BiketeamMigrationPreviewDto} and {@code BiketeamMigrationConfirmDto} — keep them in step).
 * The endpoints are still public: hiding them only keeps them out of the contract.
 */
@Path("/api/biketeam-migration")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class BiketeamMigrationResource {

  @Inject BiketeamMigrationGrantService grantService;

  /**
   * What biketeam asks to migrate, and what it would land on in this domain. Public, like an
   * invitation preview: the visitor must see what they are asked before signing in. When signed
   * in, says whether the caller can confirm, or the first reason they cannot.
   *
   * <p>200 {@code BiketeamMigrationPreviewDto}; 400 forged, malformed or foreign request
   * (BIKETEAM_REQUEST_INVALID) or expired (BIKETEAM_REQUEST_EXPIRED); 404 when the feature is
   * disabled.
   */
  @POST
  @Path("/preview")
  @PermitAll
  @Operation(hidden = true)
  public Response previewBiketeamMigration(@Valid BiketeamMigrationTokenRequest request) {
    return Response.ok(grantService.preview(request.requestToken()))
        .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
        .build();
  }

  /**
   * Re-checks everything the preview checked, records the request for the signed-in user and this
   * domain, and mints a single-use grant biketeam redeems to start the migration. The page then
   * navigates to redirectUrl. Confirming again while the grant is unredeemed replaces it.
   *
   * <p>200 {@code BiketeamMigrationConfirmDto}; 400 BIKETEAM_REQUEST_INVALID or
   * BIKETEAM_REQUEST_EXPIRED; 401; 403 BIKETEAM_NOT_TEAM_ADMIN (the team exists here and the caller
   * does not administer it); 404 feature disabled; 409 BIKETEAM_SLUG_CONFLICT,
   * BIKETEAM_MIGRATED_IN_OTHER_DOMAIN, BIKETEAM_REQUEST_ALREADY_USED or BIKETEAM_MIGRATION_RUNNING.
   */
  @POST
  @Path("/confirm")
  @RolesAllowed("user")
  @Operation(hidden = true)
  public Response confirmBiketeamMigration(@Valid BiketeamMigrationTokenRequest request) {
    return Response.ok(grantService.confirm(request.requestToken()))
        .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
        .build();
  }
}
