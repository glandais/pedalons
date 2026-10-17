package fr.pedalons.infrastructure.exception;

import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorResponse;
import fr.pedalons.dto.error.ErrorValidationDetails;
import fr.pedalons.dto.error.FieldError;
import fr.pedalons.dto.validation.AcceptableText;
import io.quarkus.hibernate.validator.runtime.jaxrs.ResteasyReactiveViolationException;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.ElementKind;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotAuthorizedException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;
import org.jspecify.annotations.Nullable;

@Provider
public class GlobalExceptionMapper implements ExceptionMapper<Throwable> {

  private static final Logger LOG = Logger.getLogger(GlobalExceptionMapper.class);

  @Context @Nullable UriInfo uriInfo;

  @ConfigProperty(name = "pedalons.error.log-details", defaultValue = "false")
  boolean logDetails;

  /**
   * Violations on resource parameters ({@code @Valid} bodies) would otherwise reach Quarkus's own
   * mapper, which is more specific than {@code Throwable} and answers with its "Constraint
   * Violation" report instead of our {@link ErrorResponse}.
   */
  @ServerExceptionMapper
  public Response mapResourceViolation(ResteasyReactiveViolationException exception) {
    return toResponse(exception);
  }

  /**
   * Every error body is JSON, whatever the endpoint {@code @Produces}. Left to negotiation, an
   * error on a {@code application/zip} or {@code text/calendar} endpoint went out under that type
   * with the record's {@code toString()} as body — a browser following an export link then failed
   * with ERR_INVALID_RESPONSE instead of showing the 404.
   */
  @Override
  public Response toResponse(Throwable exception) {
    return Response.fromResponse(map(exception)).type(MediaType.APPLICATION_JSON_TYPE).build();
  }

  private Response map(Throwable exception) {
    switch (exception) {
      case NotFoundException e -> {
        warn(e, "Not found: {0}", getPath());
        return notFound();
      }
      case EntityNotFoundException e -> {
        warn(e, "Entity not found: {0}", getPath());
        return notFound();
      }
      case NotAuthorizedException e -> {
        warn(e, "Unauthorized: {0}", getPath());
        return unauthorized();
      }
      case ForbiddenException e -> {
        warn(e, "Forbidden: {0}", getPath());
        return forbidden();
      }
      case ConstraintViolationException cve -> {
        // A resource returning an invalid value is our bug, not the caller's: keep it a 500.
        if (isReturnValueViolation(cve)) {
          LOG.error("Invalid return value: " + getPath(), cve);
          return internal();
        }
        warn(cve, "Validation error: {0}", getPath());
        return validationError(cve);
      }
      case IllegalArgumentException e -> {
        warn(e, "Bad request: {0}", getPath());
        return badRequest();
      }
      case ServiceUnavailableException sue -> {
        // An upstream that is down or out of quota (Stadia Maps): expected and transient, already
        // logged where it happened with what is safe to log. A WARN line, never a stack at ERROR.
        LOG.warnv("Service unavailable: {0} {1}", sue.getErrorCode(), getPath());
        return pedalonsError(sue);
      }
      case PedalonsException be -> {
        if (be.getStatus().getFamily() == Response.Status.Family.CLIENT_ERROR) {
          warn(be, "Client error: {0} {1}", be.getErrorCode(), getPath());
        } else {
          LOG.errorv(be, "Server error: {0} {1}", be.getErrorCode(), getPath());
        }
        return pedalonsError(be);
      }
      case WebApplicationException wae -> {
        Response originalResponse = wae.getResponse();
        int status = originalResponse.getStatus();
        if (status >= 500) {
          LOG.errorv(wae, "Server error {0}: {1}", status, getPath());
        } else {
          warn(wae, "Client error {0}: {1}", status, getPath());
        }
        return Response.status(status).entity(new ErrorResponse(ErrorCode.UNKNOWN)).build();
      }
      default -> {
        LOG.error("Unexpected error: " + getPath(), exception);
      }
    }
    return internal();
  }

  private static boolean isReturnValueViolation(ConstraintViolationException cve) {
    return cve.getConstraintViolations().stream()
        .flatMap(v -> StreamSupport.stream(v.getPropertyPath().spliterator(), false))
        .anyMatch(node -> node.getKind() == ElementKind.RETURN_VALUE);
  }

  private void warn(Throwable t, String format, Object... params) {
    if (logDetails) {
      LOG.warnv(t, format, params);
    } else {
      LOG.warnv(format, params);
    }
  }

  private String getPath() {
    return uriInfo != null ? uriInfo.getRequestUri().getPath() : "unknown";
  }

  private Response notFound() {
    return Response.status(Response.Status.NOT_FOUND).entity(ErrorResponse.notFound()).build();
  }

  private Response unauthorized() {
    return Response.status(Response.Status.UNAUTHORIZED)
        .entity(ErrorResponse.unauthorized())
        .build();
  }

  private Response forbidden() {
    return Response.status(Response.Status.FORBIDDEN).entity(ErrorResponse.forbidden()).build();
  }

  private Response badRequest() {
    return Response.status(Response.Status.BAD_REQUEST).entity(ErrorResponse.badRequest()).build();
  }

  /**
   * Field-level errors, as {@code VALIDATION} — or {@code CONTENT_REJECTED} when the publication
   * filter is among the violations.
   */
  private static Response validationError(ConstraintViolationException cve) {
    List<FieldError> fieldErrors =
        cve.getConstraintViolations().stream()
            .map(GlobalExceptionMapper::toFieldError)
            .collect(Collectors.toList());

    // The publication filter answers with its own code, so a client can say "this text cannot be
    // published" rather than "invalid field". The field detail travels all the same.
    boolean rejected =
        cve.getConstraintViolations().stream()
            .anyMatch(v -> v.getConstraintDescriptor().getAnnotation() instanceof AcceptableText);
    ErrorResponse body =
        rejected
            ? new ErrorResponse(ErrorCode.CONTENT_REJECTED, new ErrorValidationDetails(fieldErrors))
            : ErrorResponse.validation(fieldErrors);
    return Response.status(Response.Status.BAD_REQUEST).entity(body).build();
  }

  private static FieldError toFieldError(ConstraintViolation<?> violation) {
    String propertyPath = violation.getPropertyPath().toString();
    String field =
        propertyPath.contains(".")
            ? propertyPath.substring(propertyPath.lastIndexOf('.') + 1)
            : propertyPath;

    // The rejected value is left out on purpose: it may be a password or a token.
    return new FieldError(field, violation.getMessage());
  }

  private Response pedalonsError(PedalonsException be) {
    Response.Status status = be.getStatus();
    Response.ResponseBuilder builder =
        Response.status(status).entity(new ErrorResponse(be.getErrorCode(), be.getErrorDetails()));
    // Rate limits tell the caller when to come back, instead of leaving them to guess.
    if (be instanceof TooManyRequestsException tmr) {
      builder.header("Retry-After", tmr.getRetryAfterSeconds());
    }
    return builder.build();
  }

  private Response internal() {
    return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
        .entity(ErrorResponse.internal())
        .build();
  }
}
