package fr.pedalons.dto.auth.request;

import fr.pedalons.common.EmailAddresses;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "OTP verification request")
@ValidateSchema
@Builder
public record VerifyOtpRequest(
    @NotBlank
        @Email
        @Size(max = 250)
        @Schema(description = "Email address", examples = "user@example.com")
        String email,
    @NotBlank
        @Pattern(regexp = "^\\d{6}$", message = "Code must be 6 digits")
        @Schema(description = "6-digit OTP code", examples = "123456")
        String code) {
  public VerifyOtpRequest {
    email = EmailAddresses.normalize(email);
  }
}
