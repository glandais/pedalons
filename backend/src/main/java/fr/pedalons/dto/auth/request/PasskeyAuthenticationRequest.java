package fr.pedalons.dto.auth.request;

import fr.pedalons.common.EmailAddresses;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Request for passkey authentication options")
@ValidateSchema
@Builder
public record PasskeyAuthenticationRequest(
    @Nullable
        @Email
        @Size(max = 250)
        @Schema(description = "Optional email to filter passkeys", examples = "user@example.com")
        String email) {
  public PasskeyAuthenticationRequest {
    email = EmailAddresses.normalize(email);
  }
}
