package fr.pedalons.dto.publications.response;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import fr.pedalons.domain.common.Publication;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.gps.response.RouteGpsSyncStatuses;
import fr.pedalons.dto.posts.response.PostAuthors;
import fr.pedalons.dto.posts.response.PostDto;
import fr.pedalons.dto.rides.response.RideDto;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.dto.trips.response.TripDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.asset.ThumbnailLookup.ThemedThumbnail;
import fr.pedalons.service.weather.RideWeatherSummaries;
import java.util.Map;
import org.eclipse.microprofile.openapi.annotations.media.DiscriminatorMapping;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

// Response DTOs
@JsonTypeInfo(
    use = JsonTypeInfo.Id.NAME,
    include = JsonTypeInfo.As.EXISTING_PROPERTY,
    property = "type" // discriminator
    )
@JsonSubTypes({
  @JsonSubTypes.Type(value = RideDto.class, name = "RIDE"),
  @JsonSubTypes.Type(value = PostDto.class, name = "POST"),
  @JsonSubTypes.Type(value = TripDto.class, name = "TRIP")
})
@Schema(
    description = "Publication data",
    discriminatorProperty = "type",
    discriminatorMapping = {
      @DiscriminatorMapping(value = "RIDE", schema = RideDto.class),
      @DiscriminatorMapping(value = "POST", schema = PostDto.class),
      @DiscriminatorMapping(value = "TRIP", schema = TripDto.class)
    },
    oneOf = {RideDto.class, PostDto.class, TripDto.class})
@ValidateSchema
public interface PublicationDto {

  PublicationType getType();

  Visibility getVisibility();

  String getName();

  /**
   * Builds one row of a publication list at the requested level of detail. Every page lookup is
   * required: no overload defaults one, so a list caller cannot silently render rows without their
   * tags or « me » fields.
   *
   * @param summaries the association aggregates for this page, loaded in bulk so no row has to walk
   *     an association it only needs a count of
   * @param participations what the current user is registered to on this page, likewise loaded in
   *     bulk — the "me" fields must not cost a query per row
   * @param commentCounts the comment count of each row the caller may read, also loaded in bulk; a
   *     row absent from it renders no {@code commentCount} at all
   * @param view {@link ListViewMode#COMPACT} leaves the markdown body and the asset inventory out of
   *     every row — a feed of twenty publications stops carrying twenty full articles for forty
   *     rendered lines. {@code excerpt} and {@code thumbnailUrl} are what a compact row reads, and
   *     they are present either way.
   * @param postAuthors who wrote each post of the page the caller may know of, loaded in bulk
   * @param tags the tags of every row of the page, loaded in bulk by {@code TagLookup}
   * @param rideWeather the weather line of every ride of the page, loaded in at most one query by
   *     {@code RideWeatherLookup}
   * @param tripWeather the weather line of every trip of the page, that of its next leg, loaded
   *     in at most one query by {@code TripWeatherLookup}
   * @param rideThumbnails the thumbnail of every ride of the page, its own else its route's,
   *     loaded in one query by {@code ThumbnailLookup.forRides}
   * @param tripThumbnails the thumbnail of every trip of the page, its own else its route's,
   *     loaded in one query by {@code ThumbnailLookup.forTrips}
   * @param gpsSync where the page's ride routes stand at the caller's synced GPS services, loaded
   *     with the participations by {@code ParticipationLookup.forListPage}
   */
  static PublicationDto from(
      Publication publication,
      AssetService assetService,
      PublicationListSummaries summaries,
      UserParticipations participations,
      CommentCounts commentCounts,
      PostAuthors postAuthors,
      ContentTags tags,
      RideWeatherSummaries rideWeather,
      RideWeatherSummaries tripWeather,
      Map<Long, ThemedThumbnail> rideThumbnails,
      Map<Long, ThemedThumbnail> tripThumbnails,
      RouteGpsSyncStatuses gpsSync,
      @Nullable ListViewMode view) {
    return switch (publication) {
      case Post post -> PostDto.from(post, assetService, commentCounts, postAuthors, tags, view);
      case Ride ride ->
          RideDto.fromListItem(
              ride,
              summaries.ride(ride.getId()),
              assetService,
              participations,
              commentCounts,
              tags,
              rideWeather,
              rideThumbnails,
              gpsSync,
              view);
      case Trip trip ->
          TripDto.fromListItem(
              trip,
              summaries.trip(trip.getId()),
              assetService,
              participations,
              commentCounts,
              tags,
              tripWeather,
              tripThumbnails,
              view);
      default -> throw new IllegalStateException("Invalid Publication object");
    };
  }
}
