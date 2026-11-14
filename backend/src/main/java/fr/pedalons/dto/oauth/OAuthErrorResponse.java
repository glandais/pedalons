package fr.pedalons.dto.oauth;

import com.fasterxml.jackson.annotation.JsonProperty;
import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/** The error response of RFC 6749 §5.2 — the token endpoint's only error shape. */
@Schema(description = "OAuth 2.0 token error (RFC 6749 §5.2)")
@ValidateSchema
public record OAuthErrorResponse(
    @Schema(
            description = "invalid_request, invalid_grant or unsupported_grant_type",
            required = true)
        String error,
    @JsonProperty("error_description")
        @Schema(description = "What was wrong, for the developer", required = true)
        String errorDescription) {

  public static final String INVALID_REQUEST = "invalid_request";
  public static final String INVALID_GRANT = "invalid_grant";
  public static final String UNSUPPORTED_GRANT_TYPE = "unsupported_grant_type";
}
