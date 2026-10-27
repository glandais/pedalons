package fr.pedalons.dto.auth.request;

import fr.pedalons.common.EmailAddresses;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "OTP request")
@ValidateSchema
@Builder
public record OtpRequest(
    @NotBlank
        @Email
        @Size(max = 250)
        @Schema(description = "Email address", examples = "user@example.com")
        String email) {
  public OtpRequest {
    email = EmailAddresses.normalize(email);
  }
}
