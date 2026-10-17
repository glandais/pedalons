package fr.pedalons.api.geocode;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.geocode.GeocodeResultDto;
import fr.pedalons.service.geocode.GeocodeService;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/**
 * Address lookup for the clients' geocoder fields.
 *
 * <p>Authenticated on purpose, though the upstream data is public: the three screens that geocode —
 * the ad editor, the place form and the team form — are all behind a login, and an anonymous
 * endpoint here would be a free relay spending our Stadia Maps quota, with our key, for anyone.
 */
@Path("/api/geocode")
@Produces(MediaType.APPLICATION_JSON)
@RolesAllowed("user")
@Tag(name = "Geocode", description = "Address lookup, proxied to the Stadia Maps geocoder")
public class GeocodeResource {

  @Inject GeocodeService geocodeService;

  @GET
  @Path("/search")
  @Operation(
      summary = "Search places by name",
      description =
          "Returns at most 5 places matching the query, or an empty list when the query is shorter"
              + " than 3 characters or the provider is unreachable. A result's lat and lon are null"
              + " when the provider gave no position for it (the usual case): once the user picks"
              + " it, resolve its position with GET /api/geocode/place?id=. Never resolve every"
              + " suggestion: each resolution is billed. Results come from the Stadia Maps"
              + " geocoder: a client displaying them must credit 'Stadia Maps, © OpenStreetMap"
              + " contributors & others'.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Matching places, possibly empty",
        content = @Content(schema = @Schema(implementation = GeocodeResultDto[].class)))
  })
  public List<GeocodeResultDto> searchPlaces(@QueryParam("q") String query) {
    if (query == null || query.isBlank()) {
      return List.of();
    }
    return geocodeService.search(query);
  }

  @GET
  @Path("/place")
  @Operation(
      summary = "Resolve the position of a picked place",
      description =
          "Returns the place whose id a search result carried, with lat and lon always set. Call it"
              + " only for the result the user picked, never for every suggestion: each call is"
              + " billed by the provider. The id is a query parameter because it contains ':'. An"
              + " id that is not shaped like a provider id, or that the provider does not know, is"
              + " a 404 (NOT_FOUND); a provider failure or spent quota is a 503"
              + " (GEOCODING_UNAVAILABLE) — the client should then let the user search and"
              + " pick again, or leave the position empty.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "The place, with its position",
        content = @Content(schema = @Schema(implementation = GeocodeResultDto.class))),
    @APIResponse(
        responseCode = "404",
        description = "Malformed id, or no such place at the provider (NOT_FOUND)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "503",
        description =
            "The geocoder failed, could not be reached or its quota is spent"
                + " (GEOCODING_UNAVAILABLE)",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public GeocodeResultDto resolvePlace(
      @Parameter(
              description = "The id of a search result, e.g. whosonfirst:locality:101750851",
              required = true)
          @QueryParam("id")
          String id) {
    return geocodeService.place(id);
  }
}
