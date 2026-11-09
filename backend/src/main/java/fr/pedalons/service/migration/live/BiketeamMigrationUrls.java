package fr.pedalons.service.migration.live;

import static fr.pedalons.service.migration.BiketeamMigrationService.T_POST;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_RIDE;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_ROUTE;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_TEAM_PAGE;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_TRIP;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_TRIP_STAGE;
import static fr.pedalons.service.migration.BiketeamMigrationService.faqPageKey;

import fr.pedalons.common.UrlUtils;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.repository.migration.BiketeamMigrationMapRepository;
import fr.pedalons.service.migration.BiketeamModel.BtMap;
import fr.pedalons.service.migration.BiketeamModel.BtPublication;
import fr.pedalons.service.migration.BiketeamModel.BtRide;
import fr.pedalons.service.migration.BiketeamModel.BtTrip;
import fr.pedalons.service.migration.BiketeamModel.BtTripStage;
import fr.pedalons.service.migration.BiketeamSource;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * The URL table biketeam redirects with once it switches over (docs/plans/
 * 2026-09-22-biketeam-live-migration.md §8.4): biketeam id → absolute Pédalons URL, per kind.
 *
 * <p>Built from the snapshot rather than from the mapping table alone: every live biketeam entity is
 * looked up through the mapping, and kept only when the entity it maps to belongs to the target
 * team and is not deleted. Anything absent or failed has no entry, and biketeam falls back to the team page.
 *
 * <p>Absolute URLs are the domain's {@code base_url} plus the {@code fr} form of the routes of
 * {@code contracts/routes.yaml} — biketeam's audience is French-speaking, and both routers accept
 * every locale. <strong>A route renamed in contracts/routes.yaml must be renamed here.</strong> They
 * stay valid if a slug changes later on Pédalons: the slug redirect tables take over.
 */
@ApplicationScoped
public class BiketeamMigrationUrls {

  // Keys of the urlMap, as biketeam stores them in pedalons_redirect.entity_type.
  public static final String TEAM = "TEAM";
  public static final String TEAM_ABOUT = "TEAM_ABOUT";
  public static final String TEAM_FAQ = "TEAM_FAQ";
  public static final String ROUTES_LIST = "ROUTES_LIST";
  public static final String ROUTE = "ROUTE";
  public static final String RIDE = "RIDE";
  public static final String TRIP = "TRIP";
  public static final String TRIP_STAGE = "TRIP_STAGE";
  public static final String POST = "POST";

  @Inject BiketeamMigrationMapRepository mapRepo;
  @Inject EntityManager em;

  /**
   * One read transaction whose statements do not grow with the team: per kind, one lookup of the
   * mapping rows and one of the slugs, {@value BiketeamMigrationMapRepository#IN_CHUNK} ids at a
   * time. Only the slugs are read — no entity is loaded.
   *
   * @param teamId the target Pédalons team
   * @param baseUrl the domain's {@code base_url}, as snapshotted on the job
   */
  public Map<String, Map<String, String>> build(
      BiketeamSource source, long teamId, String baseUrl) {
    String biketeamTeamId = source.team().id();
    String faqKey = faqPageKey(biketeamTeamId);
    List<String> routeIds =
        source.maps().stream().filter(m -> !m.deletion()).map(BtMap::id).toList();
    List<String> rideIds =
        source.rides().stream().filter(r -> !r.deletion()).map(BtRide::id).toList();
    Set<String> liveTrips =
        source.trips().stream()
            .filter(t -> !t.deletion())
            .map(BtTrip::id)
            .collect(Collectors.toCollection(LinkedHashSet::new));
    List<String> stageIds =
        source.tripStages().stream()
            .filter(st -> liveTrips.contains(st.tripId()))
            .map(BtTripStage::id)
            .toList();
    List<String> postIds =
        source.publications().stream().filter(p -> !p.deletion()).map(BtPublication::id).toList();

    Slugs slugs =
        QuarkusTransaction.requiringNew()
            .call(() ->
                new Slugs(
                    em.createQuery("select t.slug from Team t where t.id = :id", String.class)
                        .setParameter("id", teamId)
                        .getSingleResult(),
                    slugs(T_TEAM_PAGE, TeamPage.class, List.of(faqKey), teamId),
                    slugs(T_ROUTE, Route.class, routeIds, teamId),
                    slugs(T_RIDE, Ride.class, rideIds, teamId),
                    slugs(T_TRIP, Trip.class, List.copyOf(liveTrips), teamId),
                    stageSlugs(stageIds, teamId),
                    slugs(T_POST, Post.class, postIds, teamId)));

    String base = UrlUtils.stripTrailingSlash(baseUrl);
    String team = base + teamPath(slugs.team());
    Map<String, Map<String, String>> urls = new LinkedHashMap<>();
    urls.put(TEAM, Map.of(biketeamTeamId, team));
    urls.put(TEAM_ABOUT, Map.of(biketeamTeamId, team + "/a-propos"));
    String faq = slugs.pages().get(faqKey);
    urls.put(
        TEAM_FAQ, faq == null ? Map.of() : Map.of(biketeamTeamId, team + "/pages/" + segment(faq)));
    urls.put(ROUTES_LIST, Map.of(biketeamTeamId, team + "/parcours"));
    urls.put(ROUTE, urls(slugs.routes(), team + "/parcours/"));
    urls.put(RIDE, urls(slugs.rides(), team + "/sorties/"));
    urls.put(TRIP, urls(slugs.trips(), team + "/voyages/"));
    Map<String, String> stages = new LinkedHashMap<>();
    slugs
        .stages()
        .forEach((id, path) ->
            stages.put(
                id,
                team
                    + "/voyages/"
                    + segment(path.tripSlug())
                    + "/etapes/"
                    + segment(path.stageSlug())));
    urls.put(TRIP_STAGE, stages);
    urls.put(POST, urls(slugs.posts(), team + "/articles/"));
    return urls;
  }

  private record StagePath(String tripSlug, String stageSlug) {}

  /** Biketeam id → slug, per kind, for the entities that are live in the target team. */
  private record Slugs(
      String team,
      Map<String, String> pages,
      Map<String, String> routes,
      Map<String, String> rides,
      Map<String, String> trips,
      Map<String, StagePath> stages,
      Map<String, String> posts) {}

  private static Map<String, String> urls(Map<String, String> slugs, String prefix) {
    Map<String, String> urls = new LinkedHashMap<>();
    slugs.forEach((id, slug) -> urls.put(id, prefix + segment(slug)));
    return urls;
  }

  /**
   * Biketeam id → slug of the Pédalons entity it maps to, when that entity is of {@code type}, in
   * the team, not deleted — in the order of {@code biketeamIds}.
   */
  private Map<String, String> slugs(
      String entityType, Class<? extends TeamEntity> type, List<String> biketeamIds, long teamId) {
    Map<String, Long> mapped = mapRepo.findTriblyIds(entityType, biketeamIds);
    Map<Long, String> byId = new HashMap<>();
    List<Long> ids = List.copyOf(new LinkedHashSet<>(mapped.values()));
    for (List<Long> chunk : chunks(ids)) {
      em.createQuery(
              "select e.id, e.slug from "
                  + type.getSimpleName()
                  + " e where e.id in :ids and e.team.id = :teamId and e.deleted = false",
              Object[].class)
          .setParameter("ids", chunk)
          .setParameter("teamId", teamId)
          .getResultList()
          .forEach(row -> byId.put((Long) row[0], (String) row[1]));
    }
    Map<String, String> slugs = new LinkedHashMap<>();
    for (String biketeamId : biketeamIds) {
      Long id = mapped.get(biketeamId);
      String slug = id == null ? null : byId.get(id);
      if (slug != null) {
        slugs.put(biketeamId, slug);
      }
    }
    return slugs;
  }

  /** Same for trip stages, with their trip's slug — and only while that trip is not deleted. */
  private Map<String, StagePath> stageSlugs(List<String> biketeamIds, long teamId) {
    Map<String, Long> mapped = mapRepo.findTriblyIds(T_TRIP_STAGE, biketeamIds);
    Map<Long, StagePath> byId = new HashMap<>();
    List<Long> ids = List.copyOf(new LinkedHashSet<>(mapped.values()));
    for (List<Long> chunk : chunks(ids)) {
      em.createQuery(
              "select s.id, t.slug, s.slug from TripStage s join s.trip t"
                  + " where s.id in :ids and s.team.id = :teamId and s.deleted = false"
                  + " and t.deleted = false",
              Object[].class)
          .setParameter("ids", chunk)
          .setParameter("teamId", teamId)
          .getResultList()
          .forEach(row -> byId.put((Long) row[0], new StagePath((String) row[1], (String) row[2])));
    }
    Map<String, StagePath> paths = new LinkedHashMap<>();
    for (String biketeamId : biketeamIds) {
      Long id = mapped.get(biketeamId);
      StagePath path = id == null ? null : byId.get(id);
      if (path != null) {
        paths.put(biketeamId, path);
      }
    }
    return paths;
  }

  private static <T> List<List<T>> chunks(List<T> values) {
    List<List<T>> chunks = new ArrayList<>();
    for (int from = 0; from < values.size(); from += BiketeamMigrationMapRepository.IN_CHUNK) {
      chunks.add(
          values.subList(
              from, Math.min(values.size(), from + BiketeamMigrationMapRepository.IN_CHUNK)));
    }
    return chunks;
  }

  /** {@code base_url} + route {@code team}, {@code fr} form. */
  public static String teamUrl(String baseUrl, String teamSlug) {
    return UrlUtils.stripTrailingSlash(baseUrl) + teamPath(teamSlug);
  }

  private static String teamPath(String teamSlug) {
    return "/equipes/" + segment(teamSlug);
  }

  /** Percent-encodes everything but RFC 3986 unreserved characters, as for a path segment. */
  static String segment(String value) {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    for (byte b : value.getBytes(StandardCharsets.UTF_8)) {
      int c = b & 0xff;
      if ((c >= 'a' && c <= 'z')
          || (c >= 'A' && c <= 'Z')
          || (c >= '0' && c <= '9')
          || c == '-'
          || c == '.'
          || c == '_'
          || c == '~') {
        out.write(c);
      } else {
        out.writeBytes(String.format("%%%02X", c).getBytes(StandardCharsets.US_ASCII));
      }
    }
    return out.toString(StandardCharsets.US_ASCII);
  }
}
