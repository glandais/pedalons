package fr.pedalons.infrastructure.gps;

import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.enums.GpsServiceType;

/**
 * Strategy interface for GPS service integrations.
 * Each GPS service (Hammerhead, Wahoo, etc.) implements this interface.
 */
public interface GpsServiceClient {

  /**
   * @return The GPS service type this client handles
   */
  GpsServiceType getServiceType();

  /**
   * @return true if this client uses PKCE flow (code_verifier/code_challenge)
   */
  default boolean supportsPkce() {
    return false;
  }

  /**
   * Get the OAuth authorization URL for initiating the connection flow.
   *
   * @param state CSRF state parameter
   * @param redirectUri Callback URL after authorization
   * @return Full authorization URL to redirect user to
   */
  String getAuthorizationUrl(String state, String redirectUri);

  /**
   * Get the OAuth authorization URL with PKCE support.
   *
   * @param state CSRF state parameter
   * @param redirectUri Callback URL after authorization
   * @param codeChallenge PKCE code challenge (SHA-256 hash of code_verifier, base64url encoded)
   * @return Full authorization URL to redirect user to
   */
  default String getAuthorizationUrl(String state, String redirectUri, String codeChallenge) {
    return getAuthorizationUrl(state, redirectUri);
  }

  /**
   * Exchange an authorization code for access/refresh tokens.
   *
   * @param code Authorization code from callback
   * @param redirectUri Must match the redirect URI used in authorization
   * @return Token response containing access token, refresh token, expiry
   */
  TokenResponse exchangeCode(String code, String redirectUri);

  /**
   * Exchange an authorization code for access/refresh tokens with PKCE.
   *
   * @param code Authorization code from callback
   * @param redirectUri Must match the redirect URI used in authorization
   * @param codeVerifier PKCE code verifier used to generate the challenge
   * @return Token response containing access token, refresh token, expiry
   */
  default TokenResponse exchangeCode(String code, String redirectUri, String codeVerifier) {
    return exchangeCode(code, redirectUri);
  }

  /**
   * Refresh an expired access token using the refresh token.
   *
   * @param refreshToken The refresh token
   * @return New token response
   */
  TokenResponse refreshToken(String refreshToken);

  /**
   * Refresh an expired access token with an explicit credential: for a caller outside an HTTP
   * request — the background synchronisation (docs/LEDGER_*.md API-120) — whose domain the request
   * cannot tell.
   */
  TokenResponse refreshToken(DomainGpsCredential credential, String refreshToken);

  /**
   * Upload a route to the GPS service: a manual upload, untracked by the service ({@link
   * #createRoute} with a {@link RouteMeta#manual} meta).
   *
   * @param accessToken Valid access token
   * @param gpxContent GPX file content as bytes
   * @param routeName Name for the route on the device
   * @return Upload result with success status and external route ID
   */
  default RouteUploadResult uploadRoute(String accessToken, byte[] gpxContent, String routeName) {
    return createRoute(new GpsAuth.Bearer(accessToken), gpxContent, RouteMeta.manual(routeName))
        .toUploadResult();
  }

  /** Creates a route at the service. {@link GpsCallResult.Ok} carries its id there. */
  GpsCallResult createRoute(GpsAuth auth, byte[] gpxContent, RouteMeta meta);

  /**
   * Replaces the route {@code externalId} — trace and name — keeping its id. {@link
   * GpsCallResult.NotFound} when the user deleted it at the service.
   */
  GpsCallResult updateRoute(GpsAuth auth, String externalId, byte[] gpxContent, RouteMeta meta);

  /** Deletes the route {@code externalId}. A route already gone gives {@link GpsCallResult.NotFound}. */
  GpsCallResult deleteRoute(GpsAuth auth, String externalId);
}
