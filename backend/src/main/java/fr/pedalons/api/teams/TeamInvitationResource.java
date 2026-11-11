package fr.pedalons.api.teams;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.teams.request.CreateInvitationRequest;
import fr.pedalons.dto.teams.response.TeamInvitationDto;
import fr.pedalons.dto.teams.response.TeamInvitationListResponse;
import fr.pedalons.enums.InvitationStatus;
import fr.pedalons.service.team.TeamInvitationService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.headers.Header;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

/**
 * A team's own invitations: send, list, revoke. All three are administrator-only.
 *
 * <p>They are gated on {@code USER_TEAM/CREATE} rather than on {@code LIST}, including the listing.
 * {@code LIST} now means "may read the member directory", which organisers and — once the team opens
 * it — ordinary members hold. Who has been invited and has not yet answered is a different question,
 * and it stays with the people who did the inviting.
 */
@Path("/api/teams/{teamSlug}/invitations")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Team Invitations", description = "Invite people to a team by e-mail")
public class TeamInvitationResource {

  @Inject TeamInvitationService invitationService;

  @POST
  @Operation(
      summary = "Invite an e-mail address",
      description =
          "Sends an invitation to join the team. The response is the same whether or not an account"
              + " already exists for the address — only the wording of the e-mail differs — because"
              + " answering differently would give anyone who administers a team an"
              + " account-existence probe for the whole domain. Re-inviting the same address is not"
              + " an error: the previous pending invitation is revoked and a fresh one issued,"
              + " which is how 'resend' works. Nobody becomes a member until they accept.")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Invitation created and sent",
        content = @Content(schema = @Schema(implementation = TeamInvitationDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid address, or the caller invited themselves (TEAM_INVITE_SELF)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Not a team administrator, or the team may not add members",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description =
            "The address already belongs to a member of this team (TEAM_INVITE_ALREADY_MEMBER), or"
                + " the team's tier caps its members and members plus pending invitations reach the"
                + " cap (TEAM_MEMBER_LIMIT_REACHED, with the cap and that count); a platform admin"
                + " is exempt",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "429",
        description = "Too many invitations sent recently",
        headers =
            @Header(
                name = "Retry-After",
                description = "Seconds to wait before retrying",
                schema = @Schema(type = SchemaType.INTEGER)),
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "500",
        description = "The invitation e-mail could not be delivered; nothing was recorded",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response invite(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Valid CreateInvitationRequest request) {
    TeamInvitationDto invitation = invitationService.invite(teamSlug, request);
    return Response.status(Response.Status.CREATED).entity(invitation).build();
  }

  @GET
  @Operation(
      summary = "List a team's invitations",
      description =
          "Administrators only. This is where a mistyped address shows up: since the creation call"
              + " cannot tell the admin that an address is unknown, the pending list is what makes"
              + " a typo visible and revocable.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Invitations retrieved",
        content = @Content(schema = @Schema(implementation = TeamInvitationListResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Not a team administrator",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response listInvitations(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Page number") @QueryParam("page") @DefaultValue("0") int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("20") int size,
      @Parameter(description = "Filter by status") @QueryParam("status")
          @Nullable InvitationStatus status) {
    return Response.ok(invitationService.listInvitations(teamSlug, page, size, status)).build();
  }

  @DELETE
  @Path("/{invitationId}")
  @Operation(
      summary = "Revoke an invitation",
      description =
          "Withdraws a pending invitation. This is also the recourse when an invitation should no"
              + " longer stand — the inviter having left the team, say — since acceptance does not"
              + " re-check who sent it.")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Invitation revoked"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Not a team administrator",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or invitation not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "The invitation has already been accepted, revoked or expired",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response revoke(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Invitation ID (TSID)") @PathParam("invitationId")
          String invitationId) {
    invitationService.revoke(teamSlug, invitationId);
    return Response.noContent().build();
  }
}
