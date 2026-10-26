package fr.pedalons.api.trips;

import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.common.request.StatusChangeRequest;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.dto.trips.response.TripDto;
import fr.pedalons.dto.trips.response.TripParticipationDto;
import fr.pedalons.dto.users.response.ParticipantListResponse;
import fr.pedalons.dto.weather.response.TripWeatherAnswer;
import fr.pedalons.dto.weather.response.TripWeatherDto;
import fr.pedalons.service.calendar.PublicationIcsService;
import fr.pedalons.service.trip.TripService;
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

@Path("/api/teams/{teamSlug}/trips")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Trips", description = "Trip management and participation operations")
public class TripResource {

  @Inject TripService tripService;
  @Inject PublicationIcsService publicationIcsService;

  @POST
  @Operation(summary = "Create trip", description = "Create a new trip with optional stages")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Trip created successfully",
        content = @Content(schema = @Schema(implementation = TripDto.class))),
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
  public Response createTrip(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Valid TripRequest request) {

    TripDto trip = tripService.createTrip(teamSlug, request);

    return Response.status(Response.Status.CREATED).entity(trip).build();
  }

  @GET
  @Path("/{tripSlug}")
  @PermitAll
  @Operation(
      summary = "Get trip details",
      description = "Get detailed trip information including stages and participants")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Trip retrieved successfully",
        content = @Content(schema = @Schema(implementation = TripDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getTrip(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug) {

    TripDto trip = tripService.getDto(teamSlug, tripSlug);
    // registered makes this answer specific to the caller.
    return Response.ok(trip).header(HttpHeaders.CACHE_CONTROL, "private, no-store").build();
  }

  @GET
  @Path("/{tripSlug}/weather")
  @PermitAll
  @Operation(
      summary = "Get trip weather",
      description =
          "The forecast for the trip, stage by stage: along each stage's route at its estimated"
              + " passages (stage speed, else 25 km/h), each stage with its own state. Read from"
              + " the server's cache only — the forecast is refreshed in the background, never on"
              + " request. Readable by whoever may read the trip, and then always 200: the state is"
              + " in status. Cache-Control: private, no-cache with an ETag (revalidate with"
              + " If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Trip weather, in whatever state it is",
        content = @Content(schema = @Schema(implementation = TripWeatherDto.class))),
    @APIResponse(responseCode = "304", description = "Unchanged since the ETag sent"),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getTripWeather(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug,
      @Context Request request) {

    TripWeatherAnswer answer = tripService.getWeather(teamSlug, tripSlug);
    String etag = answer.etag();
    if (etag == null) {
      // UNAVAILABLE offers « Réessayer »: nothing may keep it, not even to revalidate.
      return Response.ok(answer.body()).header(HttpHeaders.CACHE_CONTROL, "no-store").build();
    }
    // As getRideWeather: private (who may read the trip decides), no-cache (revalidate, 304).
    EntityTag entityTag = new EntityTag(etag, true);
    Response.ResponseBuilder notModified = request.evaluatePreconditions(entityTag);
    Response.ResponseBuilder builder =
        notModified != null ? notModified : Response.ok(answer.body());
    return builder.tag(entityTag).header(HttpHeaders.CACHE_CONTROL, "private, no-cache").build();
  }

  @GET
  @Path("/{tripSlug}/participants")
  @RolesAllowed("user")
  @Operation(
      summary = "List trip participants",
      description =
          "One page of the people registered to the trip, earliest registrations first, searchable"
              + " by display name. The trip detail only embeds the first few; this is the whole"
              + " list, with its total. Members of the team only (and platform administrators):"
              + " member names are never sent to anyone else.")
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
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getTripParticipants(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug,
      @Parameter(description = "Search by display name") @QueryParam("search")
          @Nullable String search,
      @Parameter(description = "Page number (0-based)") @QueryParam("page") @DefaultValue("0")
          int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("50") int size) {

    ParticipantListResponse participants =
        tripService.getParticipants(teamSlug, tripSlug, search, page, size);
    // Who may read the trip decides who may read this: not a shared-cache answer.
    return Response.ok(participants).header(HttpHeaders.CACHE_CONTROL, "private, no-store").build();
  }

  @PUT
  @Path("/{tripSlug}")
  @Operation(
      summary = "Update trip",
      description = "Update trip information. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Trip updated successfully",
        content = @Content(schema = @Schema(implementation = TripDto.class))),
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
        description = "User is not authorized to update this trip",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response updateTrip(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug,
      @Valid TripRequest request) {

    TripDto updatedTrip = tripService.updateTrip(teamSlug, tripSlug, request);

    return Response.ok(updatedTrip).build();
  }

  @DELETE
  @Path("/{tripSlug}")
  @Operation(
      summary = "Delete trip",
      description = "Soft delete a trip. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Trip deleted successfully"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to delete this trip",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response deleteTrip(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug) {

    tripService.deleteTrip(teamSlug, tripSlug);
    return Response.noContent().build();
  }

  @POST
  @Path("/{tripSlug}/undelete")
  @Operation(
      operationId = "undeleteTrip",
      summary = "Restore trip",
      description = "Restore a soft-deleted trip. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Trip restored successfully",
        content = @Content(schema = @Schema(implementation = TripDto.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "403",
        description = "User is not authorized to restore this trip",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response undeleteTrip(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug) {
    TripDto dto = tripService.undeleteTrip(teamSlug, tripSlug);
    return Response.ok(dto).build();
  }

  @POST
  @Path("/{tripSlug}/join")
  @Operation(summary = "Join trip", description = "Join a trip as a participant")
  @APIResponses({
    @APIResponse(
        responseCode = "201",
        description = "Successfully joined trip",
        content = @Content(schema = @Schema(implementation = TripParticipationDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "User already joined or trip not published",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response joinTrip(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug) {

    TripParticipationDto participation = tripService.joinTrip(teamSlug, tripSlug);

    return Response.status(Response.Status.CREATED).entity(participation).build();
  }

  @POST
  @Path("/{tripSlug}/leave")
  @Operation(summary = "Leave trip", description = "Leave a trip as a participant")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Successfully left trip"),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team, trip, or participation not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response leaveTrip(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String tripSlug) {

    tripService.leaveTrip(teamSlug, tripSlug);

    return Response.noContent().build();
  }

  // ── Status alone, and calendar file (docs/LEDGER_DONE.md WEB-33) ──────────────────────────

  @PATCH
  @Path("/{tripSlug}/status")
  @Operation(
      operationId = "changeTripStatus",
      summary = "Change trip status",
      description =
          "Change the trip's status and nothing else — what a list row can do without the full"
              + " trip. Same side effects as a status change through the update. Requires organizer"
              + " permissions. The stages follow the trip.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Status changed",
        content = @Content(schema = @Schema(implementation = TripDto.class))),
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
        description = "User is not authorized to change this trip's status",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response changeStatus(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String slug,
      @Valid StatusChangeRequest request) {
    TripDto trip = tripService.updateStatus(teamSlug, slug, request.status());
    return Response.ok(trip).build();
  }

  @GET
  @Path("/{tripSlug}/ics")
  @Produces("text/calendar")
  @Operation(
      operationId = "downloadTripIcs",
      summary = "Download trip as a calendar file",
      description =
          "One all-day VEVENT per stage, to add the trip on its own to a calendar. Readable by"
              + " whoever may read the trip; no calendar token.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "iCalendar file",
        content =
            @Content(mediaType = "text/calendar", schema = @Schema(type = SchemaType.STRING))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @PermitAll
  public Response downloadTripIcs(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Trip URL slug") @PathParam("tripSlug") String slug) {
    String ics = publicationIcsService.tripIcs(teamSlug, slug);
    return Response.ok(ics)
        .type("text/calendar; charset=utf-8")
        .header("Content-Disposition", "attachment; filename=\"" + slug + ".ics\"")
        .build();
  }

  @PATCH
  @Path("/{tripSlug}/slug")
  @Operation(
      operationId = "changeTripSlug",
      summary = "Change trip slug",
      description = "Change trip URL slug. Requires organizer permissions.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Slug changed successfully",
        content = @Content(schema = @Schema(implementation = TripDto.class))),
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
        description = "User is not authorized to change this trip's slug",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team or trip not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "409",
        description = "Slug already in use",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  @RolesAllowed("user")
  public Response changeSlug(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Current trip URL slug") @PathParam("tripSlug") String currentSlug,
      @Valid SlugChangeRequest request) {

    TripDto trip = tripService.updateSlug(teamSlug, currentSlug, request.slug());
    return Response.ok(trip).build();
  }
}
