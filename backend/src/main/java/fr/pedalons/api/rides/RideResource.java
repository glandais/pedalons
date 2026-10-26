package fr.pedalons.api.rides;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.common.request.StatusChangeRequest;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.rides.request.*;
import fr.pedalons.dto.rides.response.*;
import fr.pedalons.dto.users.response.ParticipantListResponse;
import fr.pedalons.dto.weather.response.RideWeatherAnswer;
import fr.pedalons.dto.weather.response.RideWeatherDto;
import fr.pedalons.service.calendar.PublicationIcsService;
import fr.pedalons.service.ride.RideService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.EntityTag;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Request;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

@Path("/api/teams/{teamSlug}/rides")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Rides", description = "Ride management and participation operations")
public class RideResource {

  @Inject RideService rideService;
  @Inject PublicationIcsService publicationIcsService;

  @POST
  @Operation(summary = "Create ride", description = "Create a new ride with optional groups")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Ride created successfully",
        content = @Content(schema = @Schema(implementation = RideDto.class))),
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
        description = "User is not a team member",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response createRide(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Valid RideRequest request) {

    RideDto ride = rideService.createRide(teamSlug, request);

    return Response.status(Response.Status.CREATED).entity(ride).build();
  }

  @GET
  @Path("/{rideSlug}")
  @PermitAll
  @Operation(
      summary = "Get ride details",
      description = "Get detailed ride information including groups")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Ride retrieved successfully",
        content = @Content(schema = @Schema(implementation = RideDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getRide(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug) {

    RideDto ride = rideService.getDto(teamSlug, rideSlug);
    // registered / registeredGroupId make this answer specific to the caller.
    return Response.ok(ride).header(HttpHeaders.CACHE_CONTROL, "private, no-store").build();
  }

  @GET
  @Path("/{rideSlug}/weather")
  @PermitAll
  @Operation(
      summary = "Get ride weather",
      description =
          "The forecast for the ride: at the meeting point when it leaves, then along each group's"
              + " route at its estimated passages (group speed, else 25 km/h). Read from the"
              + " server's cache only — the forecast is refreshed in the background, never on"
              + " request. Readable by whoever may read the ride, and then always 200: the state is"
              + " in status. Cache-Control: private, no-cache with an ETag (revalidate with"
              + " If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Ride weather, in whatever state it is",
        content = @Content(schema = @Schema(implementation = RideWeatherDto.class))),
    @APIResponse(responseCode = "304", description = "Unchanged since the ETag sent"),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getRideWeather(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug,
      @Context Request request) {

    RideWeatherAnswer answer = rideService.getWeather(teamSlug, rideSlug);
    String etag = answer.etag();
    if (etag == null) {
      // UNAVAILABLE offers « Réessayer »: nothing may keep it, not even to revalidate.
      return Response.ok(answer.body()).header(HttpHeaders.CACHE_CONTROL, "no-store").build();
    }
    // private: who may read the ride decides who may read this. no-cache: revalidate every time,
    // the forecast moves underneath — and the 304 spares the body.
    EntityTag entityTag = new EntityTag(etag, true);
    Response.ResponseBuilder notModified = request.evaluatePreconditions(entityTag);
    Response.ResponseBuilder builder =
        notModified != null ? notModified : Response.ok(answer.body());
    return builder.tag(entityTag).header(HttpHeaders.CACHE_CONTROL, "private, no-cache").build();
  }

  @GET
  @Path("/{rideSlug}/participants")
  @RolesAllowed("user")
  @Operation(
      summary = "List ride participants",
      description =
          "One page of the people registered to the ride, or to one of its groups, earliest"
              + " registrations first, searchable by display name. The ride detail only embeds the"
              + " first few; this is the whole list, with its total. Members of the team only (and"
              + " platform administrators): member names are never sent to anyone else.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Participants retrieved successfully",
        content = @Content(schema = @Schema(implementation = ParticipantListResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Not signed in",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "Not a member of the team: member names are never sent to anyone else",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found (or group not in this ride)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getRideParticipants(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug,
      @Parameter(description = "Only this group of the ride (TSID); every group when absent")
          @QueryParam("groupId")
          @Nullable String groupId,
      @Parameter(description = "Search by display name") @QueryParam("search")
          @Nullable String search,
      @Parameter(description = "Page number (0-based)") @QueryParam("page") @DefaultValue("0")
          int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("50") int size) {

    ParticipantListResponse participants =
        rideService.getParticipants(
            teamSlug,
            rideSlug,
            groupId != null ? TsidUtils.toLong(groupId) : null,
            search,
            page,
            size);
    // Who may read the ride decides who may read this: not a shared-cache answer.
    return Response.ok(participants).header(HttpHeaders.CACHE_CONTROL, "private, no-store").build();
  }

  @PUT
  @Path("/{rideSlug}")
  @Operation(
      summary = "Update ride",
      description = "Update ride information. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Ride updated successfully",
        content = @Content(schema = @Schema(implementation = RideDto.class))),
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
        description = "User is not authorized to update this ride",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response updateRide(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug,
      @Valid RideRequest request) {

    RideDto updatedRide = rideService.updateRide(teamSlug, rideSlug, request);

    return Response.ok(updatedRide).build();
  }

  @DELETE
  @Path("/{rideSlug}")
  @Operation(
      summary = "Delete ride",
      description = "Soft delete a ride. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Ride deleted successfully"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to delete this ride",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response deleteRide(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug) {

    rideService.deleteRide(teamSlug, rideSlug);
    return Response.noContent().build();
  }

  @POST
  @Path("/{rideSlug}/undelete")
  @Operation(
      operationId = "undeleteRide",
      summary = "Restore ride",
      description = "Restore a soft-deleted ride. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Ride restored successfully",
        content = @Content(schema = @Schema(implementation = RideDto.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to restore this ride",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response undeleteRide(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug) {
    RideDto dto = rideService.undeleteRide(teamSlug, rideSlug);
    return Response.ok(dto).build();
  }

  // ── Status alone, and calendar file (docs/LEDGER_DONE.md WEB-33) ──────────────────────────

  @PATCH
  @Path("/{rideSlug}/status")
  @Operation(
      operationId = "changeRideStatus",
      summary = "Change ride status",
      description =
          "Change the ride's status and nothing else — what a list row can do without the full"
              + " ride. Same side effects as a status change through the update. Requires organizer"
              + " permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Status changed",
        content = @Content(schema = @Schema(implementation = RideDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Invalid status",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to change this ride's status",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response changeStatus(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String slug,
      @Valid StatusChangeRequest request) {
    RideDto ride = rideService.updateStatus(teamSlug, slug, request.status());
    return Response.ok(ride).build();
  }

  @GET
  @Path("/{rideSlug}/ics")
  @Produces("text/calendar")
  @Operation(
      operationId = "downloadRideIcs",
      summary = "Download ride as a calendar file",
      description =
          "One VEVENT for the ride, to add it on its own to a calendar. Readable by whoever may"
              + " read the ride; no calendar token.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "iCalendar file",
        content =
            @Content(mediaType = "text/calendar", schema = @Schema(type = SchemaType.STRING))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @PermitAll
  public Response downloadRideIcs(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String slug) {
    String ics = publicationIcsService.rideIcs(teamSlug, slug);
    return Response.ok(ics)
        .type("text/calendar; charset=utf-8")
        .header("Content-Disposition", "attachment; filename=\"" + slug + ".ics\"")
        .build();
  }

  @PATCH
  @Path("/{rideSlug}/slug")
  @Operation(
      operationId = "changeRideSlug",
      summary = "Change ride slug",
      description = "Change ride URL slug. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Slug changed successfully",
        content = @Content(schema = @Schema(implementation = RideDto.class))),
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
        description = "User is not authorized to change this ride's slug",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or ride not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "Slug already in use",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response changeSlug(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Current ride URL slug") @PathParam("rideSlug") String currentSlug,
      @Valid SlugChangeRequest request) {

    RideDto ride = rideService.updateSlug(teamSlug, currentSlug, request.slug());
    return Response.ok(ride).build();
  }

  @POST
  @Path("/{rideSlug}/groups/{groupId}/join")
  @Operation(summary = "Join ride group", description = "Join a ride group")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Successfully joined group",
        content = @Content(schema = @Schema(implementation = RideParticipationDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Group is full or user already joined",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team, ride, or group not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response joinGroup(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug,
      @Parameter(description = "Group ID (TSID)") @PathParam("groupId") String groupId) {

    RideParticipationDto participation =
        rideService.joinGroup(teamSlug, rideSlug, TsidUtils.toLong(groupId));

    return Response.status(Response.Status.CREATED).entity(participation).build();
  }

  @POST
  @Path("/{rideSlug}/groups/{groupId}/leave")
  @Operation(summary = "Leave ride group", description = "Leave a ride group")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Successfully left group"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team, ride, group, or participation not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response leaveGroup(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Ride URL slug") @PathParam("rideSlug") String rideSlug,
      @Parameter(description = "Group ID (TSID)") @PathParam("groupId") String groupId) {

    rideService.leaveGroup(teamSlug, rideSlug, TsidUtils.toLong(groupId));

    return Response.noContent().build();
  }
}
