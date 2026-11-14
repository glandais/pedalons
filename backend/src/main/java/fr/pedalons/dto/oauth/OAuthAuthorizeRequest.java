package fr.pedalons.dto.oauth;

import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * What the site's consent screen sends once the member pressed « Autoriser »: the parameters the
 * application put on {@code /oauth/authorize}, as they came.
 */
@Schema(description = "Approval of an OAuth 2.0 authorization request by the signed-in user")
@ValidateSchema
public record OAuthAuthorizeRequest(
    @Schema(
            description =
                "The name the application gave itself (client_id). Free text: applications are"
                    + " not registered.",
            required = true)
        @NotBlank
        @Size(max = 40)
        String clientId,
    @Schema(
            description =
                "Where the code is sent (redirect_uri): any absolute URL or deep link, without a"
                    + " fragment. Not checked against anything.",
            required = true)
        @NotBlank
        @Size(max = 2000)
        String redirectUri,
    @Schema(
            description = "PKCE challenge (code_challenge): BASE64URL(SHA-256(code_verifier))",
            required = true)
        @NotBlank
        @Pattern(regexp = "^[A-Za-z0-9_-]{43}$")
        String codeChallenge,
    @Schema(description = "PKCE method (code_challenge_method): S256 only", required = true)
        @NotBlank
        @Pattern(regexp = "^S256$")
        String codeChallengeMethod,
    @Schema(description = "Opaque value given back to the application with the code (state)")
        @Nullable
        @Size(max = 500)
        String state,
    @Schema(
            description =
                "Must be true: the user explicitly confirmed, on a screen naming the application"
                    + " and where the code goes",
            required = true)
        @NotNull
        @AssertTrue
        Boolean confirmed) {}
