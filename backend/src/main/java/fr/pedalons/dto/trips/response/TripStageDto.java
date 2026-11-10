package fr.pedalons.dto.trips.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.gps.response.RouteGpsSyncStatuses;
import fr.pedalons.dto.places.response.PlaceDetailDto;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.publication.PublicationEndCalculator.LegEstimate;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Trip stage information")
@ValidateSchema
public record TripStageDto(
    @Schema(description = "Stage ID (TSID)", required = true) String id,
    @Schema(description = "Stage slug", required = true) String slug,
    @Schema(description = "Stage name", required = true) String name,
    @Schema(description = "Stage date/time", required = true) Instant dateTime,
    @Schema(
            description =
                "IANA zone the stage's time was entered in and is read in: its start place's,"
                    + " else its route's, else the previous stage's, else the trip route's, else"
                    + " the team's. A stage may differ from its trip.",
            examples = "Asia/Tokyo",
            required = true)
        String timezone,
    @Nullable @Schema(description = "Average speed in km/h") Float averageSpeed,
    @Nullable @Schema(description = "Route") RouteDto route,
    @Nullable @Schema(description = "Start place") PlaceDetailDto startPlace,
    @Nullable @Schema(description = "End place") PlaceDetailDto endPlace,
    @Schema(description = "Stage media", required = true) MediaDto media,
    @Schema(description = "Sort order", required = true) int sortOrder,
    @Schema(
            description =
                "Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a"
                    + " stage header. Unlike sortOrder, which is a persisted rank that may have"
                    + " gaps, this is a rank a client can print.",
            required = true)
        int stageIndex,
    @Schema(
            description = "How many live stages the trip has — the '/ 5' of 'Day 2 / 5'.",
            required = true)
        int stageCount,
    @Nullable
        @Schema(
            description =
                "Number of comments on the stage's own thread. Absent when the caller cannot read"
                    + " comments (not a member of the team), like TripDto.commentCount.")
        Integer commentCount,
    @Nullable
        @Schema(
            description =
                "When the stage is expected to end: dateTime plus its route's length at its"
                    + " averageSpeed. Absent when it has no route or no averageSpeed — no default"
                    + " speed here. Known whatever the forecast window, unlike"
                    + " WeatherLegDto.arrivalTime.")
        Instant estimatedArrival,
    @Nullable
        @Schema(
            description =
                "Minutes from dateTime to estimatedArrival, rounded. Absent when"
                    + " estimatedArrival is.")
        Integer estimatedDurationMinutes) {

  /**
   * @param routeTags the tags of the stage's route, resolved with the trip's own by {@code
   *     TagLookup} — never one lookup per stage
   * @param stageIndex 1-based position among the trip's live stages
   * @param stageCount how many live stages the trip has
   * @param commentCounts the stages' comment counts, resolved with the trip's own by {@code
   *     CommentCountLookup}
   * @param gpsSync the caller's sync statuses of the stages' routes, resolved with the whole trip
   *     by {@code GpsSyncLookup} — never one lookup per stage
   */
  public static TripStageDto from(
      TripStage stage,
      AssetService assetService,
      ContentTags routeTags,
      CommentCounts commentCounts,
      RouteGpsSyncStatuses gpsSync,
      int stageIndex,
      int stageCount) {
    LegEstimate estimate = PublicationEndCalculator.estimate(stage);
    return new TripStageDto(
        TsidUtils.toString(stage.getId()),
        stage.getSlug(),
        stage.getName(),
        stage.getDateTime(),
        stage.zone().getId(),
        stage.getAverageSpeed(),
        stage.getRoute() != null
            ? RouteDto.from(stage.getRoute(), assetService, CommentCounts.NONE, routeTags, gpsSync)
            : null,
        stage.getStartPlace() != null ? PlaceDetailDto.from(stage.getStartPlace()) : null,
        stage.getEndPlace() != null ? PlaceDetailDto.from(stage.getEndPlace()) : null,
        MediaDto.from(stage, assetService),
        stage.getSortOrder(),
        stageIndex,
        stageCount,
        commentCounts.forEntity(stage.getId()),
        estimate != null ? estimate.arrival() : null,
        estimate != null ? estimate.durationMinutes() : null);
  }
}
