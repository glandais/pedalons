package fr.pedalons.api.teams;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.teams.request.AddMemberRequest;
import fr.pedalons.dto.teams.request.UpdateMemberRoleRequest;
import fr.pedalons.dto.teams.response.MemberDto;
import fr.pedalons.dto.teams.response.MemberListResponse;
import fr.pedalons.enums.MemberSortBy;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.service.team.TeamMembershipService;
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

@Path("/api/teams/{teamSlug}/members")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Team Members", description = "Team membership management operations")
public class TeamMemberResource {

  @Inject TeamMembershipService membershipService;

  @GET
  @Operation(
      summary = "Get team members",
      description =
          "Paginated list of team members. Administrators always see it; so do organisers, who need"
              + " a member list to designate a ride group's leader. Everyone else needs the team to"
              + " have set enableMemberDirectory. What is returned is graded too: 'role' and"
              + " 'joinedAt' are null unless the caller is an administrator or the directory is"
              + " open, 'search' only matches an e-mail address for an administrator, and 'role' is"
              + " refused with a 403 to a caller who does not get the roles.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Members retrieved successfully",
        content = @Content(schema = @Schema(implementation = MemberListResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description =
            "Not entitled to read this team's member directory, or to filter it by a role the"
                + " response would hide",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response getMembers(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Page number") @QueryParam("page") @DefaultValue("0") int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("50") int size,
      @Parameter(
              description =
                  "Search by display name. Also matches the e-mail address, for administrators"
                      + " only.")
          @QueryParam("search")
          @Nullable String search,
      @Parameter(
              description =
                  "Filter by role. Only for a caller who gets the roles (an administrator, or"
                      + " anyone once the directory is open): 403 otherwise.")
          @QueryParam("role")
          @Nullable TeamRole role,
      @Parameter(
              description =
                  "Order of the list, always ended by the membership id so pages never overlap."
                      + " NAME is the display name, regardless of case. JOINED_AT is the join date;"
                      + " only for a caller who gets the join dates (an administrator, or anyone"
                      + " once the directory is open): 403 otherwise. Omitted, NAME.")
          @QueryParam("sortBy")
          @Nullable MemberSortBy sortBy,
      @Parameter(
              description =
                  "Direction of sortBy. Omitted is ASC (A to Z) for NAME, and DESC (newest first)"
                      + " for JOINED_AT.")
          @QueryParam("sortDir")
          @Nullable SortDirection sortDir) {

    MemberListResponse members =
        membershipService.getTeamMembers(teamSlug, page, size, search, role, sortBy, sortDir);
    return Response.ok(members).build();
  }

  @POST
  @Path("/join")
  @Operation(summary = "Join team", description = "Request to join a team")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Successfully joined team",
        content = @Content(schema = @Schema(implementation = MemberDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Team is full or user is already a member",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description =
            "Already a member (ALREADY_REGISTERED), or the team's tier caps its members and the cap"
                + " is reached (TEAM_MEMBER_LIMIT_REACHED, with the cap and the member count)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response joinTeam(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug) {

    MemberDto membership = membershipService.joinTeam(teamSlug);
    return Response.status(Response.Status.CREATED).entity(membership).build();
  }

  @POST
  @Path("/leave")
  @Operation(summary = "Leave team", description = "Leave a team")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Successfully left team"),
    @APIResponse(
        responseCode = "400",
        description = "Cannot leave - user is the owner",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found or user is not a member",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response leaveTeam(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug) {

    membershipService.leaveTeam(teamSlug);
    return Response.noContent().build();
  }

  @POST
  @Operation(
      summary = "Add team member",
      description = "Add a member to the team. Requires ADMIN role on team.")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Member added successfully",
        content = @Content(schema = @Schema(implementation = MemberDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request or user already a member",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description =
            "Already a member (ALREADY_REGISTERED), or the team's tier caps its members and the cap"
                + " is reached (TEAM_MEMBER_LIMIT_REACHED, with the cap and the member count); a"
                + " platform admin is exempt",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not a team admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or user not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
  })
  @RolesAllowed("user")
  public Response addMember(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Valid AddMemberRequest request) {
    TeamRole role = request.role() != null ? request.role() : TeamRole.MEMBER;
    Long targetUserId = TsidUtils.toLong(request.userId());
    MemberDto membership = membershipService.addMember(teamSlug, targetUserId, role);

    return Response.status(Response.Status.CREATED).entity(membership).build();
  }

  @PUT
  @Path("/{memberId}")
  @Operation(
      summary = "Update member role",
      description = "Update a team member's role. Requires ADMIN role.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Role updated successfully",
        content = @Content(schema = @Schema(implementation = MemberDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not a team admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or member not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response updateMemberRole(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Member user ID (TSID)") @PathParam("memberId") String memberId,
      @Valid UpdateMemberRoleRequest request) {
    MemberDto membership =
        membershipService.updateMemberRole(teamSlug, TsidUtils.toLong(memberId), request.role());
    return Response.ok(membership).build();
  }

  @DELETE
  @Path("/{memberId}")
  @Operation(
      summary = "Remove team member",
      description = "Remove a member from the team. Requires ADMIN role.")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Member removed successfully"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not a team admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or member not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response removeMember(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Member user ID (TSID)") @PathParam("memberId") String memberId) {
    membershipService.removeMember(teamSlug, TsidUtils.toLong(memberId));
    return Response.noContent().build();
  }
}
