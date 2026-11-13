package fr.pedalons.api.device;

import fr.pedalons.dto.device.response.DeviceRoutesResponse;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.service.device.DeviceRouteService;
import fr.pedalons.service.gps.GpsService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.io.InputStream;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.security.SecurityRequirement;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

/**
 * Unified routes API for device applications (Garmin, Karoo, etc.). Provides route listing, file
 * downloads, and cloud sync.
 */
@Path("/api/device/routes")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Device Routes", description = "Route management for device applications")
@SecurityRequirement(name = "bearerAuth")
public class DeviceRoutesResource {

  @Inject DeviceRouteService deviceRouteService;
  @Inject GpsService gpsService;

  @GET
  @RolesAllowed("user")
  @Operation(
      operationId = "deviceListRoutes",
      summary = "List routes for user",
      description =
          "Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest"
              + " routes from user's teams.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Routes list",
        content = @Content(schema = @Schema(implementation = DeviceRoutesResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public DeviceRoutesResponse getRoutes(
      @Parameter(description = "User's current latitude (for proximity sorting)") @QueryParam("lat")
          @Nullable Double lat,
      @Parameter(description = "User's current longitude (for proximity sorting)")
          @QueryParam("lon")
          @Nullable Double lon,
      @Parameter(
              description =
                  "Also return registeredStages, the upcoming stages of the trips the user is"
                      + " registered for. Off by default: a device that does not ask keeps the"
                      + " response it always had.")
          @QueryParam("stages")
          @DefaultValue("false")
          boolean stages) {
    return deviceRouteService.getRoutesForUser(lat, lon, stages);
  }

  @GET
  @Path("/{teamSlug}/{routeSlug}/fit")
  @RolesAllowed("user")
  @Produces("application/vnd.ant.fit")
  @Operation(
      operationId = "deviceDownloadFit",
      summary = "Download FIT file",
      description = "Download route as FIT file for GPS devices")
  @APIResponses({
    @APIResponse(responseCode = "200", description = "FIT file download"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Access denied",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response downloadFit(
      @Parameter(description = "Team URL slug", required = true) @PathParam("teamSlug")
          String teamSlug,
      @Parameter(description = "Route URL slug", required = true) @PathParam("routeSlug")
          String routeSlug) {

    InputStream fitContent = deviceRouteService.getFitContent(teamSlug, routeSlug);

    String fileName = safeFileName(routeSlug) + ".fit";
    return Response.ok(fitContent)
        .header("Content-Disposition", "attachment; filename=\"" + fileName + "\"")
        .header("Content-Type", "application/vnd.ant.fit")
        .build();
  }

  @GET
  @Path("/{teamSlug}/{routeSlug}/gpx")
  @RolesAllowed("user")
  @Produces("application/gpx+xml")
  @Operation(
      operationId = "deviceDownloadGpx",
      summary = "Download GPX file",
      description = "Download route as GPX file for GPS devices")
  @APIResponses({
    @APIResponse(responseCode = "200", description = "GPX file download"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Access denied",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response downloadGpx(
      @Parameter(description = "Team URL slug", required = true) @PathParam("teamSlug")
          String teamSlug,
      @Parameter(description = "Route URL slug", required = true) @PathParam("routeSlug")
          String routeSlug) {

    InputStream gpxContent = deviceRouteService.getGpxContent(teamSlug, routeSlug);

    String fileName = safeFileName(routeSlug) + ".gpx";
    return Response.ok(gpxContent)
        .header("Content-Disposition", "attachment; filename=\"" + fileName + "\"")
        .header("Content-Type", "application/gpx+xml")
        .build();
  }

  @POST
  @Path("/{teamSlug}/{routeSlug}/sync")
  @RolesAllowed("user")
  @Operation(
      operationId = "deviceSyncRoute",
      summary = "Sync route to cloud service",
      description = "Upload route to a cloud GPS service (e.g., Hammerhead, Garmin Connect, Wahoo)")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Route synced successfully",
        content = @Content(schema = @Schema(implementation = RouteUploadResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Not connected to GPS service or invalid type",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public RouteUploadResponse syncRoute(
      @Parameter(description = "Team slug", required = true) @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route slug", required = true) @PathParam("routeSlug")
          String routeSlug,
      @Parameter(description = "GPS service type (hammerhead, garmin, wahoo)", required = true)
          @QueryParam("type")
          String type) {

    GpsServiceType serviceType = parseGpsServiceType(type);
    return gpsService.uploadRoute(serviceType, teamSlug, routeSlug);
  }

  private GpsServiceType parseGpsServiceType(String type) {
    if (type == null) {
      throw new BadRequestException("GPS service type is required");
    }
    return switch (type.toLowerCase()) {
      case "hammerhead" -> GpsServiceType.HAMMERHEAD;
      case "garmin" -> GpsServiceType.GARMIN;
      case "wahoo" -> GpsServiceType.WAHOO;
      default -> throw new BadRequestException("Unknown GPS service type: " + type);
    };
  }

  /**
   * The slug as it goes into Content-Disposition: a real slug has nothing to replace, but the path
   * parameter is what the caller sent, and a quote would end the header's filename early
   * (docs/LEDGER_*.md SEC-22, audit L13).
   */
  private static String safeFileName(String slug) {
    return slug.replaceAll("[^a-zA-Z0-9._-]", "_");
  }
}
