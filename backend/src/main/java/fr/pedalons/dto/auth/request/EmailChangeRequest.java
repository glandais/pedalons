package fr.pedalons.dto.auth.request;

import fr.pedalons.common.EmailAddresses;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Request to change the signed-in user's email address")
@ValidateSchema
public record EmailChangeRequest(
    @NotBlank
        @Email
        @Size(max = 250)
        @Schema(description = "New email address", examples = "user@example.com", required = true)
        String email) {
  public EmailChangeRequest {
    email = EmailAddresses.normalize(email);
  }
}
