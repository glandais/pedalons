package fr.pedalons.dto.rides.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.repository.ride.RideGroupRepository.GroupRow;
import fr.pedalons.service.asset.ThumbnailLookup.ThemedThumbnail;
import fr.pedalons.service.common.ParticipantPreviewLookup.ParticipantPreview;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Ride group information")
@ValidateSchema
public record RideGroupDto(
    @Schema(description = "Group ID (TSID)", required = true) String id,
    @Schema(description = "Group name", required = true) String name,
    @Nullable
        @Schema(
            description =
                "Deprecated in favour of startAt, for display: the group's start as a wall time of"
                    + " the ride's zone, null when it leaves with the ride. What an editor sends"
                    + " back as GroupRequest.time.")
        LocalTime time,
    @Schema(
            description =
                "When the group leaves: its time on the ride's local date in the ride's zone, the"
                    + " ride's dateTime when it has no time of its own.",
            required = true)
        Instant startAt,
    @Nullable @Schema(description = "Route slug") String routeSlug,
    @Nullable @Schema(description = "Average speed in km/h") Float averageSpeed,
    @Nullable @Schema(description = "Maximum participants") Integer maxParticipants,
    @Schema(description = "Current number of participants", required = true) int countParticipants,
    @Schema(
            description =
                "The first participants of the group (at most 8), earliest registrations first —"
                    + " enough to draw avatars. countParticipants is the total; the whole list is"
                    + " paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.",
            required = true)
        List<PublicUserDto> participants,
    @Schema(description = "Sort order", required = true) int sortOrder,
    @Schema(
            description =
                "Whether the current user is registered in THIS group. False if anonymous.",
            required = true)
        boolean registered,
    @Schema(
            description =
                "Whether the group has reached maxParticipants. False when maxParticipants is not"
                    + " set.",
            required = true)
        boolean full,
    @Nullable @Schema(description = "Distance in meters of the group route, if it has one")
        Float distance,
    @Nullable
        @Schema(description = "Total elevation gain in meters of the group route, if it has one")
        Float elevationGain,
    @Nullable
        @Schema(
            description =
                "The member who leads this group, when one is designated. Null means no leader was"
                    + " designated — render nothing rather than falling back on the ride's"
                    + " creator, who is the same person on every group of the ride.")
        PublicUserDto leader,
    @Nullable
        @Schema(
            description =
                "Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a"
                    + " query string; substitute {size} only.")
        String thumbnailLightUrl,
    @Nullable
        @Schema(
            description =
                "Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a"
                    + " query string; substitute {size} only.")
        String thumbnailDarkUrl,
    @Nullable
        @Schema(
            description =
                "The one thumbnail of the group route to show when the client does not theme its"
                    + " cards: the light variant if there is one, else the dark one. Null when the"
                    + " group has no route or its route has no thumbnail — the ride's own thumbnail"
                    + " is then the one to fall back on. Opaque URL: may carry a query string;"
                    + " substitute {size} only.")
        String thumbnailUrl) {

  /**
   * @param registeredGroupId the group of this ride the current user joined, or {@code null} — the
   *     caller resolved it once for the whole payload rather than once per group
   * @param routeThumbnail the thumbnail of the group's route, resolved by {@code ThumbnailLookup}
   *     for every group of the ride in one query — never by walking {@code route.getAssets()} here
   * @param participants the count and first participants of the group, resolved by {@code
   *     ParticipantPreviewLookup} for every group of the ride at once — never by walking {@code
   *     group.getParticipations()}, which hydrates the whole list
   */
  public static RideGroupDto from(
      RideGroup group,
      ZoneId rideZone,
      @Nullable Long registeredGroupId,
      @Nullable ThemedThumbnail routeThumbnail,
      ParticipantPreview participants) {
    // RideGroup.route is a to-one, already resolved (and batched across the ride's groups) by the
    // routeSlug read just below: the metrics cost no extra query.
    Route route = group.getRoute();
    return new RideGroupDto(
        TsidUtils.toString(group.getId()),
        group.getName(),
        EventTimezoneResolver.ownTime(group.getRide().getDateTime(), group.getStartAt(), rideZone),
        group.getStartAt(),
        route != null ? route.getSlug() : null,
        group.getAverageSpeed(),
        group.getMaxParticipants(),
        participants.count(),
        participants.users(),
        group.getSortOrder(),
        registeredGroupId != null && registeredGroupId.equals(group.getId()),
        group.getMaxParticipants() != null && participants.count() >= group.getMaxParticipants(),
        route != null ? route.getDistance() : null,
        route != null ? route.getElevationGain() : null,
        group.getLeader() != null ? PublicUserDto.from(group.getLeader()) : null,
        routeThumbnail != null ? routeThumbnail.light() : null,
        routeThumbnail != null ? routeThumbnail.dark() : null,
        routeThumbnail != null ? routeThumbnail.collapsed() : null);
  }

  /**
   * The group the current user joined, on a row of a publication list (docs/LEDGER_*.md API-4).
   *
   * <p>Same payload as on the detail, built from a projection rather than the entity: {@code
   * registered} is true by construction. The leader is the group's own, null when none was
   * designated — never the ride's creator.
   *
   * @param row the group's scalars, projected for the whole page in one query
   * @param routeThumbnail resolved for every such group of the page in one query
   * @param participants resolved for every such group of the page in two queries
   */
  public static RideGroupDto fromRow(
      GroupRow row, @Nullable ThemedThumbnail routeThumbnail, ParticipantPreview participants) {
    return new RideGroupDto(
        TsidUtils.toString(row.id()),
        row.name(),
        row.time(),
        row.startAt(),
        row.routeSlug(),
        row.averageSpeed(),
        row.maxParticipants(),
        participants.count(),
        participants.users(),
        row.sortOrder(),
        true,
        row.maxParticipants() != null && participants.count() >= row.maxParticipants(),
        row.routeId() != null ? row.distance() : null,
        row.routeId() != null ? row.elevationGain() : null,
        row.leaderId() != null
            ? new PublicUserDto(
                TsidUtils.toString(row.leaderId()), row.leaderDisplayName(), row.leaderAvatarUrl())
            : null,
        routeThumbnail != null ? routeThumbnail.light() : null,
        routeThumbnail != null ? routeThumbnail.dark() : null,
        routeThumbnail != null ? routeThumbnail.collapsed() : null);
  }
}
