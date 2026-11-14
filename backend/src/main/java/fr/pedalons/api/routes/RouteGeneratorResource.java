package fr.pedalons.api.routes;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.routes.request.RouteGeneratorRequest;
import fr.pedalons.dto.routes.response.RouteGeneratorResponse;
import fr.pedalons.service.route.network.RouteGeneratorService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.ws.rs.Consumes;
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

@Path("/api/teams/{teamSlug}/route-generator")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Route generator", description = "Routes made only of the roads a team already rides")
public class RouteGeneratorResource {

  @Inject RouteGeneratorService routeGeneratorService;

  @POST
  @Operation(
      operationId = "generateRoutes",
      summary = "Propose routes made of the team's own roads",
      description =
          "Proposes one to three routes, loops or one-way, whose every metre lies on a road that a"
              + " route of the team already rides. Same rights as the route planner: the caller"
              + " must be allowed to create routes in the team and the team must have its route"
              + " planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing"
              + " provider is called and no quota is drawn. Failures have their own codes, all 400:"
              + " GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no road of the team within 2"
              + " km), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL (with"
              + " RouteGeneratorNetworkDetails: also sent while the team's routes are still being"
              + " analysed) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes"
              + " (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503)"
              + " when the server has no free slot or the run took too long.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Routes proposed",
        content = @Content(schema = @Schema(implementation = RouteGeneratorResponse.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "Invalid request, planner disabled (ROUTE_PLANNER_DISABLED), or no route"
                + " (GENERATOR_START_TOO_FAR, GENERATOR_END_TOO_FAR, GENERATOR_DISTANCE_TOO_SHORT,"
                + " GENERATOR_NETWORK_TOO_SMALL, GENERATOR_NO_ROUTE)",
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
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "429",
        description =
            "Too many requests (ROUTE_GENERATOR_RATE_LIMITED); Retry-After gives the seconds",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "503",
        description = "No free slot, or time budget spent (ROUTE_GENERATOR_BUSY)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response generate(
      @PathParam("teamSlug") String teamSlug, @Valid @NotNull RouteGeneratorRequest request) {
    return Response.ok(routeGeneratorService.generate(teamSlug, request)).build();
  }
}
