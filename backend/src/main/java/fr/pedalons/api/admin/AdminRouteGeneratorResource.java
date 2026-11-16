package fr.pedalons.api.admin;

import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshRequest;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshResponse;
import fr.pedalons.dto.admin.RouteGeneratorOverlayRefreshResult;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.service.admin.RouteGeneratorOverlayAdminService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/api/admin/route-generator")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(
    name = "Admin - Route generator",
    description = "Platform admin maintenance of the teams' roads prepared for the route generator")
public class AdminRouteGeneratorResource {

  @Inject RouteGeneratorOverlayAdminService service;

  @POST
  @Path("/overlays/refresh")
  @Operation(
      operationId = "adminRefreshRouteGeneratorOverlays",
      summary = "Prepare the teams' roads for the route generator now",
      description =
          "The nightly pass, by hand: for each team (or the one given), compares the digest of its"
              + " tracks with the one the engine holds and deposits it again when it differs, is"
              + " absent, stale or about to expire (or always with force); deletes the overlay of"
              + " a deleted team, or one whose planner is off. Idempotent. With dryRun the answer"
              + " (200) lists what would be done; otherwise the pass runs in the background"
              + " (202, started=false if one already runs on this instance). Run it with dryRun"
              + " first; use force after a key rotation or a new graph.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Dry run: what would be done",
        content =
            @Content(
                schema = @Schema(implementation = RouteGeneratorOverlayRefreshResponse.class))),
    @APIResponse(
        responseCode = "202",
        description = "The pass runs in the background",
        content =
            @Content(
                schema = @Schema(implementation = RouteGeneratorOverlayRefreshResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response refresh(@Valid @NotNull RouteGeneratorOverlayRefreshRequest request) {
    RouteGeneratorOverlayRefreshResult result = service.refresh(request);
    return Response.status(result.background() ? Response.Status.ACCEPTED : Response.Status.OK)
        .entity(result.response())
        .build();
  }
}
