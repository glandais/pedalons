package fr.pedalons.api.gpx;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.dto.gpx.request.GpxPreviewFromPointsRequest;
import fr.pedalons.dto.gpx.request.GpxPreviewUpdateRequest;
import fr.pedalons.dto.gpx.response.GpxPreviewDto;
import fr.pedalons.dto.gpx.response.GpxPreviewListResponse;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.PlannerStateResponse;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.route.GpxLimits;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jboss.resteasy.reactive.PartType;
import org.jboss.resteasy.reactive.RestForm;
import org.jboss.resteasy.reactive.multipart.FileUpload;
import org.jspecify.annotations.Nullable;

/**
 * REST API for the GPX tools page: analyse a GPX file without attaching it to a team.
 */
@Path("/api/gpx-previews")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "GPX previews", description = "Analyse a GPX file outside of any team")
public class GpxPreviewResource {

  @Inject GpxPreviewService gpxPreviewService;

  @POST
  @Consumes(MediaType.MULTIPART_FORM_DATA)
  @Operation(
      summary = "Analyse a GPX file",
      description =
          "Uploads a GPX file, runs the elevation and climb pipeline, and stores the result under"
              + " an unguessable identifier for 30 days")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "GPX analysed successfully",
        content = @Content(schema = @Schema(implementation = GpxPreviewDto.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "Missing, oversized (FILE_TOO_LARGE), too long (GPX_TOO_LONG) or unparseable GPX file",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response createPreview(@RestForm("gpxFile") @Nullable FileUpload gpxFile) {
    if (gpxFile == null) {
      throw new BusinessException(ErrorCode.FILE_REQUIRED);
    }
    GpxPreviewDto preview =
        gpxPreviewService.createPreview(GpxUploads.uploadedGpx(gpxFile), gpxFile.fileName());
    return Response.status(Response.Status.CREATED).entity(preview).build();
  }

  @POST
  @Path("/merge")
  @Consumes(MediaType.MULTIPART_FORM_DATA)
  @Operation(
      summary = "Merge several GPX files into one analysed GPX file",
      description =
          "Uploads 2 to 10 GPX files (10 MB together at most) and merges all their tracks into a"
              + " single track, choosing the order of the tracks and the direction each one is"
              + " ridden in so that the summed straight-line gaps between them are as short as"
              + " possible. The result then runs the same pipeline as a single upload and is stored"
              + " the same way, for 30 days")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "GPX files merged and analysed successfully",
        content = @Content(schema = @Schema(implementation = GpxPreviewDto.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "No file (FILE_REQUIRED), fewer than 2 or more than 10 files (GPX_MERGE_FILE_COUNT),"
                + " more than 16 tracks together (GPX_MERGE_TOO_MANY_TRACKS), a file without any"
                + " point (GPX_EMPTY), oversized — one file or all of them together over 10 MB"
                + " (FILE_TOO_LARGE), too long (GPX_TOO_LONG) or"
                + " unparseable (GPX_FAILURE)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response mergePreviews(@RestForm("gpxFiles") @Nullable List<FileUpload> gpxFiles) {
    if (gpxFiles == null || gpxFiles.isEmpty()) {
      throw new BusinessException(ErrorCode.FILE_REQUIRED);
    }
    if (gpxFiles.size() > GpxLimits.MAX_MERGE_FILES) {
      // Refused before any file is touched; the service checks the lower bound too.
      throw new BusinessException(ErrorCode.GPX_MERGE_FILE_COUNT);
    }
    long totalSize = 0;
    for (FileUpload upload : gpxFiles) {
      totalSize += upload.size();
    }
    if (totalSize > GpxLimits.MAX_MERGE_TOTAL_BYTES) {
      // All the files together are bound like a single upload (SEC-6), before any of them is read.
      throw new BusinessException(ErrorCode.FILE_TOO_LARGE);
    }
    List<java.nio.file.Path> paths = new ArrayList<>();
    List<@Nullable String> fileNames = new ArrayList<>();
    for (FileUpload upload : gpxFiles) {
      paths.add(GpxUploads.uploadedGpx(upload));
      fileNames.add(upload.fileName());
    }
    GpxPreviewDto preview = gpxPreviewService.createMergedPreview(paths, fileNames);
    return Response.status(Response.Status.CREATED).entity(preview).build();
  }

  @POST
  @Path("/from-points")
  @Operation(
      summary = "Create an analysed GPX file from planner points",
      description =
          "Builds a preview from a route drawn with the planner (no GPX file; drawn = true), runs"
              + " the elevation and climb pipeline, and stores the result under an unguessable"
              + " identifier for 30 days")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Preview created successfully",
        content = @Content(schema = @Schema(implementation = GpxPreviewDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response createPreviewFromPoints(@Valid @NotNull GpxPreviewFromPointsRequest request) {
    GpxPreviewDto preview =
        gpxPreviewService.createPreviewFromPoints(
            request.name(), request.points(), request.plannerState());
    return Response.status(Response.Status.CREATED).entity(preview).build();
  }

  @GET
  @Operation(
      summary = "List the current user's analysed GPX files",
      description =
          "Returns the current user's previews still within the 30-day retention window, most"
              + " recent first")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Previews listed successfully",
        content = @Content(schema = @Schema(implementation = GpxPreviewListResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public GpxPreviewListResponse listMyPreviews(
      @Parameter(description = "Zero-based page number") @QueryParam("page") @DefaultValue("0")
          int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("20") int size) {
    return gpxPreviewService.listMine(page, size);
  }

  @GET
  @Path("/{previewId}")
  @Operation(
      summary = "Get an analysed GPX file",
      description =
          "Anyone holding the link may read the preview: the unguessable identifier is what grants"
              + " access. Creating and deleting require an account.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Preview retrieved successfully",
        content = @Content(schema = @Schema(implementation = GpxPreviewDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @PermitAll
  public GpxPreviewDto getPreview(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId) {
    return gpxPreviewService.getPreview(previewId);
  }

  @GET
  @Path("/{previewId}/planner-state")
  @Operation(
      operationId = "getPreviewPlannerState",
      summary = "Get the planner state of an analysed GPX file",
      description =
          "The control points, routed pieces and imported ranges the preview was last saved with,"
              + " for its edit page. Only the creator may read it. 'state' is absent when there is"
              + " none to read back.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "State retrieved (or absent)",
        content = @Content(schema = @Schema(implementation = PlannerStateResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not the creator",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response getPlannerState(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId) {
    return Response.ok(gpxPreviewService.getPlannerState(previewId))
        .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
        .build();
  }

  @GET
  @Path("/{previewId}/thumbnail/{size}")
  @Operation(hidden = true)
  @APIResponses({
    @APIResponse(responseCode = "200", description = "Thumbnail image"),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found, expired, or has no thumbnail",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @PermitAll
  public Response getThumbnail(
      @HeaderParam("Accept") String accept,
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId,
      @Parameter(description = "Requested square size in pixels") @PathParam("size") int size) {
    return gpxPreviewService.getThumbnail(previewId, size, accept);
  }

  @GET
  @Path("/{previewId}/gpx")
  @Produces("application/gpx+xml")
  @Operation(hidden = true)
  @APIResponses({
    @APIResponse(responseCode = "200", description = "GPX file"),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @PermitAll
  public Response downloadGpx(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId) {
    return gpxPreviewService.downloadGpx(previewId);
  }

  @GET
  @Path("/{previewId}/fit")
  @Produces("application/vnd.ant.fit")
  @Operation(hidden = true)
  @APIResponses({
    @APIResponse(responseCode = "200", description = "FIT file"),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @PermitAll
  public Response downloadFit(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId) {
    return gpxPreviewService.downloadFit(previewId);
  }

  @PUT
  @Path("/{previewId}")
  @Consumes(MediaType.MULTIPART_FORM_DATA)
  @Operation(
      summary = "Update an analysed GPX file",
      description =
          "Rename the preview and, when a new GPX file or planner points are provided, replay the"
              + " pipeline to replace its track. Only the creator may edit.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Preview updated successfully",
        content = @Content(schema = @Schema(implementation = GpxPreviewDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request or GPX file",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not the creator",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public GpxPreviewDto updatePreview(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId,
      @RestForm("preview") @PartType(MediaType.APPLICATION_JSON) @Valid @NotNull
          GpxPreviewUpdateRequest request,
      @RestForm("gpxFile") @Nullable FileUpload gpxFile) {
    return gpxPreviewService.updatePreview(
        previewId,
        request.name(),
        GpxUploads.uploadedGpx(gpxFile),
        request.points(),
        request.plannerState());
  }

  @DELETE
  @Path("/{previewId}")
  @Operation(summary = "Delete an analysed GPX file", description = "Only the creator may delete")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Preview deleted successfully"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not the creator",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response deletePreview(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId) {
    gpxPreviewService.delete(previewId);
    return Response.noContent().build();
  }

  @POST
  @Path("/{previewId}/gps/{serviceType}")
  @Operation(
      summary = "Send an analysed GPX file to a GPS service",
      description =
          "Uploads the preview to the current user's connected Garmin, Hammerhead or Wahoo")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Upload completed",
        content = @Content(schema = @Schema(implementation = RouteUploadResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "GPS service not connected",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Preview not found or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public RouteUploadResponse uploadToGpsService(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId,
      @Parameter(description = "GPS service type") @PathParam("serviceType")
          GpsServiceType serviceType) {
    return gpxPreviewService.uploadToGpsService(previewId, serviceType);
  }

  @POST
  @Path("/{previewId}/routes/{teamSlug}")
  @Operation(
      summary = "Save an analysed GPX file as a route",
      description =
          "Creates a team route from the preview's original upload. A preview that was drawn in the"
              + " route planner (drawn = true) is refused with ROUTE_PLANNER_DISABLED when the team"
              + " has no route planner; an imported GPX file can become a route of any team.")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Route created successfully",
        content = @Content(schema = @Schema(implementation = RouteDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request, or drawn preview and team without route planner",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not a team member",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Preview or team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response createRouteFromPreview(
      @Parameter(description = "Public preview identifier") @PathParam("previewId")
          String previewId,
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Valid @NotNull RouteRequest request) {
    RouteDto route = gpxPreviewService.createRoute(previewId, teamSlug, request);
    return Response.status(Response.Status.CREATED).entity(route).build();
  }
}
