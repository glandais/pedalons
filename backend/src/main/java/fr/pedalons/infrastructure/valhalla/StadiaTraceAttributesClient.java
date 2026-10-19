package fr.pedalons.infrastructure.valhalla;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.annotation.ClientHeaderParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * Stadia Maps trace attributes, {@code POST /trace_attributes/v1} (Valhalla protocol), called by the
 * surface worker only (docs/LEDGER_*.md WEB-100, C1b) — never during an HTTP request. 20 credits a
 * request, like routing. Measured limits (not published): 16 000 points (code 153) and 200 km (code
 * 154) per request.
 *
 * <p>Same host, key and header as {@link StadiaMapsClient}; a config key of its own, as the
 * geocoder has. The responses are gzip ({@code enable-response-decompression}).
 */
@RegisterRestClient(configKey = "stadiamaps-trace")
@Path("/trace_attributes/v1")
@ClientHeaderParam(
    name = "Authorization",
    value = "Stadia-Auth ${pedalons.routing.stadiamaps.api-key}")
public interface StadiaTraceAttributesClient {

  @POST
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  TraceAttributesResponse traceAttributes(TraceAttributesRequest request);
}
