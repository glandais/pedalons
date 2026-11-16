package fr.pedalons.api.pages;

import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.pages.request.ReorderPagesRequest;
import fr.pedalons.dto.pages.request.TeamPageRequest;
import fr.pedalons.dto.pages.response.TeamPageDto;
import fr.pedalons.dto.pages.response.TeamPageSummaryDto;
import fr.pedalons.service.page.TeamPageService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
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

@Path("/api/teams/{teamSlug}/pages")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Team Pages", description = "Team page management operations")
public class TeamPageResource {

  @Inject TeamPageService teamPageService;

  @GET
  @PermitAll
  @Operation(summary = "List team pages", description = "Get list of additional pages for a team")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Pages retrieved successfully",
        content = @Content(schema = @Schema(implementation = TeamPageSummaryDto[].class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response listPages(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug) {

    List<TeamPageSummaryDto> pages = teamPageService.listPages(teamSlug);
    return Response.ok(pages).build();
  }

  @GET
  @Path("/{pageSlug}")
  @PermitAll
  @Operation(summary = "Get page details", description = "Get detailed page information")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Page retrieved successfully",
        content = @Content(schema = @Schema(implementation = TeamPageDto.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to view this page",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or page not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getPage(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Page URL slug") @PathParam("pageSlug") String pageSlug) {

    TeamPageDto page = teamPageService.getDto(teamSlug, pageSlug);
    return Response.ok(page).build();
  }

  @POST
  @Operation(
      summary = "Create page",
      description =
          "Create a new team page. Requires admin permissions. Maximum 3 additional pages per"
              + " team.")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Page created successfully",
        content = @Content(schema = @Schema(implementation = TeamPageDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid request or maximum pages reached",
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
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response createPage(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Valid TeamPageRequest request) {

    TeamPageDto page = teamPageService.createPage(teamSlug, request);
    return Response.status(Response.Status.CREATED).entity(page).build();
  }

  @PUT
  @Path("/{pageSlug}")
  @Operation(
      summary = "Update page",
      description = "Update page information. Requires admin permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Page updated successfully",
        content = @Content(schema = @Schema(implementation = TeamPageDto.class))),
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
        description = "Team or page not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response updatePage(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Page URL slug") @PathParam("pageSlug") String pageSlug,
      @Valid TeamPageRequest request) {

    TeamPageDto updatedPage = teamPageService.updatePage(teamSlug, pageSlug, request);
    return Response.ok(updatedPage).build();
  }

  @DELETE
  @Path("/{pageSlug}")
  @Operation(
      summary = "Delete page",
      description = "Delete a team page. Requires admin permissions.")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Page deleted successfully"),
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
        description = "Team or page not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response deletePage(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Page URL slug") @PathParam("pageSlug") String pageSlug) {

    teamPageService.deletePage(teamSlug, pageSlug);
    return Response.noContent().build();
  }

  @POST
  @Path("/{pageSlug}/undelete")
  @Operation(
      operationId = "undeletePage",
      summary = "Restore page",
      description = "Restore a soft-deleted team page. Requires admin permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Page restored successfully",
        content = @Content(schema = @Schema(implementation = TeamPageDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Maximum pages reached",
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
        description = "Team or page not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response undeletePage(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Page URL slug") @PathParam("pageSlug") String pageSlug) {
    TeamPageDto dto = teamPageService.undeletePage(teamSlug, pageSlug);
    return Response.ok(dto).build();
  }

  @PUT
  @Path("/reorder")
  @Operation(
      summary = "Reorder pages",
      description = "Reorder team pages. Requires admin permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Pages reordered successfully",
        content = @Content(schema = @Schema(implementation = TeamPageSummaryDto[].class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid page IDs",
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
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response reorderPages(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Valid ReorderPagesRequest request) {

    List<TeamPageSummaryDto> pages = teamPageService.reorderPages(teamSlug, request);
    return Response.ok(pages).build();
  }

  @PATCH
  @Path("/{pageSlug}/slug")
  @Operation(
      operationId = "changePageSlug",
      summary = "Change page slug",
      description = "Change page URL slug. Requires admin permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Slug changed successfully",
        content = @Content(schema = @Schema(implementation = TeamPageDto.class))),
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
        description = "User is not a team admin",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or page not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "Slug already in use",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response changeSlug(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Current page URL slug") @PathParam("pageSlug") String currentSlug,
      @Valid SlugChangeRequest request) {

    TeamPageDto page = teamPageService.updateSlug(teamSlug, currentSlug, request.slug());
    return Response.ok(page).build();
  }
}
