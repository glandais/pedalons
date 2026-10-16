package fr.pedalons.api.gps;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.gps.request.GpsAutoSyncRequest;
import fr.pedalons.dto.gps.response.GpsOAuthUrlResponse;
import fr.pedalons.dto.gps.response.GpsServiceConnectionDto;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.enums.GpsConnectReturn;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.service.gps.GpsService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.net.URI;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

@Path("/api/gps")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "GPS Services", description = "GPS device integration operations")
public class GpsResource {

  @Inject GpsService gpsService;

  @GET
  @Path("/available")
  @RolesAllowed("user")
  @Operation(
      summary = "Get available GPS services",
      description = "Get list of GPS service types configured for this domain")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "List of available GPS service types",
        content = @Content(schema = @Schema(implementation = GpsServiceType[].class)))
  })
  public Response getAvailableServices() {
    List<GpsServiceType> available = gpsService.getAvailableServices();
    return Response.ok(available).build();
  }

  @GET
  @Path("/connect/{serviceType}")
  @RolesAllowed("user")
  @Operation(
      summary = "Get OAuth authorization URL",
      description = "Get the OAuth authorization URL to connect a GPS service")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Authorization URL",
        content = @Content(schema = @Schema(implementation = GpsOAuthUrlResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Service already connected",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response getConnectUrl(
      @Parameter(description = "GPS service type") @PathParam("serviceType")
          GpsServiceType serviceType,
      @Parameter(
              description =
                  "Where the OAuth callback sends the browser back to. PROFILE when absent.")
          @QueryParam("returnTo")
          @Nullable GpsConnectReturn returnTo) {
    GpsOAuthUrlResponse response =
        gpsService.initiateOAuth(
            serviceType, returnTo != null ? returnTo : GpsConnectReturn.PROFILE);
    return Response.ok(response).build();
  }

  @GET
  @Path("/callback/{serviceType}")
  @PermitAll
  @Operation(
      summary = "OAuth callback",
      description =
          "Handles OAuth callback from GPS service and redirects to the frontend page chosen by"
              + " the returnTo of the connect call (the profile by default). OAuth 2.0 brings"
              + " code and state; OAuth 1.0a (Garmin, when the domain's credential says so)"
              + " brings oauth_token and oauth_verifier.")
  @APIResponses({
    @APIResponse(responseCode = "302", description = "Redirects to frontend"),
    @APIResponse(
        responseCode = "400",
        description = "Invalid state or code",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response handleCallback(
      @Parameter(description = "GPS service type") @PathParam("serviceType")
          GpsServiceType serviceType,
      @QueryParam("code") @Nullable String code,
      @QueryParam("state") @Nullable String state,
      @QueryParam("error") @Nullable String error,
      @Parameter(description = "OAuth 1.0a request token") @QueryParam("oauth_token")
          @Nullable String oauthToken,
      @Parameter(description = "OAuth 1.0a verifier") @QueryParam("oauth_verifier")
          @Nullable String oauthVerifier) {

    // Read before the callback consumes the state; a refusal carries the state too, so it lands
    // on the page that started the connection (docs/LEDGER_*.md API-63). Under OAuth 1.0a the
    // request token is what the state row is keyed by (API-62).
    String stateKey = state != null ? state : oauthToken;
    GpsConnectReturn returnTo =
        stateKey != null ? gpsService.findReturnTarget(stateKey) : GpsConnectReturn.PROFILE;

    // Handle OAuth error. The provider's value is never copied into the redirect: it arrives from
    // whoever built the link, and would add parameters to it — or make URI.create throw
    // (docs/LEDGER_*.md SEC-12, audit L8). A fixed key per case, the standard refusal kept apart.
    if (error != null) {
      String key = "access_denied".equals(error) ? "access_denied" : "provider_error";
      return redirect(returnTo, "gps_error=" + key);
    }

    // OAuth 1.0a (docs/LEDGER_*.md API-62). A request token back without a verifier is a refusal:
    // the protocol defines no error parameter.
    if (oauthToken != null) {
      if (oauthVerifier == null) {
        return redirect(returnTo, "gps_error=access_denied");
      }
      try {
        gpsService.handleOAuth1Callback(serviceType, oauthToken, oauthVerifier);
        return redirect(returnTo, "gps_connected=" + serviceType.name().toLowerCase());
      } catch (Exception e) {
        return redirect(returnTo, "gps_error=connection_failed");
      }
    }

    if (code == null || state == null) {
      return redirect(returnTo, "gps_error=missing_params");
    }

    try {
      gpsService.handleCallback(serviceType, code, state);
      return redirect(returnTo, "gps_connected=" + serviceType.name().toLowerCase());
    } catch (Exception e) {
      return redirect(returnTo, "gps_error=connection_failed");
    }
  }

  private Response redirect(GpsConnectReturn returnTo, String query) {
    return Response.temporaryRedirect(
            URI.create(gpsService.getFrontendBaseUrl() + returnTo.getPath() + "?" + query))
        .build();
  }

  @DELETE
  @Path("/disconnect/{serviceType}")
  @RolesAllowed("user")
  @Operation(summary = "Disconnect GPS service", description = "Disconnect a connected GPS service")
  @APIResponses({
    @APIResponse(responseCode = "204", description = "Service disconnected"),
    @APIResponse(
        responseCode = "400",
        description = "Service not connected",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response disconnect(
      @Parameter(description = "GPS service type") @PathParam("serviceType")
          GpsServiceType serviceType) {
    gpsService.disconnect(serviceType);
    return Response.noContent().build();
  }

  @PUT
  @Path("/connections/{serviceType}/auto-sync")
  @RolesAllowed("user")
  @Operation(
      operationId = "setGpsAutoSync",
      summary = "Turn the automatic route sync on or off",
      description =
          "Turns on or off, for one connected service, the automatic sending of the routes of the"
              + " rides the user is registered in (from 7 days before the departure until a day"
              + " after it), kept in sync with their changes. Turning it off removes from the"
              + " service the upcoming routes it sent. A RECONNECT_REQUIRED state is only cleared"
              + " by connecting the service again.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "The connection, with its new sync state",
        content = @Content(schema = @Schema(implementation = GpsServiceConnectionDto.class))),
    @APIResponse(
        responseCode = "400",
        description = "Service not connected",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public GpsServiceConnectionDto setAutoSync(
      @Parameter(description = "GPS service type") @PathParam("serviceType")
          GpsServiceType serviceType,
      @Valid GpsAutoSyncRequest request) {
    return gpsService.setAutoSync(serviceType, Boolean.TRUE.equals(request.enabled()));
  }

  @POST
  @Path("/upload/{serviceType}/{teamSlug}/{routeSlug}")
  @RolesAllowed("user")
  @Operation(
      summary = "Upload route to GPS service",
      description = "Upload a route to a connected GPS service")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Route uploaded",
        content = @Content(schema = @Schema(implementation = RouteUploadResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "Service not connected or upload failed",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "401",
        description = "Unauthorized",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @APIResponse(
        responseCode = "404",
        description = "Route not found",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response uploadRoute(
      @Parameter(description = "GPS service type") @PathParam("serviceType")
          GpsServiceType serviceType,
      @Parameter(description = "Team URL slug") @PathParam("teamSlug") String teamSlug,
      @Parameter(description = "Route URL slug") @PathParam("routeSlug") String routeSlug) {
    RouteUploadResponse response = gpsService.uploadRoute(serviceType, teamSlug, routeSlug);
    return Response.ok(response).build();
  }
}
