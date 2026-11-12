package fr.pedalons.repository.ad;

import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;

import fr.pedalons.common.CoarseLocation;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.TeamEntityType;
import fr.pedalons.repository.common.TeamEntityRepository;
import fr.pedalons.repository.query.PedalonsQuery;
import fr.pedalons.repository.tag.TagFilter;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AdRepository implements TeamEntityRepository<Ad, AdQuery> {

  /** Same default as the route search: a comfortable ride out and back. */
  private static final double DEFAULT_NEAR_RADIUS = 25_000;

  /** Beyond this the filter selects everything anyway, so it only buys a full scan. */
  private static final double MAX_NEAR_RADIUS = 500_000;

  @Override
  public AdQuery getQuerySlug(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      String slug,
      boolean includeDeleted,
      boolean platformAdmin) {
    return AdQuery.builder()
        .domainId(domainId)
        .teamIds(Set.of(teamId))
        .userId(userId)
        .slug(slug)
        .includeDeleted(includeDeleted)
        .platformAdmin(platformAdmin)
        .build();
  }

  @Override
  public AdQuery getQueryId(
      Long domainId,
      Long teamId,
      @Nullable Long userId,
      Long id,
      boolean includeDeleted,
      boolean platformAdmin) {
    return AdQuery.builder()
        .domainId(domainId)
        .teamIds(Set.of(teamId))
        .userId(userId)
        .id(id)
        .includeDeleted(includeDeleted)
        .platformAdmin(platformAdmin)
        .build();
  }

  @Override
  public TeamEntityType getEntityType() {
    return TeamEntityType.AD;
  }

  @Override
  public EntityType getAllEntityType() {
    return EntityType.AD;
  }

  @Override
  public PedalonsQuery andSpecific(PedalonsQuery pedalonsQuery, AdQuery query) {
    AdType adType = query.adType();
    if (adType != null) {
      pedalonsQuery = pedalonsQuery.and("te.adType = :adType", Map.of("adType", adType));
    }
    if (query.minPrice() != null) {
      pedalonsQuery =
          pedalonsQuery.and("te.price >= :minPrice", Map.of("minPrice", query.minPrice()));
    }
    if (query.maxPrice() != null) {
      pedalonsQuery =
          pedalonsQuery.and("te.price <= :maxPrice", Map.of("maxPrice", query.maxPrice()));
    }

    // Geographic proximity, same shape as RouteRepository — one point here, so no NearType.
    //
    // The column holds the seller's exact position; only the blurred one is ever published
    // (see CoarseLocation). The filter therefore measures from the blurred point, never the exact
    // one: over the exact column, "is this ad within R of C?" is an oracle, and quantising C and R
    // does not close it — each answer still splits the cell along a circle, and circles from
    // different centres cut it finer than the cell (docs/LEDGER_*.md SEC-8). Over the blurred
    // point, the answer depends only on the published cell, so two ads in the same cell always
    // come back together.
    //
    // The probe and the radius stay quantised as well (API-31): the answer is then a function of
    // cells alone. Cost: results shift by under a cell — irrelevant when choosing between "a short
    // ride" and "a drive away", which is all this filter is for.
    if (query.nearLat() != null && query.nearLon() != null) {
      Point<G2D> probe = CoarseLocation.blur(point(WGS84, g(query.nearLon(), query.nearLat())));
      double radius = query.nearRadius() != null ? query.nearRadius() : DEFAULT_NEAR_RADIUS;
      // Capped: an unbounded radius neutralises the filter and still pays for a full-table
      // st_distancesphere, which is not indexable as written.
      radius = Math.min(radius, MAX_NEAR_RADIUS);
      radius = CoarseLocation.snapRadiusUp(radius);
      pedalonsQuery =
          pedalonsQuery.and(
              "st_distancesphere(coarse_location(te.locationGeometry), :nearPoint) <= :nearRadius",
              Map.of("nearPoint", probe, "nearRadius", radius));
    }

    Set<Long> tagIds = query.tagIds();
    if (tagIds != null) {
      pedalonsQuery = TagFilter.andTaggedWithAny(pedalonsQuery, "te", tagIds);
    }

    if (query.sortBy() != null) {
      SortDirection dir = query.sortDir() != null ? query.sortDir() : SortDirection.DESC;
      // The ad id ends the key, in the same direction, so equal prices or names stay in one order.
      String d = dir.name().toLowerCase();
      pedalonsQuery = pedalonsQuery.order(query.sortBy().getField() + " " + d + ", te.id " + d);
    }
    return pedalonsQuery;
  }

  /** Ads a user posted, for the GDPR data export. */
  public List<Ad> findByCreator(Long domainId, Long userId) {
    return list("createdBy.id = ?2 and team.domain.id = ?1 order by createdAt", domainId, userId);
  }
}
