package fr.pedalons.dto.error;

import java.util.List;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * Why a save broke the invariant "a ride or a trip that is not {@code TEAM} only uses routes that
 * are not {@code TEAM}" (docs/LEDGER_*.md API-176, decisions D5 and D6). Exactly one of the two
 * lists is filled: {@code routes} when a ride or a trip is saved, {@code usages} when a route is.
 */
@RequiredArgsConstructor
@Getter
public class IncompatibleVisibilityDetails implements ErrorDetails {
  @Schema(description = "Type", required = true)
  final ErrorCode type = ErrorCode.INCOMPATIBLE_VISIBILITY;

  @Schema(
      description =
          "Saving a ride or a trip (creation, update, restore): its TEAM routes — its own, its"
              + " groups' or its stages'. Replaying the creation or the update with"
              + " alignVisibility = true raises each to its proposedVisibility in the same"
              + " transaction. Empty when a route was saved.",
      required = true)
  final List<IncompatibleRouteDto> routes;

  @Schema(
      description =
          "Saving a route as TEAM: the rides and trips visible outside the team that use it —"
              + " directly, through a group or through a stage — drafts included, deleted ones"
              + " left out. There is no alignment in this direction: change them first. Empty when"
              + " a ride or a trip was saved.",
      required = true)
  final List<IncompatibleRouteUsageDto> usages;

  public static IncompatibleVisibilityDetails ofRoutes(List<IncompatibleRouteDto> routes) {
    return new IncompatibleVisibilityDetails(routes, List.of());
  }

  public static IncompatibleVisibilityDetails ofUsages(List<IncompatibleRouteUsageDto> usages) {
    return new IncompatibleVisibilityDetails(List.of(), usages);
  }
}
