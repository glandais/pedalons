package fr.pedalons.api.router;

import fr.pedalons.api.gpx.GpxUploads;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.router.request.RouterRequest;
import fr.pedalons.dto.router.response.GpxImportResponse;
import fr.pedalons.dto.router.response.RouterResponse;
import fr.pedalons.service.router.GpxImportService;
import fr.pedalons.service.router.RouterService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jboss.resteasy.reactive.RestForm;
import org.jboss.resteasy.reactive.multipart.FileUpload;
import org.jspecify.annotations.Nullable;

@Path("/api/router")
@Produces(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Router", description = "Route calculation using the Stadia Maps routing API")
public class RouterResource {

  @Inject RouterService routerService;

  @Inject GpxImportService gpxImportService;

  @POST
  @Operation(
      summary = "Calculate route",
      description =
          "Calculate a route between two points using the Stadia Maps routing API. Each call is"
              + " billed against a monthly quota, so the checks come first: with teamSlug, the"
              + " caller must be allowed to create routes in that team and the team must have the"
              + " route planner enabled; without it, the domain's GPX planner must be enabled."
              + " Otherwise ROUTE_PLANNER_DISABLED. Routing failures have their own codes:"
              + " ROUTING_SEGMENT_TOO_LONG and ROUTING_NO_ROUTE (400), ROUTING_QUOTA_EXCEEDED and"
              + " ROUTING_UNAVAILABLE (503).")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Route calculated successfully",
        content = @Content(schema = @Schema(implementation = RouterResponse.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "Invalid request parameters, planner disabled (ROUTE_PLANNER_DISABLED), segment too"
                + " long (ROUTING_SEGMENT_TOO_LONG) or no route between the points"
                + " (ROUTING_NO_ROUTE)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User may not create routes in the team",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found in this domain",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "503",
        description =
            "Routing service unavailable (ROUTING_UNAVAILABLE) or its monthly quota is spent"
                + " (ROUTING_QUOTA_EXCEEDED)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response route(@Valid RouterRequest request) {
    RouterResponse resp = routerService.getRoute(request);
    return Response.ok(resp).build();
  }

  @POST
  @Path("/import-gpx")
  @Consumes(MediaType.MULTIPART_FORM_DATA)
  @Operation(
      operationId = "importGpx",
      summary = "Load a GPX file into the route editor",
      description =
          "Processes a GPX file with the FAST elevations and returns its tracks as polylines, with"
              + " the ascent accumulated up to each point. Nothing is stored and the routing"
              + " provider is not called. Same rights as the route calculation: with teamSlug, the"
              + " caller must be allowed to create routes in that team and the team must have the"
              + " route planner enabled; without it, the domain's GPX planner must be enabled.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "GPX file processed",
        content = @Content(schema = @Schema(implementation = GpxImportResponse.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "No file (FILE_REQUIRED), oversized (FILE_TOO_LARGE), unparseable (GPX_FAILURE),"
                + " without any track (GPX_EMPTY), too long (GPX_TOO_LONG), planner disabled"
                + " (ROUTE_PLANNER_DISABLED), or more than 8 tracks or 100 000 points once"
                + " simplified (PLANNER_IMPORT_TOO_LARGE)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User may not create routes in the team",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found in this domain",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response importGpx(
      @RestForm("gpxFile") @Nullable FileUpload gpxFile,
      @RestForm("teamSlug") @Nullable @Size(max = 250) String teamSlug) {
    // Rights first (inside the service), then the file, its size, and the read.
    GpxImportResponse resp =
        gpxImportService.importGpx(
            teamSlug,
            () -> {
              if (gpxFile == null) {
                throw new BusinessException(ErrorCode.FILE_REQUIRED);
              }
              return GpxUploads.uploadedGpx(gpxFile);
            },
            gpxFile == null ? null : gpxFile.fileName());
    return Response.ok(resp).build();
  }
}
