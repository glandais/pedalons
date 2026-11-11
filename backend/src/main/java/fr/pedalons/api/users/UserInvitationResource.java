package fr.pedalons.api.users;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.teams.response.MemberDto;
import fr.pedalons.dto.teams.response.MyInvitationListResponse;
import fr.pedalons.service.team.TeamInvitationService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
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

/**
 * The invitations waiting for the signed-in user.
 *
 * <p>This is what catches the one case the token link does not: someone invited before they had an
 * account, who then signs up through the ordinary form rather than by clicking the link. No
 * membership is ever created automatically at sign-up — signing up is not joining a team, and with
 * two invitations waiting there would be nothing to choose between them — so they wait here.
 */
@Path("/api/users/me/invitations")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Invitations", description = "Redeem a team invitation")
public class UserInvitationResource {

  @Inject TeamInvitationService invitationService;

  @GET
  @Operation(
      operationId = "listMyInvitations",
      summary = "My pending invitations",
      description =
          "Live invitations addressed to the current user, newest first. Teams they already belong"
              + " to are left out.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Invitations retrieved",
        content = @Content(schema = @Schema(implementation = MyInvitationListResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response listMine() {
    return Response.ok(invitationService.listMine()).build();
  }

  @POST
  @Path("/{invitationId}/accept")
  @Operation(
      operationId = "acceptMyInvitation",
      summary = "Accept one of my invitations",
      description = "Same effect as redeeming the token, for an invitation reached from this list.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Joined, or already a member",
        content = @Content(schema = @Schema(implementation = MemberDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invitation expired, revoked or already used",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "The invitation is addressed to someone else",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Invitation not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description =
            "The team's tier caps its members and the cap is reached since the invitation was sent"
                + " (TEAM_MEMBER_LIMIT_REACHED, with the cap and the member count); the invitation"
                + " stays pending",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response acceptMine(
      @Parameter(description = "Invitation ID (TSID)") @PathParam("invitationId")
          String invitationId) {
    return Response.ok(invitationService.acceptMine(invitationId)).build();
  }
}
