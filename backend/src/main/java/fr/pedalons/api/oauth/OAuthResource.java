package fr.pedalons.api.oauth;

import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.oauth.OAuthAuthorizeRequest;
import fr.pedalons.dto.oauth.OAuthAuthorizeResponse;
import fr.pedalons.dto.oauth.OAuthErrorResponse;
import fr.pedalons.dto.oauth.OAuthTokenResponse;
import fr.pedalons.service.oauth.OAuthService;
import jakarta.annotation.security.PermitAll;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.FormParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.Optional;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import org.jspecify.annotations.Nullable;

/**
 * OAuth 2.0 authorization code flow with PKCE, for external applications (docs/LEDGER_*.md
 * API-199). The authorization endpoint itself is a page of the site, {@code /oauth/authorize}: it
 * shows the consent screen and calls {@link #authorize}; an application only ever calls {@link
 * #token}. The flow and what it deliberately leaves out are described on {@link OAuthService}.
 */
@Path("/api/oauth")
@Tag(
    name = "OAuth",
    description =
        "OAuth 2.0 authorization code flow with PKCE (S256), for external applications. Send the"
            + " browser to the site's /oauth/authorize, then exchange the code on"
            + " /api/oauth/token. No registration, no client secret, no scopes: the access token"
            + " is the bearer JWT every secured operation takes.")
public class OAuthResource {

  private static final String AUTHORIZATION_CODE_GRANT = "authorization_code";
  private static final String REFRESH_TOKEN_GRANT = "refresh_token";

  @Inject OAuthService oauthService;

  @POST
  @Path("/authorize")
  @RolesAllowed("user")
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  @Operation(
      operationId = "oauthAuthorize",
      summary = "Approve an OAuth authorization request",
      description =
          "Called by the site's consent screen once the signed-in user pressed « Autoriser »:"
              + " mints a single-use authorization code and returns the redirect_uri to send the"
              + " browser to. Not for applications — they send the browser to /oauth/authorize.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Where to send the browser",
        content = @Content(schema = @Schema(implementation = OAuthAuthorizeResponse.class))),
    @APIResponse(
        responseCode = "400",
        description =
            "Invalid request: a redirect_uri that is not an absolute URI, carries a fragment or"
                + " uses a scheme a browser runs (javascript:, data:…), a challenge that is not"
                + " S256, or no explicit confirmation",
        content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  public Response authorize(@Valid OAuthAuthorizeRequest request) {
    return Response.ok(oauthService.authorize(request)).build();
  }

  @POST
  @Path("/token")
  @PermitAll
  @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
  @Produces(MediaType.APPLICATION_JSON)
  @Operation(
      operationId = "oauthToken",
      summary = "Exchange an authorization code, or refresh an access token",
      description =
          "The OAuth 2.0 token endpoint (RFC 6749 §3.2), form-encoded. grant_type="
              + "authorization_code takes code, client_id, redirect_uri (both as sent to"
              + " /oauth/authorize) and code_verifier (PKCE); a code is good once, for five"
              + " minutes. grant_type=refresh_token takes refresh_token, which rotates: keep the"
              + " one of the answer. Access tokens last 15 minutes, a refresh token 90 days"
              + " after its last use, until the user revokes the application from their profile.")
  @APIResponses({
    @APIResponse(
        responseCode = "200",
        description = "Tokens",
        content = @Content(schema = @Schema(implementation = OAuthTokenResponse.class))),
    @APIResponse(
        responseCode = "400",
        description = "invalid_request, invalid_grant or unsupported_grant_type",
        content = @Content(schema = @Schema(implementation = OAuthErrorResponse.class)))
  })
  public Response token(
      @FormParam("grant_type") @Nullable String grantType,
      @FormParam("code") @Nullable String code,
      @FormParam("client_id") @Nullable String clientId,
      @FormParam("redirect_uri") @Nullable String redirectUri,
      @FormParam("code_verifier") @Nullable String codeVerifier,
      @FormParam("refresh_token") @Nullable String refreshToken) {
    if (isBlank(grantType)) {
      return error(OAuthErrorResponse.INVALID_REQUEST, "grant_type is required");
    }
    Optional<OAuthTokenResponse> tokens;
    switch (grantType) {
      case AUTHORIZATION_CODE_GRANT -> {
        if (isBlank(code) || isBlank(clientId) || isBlank(redirectUri) || isBlank(codeVerifier)) {
          return error(
              OAuthErrorResponse.INVALID_REQUEST,
              "code, client_id, redirect_uri and code_verifier are required");
        }
        tokens = oauthService.exchangeCode(code, clientId, redirectUri, codeVerifier);
      }
      case REFRESH_TOKEN_GRANT -> {
        if (isBlank(refreshToken)) {
          return error(OAuthErrorResponse.INVALID_REQUEST, "refresh_token is required");
        }
        tokens = oauthService.refresh(refreshToken);
      }
      default -> {
        return error(
            OAuthErrorResponse.UNSUPPORTED_GRANT_TYPE,
            "grant_type must be authorization_code or refresh_token");
      }
    }
    if (tokens.isEmpty()) {
      return error(
          OAuthErrorResponse.INVALID_GRANT,
          "The code or refresh token is invalid, expired, revoked or was issued to another"
              + " client");
    }
    // RFC 6749 §5.1: a response carrying tokens is never cached.
    return Response.ok(tokens.get())
        .header(HttpHeaders.CACHE_CONTROL, "no-store")
        .header("Pragma", "no-cache")
        .build();
  }

  private static boolean isBlank(@Nullable String value) {
    return value == null || value.isBlank();
  }

  private static Response error(String error, String description) {
    return Response.status(Response.Status.BAD_REQUEST)
        .entity(new OAuthErrorResponse(error, description))
        .type(MediaType.APPLICATION_JSON)
        .header(HttpHeaders.CACHE_CONTROL, "no-store")
        .build();
  }
}
