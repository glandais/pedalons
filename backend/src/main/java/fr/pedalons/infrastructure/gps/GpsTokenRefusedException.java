package fr.pedalons.infrastructure.gps;

import fr.pedalons.common.exception.InternalException;
import fr.pedalons.dto.error.ErrorCode;
import java.io.IOException;

/**
 * The token endpoint of a GPS service answered 400 or 401: the grant itself is refused (revoked
 * access, a refresh token already used or expired — OAuth 2.0 {@code invalid_grant}). Only a
 * reconnection helps, unlike a network error or a 5xx, which a later attempt may get past
 * (docs/LEDGER_*.md API-120). An {@link InternalException} like any other token failure, so callers
 * that do not tell them apart behave as before.
 */
public class GpsTokenRefusedException extends InternalException {

  public GpsTokenRefusedException(String service, int status) {
    super(
        ErrorCode.GPS_TOKEN_EXCHANGE_FAILED,
        new IOException(service + " token request refused: " + status));
  }

  /** Whether a token endpoint's status means the grant is refused rather than a passing failure. */
  public static boolean isRefusal(int status) {
    return status == 400 || status == 401;
  }

  /** Whether {@code e}, or one of its causes, is a refusal. */
  public static boolean isCausedBy(Throwable e) {
    for (Throwable t = e; t != null; t = t.getCause()) {
      if (t instanceof GpsTokenRefusedException) {
        return true;
      }
      if (t.getCause() == t) {
        break;
      }
    }
    return false;
  }
}
