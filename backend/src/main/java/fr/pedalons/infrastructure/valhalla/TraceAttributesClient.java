package fr.pedalons.infrastructure.valhalla;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * Trace attributes, {@code POST /trace_attributes/v1} (Valhalla protocol), served by osm-surface
 * (github.com/glandais/osm-surface, in the shared stack): Valhalla's {@code map_snap} rebuilt on the
 * VersaTiles OpenStreetMap vector tiles, a drop-in for the Stadia Maps endpoint it replaced
 * (docs/LEDGER_*.md OPS-57). Called by the surface worker only (WEB-100, C1b) — never during an
 * HTTP request. Its limits are Stadia's: 16 000 points (code 153) and 200 km (code 154) per request;
 * a 503 when it cannot load the tiles.
 *
 * <p>No key: the service is ours and only reachable over the shared network. The responses are gzip
 * ({@code enable-response-decompression}).
 */
@RegisterRestClient(configKey = "osm-surface")
@Path("/trace_attributes/v1")
public interface TraceAttributesClient {

  @POST
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  TraceAttributesResponse traceAttributes(TraceAttributesRequest request);
}
