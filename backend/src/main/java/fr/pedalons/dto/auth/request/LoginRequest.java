package fr.pedalons.dto.auth.request;

import fr.pedalons.common.EmailAddresses;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Password login request")
@ValidateSchema
@Builder
public record LoginRequest(
    @NotBlank
        @Email
        @Size(max = 250)
        @Schema(description = "Email address", examples = "user@example.com")
        String email,
    @NotBlank @Size(max = 100) @Schema(description = "Password") String password) {
  public LoginRequest {
    email = EmailAddresses.normalize(email);
  }
}
