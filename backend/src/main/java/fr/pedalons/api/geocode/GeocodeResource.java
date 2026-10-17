package fr.pedalons.api.geocode;

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
              + " than 3 characters or the provider is unreachable. Results come from the Stadia"
              + " Maps geocoder: a client displaying them must credit 'Stadia Maps,"
              + " © OpenStreetMap contributors & others'.")
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
}
