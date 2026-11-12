package fr.pedalons.api.publications;

import fr.pedalons.common.QueryInstants;
import fr.pedalons.dto.common.CountResponse;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.publications.response.PublicationListResponse;
import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.PublicationWhen;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.Status;
import fr.pedalons.service.common.PublicationService;
import jakarta.annotation.security.PermitAll;
import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

@Path("/api/teams/{teamSlug}/publications")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Publications", description = "Publication listing")
public class TeamPublicationResource {

  @Inject PublicationService publicationService;

  static final String TAGS_PARAM_DESCRIPTION =
      "Only the publications carrying at least one of these tags — ids (TSID) of the team's tags"
          + " of kind 'type', comma-separated or repeated. Honoured with a 'type' only: the mixed"
          + " feed has no tag filter and ignores it. Unknown ids are ignored; a filter left with no"
          + " known id filters nothing.";

  static final String WITHOUT_ROUTE_PARAM_DESCRIPTION =
      "Only the rides routed nowhere: neither the ride nor any of its groups has a route. Every"
          + " other type of publication is left out.";

  static final String WITH_FULL_GROUP_PARAM_DESCRIPTION =
      "Only the rides with at least one group at capacity (maxParticipants reached). Every other"
          + " type of publication is left out.";

  @GET
  @PermitAll
  @Operation(
      summary = "List publications",
      description = "Get paginated list of publications for a team with optional filtering")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Publications retrieved successfully",
        content = @Content(schema = @Schema(implementation = PublicationListResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response listPublications(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Type") @QueryParam("type") @Nullable PublicationType type,
      @Parameter(description = "Search by name/markdown") @QueryParam("search")
          @Nullable String search,
      @Parameter(description = "Start date filter (ISO format)") @QueryParam("from")
          @Nullable String fromStr,
      @Parameter(description = "End date filter (ISO format)") @QueryParam("to")
          @Nullable String toStr,
      @Parameter(
              description =
                  "Only publications with this status. Narrows the visibility rules, never widens"
                      + " them.")
          @QueryParam("status")
          @Nullable Status status,
      @Parameter(
              description =
                  "Only publications the current user is registered to (rides and trips). Yields"
                      + " nothing for an anonymous visitor.")
          @QueryParam("participating")
          @DefaultValue("false")
          boolean participating,
      @Parameter(description = TAGS_PARAM_DESCRIPTION) @QueryParam("tags")
          @Nullable List<String> tags,
      @Parameter(description = PublicationResource.VIEW_PARAM_DESCRIPTION) @QueryParam("view")
          @Nullable ListViewMode view,
      @Parameter(
              description =
                  "Order of the publication date. Omitted, or DESC, is newest first (the feed);"
                      + " ASC is soonest first — what a window of upcoming outings needs, so a"
                      + " page keeps the nearest ones. Given, it overrides the order set by when,"
                      + " except with when=UPCOMING_FIRST or EARLIER, which ignore it.")
          @QueryParam("sortDir")
          @Nullable SortDirection sortDir,
      @Parameter(description = PublicationResource.WHEN_PARAM_DESCRIPTION) @QueryParam("when")
          @Nullable PublicationWhen when,
      @Parameter(description = WITHOUT_ROUTE_PARAM_DESCRIPTION)
          @QueryParam("withoutRoute")
          @DefaultValue("false")
          boolean withoutRoute,
      @Parameter(description = WITH_FULL_GROUP_PARAM_DESCRIPTION)
          @QueryParam("withFullGroup")
          @DefaultValue("false")
          boolean withFullGroup,
      @Parameter(description = PublicationResource.DATED_PARAM_DESCRIPTION)
          @QueryParam("dated")
          @DefaultValue("false")
          boolean dated,
      @Parameter(description = "Page number") @QueryParam("page") @DefaultValue("0") int page,
      @Parameter(description = "Page size") @QueryParam("size") @DefaultValue("20") int size) {

    Instant from = QueryInstants.parse(fromStr);
    Instant to = QueryInstants.parse(toStr);

    PublicationListResponse publications =
        publicationService.listTeam(
            teamSlug,
            type,
            search,
            from,
            to,
            status,
            participating,
            tags,
            view,
            when,
            sortDir,
            withoutRoute,
            withFullGroup,
            dated,
            page,
            size);

    // Rows carry per-user fields (registered, registeredGroupId): not shareable between users.
    return Response.ok(publications)
        .header(HttpHeaders.CACHE_CONTROL, PublicationResource.PRIVATE_NO_STORE)
        .build();
  }

  @GET
  @PermitAll
  @Path("/count")
  @Operation(
      operationId = "countPublications",
      summary = "Count publications",
      description =
          "How many of the team's publications match the filters, with none of them read. Accepts"
              + " exactly the same filters as the listing, minus pagination, so a count and the"
              + " list it opens can never disagree.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Count computed successfully",
        content = @Content(schema = @Schema(implementation = CountResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Team not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response countPublications(
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Type") @QueryParam("type") @Nullable PublicationType type,
      @Parameter(description = "Search by name/markdown") @QueryParam("search")
          @Nullable String search,
      @Parameter(description = "Start date filter (ISO format)") @QueryParam("from")
          @Nullable String fromStr,
      @Parameter(description = "End date filter (ISO format)") @QueryParam("to")
          @Nullable String toStr,
      @Parameter(
              description =
                  "Only publications with this status. Narrows the visibility rules, never widens"
                      + " them.")
          @QueryParam("status")
          @Nullable Status status,
      @Parameter(
              description =
                  "Only publications the current user is registered to (rides and trips). Yields"
                      + " zero for an anonymous visitor.")
          @QueryParam("participating")
          @DefaultValue("false")
          boolean participating,
      @Parameter(description = TAGS_PARAM_DESCRIPTION) @QueryParam("tags")
          @Nullable List<String> tags,
      @Parameter(description = WITHOUT_ROUTE_PARAM_DESCRIPTION)
          @QueryParam("withoutRoute")
          @DefaultValue("false")
          boolean withoutRoute,
      @Parameter(description = WITH_FULL_GROUP_PARAM_DESCRIPTION)
          @QueryParam("withFullGroup")
          @DefaultValue("false")
          boolean withFullGroup,
      @Parameter(description = PublicationResource.WHEN_PARAM_DESCRIPTION) @QueryParam("when")
          @Nullable PublicationWhen when,
      @Parameter(description = PublicationResource.DATED_PARAM_DESCRIPTION)
          @QueryParam("dated")
          @DefaultValue("false")
          boolean dated) {

    Instant from = QueryInstants.parse(fromStr);
    Instant to = QueryInstants.parse(toStr);

    CountResponse count =
        publicationService.countTeam(
            teamSlug,
            type,
            search,
            from,
            to,
            status,
            participating,
            tags,
            withoutRoute,
            withFullGroup,
            when,
            dated);

    // The figure depends on who is asking — both through the visibility rules and through
    // 'participating': not shareable between users.
    return Response.ok(count)
        .header(HttpHeaders.CACHE_CONTROL, PublicationResource.PRIVATE_NO_STORE)
        .build();
  }
}
