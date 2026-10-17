package fr.pedalons.infrastructure.valhalla;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.annotation.ClientHeaderParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * The Stadia Maps routing API, {@code POST /route/v1} (there is no {@code /route/v2}: it answers 404), whose request and response are the Valhalla
 * protocol ({@link ValhallaRequest}, {@link ValhallaResponse}: polyline6 shapes). The base URL is
 * {@code STADIAMAPS_URL} ({@code https://api-eu.stadiamaps.com} by default: the EU-only host, so the
 * requests stay on servers in the European Union).
 *
 * <p>The key ({@code STADIAMAPS_API_KEY}) is sent in the {@code Authorization: Stadia-Auth} header,
 * never as a query parameter, so no URL ever carries it. Nothing logs the request either way.
 *
 * <p>Published limits: 50 locations per request, 500 km as the crow flies for {@code bicycle}
 * (250 km for {@code pedestrian}); a spent quota answers 429.
 */
@RegisterRestClient(configKey = "stadiamaps")
@Path("/route/v1")
@ClientHeaderParam(
    name = "Authorization",
    value = "Stadia-Auth ${pedalons.routing.stadiamaps.api-key}")
public interface StadiaMapsClient {

  @POST
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  ValhallaResponse route(ValhallaRequest request);
}
