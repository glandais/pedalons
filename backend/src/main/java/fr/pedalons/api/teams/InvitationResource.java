package fr.pedalons.api.teams;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.teams.request.AcceptInvitationRequest;
import fr.pedalons.dto.teams.response.InvitationPreviewDto;
import fr.pedalons.dto.teams.response.MemberDto;
import fr.pedalons.service.team.TeamInvitationService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/**
 * Redeeming an invitation, from the invitee's side.
 *
 * <p>Outside the {@code /api/teams/{teamSlug}} tree on purpose: the token already names its team,
 * and {@code @CheckAccess} reads the slug from the first argument of the service method, so there
 * would be nothing for it to read anyway.
 */
@Path("/api/invitations")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Invitations", description = "Redeem a team invitation")
public class InvitationResource {

  @Inject TeamInvitationService invitationService;

  @POST
  @Path("/preview")
  @Operation(
      summary = "Read an invitation",
      description =
          "What the invitation says, for whoever holds its token. Public, because an invitation"
              + " opened in a signed-out browser has to be able to name the team and the person"
              + " inviting — otherwise the page can only show a bare login form with no explanation"
              + " of why. Nothing here goes beyond what the e-mail already said, and the invited"
              + " address comes back masked.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Invitation found",
        content = @Content(schema = @Schema(implementation = InvitationPreviewDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Unknown or malformed token (TEAM_INVITE_INVALID)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @PermitAll
  public Response preview(@Valid AcceptInvitationRequest request) {
    return Response.ok(invitationService.preview(request.token())).build();
  }

  @POST
  @Path("/accept")
  @Operation(
      summary = "Accept an invitation",
      description =
          "Joins the team the token names. Requires a session: accepting is consenting, and a"
              + " consent attaches to an account — a public accept handing back a session would"
              + " make the invitation link a login credential. Idempotent: replaying it, or"
              + " accepting when already a member, returns the existing membership without changing"
              + " its role, so an invitation as MEMBER never demotes an administrator.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Joined, or already a member",
        content = @Content(schema = @Schema(implementation = MemberDto.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "Invitation unknown, expired, revoked or already used (TEAM_INVITE_INVALID /"
                + " _EXPIRED / _REVOKED / _ALREADY_USED)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description =
            "Signed in as someone else (TEAM_INVITE_EMAIL_MISMATCH), or the account's address is"
                + " unverified (EMAIL_NOT_VERIFIED)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description =
            "The team's tier caps its members and the cap is reached since the invitation was sent"
                + " (TEAM_MEMBER_LIMIT_REACHED, with the cap and the member count); the invitation"
                + " stays pending",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response accept(@Valid AcceptInvitationRequest request) {
    return Response.ok(invitationService.accept(request.token())).build();
  }
}
