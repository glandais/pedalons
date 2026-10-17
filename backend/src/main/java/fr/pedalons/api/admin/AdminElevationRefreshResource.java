package fr.pedalons.api.admin;

import fr.pedalons.dto.admin.ElevationRefreshRetryRequest;
import fr.pedalons.dto.admin.ElevationRefreshRetryResponse;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.service.admin.ElevationRefreshRetryService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

@Path("/api/admin/elevation-refresh")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(
    name = "Admin - Elevation",
    description = "Platform admin maintenance of the background HD elevation recomputation")
public class AdminElevationRefreshResource {

  @Inject ElevationRefreshRetryService elevationRefreshRetryService;

  @POST
  @Path("/retry")
  @Operation(
      operationId = "adminRetryElevationRefresh",
      summary = "Retry abandoned HD elevation recomputations",
      description =
          "Start again the HD recomputation of the routes and GPX-tool previews whose request used"
              + " up its attempts (they stay on the fast profile, state FAST). Their attempts are"
              + " reset and their due times spread one minute apart, oldest first, so the worker"
              + " is not flooded; the targets go back to PENDING. Idempotent: a second call finds"
              + " nothing. Run it with dryRun first.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Retry report",
        content = @Content(schema = @Schema(implementation = ElevationRefreshRetryResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response retry(
      @Parameter(description = "Target domain ID (defaults to the request's domain)")
          @QueryParam("domainId")
          @Nullable String domainId,
      @Valid ElevationRefreshRetryRequest request) {
    return Response.ok(elevationRefreshRetryService.retry(domainId, request)).build();
  }
}
