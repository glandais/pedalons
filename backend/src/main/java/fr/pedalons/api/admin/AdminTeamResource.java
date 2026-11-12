package fr.pedalons.api.admin;

import fr.pedalons.dto.admin.AdminTeamAttributesRequest;
import fr.pedalons.dto.admin.AdminTeamDto;
import fr.pedalons.dto.admin.AdminTeamListResponse;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.enums.TeamTier;
import fr.pedalons.service.admin.AdminTeamService;
import fr.pedalons.service.security.annotation.Admin;
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

@Path("/api/admin/teams")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Admin - Teams", description = "Platform admin team management")
public class AdminTeamResource {

  @Inject AdminTeamService adminTeamService;

  @GET
  @Admin
  @Operation(
      operationId = "adminListTeams",
      summary = "List all teams",
      description = "Get a paginated list of all teams")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Teams retrieved successfully",
        content = @Content(schema = @Schema(implementation = AdminTeamListResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response listTeams(
      @Parameter(description = "Filter by domain ID") @QueryParam("domainId")
          @Nullable String domainId,
      @Parameter(description = "Filter by tier: the free teams, to unlock one; the unlocked ones")
          @QueryParam("tier")
          @Nullable TeamTier tier,
      @Parameter(description = "Page number (0-indexed)") @QueryParam("page") @DefaultValue("0")
          int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("20") int size) {

    PedalonsPage<AdminTeamDto> result = adminTeamService.listTeams(domainId, tier, page, size);
    AdminTeamListResponse response =
        new AdminTeamListResponse(result.items(), result.total(), page, size);
    return Response.ok(response).build();
  }

  @GET
  @Path("/{teamId}")
  @Admin
  @Operation(
      operationId = "adminGetTeam",
      summary = "Get team details",
      description = "Get detailed team information")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Team retrieved successfully",
        content = @Content(schema = @Schema(implementation = AdminTeamDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getTeam(@Parameter(description = "Team ID") @PathParam("teamId") String teamId) {

    AdminTeamDto team = adminTeamService.getTeam(teamId);
    return Response.ok(team).build();
  }

  @PATCH
  @Path("/{teamId}/attributes")
  @Admin
  @Operation(
      operationId = "adminUpdateTeamAttributes",
      summary = "Update team governance attributes",
      description = "Update platform-controlled team governance attributes")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Team attributes updated successfully",
        content = @Content(schema = @Schema(implementation = AdminTeamDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response updateTeamAttributes(
      @Parameter(description = "Team ID") @PathParam("teamId") String teamId,
      @Valid AdminTeamAttributesRequest request) {

    AdminTeamDto team = adminTeamService.updateTeamAttributes(teamId, request);
    return Response.ok(team).build();
  }

  @POST
  @Path("/{teamId}/toggle-deleted")
  @Admin
  @Operation(
      operationId = "adminToggleTeamDeleted",
      summary = "Toggle team deleted",
      description = "Toggle team soft-delete status (archive/restore)")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Team deleted status toggled successfully",
        content = @Content(schema = @Schema(implementation = AdminTeamDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Forbidden - not a platform admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response toggleTeamDeleted(
      @Parameter(description = "Team ID") @PathParam("teamId") String teamId) {

    AdminTeamDto team = adminTeamService.toggleTeamDeleted(teamId);
    return Response.ok(team).build();
  }
}
