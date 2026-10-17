package fr.pedalons.common.exception;

import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorDetails;
import jakarta.ws.rs.core.Response;
import org.jspecify.annotations.Nullable;

/**
 * A request that fails because a service we depend on does not answer, or refuses us — HTTP 503.
 * The caller did nothing wrong and may try again later.
 */
public class ServiceUnavailableException extends PedalonsException {

  public ServiceUnavailableException(
      ErrorCode errorCode, @Nullable ErrorDetails errorDetails, @Nullable Throwable cause) {
    super(errorCode, errorDetails, cause);
  }

  public ServiceUnavailableException(ErrorCode errorCode) {
    this(errorCode, null, null);
  }

  @Override
  public Response.Status getStatus() {
    return Response.Status.SERVICE_UNAVAILABLE;
  }
}
