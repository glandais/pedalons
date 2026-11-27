package fr.pedalons.api.admin;

import fr.pedalons.dto.admin.ThumbnailCatchUpStatus;
import fr.pedalons.dto.admin.ThumbnailRegenerationRequest;
import fr.pedalons.dto.admin.ThumbnailRegenerationResponse;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.service.admin.ThumbnailRegenerationService;
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

@Path("/api/admin/thumbnails")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Admin - Thumbnails", description = "Platform admin map-thumbnail maintenance")
public class AdminThumbnailResource {

  @Inject ThumbnailRegenerationService thumbnailRegenerationService;

  @POST
  @Path("/regenerate")
  @Operation(
      operationId = "adminRegenerateThumbnails",
      summary = "Regenerate map thumbnails",
      description =
          "Redraw the light and dark map thumbnails of routes, rides and trips from the geometry"
              + " already stored, selected by drawing date, stored size or absence. Synchronous;"
              + " run it with dryRun first.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Regeneration report",
        content = @Content(schema = @Schema(implementation = ThumbnailRegenerationResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "No selection criterion given",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response regenerate(
      @Parameter(description = "Target domain ID (defaults to the request's domain)")
          @QueryParam("domainId")
          @Nullable String domainId,
      @Valid ThumbnailRegenerationRequest request) {
    return Response.ok(thumbnailRegenerationService.regenerate(domainId, request)).build();
  }

  @GET
  @Path("/catch-up")
  @Operation(
      operationId = "adminGetThumbnailCatchUp",
      summary = "State of the automatic thumbnail catch-up",
      description =
          "How many routes, rides and trips of the domain have thumbnails drawn before the current"
              + " basemap, how many of those wait for a new attempt, and how many the catch-up"
              + " gave up on.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Catch-up state",
        content = @Content(schema = @Schema(implementation = ThumbnailCatchUpStatus.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response catchUp(
      @Parameter(description = "Target domain ID (defaults to the request's domain)")
          @QueryParam("domainId")
          @Nullable String domainId) {
    return Response.ok(thumbnailRegenerationService.catchUpStatus(domainId)).build();
  }
}
