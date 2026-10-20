package fr.pedalons.api.routes;

import fr.pedalons.api.gpx.GpxUploads;
import fr.pedalons.dto.common.CountResponse;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.routes.request.RouteFilterParams;
import fr.pedalons.dto.routes.request.RouteListParams;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.*;
import fr.pedalons.infrastructure.jaxrs.PedalonsMediaType;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.annotation.TileTokenAuth;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
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
 * REST API for route management.
 * Handles GPX upload, route CRUD, and file downloads.
 */
@Path("/api/teams/{teamSlug}/routes")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Routes", description = "GPX route management operations")
public class RouteResource {

  /**
   * The {@code ?tags=} filter, team-scoped only (docs/plans/archive/2026-10-01-tags.md D7): declared here
   * rather than on {@code RouteFilterParams}, which the cross-team endpoints share.
   */
  static final String TAGS_PARAM_DESCRIPTION =
      "Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags,"
          + " comma-separated or repeated. Unknown ids are ignored; a filter left with no known id"
          + " filters nothing.";

  /** Route payloads carry commentCount, which depends on who is asking. */
  static final String PRIVATE_NO_STORE = "private, no-store";

  @Inject RouteService routeService;

  /**
   * List routes for a team with filtering and sorting.
   */
  @GET
  @PermitAll
  @Operation(
      summary = "List routes",
      description = "Get paginated list of routes for a team with optional filters and sorting")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Routes retrieved successfully",
        content = @Content(schema = @Schema(implementation = RouteListResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
  })
  public Response listRoutes(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @BeanParam RouteListParams params,
      @Parameter(description = TAGS_PARAM_DESCRIPTION) @QueryParam("tags")
          @Nullable List<String> tags) {

    RouteListResponse routes =
        routeService.getRoutes(teamSlug, params.toBuilder().tags(tags).build());

    // Rows carry a per-user field (commentCount, which follows the caller's team
    // membership): never let a shared cache keep one user's answer for the next one.
    return Response.ok(routes).header(HttpHeaders.CACHE_CONTROL, PRIVATE_NO_STORE).build();
  }

  /**
   * How many routes the same filters match, without listing any.
   */
  @GET
  @PermitAll
  @Path("/count")
  @Operation(
      operationId = "countRoutes",
      summary = "Count routes",
      description =
          "How many of the team's routes match the filters, with none of them read. Accepts exactly"
              + " the same filters as the route list, minus sorting and pagination, so the figure"
              + " and the list it opens can never disagree. Meant for a filter sheet that wants to"
              + " announce its result count before the user commits to it.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Count computed successfully",
        content = @Content(schema = @Schema(implementation = CountResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
  })
  public Response countRoutes(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @BeanParam RouteFilterParams params,
      @Parameter(description = TAGS_PARAM_DESCRIPTION) @QueryParam("tags")
          @Nullable List<String> tags) {

    return Response.ok(routeService.countRoutes(teamSlug, params.toBuilder().tags(tags).build()))
        .build();
  }

  /**
   * Vector tile of a team's routes.
   */
  @GET
  @PermitAll
  @TileTokenAuth
  @Path("/tiles/{z}/{x}/{y}.mvt")
  @Produces(PedalonsMediaType.MAPBOX_VECTOR_TILE)
  @Operation(
      summary = "Team routes vector tile",
      description =
          "Mapbox vector tile holding the team's routes, layer 'routes'. Accepts the same filters"
              + " as the route list, minus sorting and pagination, which a tile has no use for."
              + " Fetched directly by the map renderer, outside the authenticated HTTP stack: a"
              + " browser authenticates with its session cookie, any other client with the 't'"
              + " tile token.")
  @APIResponses({
    @APIResponse(responseCode = "200", description = "Tile retrieved successfully"),
    @APIResponse(responseCode = "400", description = "Invalid tile coordinates"),
    @APIResponse(responseCode = "401", description = "Invalid or expired tile token"),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response routesTile(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Zoom level") @PathParam("z") int z,
      @Parameter(description = "Tile column") @PathParam("x") int x,
      @Parameter(description = "Tile row") @PathParam("y") int y,
      // Declared so the contract is honest and the generated clients expose it, but deliberately
      // unread here: TileTokenFilter consumes it before this method exists. Do not delete it as
      // "dead" — removing it would silently drop the parameter from the contract.
      @Parameter(
              description =
                  "Tile token from POST /api/tiles/token, for clients whose map renderer cannot"
                      + " carry an Authorization header. Omitted, the request falls back to the"
                      + " session cookie and then to the anonymous visitor.")
          @QueryParam("t")
          @Nullable String tileToken,
      @BeanParam RouteFilterParams params,
      @Parameter(description = TAGS_PARAM_DESCRIPTION) @QueryParam("tags")
          @Nullable List<String> tags) {

    return RouteTiles.response(
        routeService.getRoutesTile(teamSlug, params.toBuilder().tags(tags).build(), z, x, y));
  }

  /**
   * Bounding box of a team's routes.
   */
  @GET
  @PermitAll
  @Path("/bounds")
  @Operation(
      summary = "Team routes bounding box",
      description =
          "Extent enclosing the team's routes, so a map can open framed on them. Accepts the same"
              + " filters as the route list, minus sorting and pagination. Yields a null box when"
              + " no route matches.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Bounding box retrieved successfully",
        content = @Content(schema = @Schema(implementation = RouteBoundsResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getRoutesBounds(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @BeanParam RouteFilterParams params,
      @Parameter(description = TAGS_PARAM_DESCRIPTION) @QueryParam("tags")
          @Nullable List<String> tags) {

    return Response.ok(
            routeService.getRoutesBounds(teamSlug, params.toBuilder().tags(tags).build()))
        .build();
  }

  /**
   * Create a new route with GPX upload.
   * Uses multipart/form-data for file upload.
   */
  @POST
  @Consumes(MediaType.MULTIPART_FORM_DATA)
  @Operation(summary = "Create route", description = "Create a new route by uploading a GPX file")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Route created successfully",
        content = @Content(schema = @Schema(implementation = RouteDto.class))),
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
        description = "User is not a team member",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response createRoute(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @RestForm("route") @PartType(MediaType.APPLICATION_JSON) @Valid @NotNull
          RouteRequest routeRequest,
      @RestForm("gpxFile") @Nullable FileUpload gpxFile)
      throws Exception {

    RouteDto route =
        routeService.createRoute(teamSlug, routeRequest, GpxUploads.uploadedGpx(gpxFile));

    return Response.status(Response.Status.CREATED).entity(route).build();
  }

  /**
   * Get several routes' details at once.
   *
   * <p>Declared before {@code /{routeSlug}} so the literal path segment "bulk" is matched by this
   * method rather than captured as a route slug — JAX-RS scores a literal segment over a template
   * one regardless of declaration order, but the ordering is kept here too as documentation of that
   * fact. {@code SlugService} refuses to hand out "bulk" (and the other literal siblings of this
   * resource: "count", "bounds", "tiles") to a new or renamed route so this shadowing can never
   * strand one — see {@code SlugService.RESERVED_SLUGS}.
   */
  @GET
  @Path("/bulk")
  @PermitAll
  @Operation(
      operationId = "getRoutesBulk",
      summary = "Get several routes' details at once",
      description =
          "The detail of every requested 'slug' that exists and the caller may read, in one"
              + " round-trip — built for the screens that load several routes together (a ride's"
              + " stages, a comparison view), which would otherwise cost one request per route."
              + " Each row is exactly what the single-route endpoint returns, geometry included"
              + " (track surfaces too, read for the whole batch at once). Unknown slugs and slugs"
              + " the caller may not read are silently left out of the answer rather than failing"
              + " the whole batch. Set 'geometry' to false for the screens that only need each"
              + " route's name and figures. The response also carries the bounding box of the track"
              + " geometry actually sent back (waypoints are excluded, so an imported meeting-point"
              + " or car-park waypoint far off the track cannot widen it), so a map can frame the"
              + " batch without a second request.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Routes retrieved successfully",
        content = @Content(schema = @Schema(implementation = RoutesBulkResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "More than " + RouteService.MAX_BULK_SLUGS + " slugs requested",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
  })
  public Response getRoutesBulk(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(
              description =
                  "Route slug to include, repeatable. Capped at "
                      + RouteService.MAX_BULK_SLUGS
                      + "; unknown slugs and slugs the caller may not read are silently omitted"
                      + " from the response rather than erroring. Unlike GET /{routeSlug}, a slug"
                      + " that was renamed is also omitted rather than followed to the route's"
                      + " current slug: the single-route endpoint falls back to the rename"
                      + " history, this one does not. Same 'omit, never fail' contract as an"
                      + " unknown or unreadable slug, just for a different reason.")
          @QueryParam("slug")
          List<String> slugs,
      @Parameter(
              description =
                  "Whether to include each route's track geometry. False answers metadata only —"
                      + " name, distances, media, asset links — with an empty 'tracks' array and no"
                      + " 'extent', for the screens that name routes without drawing them.")
          @QueryParam("geometry")
          @DefaultValue("true")
          boolean geometry) {

    RoutesBulkResponse routes =
        routeService.getRoutesBulk(teamSlug, slugs == null ? List.of() : slugs, geometry);
    // Rows carry a per-user field (commentCount, which follows the caller's team
    // membership): never let a shared cache keep one user's answer for the next one.
    return Response.ok(routes).header(HttpHeaders.CACHE_CONTROL, PRIVATE_NO_STORE).build();
  }

  /**
   * Get route details by ID.
   */
  @GET
  @Path("/{routeSlug}")
  @PermitAll
  @Operation(
      summary = "Get route details",
      description =
          "Get detailed route information including GPS coordinates and statistics. The track is"
              + " returned exactly as stored — already resampled and Douglas-Peucker-filtered at"
              + " import, which lands it at roughly one point every 90 m. Every coordinate carries"
              + " longitude, latitude, elevation and cumulative distance in meters, so a client can"
              + " draw both the line and its elevation profile from this one payload.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Route retrieved successfully",
        content = @Content(schema = @Schema(implementation = RouteDetailDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
  })
  public Response getRoute(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route slug") @PathParam("routeSlug") String routeSlug) {

    RouteDetailDto route = routeService.getDto(teamSlug, routeSlug);
    // Rows carry a per-user field (commentCount, which follows the caller's team
    // membership): never let a shared cache keep one user's answer for the next one.
    return Response.ok(route).header(HttpHeaders.CACHE_CONTROL, PRIVATE_NO_STORE).build();
  }

  /**
   * List the rides and trips that use this route.
   */
  @GET
  @Path("/{routeSlug}/usages")
  @PermitAll
  @Operation(
      operationId = "getRouteUsages",
      summary = "List route usages",
      description =
          "Rides and trips that reference this route, directly or via a group/stage. Results are"
              + " visibility filtered for the caller.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Usages retrieved successfully",
        content = @Content(schema = @Schema(implementation = RouteUsagesResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
  })
  public Response getRouteUsages(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route slug") @PathParam("routeSlug") String routeSlug) {

    RouteUsagesResponse usages = routeService.getUsages(teamSlug, routeSlug);
    return Response.ok(usages).build();
  }

  /**
   * The editing state of the route planner, for the edit page only.
   */
  @GET
  @Path("/{routeSlug}/planner-state")
  @RolesAllowed("user")
  @Operation(
      operationId = "getRoutePlannerState",
      summary = "Get the planner state of a route",
      description =
          "The control points, routed pieces and imported ranges the route was last saved with,"
              + " for its edit page. Reserved to those who may edit the route. 'state' is absent"
              + " when there is none to read back (never saved with one, track replaced since by"
              + " a path that does not carry it, several tracks): the editor then opens the saved"
              + " track as an import.")
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
        description = "User is not authorized to update this route",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getRoutePlannerState(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route slug") @PathParam("routeSlug") String routeSlug) {
    return Response.ok(routeService.getPlannerState(teamSlug, routeSlug))
        .header(HttpHeaders.CACHE_CONTROL, PRIVATE_NO_STORE)
        .build();
  }

  /**
   * Update route metadata and optionally GPX file.
   */
  @PUT
  @Consumes(MediaType.MULTIPART_FORM_DATA)
  @Path("/{routeSlug}")
  @Operation(
      summary = "Update route",
      description =
          "Update route metadata (name, markdown, etc.) and optionally replace the GPX file. "
              + "If a new GPX file is provided, the old track data and climbs will be replaced.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Route updated successfully",
        content = @Content(schema = @Schema(implementation = RouteDto.class))),
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
        description = "User is not authorized to update this route",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response updateRoute(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route slug") @PathParam("routeSlug") String routeSlug,
      @RestForm("route") @PartType(MediaType.APPLICATION_JSON) @Valid @NotNull RouteRequest request,
      @RestForm("gpxFile") @Nullable FileUpload gpxFile) {

    RouteDto route =
        routeService.updateRoute(teamSlug, routeSlug, request, GpxUploads.uploadedGpx(gpxFile));
    return Response.ok(route).build();
  }

  /**
   * Delete route.
   */
  @DELETE
  @Path("/{routeSlug}")
  @Operation(
      summary = "Delete route",
      description = "Soft delete a route. Requires route creator or team admin permissions.")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Route deleted successfully"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to delete this route",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response deleteRoute(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route slug") @PathParam("routeSlug") String routeSlug) {

    routeService.deleteRoute(teamSlug, routeSlug);
    return Response.noContent().build();
  }

  @POST
  @Path("/{routeSlug}/undelete")
  @Operation(
      operationId = "undeleteRoute",
      summary = "Restore route",
      description =
          "Restore a soft-deleted route. Requires route creator or team admin permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Route restored successfully",
        content = @Content(schema = @Schema(implementation = RouteDetailDto.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to restore this route",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response undeleteRoute(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route slug") @PathParam("routeSlug") String routeSlug) {
    RouteDetailDto dto = routeService.undeleteRoute(teamSlug, routeSlug);
    return Response.ok(dto).build();
  }

  @PATCH
  @Path("/{routeSlug}/slug")
  @Operation(
      operationId = "changeRouteSlug",
      summary = "Change route slug",
      description = "Change route URL slug. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Slug changed successfully",
        content = @Content(schema = @Schema(implementation = RouteDetailDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid slug format",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to change this route's slug",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "Slug already in use",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response changeSlug(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Current route URL slug") @PathParam("routeSlug") String currentSlug,
      @Valid SlugChangeRequest request) {

    RouteDetailDto route = routeService.updateSlug(teamSlug, currentSlug, request.slug());
    return Response.ok(route).build();
  }
}
