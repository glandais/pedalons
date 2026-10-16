package fr.pedalons.infrastructure.gps;

import java.util.Map;

/**
 * How one request to a GPS service is authorised: a bearer token (OAuth 2.0, every service) or an
 * OAuth 1.0a signature (Garmin's legacy programme, docs/LEDGER_*.md API-62). The route calls of the
 * clients take one, so that they need neither the request's domain nor the connection: the caller
 * — an endpoint or the background synchronisation (docs/LEDGER_*.md API-120) — resolves it.
 *
 * <p>{@code toString} never prints a token: these values end up in log lines and mock failures.
 */
public sealed interface GpsAuth {

  /** The {@code Authorization} header for a request of this method on this URL. */
  String authorizationHeader(String method, String url);

  /** OAuth 2.0. */
  record Bearer(String accessToken) implements GpsAuth {
    @Override
    public String authorizationHeader(String method, String url) {
      return "Bearer " + accessToken;
    }

    @Override
    public String toString() {
      return "Bearer[***]";
    }
  }

  /**
   * OAuth 1.0a: the signature covers the method and the URL, the course id included for a {@code
   * PUT} or a {@code DELETE}; a JSON body never enters it.
   */
  record OAuth1(String consumerKey, String consumerSecret, String token, String tokenSecret)
      implements GpsAuth {
    @Override
    public String authorizationHeader(String method, String url) {
      return OAuth1Signer.authorizationHeader(
          method, url, consumerKey, consumerSecret, token, tokenSecret, Map.of());
    }

    @Override
    public String toString() {
      return "OAuth1[***]";
    }
  }
}
