package fr.pedalons.dto.oauth;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/** The token response of RFC 6749 §5.1, with its field names: OAuth libraries read those. */
@Schema(description = "OAuth 2.0 token response (RFC 6749 §5.1)")
@ValidateSchema
@JsonInclude(JsonInclude.Include.NON_NULL)
public record OAuthTokenResponse(
    @JsonProperty("access_token")
        @Schema(
            description = "Access token, sent as « Authorization: Bearer … » on every API call",
            required = true)
        String accessToken,
    @JsonProperty("token_type") @Schema(description = "Always 'Bearer'", required = true)
        String tokenType,
    @JsonProperty("expires_in")
        @Schema(description = "Lifetime of the access token, in seconds", required = true)
        int expiresIn,
    @JsonProperty("refresh_token")
        @Schema(
            description =
                "Refresh token, to keep in place of the one presented: it rotates at every"
                    + " refresh. Absent when the refresh came within the grace of a rotation made"
                    + " by another one — keep the token already held.")
        @Nullable String refreshToken) {}
