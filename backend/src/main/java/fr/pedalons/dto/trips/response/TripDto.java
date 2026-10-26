package fr.pedalons.dto.trips.response;

import fr.pedalons.common.MarkdownExcerpt;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.publications.response.PublicationDto;
import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.publications.response.UserParticipations;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.dto.tags.response.TagDto;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.dto.weather.response.RideWeatherSummaryDto;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.asset.ThumbnailLookup.ThemedThumbnail;
import fr.pedalons.service.common.ParticipantPreviewLookup.ParticipantPreview;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.weather.RideWeatherSummaries;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.IntStream;
import lombok.Getter;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Trip data")
@ValidateSchema
@Getter
public class TripDto implements PublicationDto {

  @Schema(description = "Type", required = true)
  final PublicationType type = PublicationType.TRIP;

  @Schema(description = "Team", required = true)
  final TeamPublicationDto team;

  @Schema(description = "Publication ID (TSID)", required = true)
  final String id;

  @Schema(description = "Publication URL slug", required = true)
  final String slug;

  @Schema(description = "Publication name", required = true)
  final String name;

  @Schema(description = "Publication media", required = true)
  final MediaDto media;

  @Nullable
  @Schema(
      description =
          "Plain-text opening of the markdown body, flattened (links become their label) and cut on"
              + " a word boundary at about 200 characters. Null when the body holds no text. Lets a"
              + " list row render its two lines without the body being sent at all — see the 'view'"
              + " parameter.")
  final String excerpt;

  @Schema(description = "Trip start date/time", required = true)
  final Instant dateTime;

  @Schema(
      description =
          "IANA zone the trip's times were entered in and read in: its first stage's, else its"
              + " route's, else the team's. dateTime, endDate, endDateTime and publishAt are"
              + " rendezvous in this zone.",
      examples = "Europe/Paris",
      required = true)
  final String timezone;

  @Nullable
  @Schema(
      description =
          "Date of the last stage — the day the trip ends. Null when the trip has no stage, in"
              + " which case it lasts a day and dateTime is both ends.")
  final Instant endDate;

  @Schema(
      description =
          "When the trip is over, computed by the server: the end of its latest stage — its"
              + " departure plus its route's length at its average speed, or plus 3 hours when the"
              + " stage has no speed or no route — or dateTime plus 3 hours for a trip with no"
              + " stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar"
              + " read.",
      required = true)
  final Instant endDateTime;

  @Schema(description = "Publication status", required = true)
  final Status status;

  @Schema(
      description =
          "Whether the trip is over, computed by the server when the response is built: its last"
              + " stage (endDate, or dateTime when there is none) has started. Independent of"
              + " status — a past cancelled trip is both CANCELLED and finished.",
      required = true)
  final boolean finished;

  @Schema(description = "Visibility level", required = true)
  final Visibility visibility;

  @Nullable
  @Schema(description = "Publication timestamp")
  final Instant publishAt;

  @Nullable
  @Schema(description = "Creation timestamp")
  final Instant createdAt;

  @Nullable
  @Schema(description = "Route slug")
  final String routeSlug;

  @Schema(description = "Number of participants", required = true)
  final int participantCount;

  @Schema(description = "Number of stages", required = true)
  final int stageCount;

  @Nullable
  @Schema(
      description =
          "Distance in metres over every stage that has a route. Null when no stage has one — an"
              + " unrouted trip has no distance, which is not the same as a distance of zero.")
  final Float totalDistance;

  @Nullable
  @Schema(
      description =
          "Elevation gain in metres over every stage that has a route. Null when no stage has one.")
  final Float totalElevationGain;

  @Schema(description = "Trip stages", required = true)
  final List<TripStageDto> stages;

  @Schema(
      description =
          "The first participants of the trip (at most 8), earliest registrations first — enough to"
              + " draw avatars; empty on a list row. participantCount is the total; the whole list"
              + " is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty"
              + " for a caller who is not a member of the team (member names are never sent to"
              + " anyone else): the count stays.",
      required = true)
  final List<PublicUserDto> participants;

  @Nullable
  @Schema(
      description =
          "Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.")
  final String thumbnailLightUrl;

  @Nullable
  @Schema(
      description =
          "Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.")
  final String thumbnailDarkUrl;

  @Nullable
  @Schema(
      description =
          "The one thumbnail to show when the client does not theme its cards: the light variant if"
              + " there is one, else the dark one. Saves a compact row from carrying media.assets"
              + " just to find a picture. Opaque URL: may carry a query string; substitute {size}"
              + " only.")
  final String thumbnailUrl;

  @Schema(description = "Whether the trip is soft-deleted", required = true)
  final boolean deleted;

  @Schema(
      description = "Whether the current user is registered for this trip. False if anonymous.",
      required = true)
  final boolean registered;

  @Nullable
  @Schema(
      description =
          "Number of comments, replies included. Absent when the caller may not read the comments"
              + " of this trip — comments are members-only, so an outsider is told nothing, not"
              + " even zero.")
  final Integer commentCount;

  @Schema(
      description =
          "The team's TRIP tags the trip carries, sorted by label. Empty when it carries none.",
      required = true)
  final List<TagDto> tags;

  @Nullable
  @Schema(
      description =
          "The weather line of a list card: that of the trip's next leg — its first stage still to"
              + " leave, else the trip itself when it has no stage — at the start of its route,"
              + " over the window from its departure to its estimated arrival. Absent when there is"
              + " nothing to show — trip finished, draft or cancelled, next stage without a route,"
              + " forecast not in cache yet — and on the trip's own detail, which reads"
              + " getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE.")
  final RideWeatherSummaryDto weather;

  public TripDto(
      TeamPublicationDto team,
      String id,
      String slug,
      String name,
      MediaDto media,
      @Nullable String excerpt,
      Instant dateTime,
      String timezone,
      @Nullable Instant endDate,
      Instant endDateTime,
      Status status,
      Visibility visibility,
      @Nullable Instant publishAt,
      @Nullable Instant createdAt,
      @Nullable String routeSlug,
      int participantCount,
      int stageCount,
      @Nullable Float totalDistance,
      @Nullable Float totalElevationGain,
      List<TripStageDto> stages,
      List<PublicUserDto> participants,
      @Nullable String thumbnailLightUrl,
      @Nullable String thumbnailDarkUrl,
      @Nullable String thumbnailUrl,
      boolean deleted,
      boolean registered,
      @Nullable Integer commentCount,
      List<TagDto> tags,
      @Nullable RideWeatherSummaryDto weather) {
    super();
    this.team = team;
    this.id = id;
    this.slug = slug;
    this.name = name;
    this.media = media;
    this.excerpt = excerpt;
    this.dateTime = dateTime;
    this.timezone = timezone;
    this.endDate = endDate;
    this.endDateTime = endDateTime;
    this.status = status;
    // docs/LEDGER_*.md API-16: the one rule the clients used to derive each on its own.
    this.finished = (endDate != null ? endDate : dateTime).isBefore(Instant.now());
    this.visibility = visibility;
    this.publishAt = publishAt;
    this.createdAt = createdAt;
    this.routeSlug = routeSlug;
    this.participantCount = participantCount;
    this.stageCount = stageCount;
    this.totalDistance = totalDistance;
    this.totalElevationGain = totalElevationGain;
    this.stages = stages;
    this.participants = participants;
    this.thumbnailLightUrl = thumbnailLightUrl;
    this.thumbnailDarkUrl = thumbnailDarkUrl;
    this.thumbnailUrl = thumbnailUrl;
    this.deleted = deleted;
    this.registered = registered;
    this.commentCount = commentCount;
    this.tags = tags;
    this.weather = weather;
  }

  /**
   * Builds a list row without touching {@code trip.getStages()} or {@code trip.getParticipations()}.
   *
   * <p>A list row renders neither stages nor participants — only their counts — and {@link
   * TripListSummary} carries those, loaded in bulk for the whole page. Going through {@link #from}
   * here would load both collections of every trip on the page just to call {@code size()} on them.
   *
   * <p>No overload defaults the page lookups: a list caller that forgot one would render the row
   * silently without it (no tags, no « me » fields) instead of failing to compile.
   *
   * @param participations the current user's registrations for this whole page, resolved in one
   *     query by {@code ParticipationLookup} — never one lookup per row
   * @param tags the tags of this whole page, resolved in one query by {@code TagLookup}
   * @param weather the weather lines of this whole page, resolved in at most one query by {@code
   *     TripWeatherLookup}
   * @param thumbnails trip id → thumbnail, the trip's own else its route's, for this whole page,
   *     resolved in one query by {@code ThumbnailLookup.forTrips} — never {@code
   *     trip.getRoute().getAssets()} per row (docs/LEDGER_*.md API-83)
   * @param view {@link ListViewMode#COMPACT} leaves the markdown body and the asset inventory out of the
   *     row; {@code excerpt} and {@code thumbnailUrl} carry what it renders instead
   */
  public static TripDto fromListItem(
      Trip trip,
      TripListSummary summary,
      AssetService assetService,
      UserParticipations participations,
      CommentCounts commentCounts,
      ContentTags tags,
      RideWeatherSummaries weather,
      Map<Long, ThemedThumbnail> thumbnails,
      @Nullable ListViewMode view) {
    return build(
        trip,
        List.of(),
        List.of(),
        summary.stageCount(),
        summary.participantCount(),
        summary.totalDistance(),
        summary.totalElevationGain(),
        summary.endDate(),
        assetService,
        participations.isRegisteredToTrip(trip.getId()),
        commentCounts.forEntity(trip.getId()),
        tags.forContent(trip.getId()),
        RideWeatherSummaryDto.fromNullable(
            weather.forTrip(trip.getId()), weather.zoneForTrip(trip.getId())),
        thumbnails.get(trip.getId()),
        view);
  }

  /**
   * @param participants the count and first participants of the trip, resolved by {@code
   *     ParticipantPreviewLookup} — never by walking {@code trip.getParticipations()}, which
   *     hydrates every registration (docs/LEDGER_*.md API-12)
   * @param commentCounts the comment counts of the trip and of its live stages, resolved together
   * @param tags the tags of the trip and of its stages' routes, resolved together in one query by
   *     {@code TagLookup}
   */
  public static TripDto from(
      Trip trip,
      AssetService assetService,
      UserParticipations participations,
      CommentCounts commentCounts,
      ParticipantPreview participants,
      ContentTags tags) {
    List<TripStage> liveStages =
        trip.getStages().stream()
            .filter(s -> !s.isDeleted())
            .sorted(Comparator.comparing(TripStage::getSortOrder))
            .toList();

    List<TripStageDto> stageDtos =
        IntStream.range(0, liveStages.size())
            .mapToObj(
                i ->
                    TripStageDto.from(
                        liveStages.get(i),
                        assetService,
                        tags,
                        commentCounts,
                        i + 1,
                        liveStages.size()))
            .toList();
    List<PublicUserDto> participantDtos = participants.users();

    return build(
        trip,
        stageDtos,
        participantDtos,
        trip.getStageCount(),
        participants.count(),
        totalOf(liveStages, Route::getDistance),
        totalOf(liveStages, Route::getElevationGain),
        endDateOf(liveStages),
        assetService,
        participations.isRegisteredToTrip(trip.getId()),
        commentCounts.forEntity(trip.getId()),
        tags.forContent(trip.getId()),
        null,
        ownOrRouteThumbnail(trip, assetService),
        ListViewMode.FULL);
  }

  /**
   * The detail path's thumbnail: one trip, so walking its assets (which {@code MediaDto} reads
   * anyway) is fine. Same rule as {@code ThumbnailLookup.forTrips} on the list path — the trip's
   * own variants, else its route's.
   */
  private static @Nullable ThemedThumbnail ownOrRouteThumbnail(
      Trip trip, AssetService assetService) {
    String light = null;
    String dark = null;
    for (var asset : trip.getAssets()) {
      switch (asset.getType()) {
        case TRIP_THUMBNAIL_LIGHT -> light = assetService.getImageUrl(asset);
        case TRIP_THUMBNAIL_DARK -> dark = assetService.getImageUrl(asset);
        default -> {}
      }
    }
    if (light == null && dark == null && trip.getRoute() != null) {
      for (var asset : trip.getRoute().getAssets()) {
        switch (asset.getType()) {
          case ROUTE_THUMBNAIL_LIGHT -> light = assetService.getImageUrl(asset);
          case ROUTE_THUMBNAIL_DARK -> dark = assetService.getImageUrl(asset);
          default -> {}
        }
      }
    }
    return light == null && dark == null ? null : new ThemedThumbnail(light, dark);
  }

  /**
   * Sums one route figure over the stages that have a route.
   *
   * <p>Null rather than zero when no stage has a route: a trip nobody has drawn yet has no distance,
   * which a client must be able to tell from a distance of zero. The list path gets the same numbers
   * from {@link TripListSummary}, computed by the database for the whole page at once — this is the
   * detail path, where the stages are in hand already.
   */
  private static @Nullable Float totalOf(
      List<TripStage> stages, Function<Route, @Nullable Float> figure) {
    Float total = null;
    for (TripStage stage : stages) {
      Route route = stage.getRoute();
      if (route == null) {
        continue;
      }
      Float value = figure.apply(route);
      if (value != null) {
        total = total == null ? value : total + value;
      }
    }
    return total;
  }

  /** The date of the last stage, or null for a trip with no stage. */
  private static @Nullable Instant endDateOf(List<TripStage> stages) {
    return stages.stream().map(TripStage::getDateTime).max(Comparator.naturalOrder()).orElse(null);
  }

  private static TripDto build(
      Trip trip,
      List<TripStageDto> stageDtos,
      List<PublicUserDto> participantDtos,
      int stageCount,
      int participantCount,
      @Nullable Float totalDistance,
      @Nullable Float totalElevationGain,
      @Nullable Instant endDate,
      AssetService assetService,
      boolean registered,
      @Nullable Integer commentCount,
      List<TagDto> tags,
      @Nullable RideWeatherSummaryDto weather,
      @Nullable ThemedThumbnail thumbnail,
      @Nullable ListViewMode view) {
    return new TripDto(
        TeamPublicationDto.from(trip.getTeam()),
        TsidUtils.toString(trip.getId()),
        trip.getSlug(),
        trip.getName(),
        MediaDto.from(trip, assetService, view),
        MarkdownExcerpt.of(trip.getMarkdown()),
        trip.getDateTime(),
        trip.zone().getId(),
        endDate,
        PublicationEndCalculator.effectiveEnd(trip),
        trip.getStatus(),
        trip.getVisibility(),
        trip.getPublishAt(),
        trip.getCreatedAt(),
        trip.getRoute() != null ? trip.getRoute().getSlug() : null,
        participantCount,
        stageCount,
        totalDistance,
        totalElevationGain,
        stageDtos,
        participantDtos,
        thumbnail != null ? thumbnail.light() : null,
        thumbnail != null ? thumbnail.dark() : null,
        thumbnail != null ? thumbnail.collapsed() : null,
        trip.isDeleted(),
        registered,
        commentCount,
        tags,
        weather);
  }
}
