package fr.pedalons.infrastructure.routedetails;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * osm-route-details (github.com/glandais/osm-route-details, in the shared stack), contract api 1.6.
 * No key: the service is ours and only reachable over the shared network. The answers are gzip.
 *
 * <p>Never injected directly: {@link RouteDetailsGateway} builds two instances, one per profile,
 * because {@code fast} and {@code full} need different read timeouts. An error status comes out of
 * the client's default mapper as a {@code WebApplicationException}, which the gateway turns into a
 * {@link RouteDetailsException}.
 */
@RegisterRestClient(configKey = "osm-route-details")
@Path("/v1")
public interface RouteDetailsClient {

  @POST
  @Path("/route-details")
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  RouteDetailsResponse routeDetails(RouteDetailsRequest request);

  @GET
  @Path("/capabilities")
  @Produces(MediaType.APPLICATION_JSON)
  RouteDetailsCapabilities capabilities();
}
