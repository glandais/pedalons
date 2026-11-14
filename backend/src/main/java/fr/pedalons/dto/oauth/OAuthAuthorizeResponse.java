package fr.pedalons.dto.oauth;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Where the site sends the browser once an OAuth 2.0 request is approved")
@ValidateSchema
public record OAuthAuthorizeResponse(
    @Schema(
            description =
                "The application's redirect_uri, carrying the authorization code and the state",
            required = true)
        String redirectUri) {}
