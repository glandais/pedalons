package fr.pedalons.dto.error;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.DiscriminatorMapping;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

// Response DTOs
@JsonTypeInfo(
    use = JsonTypeInfo.Id.NAME,
    include = JsonTypeInfo.As.EXISTING_PROPERTY,
    property = "type" // discriminator
    )
@JsonSubTypes({
  @JsonSubTypes.Type(value = ErrorValidationDetails.class, name = "VALIDATION"),
  @JsonSubTypes.Type(value = NotFoundDetails.class, name = "NOT_FOUND"),
  @JsonSubTypes.Type(value = AssetNotAvailableDetails.class, name = "ASSET_NOT_AVAILABLE"),
  @JsonSubTypes.Type(value = IncompatibleVisibilityDetails.class, name = "INCOMPATIBLE_VISIBILITY"),
  @JsonSubTypes.Type(value = TeamMemberLimitDetails.class, name = "TEAM_MEMBER_LIMIT_REACHED"),
  @JsonSubTypes.Type(value = PlannerQuotaDetails.class, name = "PLANNER_QUOTA_REACHED"),
})
@Schema(
    description = "Error details",
    discriminatorProperty = "type",
    discriminatorMapping = {
      @DiscriminatorMapping(value = "VALIDATION", schema = ErrorValidationDetails.class),
      @DiscriminatorMapping(value = "NOT_FOUND", schema = NotFoundDetails.class),
      @DiscriminatorMapping(value = "ASSET_NOT_AVAILABLE", schema = AssetNotAvailableDetails.class),
      @DiscriminatorMapping(
          value = "INCOMPATIBLE_VISIBILITY",
          schema = IncompatibleVisibilityDetails.class),
      @DiscriminatorMapping(
          value = "TEAM_MEMBER_LIMIT_REACHED",
          schema = TeamMemberLimitDetails.class),
      @DiscriminatorMapping(value = "PLANNER_QUOTA_REACHED", schema = PlannerQuotaDetails.class),
    },
    oneOf = {
      ErrorValidationDetails.class,
      NotFoundDetails.class,
      AssetNotAvailableDetails.class,
      IncompatibleVisibilityDetails.class,
      TeamMemberLimitDetails.class,
      PlannerQuotaDetails.class
    })
@ValidateSchema
public interface ErrorDetails {

  ErrorCode getType();
}
