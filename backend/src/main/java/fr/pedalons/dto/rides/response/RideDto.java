package fr.pedalons.dto.rides.response;

import fr.pedalons.common.MarkdownExcerpt;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.places.response.PlaceDetailDto;
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
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.asset.ThumbnailLookup.ThemedThumbnail;
import fr.pedalons.service.common.ParticipantPreviewLookup.ParticipantPreview;
import fr.pedalons.service.common.ParticipantPreviewLookup.PreviewedParticipant;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.weather.RideWeatherSummaries;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import lombok.Getter;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

// Response DTOs
@Schema(description = "Ride summary data")
@ValidateSchema
@Getter
public class RideDto implements PublicationDto {

  @Schema(description = "Type", required = true)
  final PublicationType type = PublicationType.RIDE;

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

  @Schema(description = "Publication date/time", required = true)
  final Instant dateTime;

  @Schema(
      description =
          "IANA zone the ride's times were entered in and read in: its start place's, else its"
              + " route's, else the team's. dateTime, publishAt, endDateTime and the groups'"
              + " startAt are rendezvous in this zone.",
      examples = "Europe/Paris",
      required = true)
  final String timezone;

  @Schema(
      description =
          "When the ride is over, computed by the server: the latest of its groups, each one its"
              + " departure plus its route's length at its average speed — or plus 3 hours when the"
              + " group has no speed or no route, and for a ride with no group. What the upcoming"
              + " and past lists (when=UPCOMING|PAST) and the calendar read.",
      required = true)
  final Instant endDateTime;

  @Schema(description = "Publication status", required = true)
  final Status status;

  @Schema(
      description =
          "Whether the ride is over, computed by the server when the response is built: its start"
              + " time has passed. Independent of status — a past cancelled ride is both"
              + " CANCELLED and finished.",
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

  @Schema(description = "Number of groups", required = true)
  final int groupCount;

  @Schema(description = "Ride groups", required = true)
  final List<RideGroupDto> groups;

  @Schema(
      description =
          "Every group of the ride in sort order, as a card shows it: name, pace, start time and"
              + " fill (countParticipants against maxParticipants). Filled on list rows too, where"
              + " groups is empty — a card draws its per-group fill bars without opening the ride."
              + " Carries no leader nor participants: those are on groups, in the detail.",
      required = true)
  final List<RideGroupSummaryDto> groupSummaries;

  @Nullable
  @Schema(
      description =
          "Distance in meters of the ride's route — or, when the ride itself has none, of the"
              + " route of its first group (in sort order) that has one. Null when no route is set"
              + " anywhere.")
  final Float distance;

  @Nullable
  @Schema(
      description =
          "Total elevation gain in meters, from the same route as distance. Null when no route is"
              + " set anywhere.")
  final Float elevationGain;

  @Nullable
  @Schema(
      description =
          "Surface type, from the same route as distance. Null when no route is set anywhere.")
  final SurfaceType surfaceType;

  @Nullable
  @Schema(description = "Start place")
  final PlaceDetailDto startPlace;

  @Nullable
  @Schema(description = "End place")
  final PlaceDetailDto endPlace;

  @Schema(description = "Preview of first participants (max 5)", required = true)
  final List<PublicUserDto> topParticipants;

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

  @Schema(description = "Whether the ride is soft-deleted", required = true)
  final boolean deleted;

  @Schema(
      description =
          "Whether the current user is registered in one of this ride's groups. False if"
              + " anonymous.",
      required = true)
  final boolean registered;

  @Nullable
  @Schema(description = "ID (TSID) of the group the current user joined, null if not registered")
  final String registeredGroupId;

  @Nullable
  @Schema(
      description =
          "The group the current user joined, in full — the same object as the matching entry of"
              + " groups. Null if not registered or anonymous. Set on list rows too, where groups"
              + " is empty: a client rendering \"my next ride\" needs no second request for its"
              + " group. Its leader is the group's own, null when none was designated.")
  final RideGroupDto registeredGroup;

  @Schema(
      description =
          "Whether every group of the ride has reached its capacity. False when the ride has no"
              + " group, or when at least one group has no maxParticipants.",
      required = true)
  final boolean full;

  @Nullable
  @Schema(
      description =
          "Capacity of the whole ride: the sum of its groups' maxParticipants, to render"
              + " participantCount against it (\"12/40\"). Null when the ride has no group, or when"
              + " at least one group has no maxParticipants — the ride then has no overall limit,"
              + " and is never full. Set on list rows too, where groups is empty.")
  final Integer maxParticipants;

  @Nullable
  @Schema(
      description =
          "Number of comments, replies included. Absent when the caller may not read the comments"
              + " of this ride — comments are members-only, so an outsider is told nothing, not"
              + " even zero.")
  final Integer commentCount;

  @Schema(
      description =
          "The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.",
      required = true)
  final List<TagDto> tags;

  @Nullable
  @Schema(
      description =
          "The weather line of a card: the meeting point, over the window from the departure to"
              + " the estimated arrival of the last group. Absent when there is nothing to show —"
              + " finished or cancelled ride, no place, forecast not in cache yet; present only"
              + " with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.")
  final RideWeatherSummaryDto weather;

  public RideDto(
      TeamPublicationDto team,
      String id,
      String slug,
      String name,
      MediaDto media,
      @Nullable String excerpt,
      Instant dateTime,
      String timezone,
      Instant endDateTime,
      Status status,
      Visibility visibility,
      @Nullable Instant publishAt,
      @Nullable Instant createdAt,
      @Nullable String routeSlug,
      int participantCount,
      int groupCount,
      List<RideGroupDto> groups,
      List<RideGroupSummaryDto> groupSummaries,
      @Nullable Float distance,
      @Nullable Float elevationGain,
      @Nullable SurfaceType surfaceType,
      @Nullable PlaceDetailDto startPlace,
      @Nullable PlaceDetailDto endPlace,
      List<PublicUserDto> topParticipants,
      @Nullable String thumbnailLightUrl,
      @Nullable String thumbnailDarkUrl,
      @Nullable String thumbnailUrl,
      boolean deleted,
      boolean registered,
      @Nullable String registeredGroupId,
      @Nullable RideGroupDto registeredGroup,
      boolean full,
      @Nullable Integer maxParticipants,
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
    this.endDateTime = endDateTime;
    this.status = status;
    // docs/LEDGER_*.md API-16: the one rule the clients used to derive each on its own.
    this.finished = dateTime.isBefore(Instant.now());
    this.visibility = visibility;
    this.publishAt = publishAt;
    this.createdAt = createdAt;
    this.routeSlug = routeSlug;
    this.participantCount = participantCount;
    this.groupCount = groupCount;
    this.groups = groups;
    this.groupSummaries = groupSummaries;
    this.distance = distance;
    this.elevationGain = elevationGain;
    this.surfaceType = surfaceType;
    this.startPlace = startPlace;
    this.endPlace = endPlace;
    this.topParticipants = topParticipants;
    this.thumbnailLightUrl = thumbnailLightUrl;
    this.thumbnailDarkUrl = thumbnailDarkUrl;
    this.thumbnailUrl = thumbnailUrl;
    this.deleted = deleted;
    this.registered = registered;
    this.registeredGroupId = registeredGroupId;
    this.registeredGroup = registeredGroup;
    this.full = full;
    this.maxParticipants = maxParticipants;
    this.commentCount = commentCount;
    this.tags = tags;
    this.weather = weather;
  }

  /**
   * Builds a list row without touching {@code ride.getGroups()}.
   *
   * <p>The group/participant numbers come from {@link RideListSummary}, which the caller loaded in
   * bulk for the whole page. Going through {@link #from} here would hydrate every participation and
   * every participant of every ride on the page just to count them and keep five.
   *
   * <p>No overload defaults the page lookups: a list caller that forgot one would render the row
   * silently without it (no tags, no « me » fields) instead of failing to compile.
   *
   * @param participations the current user's registrations for this whole page, resolved in one
   *     query by {@code ParticipationLookup} — never one lookup per row
   * @param tags the tags of this whole page, resolved in one query by {@code TagLookup}
   * @param weather the weather lines of this whole page, resolved in at most one query by {@code
   *     RideWeatherLookup}
   * @param thumbnails ride id → thumbnail, the ride's own else its route's, for this whole page,
   *     resolved in one query by {@code ThumbnailLookup.forRides} — never {@code
   *     ride.getRoute().getAssets()} per row (docs/LEDGER_*.md API-80)
   * @param view {@link ListViewMode#COMPACT} leaves the markdown body and the asset inventory out of the
   *     row; {@code excerpt} and {@code thumbnailUrl} carry what it renders instead
   */
  public static RideDto fromListItem(
      Ride ride,
      RideListSummary summary,
      AssetService assetService,
      UserParticipations participations,
      CommentCounts commentCounts,
      ContentTags tags,
      RideWeatherSummaries weather,
      Map<Long, ThemedThumbnail> thumbnails,
      @Nullable ListViewMode view) {
    return build(
        ride,
        List.of(),
        summary.groups(),
        summary.firstGroupRoute(),
        summary.groupCount(),
        summary.participantCount(),
        summary.topParticipants(),
        assetService,
        participations.registeredGroupId(ride.getId()),
        participations.registeredGroup(ride.getId()),
        summary.full(),
        summary.maxParticipants(),
        commentCounts.forEntity(ride.getId()),
        tags.forContent(ride.getId()),
        weather,
        thumbnails.get(ride.getId()),
        view);
  }

  /**
   * @param routeThumbnails route id → thumbnail, for the routes of this ride's groups, resolved in
   *     one query by {@code ThumbnailLookup} — never one lookup per group
   * @param groupParticipants group id → count and first participants, for every group of this
   *     ride, resolved by {@code ParticipantPreviewLookup} in two queries. Counts, capacity and the
   *     avatars all come from it: walking {@code group.getParticipations()} here would hydrate every
   *     registration of the ride (docs/LEDGER_*.md API-12).
   * @param tags the ride's tags, from {@code TagLookup}
   * @param weather the ride's weather line, from {@code RideWeatherLookup}
   */
  public static RideDto from(
      Ride ride,
      AssetService assetService,
      UserParticipations participations,
      CommentCounts commentCounts,
      Map<Long, ThemedThumbnail> routeThumbnails,
      Map<Long, ParticipantPreview> groupParticipants,
      List<TagDto> tags,
      RideWeatherSummaries weather) {
    Long registeredGroupId = participations.registeredGroupId(ride.getId());
    List<RideGroup> groups =
        ride.getGroups().stream().sorted(Comparator.comparing(RideGroup::getSortOrder)).toList();
    // Read once: the groups' fallback start is in the ride's zone (docs/LEDGER_*.md API-60).
    ZoneId rideZone = ride.zone();
    Function<RideGroup, ParticipantPreview> preview =
        group -> groupParticipants.getOrDefault(group.getId(), ParticipantPreview.EMPTY);

    List<RideGroupDto> groupDtos =
        groups.stream()
            .map(
                group ->
                    RideGroupDto.from(
                        group,
                        rideZone,
                        registeredGroupId,
                        group.getRoute() != null
                            ? routeThumbnails.get(group.getRoute().getId())
                            : null,
                        preview.apply(group)))
            .toList();

    // The first 5 registrations of the ride. Each group's preview holds its own earliest ones, so
    // merging them is enough; a member is in one group of a ride at most, the distinct is a guard.
    Set<String> seenUserIds = new HashSet<>();
    List<PublicUserDto> topParticipants =
        groups.stream()
            .flatMap(group -> preview.apply(group).first().stream())
            .sorted(Comparator.comparing(PreviewedParticipant::registeredAt))
            .map(PreviewedParticipant::user)
            .filter(user -> seenUserIds.add(user.id()))
            .limit(5)
            .toList();

    // "Every group is at capacity" is a fold over the previews' counts, not a query. A ride with no
    // group is not full.
    boolean full =
        !groups.isEmpty()
            && groups.stream()
                .allMatch(
                    g ->
                        g.getMaxParticipants() != null
                            && preview.apply(g).count() >= g.getMaxParticipants());
    int participantCount = groups.stream().mapToInt(g -> preview.apply(g).count()).sum();
    // Same rule as RideSummaryRepository on the list path: the sum of the capacities, null as soon
    // as one group is uncapped (or there is no group).
    Integer maxParticipants =
        groups.isEmpty() || groups.stream().anyMatch(g -> g.getMaxParticipants() == null)
            ? null
            : groups.stream().mapToInt(RideGroup::getMaxParticipants).sum();

    RideGroupDto registeredGroup =
        groupDtos.stream().filter(RideGroupDto::registered).findFirst().orElse(null);

    // Same fallback as the list row: the first group in sort order that has a route.
    RideListSummary.RouteMetrics firstGroupRoute =
        groups.stream()
            .map(RideGroup::getRoute)
            .filter(Objects::nonNull)
            .findFirst()
            .map(RideDto::metricsOf)
            .orElse(null);

    return build(
        ride,
        groupDtos,
        groupDtos.stream().map(RideGroupSummaryDto::from).toList(),
        firstGroupRoute,
        groups.size(),
        participantCount,
        topParticipants,
        assetService,
        registeredGroupId,
        registeredGroup,
        full,
        maxParticipants,
        commentCounts.forEntity(ride.getId()),
        tags,
        weather,
        ownOrRouteThumbnail(ride, assetService),
        ListViewMode.FULL);
  }

  /**
   * The detail path's thumbnail: one ride, so walking its assets (which {@code MediaDto} reads
   * anyway) is fine. Same rule as {@code ThumbnailLookup.forRides} on the list path — the ride's
   * own variants, else its route's.
   */
  private static @Nullable ThemedThumbnail ownOrRouteThumbnail(
      Ride ride, AssetService assetService) {
    String light = null;
    String dark = null;
    for (var asset : ride.getAssets()) {
      switch (asset.getType()) {
        case RIDE_THUMBNAIL_LIGHT -> light = assetService.getImageUrl(asset);
        case RIDE_THUMBNAIL_DARK -> dark = assetService.getImageUrl(asset);
        default -> {}
      }
    }
    if (light == null && dark == null && ride.getRoute() != null) {
      for (var asset : ride.getRoute().getAssets()) {
        switch (asset.getType()) {
          case ROUTE_THUMBNAIL_LIGHT -> light = assetService.getImageUrl(asset);
          case ROUTE_THUMBNAIL_DARK -> dark = assetService.getImageUrl(asset);
          default -> {}
        }
      }
    }
    return light == null && dark == null ? null : new ThemedThumbnail(light, dark);
  }

  private static RideListSummary.RouteMetrics metricsOf(Route route) {
    return new RideListSummary.RouteMetrics(
        route.getDistance(), route.getElevationGain(), route.getSurfaceType());
  }

  private static RideDto build(
      Ride ride,
      List<RideGroupDto> groupDtos,
      List<RideGroupSummaryDto> groupSummaries,
      RideListSummary.@Nullable RouteMetrics firstGroupRoute,
      int groupCount,
      int participantCount,
      List<PublicUserDto> topParticipants,
      AssetService assetService,
      @Nullable Long registeredGroupId,
      @Nullable RideGroupDto registeredGroup,
      boolean full,
      @Nullable Integer maxParticipants,
      @Nullable Integer commentCount,
      List<TagDto> tags,
      RideWeatherSummaries weather,
      @Nullable ThemedThumbnail thumbnail,
      @Nullable ListViewMode view) {
    Place startPlace = ride.getStart();
    Place endPlace = ride.getEnd();
    // Ride.route is an eager to-one, already loaded with the ride: the metrics cost no query.
    RideListSummary.RouteMetrics metrics =
        ride.getRoute() != null ? metricsOf(ride.getRoute()) : firstGroupRoute;

    return new RideDto(
        TeamPublicationDto.from(ride.getTeam()),
        TsidUtils.toString(ride.getId()),
        ride.getSlug(),
        ride.getName(),
        MediaDto.from(ride, assetService, view),
        MarkdownExcerpt.of(ride.getMarkdown()),
        ride.getDateTime(),
        ride.zone().getId(),
        PublicationEndCalculator.effectiveEnd(ride),
        ride.getStatus(),
        ride.getVisibility(),
        ride.getPublishAt(),
        ride.getCreatedAt(),
        ride.getRoute() != null ? ride.getRoute().getSlug() : null,
        participantCount,
        groupCount,
        groupDtos,
        groupSummaries,
        metrics != null ? metrics.distance() : null,
        metrics != null ? metrics.elevationGain() : null,
        metrics != null ? metrics.surfaceType() : null,
        startPlace != null ? PlaceDetailDto.from(startPlace) : null,
        endPlace != null ? PlaceDetailDto.from(endPlace) : null,
        topParticipants,
        thumbnail != null ? thumbnail.light() : null,
        thumbnail != null ? thumbnail.dark() : null,
        thumbnail != null ? thumbnail.collapsed() : null,
        ride.isDeleted(),
        registeredGroupId != null,
        registeredGroupId != null ? TsidUtils.toString(registeredGroupId) : null,
        registeredGroup,
        full,
        maxParticipants,
        commentCount,
        tags,
        RideWeatherSummaryDto.fromNullable(weather.forRide(ride.getId())));
  }
}
