package fr.pedalons.common.exception;

import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorDetails;
import jakarta.ws.rs.core.Response;
import org.jspecify.annotations.Nullable;

public class ForbiddenException extends PedalonsException {
  public ForbiddenException(@Nullable ErrorDetails errorDetails, @Nullable Throwable cause) {
    super(ErrorCode.FORBIDDEN, errorDetails, cause);
  }

  /**
   * A refusal that has a reason worth naming. The bare {@code FORBIDDEN} is right when there is
   * nothing useful to say — the caller simply may not — but some refusals are actionable, and the
   * client can only act on them if it is told which one it hit.
   */
  public ForbiddenException(ErrorCode errorCode) {
    super(errorCode, null, null);
  }

  /** As {@link #ForbiddenException(ErrorCode)}, with the details the client needs to say why. */
  public ForbiddenException(ErrorCode errorCode, ErrorDetails errorDetails) {
    super(errorCode, errorDetails, null);
  }

  public ForbiddenException(@Nullable Throwable cause) {
    this(null, cause);
  }

  public ForbiddenException() {
    this((ErrorDetails) null, null);
  }

  @Override
  public Response.Status getStatus() {
    return Response.Status.FORBIDDEN;
  }
}
