package fr.pedalons.api.routes;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.routes.request.RouteRetouchRequest;
import fr.pedalons.dto.routes.response.RouteRetouchOfferDto;
import fr.pedalons.dto.routes.response.RouteRetouchResponse;
import fr.pedalons.service.route.network.RouteRetouchService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

@Path("/api/teams/{teamSlug}/routes/{routeSlug}/retouch")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Route generator", description = "Routes that favour the roads a team already rides")
public class RouteRetouchResource {

  @Inject RouteRetouchService routeRetouchService;

  @GET
  @Operation(
      operationId = "getRouteRetouchOffer",
      summary = "Whether a route can be retouched by the caller, and within which bounds",
      description =
          "Answers 200 whatever the outcome: `available` and, when not, `unavailableReason`"
              + " (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the"
              + " route's analysis is not finished, show the action disabled). The offer comes from"
              + " the engine's capabilities (a generator engine that cannot edit offers nothing)"
              + " and from the head of the route's stored documents: nothing is computed, the"
              + " engine is not called and no request is counted. The route must be readable by the"
              + " caller (404 otherwise).")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "The offer",
        content = @Content(schema = @Schema(implementation = RouteRetouchOfferDto.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or route not found, or not readable by the caller",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response offer(
      @PathParam("teamSlug") String teamSlug, @PathParam("routeSlug") String routeSlug) {
    return Response.ok(routeRetouchService.offer(teamSlug, routeSlug)).build();
  }

  @POST
  @Operation(
      operationId = "retouchRoute",
      summary = "Propose changes to a saved route: a total distance, or a new finish",
      description =
          "Proposes one to three routes that change ONE stretch of the saved route and keep the"
              + " rest as it was drawn, by asking the route generator's engine (osm-route-details):"
              + " `targetDistanceKm` aims at a total distance (within the offer's bounds, 30"
              + " percent of the route at most), `end` moves the finish (a point, or a place of the"
              + " team); exactly one of the two. Each proposal carries the whole polyline and the"
              + " indices of the stretch that changed. Ascent and descent come from the same"
              + " profile for the original (`originalAscentM`) and the proposals. Nothing is"
              + " stored, no quota is drawn: the proposal is opened in the planner as a new route."
              + " Same rights as the route planner plus reading the route; the route's street edges"
              + " must be computed for its current track (ROUTE_RETOUCH_NOT_READY otherwise:"
              + " nothing is computed on the fly). Refusals are answers, all 400:"
              + " ROUTE_RETOUCH_NO_SHORTER (shortening fails about four times in ten, a normal"
              + " case), ROUTE_RETOUCH_NO_PROPOSAL, ROUTE_RETOUCH_ORDER_ANOMALY (about one track in"
              + " twenty), ROUTE_RETOUCH_CHANGE_TOO_SMALL, ROUTE_RETOUCH_CHANGE_TOO_LARGE,"
              + " ROUTE_RETOUCH_END_UNREACHABLE, ROUTE_RETOUCH_UNSUPPORTED,"
              + " ROUTE_RETOUCH_NOT_READY, GENERATOR_END_TOO_FAR, GENERATOR_OUT_OF_COVERAGE. The 30"
              + " requests per 15 minutes of the route generator are shared"
              + " (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503),"
              + " GENERATOR_UNAVAILABLE (503, also when the engine does not announce route edits:"
              + " nothing is sent to it).")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Proposals",
        content = @Content(schema = @Schema(implementation = RouteRetouchResponse.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "Invalid request, planner disabled (ROUTE_PLANNER_DISABLED), or a refusal"
                + " (ROUTE_RETOUCH_*, GENERATOR_END_TOO_FAR, GENERATOR_OUT_OF_COVERAGE)",
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
        description = "Team or route not found, or not readable by the caller",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "429",
        description =
            "Too many requests (ROUTE_GENERATOR_RATE_LIMITED); Retry-After gives the seconds",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "503",
        description =
            "The engine has no free slot or took too long (ROUTE_GENERATOR_BUSY), or is off,"
                + " unreachable or cannot edit (GENERATOR_UNAVAILABLE)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response retouch(
      @PathParam("teamSlug") String teamSlug,
      @PathParam("routeSlug") String routeSlug,
      @Valid @NotNull RouteRetouchRequest request) {
    return Response.ok(routeRetouchService.retouch(teamSlug, routeSlug, request)).build();
  }
}
