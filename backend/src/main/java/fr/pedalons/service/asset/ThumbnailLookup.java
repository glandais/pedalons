package fr.pedalons.service.asset;

import fr.pedalons.domain.common.Publication;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.asset.AssetRepository.ThumbnailRow;
import fr.pedalons.service.security.PedalonsQueryContext;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import org.jspecify.annotations.Nullable;

/**
 * Resolves thumbnail URLs for a set of entities in bulk — one query for a whole page, or for a whole
 * calendar window.
 *
 * <p>The single-entity path ({@code AssetService.getImageUrl}) is fine when there is one entity. Fed
 * a list, it becomes the classic shape: {@code entity.getAssets()} is a lazy collection, so a
 * three-month agenda over a busy team walks it once per event and hydrates every asset of every
 * ride. That is the regression this class exists to prevent; see {@link
 * AssetRepository#findThumbnails}.
 *
 * <p>Callers hand in every id that may carry the picture — for a ride, both the ride and its route —
 * and read the result back with a fallback, {@code map.get(rideId)} then {@code map.get(routeId)},
 * mirroring what {@code RideDto} does on the detail path.
 *
 * <p><b>Tenancy:</b> the domain comes from the request context and is applied in the query, so an id
 * belonging to another domain resolves to nothing rather than to a URL.
 */
@ApplicationScoped
public class ThumbnailLookup {

  @Inject AssetRepository assetRepository;

  @Inject PedalonsQueryContext pedalonsContext;

  /**
   * The two themed variants of one entity's thumbnail, either of which may be absent.
   *
   * <p>They are kept apart rather than collapsed because a client renders in a colour scheme the
   * server does not know: picking one here would hand a dark-mode calendar the light map tile.
   *
   * @param light URL template of the light variant, null when the entity has only a dark one
   * @param dark URL template of the dark variant, null when the entity has only a light one
   */
  public record ThemedThumbnail(@Nullable String light, @Nullable String dark) {

    /**
     * One of the two, for a client that renders a single picture and does not care which — light
     * first, because it is the variant every thumbnail generator produces.
     */
    public @Nullable String collapsed() {
      return light != null ? light : dark;
    }
  }

  /**
   * Both themed thumbnail variants per entity, in one query.
   *
   * @param teamEntityIds rides, trip stages and their routes, in any order, duplicates allowed
   * @return entity id → its variants (URL templates, each containing a {@code {size}} placeholder);
   *     entities with no thumbnail at all are simply absent, so a present value always carries at
   *     least one of the two
   */
  public Map<Long, ThemedThumbnail> forTeamEntities(Collection<Long> teamEntityIds) {
    if (teamEntityIds.isEmpty()) {
      return Map.of();
    }
    Map<Long, String> light = new HashMap<>();
    Map<Long, String> dark = new HashMap<>();
    for (ThumbnailRow row : assetRepository.findThumbnails(getDomainId(), teamEntityIds)) {
      String url =
          AssetService.buildImageUrl(row.teamSlug(), row.visibility(), row.assetId(), row.fileId());
      (isLight(row) ? light : dark).put(row.teamEntityId(), url);
    }
    Map<Long, ThemedThumbnail> thumbnails = new HashMap<>();
    for (Long entityId : union(light.keySet(), dark.keySet())) {
      thumbnails.put(entityId, new ThemedThumbnail(light.get(entityId), dark.get(entityId)));
    }
    return thumbnails;
  }

  /**
   * The thumbnail each ride shows on a list row, in one query for the whole page: the ride's own,
   * else its route's — the same fallback {@code RideDto} applies on the detail path. The ride and
   * route asset collections are never walked (docs/LEDGER_*.md API-80).
   *
   * @return ride id → its thumbnail; a ride with none, neither its own nor its route's, is absent
   */
  public Map<Long, ThemedThumbnail> forRides(List<Ride> rides) {
    return ownElseRoute(rides, Ride::getRoute);
  }

  /**
   * The thumbnail each trip shows on a list row, in one query for the whole page: the trip's own,
   * else its route's — the same fallback {@code TripDto} applies on the detail path. The trip and
   * route asset collections are never walked (docs/LEDGER_*.md API-83).
   *
   * @return trip id → its thumbnail; a trip with none, neither its own nor its route's, is absent
   */
  public Map<Long, ThemedThumbnail> forTrips(List<Trip> trips) {
    return ownElseRoute(trips, Trip::getRoute);
  }

  /**
   * One query for the publications and their routes, then each publication's own thumbnail, else
   * its route's. {@code route} must be an eager to-one, already loaded with the publication, so that
   * reading its id costs nothing — {@code Ride.route} and {@code Trip.route} are.
   */
  private <P extends Publication> Map<Long, ThemedThumbnail> ownElseRoute(
      List<P> publications, Function<P, @Nullable Route> route) {
    if (publications.isEmpty()) {
      return Map.of();
    }
    Set<Long> ids = new HashSet<>();
    for (P publication : publications) {
      ids.add(publication.getId());
      Route r = route.apply(publication);
      if (r != null) {
        ids.add(r.getId());
      }
    }
    Map<Long, ThemedThumbnail> byEntity = forTeamEntities(ids);
    Map<Long, ThemedThumbnail> byPublication = new HashMap<>();
    for (P publication : publications) {
      ThemedThumbnail thumbnail = byEntity.get(publication.getId());
      Route r = route.apply(publication);
      if (thumbnail == null && r != null) {
        thumbnail = byEntity.get(r.getId());
      }
      if (thumbnail != null) {
        byPublication.put(publication.getId(), thumbnail);
      }
    }
    return byPublication;
  }

  private static Set<Long> union(Set<Long> a, Set<Long> b) {
    Set<Long> all = new HashSet<>(a);
    all.addAll(b);
    return all;
  }

  private Long getDomainId() {
    return pedalonsContext.getDomainId();
  }

  private static boolean isLight(ThumbnailRow row) {
    return row.type().name().endsWith("_LIGHT");
  }
}
