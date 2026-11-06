package fr.pedalons.service.migration;

import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;

import fr.pedalons.common.PersistenceErrors;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.migration.BiketeamMigrationMap;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ridetemplate.RideTemplate;
import fr.pedalons.domain.ridetemplate.RideTemplateGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.common.asset.AssetsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.places.request.PlaceRequest;
import fr.pedalons.dto.places.response.PlaceDetailDto;
import fr.pedalons.dto.posts.request.PostRequest;
import fr.pedalons.dto.posts.response.PostDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.rides.response.RideDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.dto.trips.request.StageRequest;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.dto.trips.response.TripDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.repository.migration.BiketeamMigrationMapRepository;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.post.PostRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.ridetemplate.RideTemplateGroupRepository;
import fr.pedalons.repository.ridetemplate.RideTemplateRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.repository.team.TeamPageRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.repository.trip.TripRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.asset.response.AssetWithFile;
import fr.pedalons.service.common.SlugService;
import fr.pedalons.service.migration.BiketeamMigrationProgress.Codes;
import fr.pedalons.service.migration.BiketeamMigrationProgress.Counter;
import fr.pedalons.service.migration.BiketeamMigrationProgress.Outcome;
import fr.pedalons.service.migration.BiketeamMigrationProgress.Phase;
import fr.pedalons.service.migration.BiketeamModel.BtMap;
import fr.pedalons.service.migration.BiketeamModel.BtPlace;
import fr.pedalons.service.migration.BiketeamModel.BtPublication;
import fr.pedalons.service.migration.BiketeamModel.BtRide;
import fr.pedalons.service.migration.BiketeamModel.BtRideGroup;
import fr.pedalons.service.migration.BiketeamModel.BtRideGroupTemplate;
import fr.pedalons.service.migration.BiketeamModel.BtRideTemplate;
import fr.pedalons.service.migration.BiketeamModel.BtTeam;
import fr.pedalons.service.migration.BiketeamModel.BtTeamDescription;
import fr.pedalons.service.migration.BiketeamModel.BtTrip;
import fr.pedalons.service.migration.BiketeamModel.BtTripStage;
import fr.pedalons.service.migration.BiketeamSource.ImageKind;
import fr.pedalons.service.migration.live.BiketeamExportException;
import fr.pedalons.service.migration.live.BiketeamJobFailure;
import fr.pedalons.service.migration.live.BiketeamJobLostException;
import fr.pedalons.service.migration.live.BiketeamTargetResolver;
import fr.pedalons.service.notification.NotificationPublisher;
import fr.pedalons.service.place.PlaceService;
import fr.pedalons.service.post.PostService;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.ride.RideService;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.tag.TagService;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import fr.pedalons.service.trip.TripService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.function.LongConsumer;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Maps one biketeam team onto Pédalons, whatever the {@link BiketeamSource}: writes through the
 * existing Pédalons services, and tracks source-row → target-id mappings in {@link
 * BiketeamMigrationMap} for replayability.
 *
 * <p>One entry point, {@link #migrateTeamLive}: one team, from biketeam's export API, into the
 * domain a Pédalons user confirmed on, with that user as its author (and ADMIN of a team it
 * creates). No people are imported: no users, memberships, participations or comments.
 *
 * <p>It expects a request context carrying the target domain and the acting user ({@link
 * PedalonsQueryContext#setUserForTest}, {@link DomainResolver#setDomainForTest}), so that {@code
 * @CheckAccess} on the called services passes without HTTP, and runs under {@link
 * NotificationPublisher#silently}: the replayed history is not news.
 */
@ApplicationScoped
public class BiketeamMigrationService {

  private static final Logger LOG = Logger.getLogger(BiketeamMigrationService.class);

  /**
   * The longest transaction of one element: a route, with its GPX pipeline. The others are capped
   * at 120 s. The live migration's {@code stuck-after} must stay above it (checked at startup).
   */
  public static final int LONGEST_ITEM_TRANSACTION_SECONDS = 600;

  // Mapping table entity types
  public static final String T_TEAM = "TEAM";
  public static final String T_TEAM_PAGE = "TEAM_PAGE";
  public static final String T_PLACE = "PLACE";
  public static final String T_ROUTE = "ROUTE";
  public static final String T_RIDE = "RIDE";
  public static final String T_RIDE_GROUP = "RIDE_GROUP";
  public static final String T_RIDE_TEMPLATE = "RIDE_TEMPLATE";
  public static final String T_RIDE_TEMPLATE_GROUP = "RIDE_TEMPLATE_GROUP";
  public static final String T_TRIP = "TRIP";
  public static final String T_TRIP_STAGE = "TRIP_STAGE";
  public static final String T_POST = "POST";
  public static final String T_ASSET = "ASSET";

  /**
   * Mapping key suffix of the FAQ page. {@link #T_TEAM_PAGE} keyed on the bare team id already
   * means that team's about page, and both are minted from the same source row.
   */
  private static final String FAQ_PAGE_KEY_SUFFIX = ":faq";

  /** Mapping key prefix of the team logo asset: {@code misc:<teamId>}. */
  private static final String LOGO_ASSET_KEY_PREFIX = "misc:";

  /** Biketeam had no title for its markdown page — its navbar and template both say "FAQ". */
  private static final String FAQ_PAGE_NAME = "FAQ";

  /** Departure of every trip stage but the first — see {@link #stageDeparture}. */
  private static final LocalTime LATER_STAGE_DEPARTURE = LocalTime.of(8, 0);

  /** MD5 of biketeam's placeholder team logo — see {@link #isPlaceholderLogo}. */
  private static final Set<String> PLACEHOLDER_LOGO_MD5 =
      Set.of(
          // misc/<team>/logo.png as stored by ImageService.save (resized once at team creation)
          "fc9ed08a9d6f7f1989c804c8a6961721",
          // biketeam's src/main/resources/default-images/empty.png, unresized
          "b63f0a99a10ed3b8bdf36acc72f620a5");

  @Inject BiketeamMigrationMapRepository mapRepo;
  @Inject EntityManager em;

  @Inject TeamRepository teamRepository;
  @Inject UserTeamRepository userTeamRepository;
  @Inject PlaceRepository placeRepository;
  @Inject RouteRepository routeRepository;
  @Inject RideRepository rideRepository;
  @Inject TripRepository tripRepository;
  @Inject PostRepository postRepository;
  @Inject RideTemplateRepository rideTemplateRepository;
  @Inject RideTemplateGroupRepository rideTemplateGroupRepository;
  @Inject TeamPageRepository teamPageRepository;

  @Inject SlugService slugService;

  @Inject PlaceService placeService;
  @Inject RouteService routeService;
  @Inject RideService rideService;
  @Inject TripService tripService;
  @Inject PostService postService;
  @Inject AssetService assetService;
  @Inject TagService tagService;
  @Inject PublicationEndCalculator publicationEndCalculator;

  /**
   * Everything one team's run carries, so the per-kind methods below need no ten-argument lists.
   *
   * @param liveTeamId the biketeam team id to tag mapping rows with
   */
  record Run(
      Team team,
      User actor,
      BiketeamSource source,
      ZoneId zone,
      String liveTeamId,
      BiketeamMigrationProgress progress) {

    String sourceTeam() {
      return source.team().id();
    }
  }

  // ─── Live entry point ─────────────────────────────────────────────────────

  /**
   * Migrates one biketeam team into {@code domain}, as {@code actor}: creates the target team with
   * {@code actor} as its ADMIN, or reuses the migrated one as it is, then maps its content. The target must already have been
   * resolved — conflicts, reset — by the caller (docs/plans/2026-09-22-biketeam-live-migration.md
   * §7.3), which passes the team it resolved as {@code expectedTeamId}. That resolution committed in
   * a transaction of its own, so it is checked again here, in the transaction that writes the
   * target: see {@link #ensureLiveTargetTeam}.
   *
   * <p>No people: no user, membership, participation or comment is created, and {@code RideGroupDto.leader} stays null — it is never derived from {@code
   * createdBy}.
   *
   * @param expectedTeamId the migrated team the caller resolved, or null to create one
   * @param setAside with {@code expectedTeamId} null, sets the previous team aside (trash, slug
   *     renamed, mapping forgotten) in the transaction that creates the new one, before the slug is
   *     checked: a conflict rolls it back, and the previous team stays as it was; or null
   * @param onTarget told the target team's id as soon as it exists, before the content is mapped
   * @return the target team
   */
  public Team migrateTeamLive(
      Domain domain,
      User actor,
      BiketeamSource source,
      @Nullable Long expectedTeamId,
      @Nullable Runnable setAside,
      LongConsumer onTarget,
      BiketeamMigrationProgress progress) {
    BtTeam btTeam = source.team();
    LOG.infof("Live-migrating biketeam team '%s' (%s)", btTeam.id(), btTeam.name());
    progress.phase(Phase.TEAM, 1);
    Team team =
        ensureLiveTargetTeam(domain, actor, btTeam, source.zone(), expectedTeamId, setAside);
    onTarget.accept(team.getId());
    Run run = new Run(team, actor, source, source.zone(), btTeam.id(), progress);
    migrateTeamContent(run);
    return team;
  }

  /**
   * The team's content, in the order the import always used: about page, FAQ, logo, places,
   * routes, ride templates, publications, rides, trips. Each place, route, template, publication,
   * ride and trip is its own error boundary; the team pages and logo are not.
   */
  private void migrateTeamContent(Run r) {
    if (migrateTeamDescription(r)) {
      r.progress().count(Counter.TEAM_PAGES, Outcome.MIGRATED);
    }
    if (migrateTeamPage(r)) {
      r.progress().count(Counter.TEAM_PAGES, Outcome.MIGRATED);
    }
    Outcome logo = migrateTeamLogo(r);
    if (logo != null) {
      r.progress().count(Counter.IMAGES, logo);
    }
    r.progress().tick();

    Map<String, Long> placeIds = migratePlaces(r);
    Map<String, Long> routeIds = migrateMaps(r);
    migrateRideTemplates(r);
    migratePublications(r);
    migrateRides(r, routeIds, placeIds);
    migrateTrips(r, routeIds);
  }

  // ─── Domain / team / admin ────────────────────────────────────────────────

  /**
   * The live path's target team — in one transaction that re-checks what {@code
   * BiketeamTargetResolver} decided in an earlier one: a Pédalons user may have created a team at
   * the slug in between, and a native team must never be taken over
   * (docs/plans/2026-09-22-biketeam-live-migration.md §7.3).
   *
   * <ul>
   *   <li>{@code expectedTeamId} null — nothing live was migrated: only creates, at {@link
   *       BiketeamTargetResolver#targetSlug}, with biketeam's visibility and joinability and {@code
   *       actor} as ADMIN. A team found at the slug, or created concurrently ({@code
   *       uk_teams_domain_slug}), fails the job with {@code BIKETEAM_SLUG_CONFLICT}.
   *   <li>otherwise — reuses that team, whatever its slug has become, only if it is still live, in
   *       {@code domain}, and the {@code TEAM} mapping row still points at it; any other state fails
   *       the job the same way. Its Pédalons settings — visibility, joinability, memberships — are
   *       left alone: the team has had a life here since, and the imported content follows its
   *       visibility. {@code actor} was checked to administer it (or to be a PLATFORM_ADMIN) and is
   *       not made a member.
   * </ul>
   *
   * Nothing — mapping row, membership, setting aside — is kept unless these checks pass: they all
   * share this transaction.
   */
  @Transactional
  protected Team ensureLiveTargetTeam(
      Domain domain,
      User actor,
      BtTeam src,
      ZoneId zone,
      @Nullable Long expectedTeamId,
      @Nullable Runnable setAside) {
    if (expectedTeamId == null) {
      if (setAside != null) {
        // Rolled back with the rest when the slug below is taken: the team is only trashed once
        // its successor is sure to be created.
        setAside.run();
        teamRepository.flush();
      }
      String slug = BiketeamTargetResolver.targetSlug(src.id());
      Optional<Team> existing =
          teamRepository.findBySlugAndDomainIncludingDeleted(domain.getId(), slug);
      if (existing.isPresent()) {
        throw slugConflict(slug, existing.get());
      }
      Team team;
      try {
        team = createTargetTeam(domain, actor, src, zone, slug);
      } catch (RuntimeException e) {
        if (PersistenceErrors.isUniqueViolation(e)) {
          throw new BiketeamJobFailure(
              "BIKETEAM_SLUG_CONFLICT", "Slug '" + slug + "' was taken while the job was starting");
        }
        throw e;
      }
      // Like TeamService.createTeam: a redirect left at this slug by a renamed team yields to it.
      slugService.clearTeamRedirect(domain.getId(), slug);
      ensureMembership(team, actor, TeamRole.ADMIN);
      return team;
    }
    Team t = teamRepository.findByIdOptional(expectedTeamId).orElse(null);
    if (t == null
        || t.isDeleted()
        || !t.getDomain().getId().equals(domain.getId())
        || !expectedTeamId.equals(mapRepo.findTriblyId(T_TEAM, src.id()))) {
      throw new BiketeamJobFailure(
          "BIKETEAM_SLUG_CONFLICT",
          "The team migrated from '" + src.id() + "' is no longer the one resolved for this job");
    }
    // Only tags the row with the biketeam team (a row of the legacy import has no tag yet).
    mapRepo.upsert(T_TEAM, src.id(), t.getId(), null, src.id());
    return t;
  }

  private static BiketeamJobFailure slugConflict(String slug, Team found) {
    return new BiketeamJobFailure(
        "BIKETEAM_SLUG_CONFLICT", "Slug '" + slug + "' is taken by team '" + found.getName() + "'");
  }

  /**
   * A new target team at {@code slug}. Biketeam's visibility and joinability are applied here, at
   * creation only — a replay leaves the Pédalons settings alone.
   */
  private Team createTargetTeam(Domain domain, User creator, BtTeam src, ZoneId zone, String slug) {
    Visibility visibility = mapTeamVisibility(src.visibility());
    Team team = new Team(domain, creator, src.name(), slug, visibility);
    team.setEnableRoutes(true);
    team.setEnableRides(true);
    team.setEnableTrips(true);
    team.setEnablePosts(true);
    team.setEnableAds(false);
    team.setEnableRoutePlanner(true);
    team.setVisibilityEditable(true);
    // Biketeam gates /join behind authorizePublicAccess, so a private team can't be self-joined.
    team.setJoinable(visibility != Visibility.TEAM);
    team.setAddMemberAllowed(true);
    // Biketeam's own zone (team_configuration.timezone), at creation only: a replay leaves a zone
    // changed in Pédalons alone. The about page was built by the constructor, with the default.
    team.setTimezone(zone.getId());
    team.getAboutPage().setTimezone(zone.getId());
    teamRepository.persistAndFlush(team);
    mapRepo.upsert(T_TEAM, src.id(), team.getId(), null, src.id());
    Instant createdAt = at(zone, src.createdAt(), null);
    backdate("teams", team.getId(), createdAt);
    // The about page is cascade-created with the team and has no date of its own in biketeam.
    backdate("team_entities", team.getAboutPage().getId(), createdAt);
    return team;
  }

  @Transactional
  protected void ensureMembership(Team team, User user, TeamRole role) {
    Optional<UserTeam> existing = userTeamRepository.findByUserAndTeam(user.getId(), team.getId());
    if (existing.isPresent()) {
      UserTeam ut = existing.get();
      if (ut.getRole() != role) {
        ut.setRole(role);
        userTeamRepository.persist(ut);
      }
      return;
    }
    UserTeam ut = new UserTeam(user, user, team, role);
    userTeamRepository.persist(ut);
  }

  // ─── Team description ─────────────────────────────────────────────────────

  /**
   * Biketeam held the team presentation and its contact details in {@code team_description}.
   * Pédalons has no equivalent columns, so both are rendered into the team's about page markdown.
   *
   * @return whether the about page was written
   */
  @Transactional
  protected boolean migrateTeamDescription(Run r) {
    BtTeamDescription src = r.source().teamDescription();
    if (src == null) {
      return false;
    }
    String markdown = renderTeamDescription(src);
    if (markdown.isBlank()) {
      return false;
    }
    Team managed = teamRepository.findByIdOptional(r.team().getId()).orElseThrow();
    TeamPage about = managed.getAboutPage();
    if (about == null) {
      LOG.warnf("Team '%s' has no about page — skipping team description", managed.getSlug());
      return false;
    }
    about.setMarkdown(markdown);
    about.setStatus(Status.PUBLISHED);
    about.setVisibility(contentVisibility(managed.getVisibility()));
    teamRepository.persist(managed);
    map(r, T_TEAM_PAGE, r.sourceTeam(), about.getId());
    LOG.infof("Migrated team description into the about page of '%s'", managed.getSlug());
    return true;
  }

  // ─── Team FAQ page ────────────────────────────────────────────────────────

  /**
   * Biketeam gave a team exactly one free-form page — {@code team_configuration.markdown_page},
   * served by its {@code FAQController} at {@code /{teamId}/faq} under the fixed title "FAQ". There
   * is no second page type in the schema, so this is the whole of it: it becomes one additional
   * {@link TeamPage} named {@value #FAQ_PAGE_NAME}, alongside the about page that carries the team
   * description.
   *
   * <p>The content is already Markdown, so no {@link #biketeamToMarkdown} pass — only line-ending
   * normalisation. Written through the repository rather than {@code TeamPageService.createPage},
   * which would refuse anything past its three-additional-pages cap; biketeam can never supply more
   * than one, but the cap counts what earlier runs left behind.
   *
   * @return whether the FAQ page was written
   */
  @Transactional
  protected boolean migrateTeamPage(Run r) {
    String sourceTeam = r.sourceTeam();
    String markdown = normalizeNewlines(r.source().teamMarkdownPage());
    if (markdown.isBlank()) {
      return false;
    }
    Team managed = teamRepository.findByIdOptional(r.team().getId()).orElseThrow();
    String key = faqPageKey(sourceTeam);
    Long mapped = mapRepo.findTriblyId(T_TEAM_PAGE, key);
    TeamPage page =
        mapped == null
            ? null
            : owned(teamPageRepository.findByIdOptional(mapped).orElse(null), managed);
    boolean created = page == null;
    Instant createdAt = at(r.zone(), r.source().team().createdAt(), null);
    if (created) {
      String slug = slugService.generateSlug(FAQ_PAGE_NAME, managed.getId(), teamPageRepository);
      page =
          TeamPage.createAdditionalPage(
              r.actor(),
              managed,
              FAQ_PAGE_NAME,
              slug,
              contentVisibility(managed.getVisibility()),
              teamPageRepository.getNextPageOrder(managed.getId()));
      page.setDateTime(createdAt);
    }
    page.setMarkdown(markdown);
    page.setStatus(Status.PUBLISHED);
    page.setVisibility(contentVisibility(managed.getVisibility()));
    teamPageRepository.persistAndFlush(page);
    map(r, T_TEAM_PAGE, key, page.getId());
    if (created) {
      backdate("team_entities", page.getId(), createdAt);
    }
    LOG.infof("Migrated the FAQ page of team '%s'", managed.getSlug());
    return true;
  }

  // ─── Team logo ────────────────────────────────────────────────────────────

  /**
   * Biketeam kept the team logo at {@code misc/<teamId>/logo.<ext>}. Pédalons reads a team's logo
   * from the {@code LOGO} asset of its about page ({@code TeamAvatar} renders {@code
   * team.about.assets.logo}), so that is where it lands.
   *
   * <p>No {@code ::asset{}} directive here, unlike {@link #attachImage}: a logo is addressed through
   * {@code assets.logo}, not from the markdown, and a directive would render it inline in the page.
   * {@code AssetService.updateAssets} keeps it regardless — it re-adds {@code assets.logo()} without
   * consulting the markdown.
   *
   * <p>Not transactional: the file is downloaded between two short transactions — the check of the
   * mapping, then the upload — never while one is open (a slow download would otherwise hold a
   * connection and time the transaction out).
   *
   * @return the outcome for the images counter, or null when biketeam has no logo file at all
   */
  protected @Nullable Outcome migrateTeamLogo(Run r) {
    SourceFile logo = r.source().logo();
    if (logo == null) {
      return null;
    }
    if (isPlaceholderLogo(logo)) {
      return Outcome.SKIPPED;
    }
    String key = logoKey(r.sourceTeam());
    if (QuarkusTransaction.requiringNew().call(() -> reusableLogo(r, key) != null)) {
      return Outcome.MIGRATED;
    }
    Fetched fetched = Fetched.of(logo);
    return QuarkusTransaction.requiringNew().call(() -> storeTeamLogo(r, logo, key, fetched));
  }

  /**
   * The logo asset already mapped for this team, or null. A mapping row is only trusted when the
   * asset is the logo of this very team: the key is global, and may still point at the logo of an
   * earlier target — a trashed team, in another domain.
   */
  private @Nullable Long reusableLogo(Run r, String key) {
    Long assetId = mapRepo.findTriblyId(T_ASSET, key);
    if (assetId == null) {
      return null;
    }
    Team managed = teamRepository.findByIdOptional(r.team().getId()).orElseThrow();
    TeamPage about = managed.getAboutPage();
    fr.pedalons.domain.asset.Asset asset = em.find(fr.pedalons.domain.asset.Asset.class, assetId);
    if (about == null
        || asset == null
        || !asset.getTeam().getId().equals(managed.getId())
        || asset.getTeamEntity() == null
        || asset.getTeamEntity().isDeleted()
        || !asset.getTeamEntity().getId().equals(about.getId())) {
      return null;
    }
    return assetId;
  }

  private Outcome storeTeamLogo(Run r, SourceFile logo, String key, Fetched fetched) {
    String sourceTeam = r.sourceTeam();
    Team managed = teamRepository.findByIdOptional(r.team().getId()).orElseThrow();
    TeamPage about = managed.getAboutPage();
    if (about == null) {
      LOG.warnf("Team '%s' has no about page — skipping logo", managed.getSlug());
      return Outcome.SKIPPED;
    }
    try {
      Path file = fetched.path(logo);
      try (InputStream in = Files.newInputStream(file)) {
        AssetWithFile awf = assetService.addAsset(about, AssetType.LOGO, logo.fileName());
        Files.copy(in, awf.file().toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        assetService.uploadAssetFile(awf.asset());
        readImageDimensions(file, awf.asset());
        map(r, T_ASSET, key, awf.asset().getId());
        LOG.infof("Migrated logo of team '%s'", managed.getSlug());
        return Outcome.MIGRATED;
      }
    } catch (IOException e) {
      LOG.warnf(e, "Failed to upload logo %s for team %s", logo.fileName(), sourceTeam);
      r.progress()
          .warning(
              "LOGO",
              sourceTeam,
              e instanceof SourceFileUnavailableException
                  ? Codes.FILE_DOWNLOAD_FAILED
                  : Codes.IMAGE_FAILED,
              message(e));
      return Outcome.FAILED;
    }
  }

  /**
   * Biketeam handed every new team a copy of its {@code default-images/empty.png} placeholder, so a
   * logo file existing proves nothing: many teams never replaced it. Importing
   * those would replace Pédalons' initials avatar with a blank square.
   *
   * <p>Digest of the bytes as biketeam stored them — {@code ImageService.save} re-encodes the
   * placeholder once, identically, at team creation. The resource itself is listed too, in case a
   * copy escaped the resize. The live source knows the digest from the export without downloading.
   */
  private static boolean isPlaceholderLogo(SourceFile logo) {
    String md5 = logo.md5();
    if (md5 == null) {
      LOG.warnf("Could not digest %s — importing it as a real logo", logo.fileName());
      return false;
    }
    return PLACEHOLDER_LOGO_MD5.contains(md5.toLowerCase(Locale.ROOT));
  }

  private static String renderTeamDescription(BtTeamDescription d) {
    StringBuilder md = new StringBuilder(biketeamToMarkdown(d.description()));

    List<String> address = new ArrayList<>();
    addIfPresent(address, d.addressStreetLine());
    addIfPresent(address, joinNonBlank(" ", d.addressPostalCode(), d.addressPostalCity()));

    List<String> entries = new ArrayList<>();
    addEntry(entries, "Téléphone", d.phoneNumber());
    addEntry(entries, "Email", link(d.email(), "mailto:" + trimmed(d.email())));
    addEntry(entries, "Facebook", socialLink(d.facebook(), "https://www.facebook.com/"));
    addEntry(entries, "Instagram", socialLink(d.instagram(), "https://www.instagram.com/"));
    addEntry(entries, "Twitter", socialLink(d.twitter(), "https://twitter.com/"));
    addEntry(entries, "Site", webLink(d.other()));

    if (address.isEmpty() && entries.isEmpty()) {
      return md.toString();
    }
    if (md.length() > 0) {
      md.append("\n\n");
    }
    md.append("## Contact");
    if (!address.isEmpty()) {
      // Two trailing spaces = markdown hard break, so the address stays on its own lines.
      md.append("\n\n").append(String.join("  \n", address));
    }
    if (!entries.isEmpty()) {
      md.append("\n\n").append(String.join("\n", entries));
    }
    return md.toString();
  }

  private static void addIfPresent(List<String> target, @Nullable String value) {
    String v = trimmed(value);
    if (!v.isEmpty()) {
      target.add(v);
    }
  }

  private static void addEntry(List<String> target, String label, @Nullable String rendered) {
    if (rendered != null && !rendered.isBlank()) {
      target.add("- " + label + " : " + rendered);
    }
  }

  /** Renders {@code [text](url)}, or null when the value is absent. */
  private static @Nullable String link(@Nullable String text, @Nullable String url) {
    String t = trimmed(text);
    return t.isEmpty() ? null : "[" + t + "](" + url + ")";
  }

  /** Biketeam stores bare handles; some users typed a full URL instead. */
  private static @Nullable String socialLink(@Nullable String handle, String baseUrl) {
    String h = trimmed(handle);
    if (h.isEmpty()) {
      return null;
    }
    return h.startsWith("http") ? link(h, h) : link(h, baseUrl + h);
  }

  /** A free-text field in biketeam: linkify it only when it actually looks like a URL. */
  private static @Nullable String webLink(@Nullable String value) {
    String v = trimmed(value);
    if (v.isEmpty()) {
      return null;
    }
    return v.startsWith("http") ? link(v, v) : v;
  }

  private static @Nullable String joinNonBlank(String separator, @Nullable String... parts) {
    String joined =
        Stream.of(parts)
            .map(BiketeamMigrationService::trimmed)
            .filter(s -> !s.isEmpty())
            .collect(Collectors.joining(separator));
    return joined.isEmpty() ? null : joined;
  }

  private static String trimmed(@Nullable String s) {
    return s == null ? "" : s.trim();
  }

  // ─── Places ───────────────────────────────────────────────────────────────

  private Map<String, Long> migratePlaces(Run r) {
    Map<String, Long> ids = new HashMap<>();
    Team team = r.team();
    List<BtPlace> places = r.source().places();
    r.progress().phase(Phase.PLACES, places.size());
    for (BtPlace bt : places) {
      r.progress().beforeItem();
      try {
        QuarkusTransaction.requiringNew()
            .run(
                () -> {
                  PlaceRequest req =
                      new PlaceRequest(
                          bt.name(),
                          truncate(bt.address(), 200),
                          null,
                          bt.startPlace(),
                          bt.endPlace(),
                          toPoint(bt.pointLat(), bt.pointLng()));
                  Long mapped = mapRepo.findTriblyId(T_PLACE, bt.id());
                  Place place = null;
                  if (mapped != null) {
                    place = placeRepository.findByIdAndTeam(mapped, team.getId()).orElse(null);
                  }
                  if (place != null) {
                    place.setName(req.name());
                    place.setAddress(req.address());
                    place.setLink(req.link());
                    place.setStartPlace(req.startPlace());
                    place.setEndPlace(req.endPlace());
                    place.setGeometry(req.geometry());
                    placeRepository.persist(place);
                  } else {
                    PlaceDetailDto created = placeService.createPlace(team.getSlug(), req);
                    place =
                        placeRepository
                            .findByIdAndTeam(TsidUtils.toLong(created.id()), team.getId())
                            .orElseThrow();
                  }
                  map(r, T_PLACE, bt.id(), place.getId());
                  ids.put(bt.id(), place.getId());
                });
        r.progress().count(Counter.PLACES, Outcome.MIGRATED);
      } catch (Exception e) {
        LOG.warnf(e, "Failed to migrate place biketeam.id=%s", bt.id());
        itemFailed(r, Counter.PLACES, "PLACE", bt.id(), e);
      }
      r.progress().tick();
    }
    return ids;
  }

  // ─── Routes (Maps + GPX) ─────────────────────────────────────────────────

  private Map<String, Long> migrateMaps(Run r) {
    Map<String, Long> ids = new HashMap<>();
    List<BtMap> maps = r.source().maps();
    r.progress().phase(Phase.ROUTES, maps.size());
    for (BtMap bt : maps) {
      // Before each route: a single GPX can hold the thread for minutes.
      r.progress().beforeItem();
      try {
        SourceFile gpxFile = bt.deletion() ? null : r.source().gpx(bt.id());
        // Computed once for both uses below.
        String fingerprint = gpxFile == null ? null : routeFingerprint(gpxFile.fingerprint());
        // Downloaded before the transaction opens, and only when the route needs it.
        Fetched gpx = gpxFile == null ? Fetched.NONE : prefetchGpx(r, bt, gpxFile, fingerprint);
        Outcome outcome =
            QuarkusTransaction.requiringNew()
                .timeout(LONGEST_ITEM_TRANSACTION_SECONDS)
                .call(() -> migrateOneMap(r, bt, ids, gpxFile, fingerprint, gpx));
        r.progress().count(Counter.ROUTES, outcome);
      } catch (Exception e) {
        LOG.warnf(e, "Failed to migrate route biketeam.id=%s", bt.id());
        itemFailed(r, Counter.ROUTES, "ROUTE", bt.id(), e);
      }
      r.progress().tick();
    }
    return ids;
  }

  /**
   * What a route records as built from: the GPX's own fingerprint and the pipeline that processed
   * it. A route an earlier {@link GpxPipeline#VERSION} built no longer matches, so the next replay
   * downloads its GPX again and rebuilds it in place (same id, same slug), once. A row the earlier
   * code wrote holds the bare {@code "<size>:<md5>"}, which matches no version.
   */
  static @Nullable String routeFingerprint(@Nullable String gpxFingerprint) {
    return gpxFingerprint == null ? null : gpxFingerprint + "@p" + GpxPipeline.VERSION;
  }

  /**
   * The GPX of a route, downloaded outside any transaction — unless the route is already built
   * from these exact bytes (same fingerprint), in which case nothing is fetched at all.
   */
  private Fetched prefetchGpx(Run r, BtMap bt, SourceFile gpxFile, @Nullable String fingerprint) {
    boolean upToDate =
        fingerprint != null
            && QuarkusTransaction.requiringNew()
                .call(
                    () -> {
                      Long mapped = mapRepo.findTriblyId(T_ROUTE, bt.id());
                      return mapped != null
                          && owned(routeRepository.findByIdOptional(mapped).orElse(null), r.team())
                              != null
                          && fingerprint.equals(mapRepo.findFingerprint(T_ROUTE, bt.id()));
                    });
    return upToDate ? Fetched.NONE : Fetched.of(gpxFile);
  }

  /**
   * @param gpxFile the route's GPX in the source, null when it has none (or the map is deleted)
   * @param fingerprint {@code gpxFile}'s fingerprint, computed once by the caller
   */
  private Outcome migrateOneMap(
      Run r,
      BtMap bt,
      Map<String, Long> ids,
      @Nullable SourceFile gpxFile,
      @Nullable String fingerprint,
      Fetched fetchedGpx)
      throws IOException {
    Team team = r.team();
    Long mapped = mapRepo.findTriblyId(T_ROUTE, bt.id());
    if (bt.deletion()) {
      Route gone =
          mapped == null
              ? null
              : owned(routeRepository.findByIdOptional(mapped).orElse(null), team);
      if (gone != null) {
        gone.setDeleted(true);
        // The rides and stages on it lose its length (docs/LEDGER_*.md API-87).
        publicationEndCalculator.refreshUsersOf(gone);
      }
      return Outcome.SKIPPED;
    }
    if (gpxFile == null) {
      r.progress().warning("ROUTE", bt.id(), Codes.GPX_MISSING, "No GPX file in the export");
    }
    // Biketeam dropped its per-map visibility flag, so a route is exactly as visible as its team.
    RouteRequest req =
        new RouteRequest(
            bt.name(),
            emptyMedia(),
            mapSurface(bt.type()),
            contentVisibility(team.getVisibility()),
            null);
    Route route = null;
    if (mapped != null) {
      route = owned(routeRepository.findByIdOptional(mapped).orElse(null), team);
    }
    String stored = mapRepo.findFingerprint(T_ROUTE, bt.id());
    if (route != null && fingerprint != null && fingerprint.equals(stored)) {
      // Same bytes as the run that built this route, so its geometry, FIT and thumbnails still
      // hold — and the live source does not even download the file. Refresh only what
      // `RouteRequest` carries; the rest of the method does the fields biketeam keeps outside it.
      route.setName(req.name());
      route.setSurfaceType(req.surfaceType());
      route.setVisibility(req.visibility());
    } else {
      Path gpx = gpxFile == null ? null : fetchedGpx.path(gpxFile);
      if (route != null) {
        routeService.updateRoute(team.getSlug(), route.getSlug(), req, gpx);
      } else {
        RouteDto created = routeService.createRoute(team.getSlug(), req, gpx);
        route = routeRepository.findByIdOptional(TsidUtils.toLong(created.id())).orElseThrow();
      }
    }
    route.setStatus(Status.PUBLISHED);
    WindDirection wd = mapWindDirection(bt.windDirection());
    if (wd != null) {
      route.setWindDirection(wd);
    }
    if (bt.postedAt() != null) {
      route.setDateTime(bt.postedAt().atStartOfDay(r.zone()).toInstant());
    }
    routeRepository.persist(route);
    // Replaced as a whole, found or created by label: a replay leaves tags and links as they are.
    List<String> tagNotes = tagService.importTags(route, r.actor(), bt.tags());
    if (!tagNotes.isEmpty()) {
      String message = String.join("; ", tagNotes);
      LOG.warnf("Route biketeam.id=%s: %s", bt.id(), message);
      r.progress().warning("ROUTE", bt.id(), Codes.TAGS_TRUNCATED, message);
    }
    // Recorded only here, once the pipeline above has run to completion: a run that dies mid-upload
    // leaves no fingerprint, so the next one redoes the work rather than trusting a half-built row.
    mapRepo.upsert(T_ROUTE, bt.id(), route.getId(), fingerprint, r.liveTeamId());
    ids.put(bt.id(), route.getId());
    backdate("team_entities", route.getId(), at(r.zone(), bt.postedAt(), null));
    return Outcome.MIGRATED;
  }

  // ─── Ride templates ───────────────────────────────────────────────────────

  private void migrateRideTemplates(Run r) {
    List<BtRideTemplate> templates = r.source().rideTemplates();
    r.progress().phase(Phase.RIDE_TEMPLATES, templates.size());
    if (templates.isEmpty()) {
      return;
    }
    Map<String, List<BtRideGroupTemplate>> groupsByTemplate = new HashMap<>();
    r.source()
        .rideGroupTemplates()
        .forEach(
            g ->
                groupsByTemplate
                    .computeIfAbsent(g.rideTemplateId(), k -> new ArrayList<>())
                    .add(g));

    for (BtRideTemplate tpl : templates) {
      r.progress().beforeItem();
      try {
        QuarkusTransaction.requiringNew()
            .run(() -> migrateOneRideTemplate(r, tpl, groupsByTemplate));
        r.progress().count(Counter.RIDE_TEMPLATES, Outcome.MIGRATED);
      } catch (Exception e) {
        LOG.warnf(e, "Failed to migrate ride template biketeam.id=%s", tpl.id());
        itemFailed(r, Counter.RIDE_TEMPLATES, "RIDE_TEMPLATE", tpl.id(), e);
      }
      r.progress().tick();
    }
  }

  private void migrateOneRideTemplate(
      Run r, BtRideTemplate tpl, Map<String, List<BtRideGroupTemplate>> groupsByTemplate) {
    Team team = r.team();
    Long mapped = mapRepo.findTriblyId(T_RIDE_TEMPLATE, tpl.id());
    RideTemplate target =
        mapped != null ? rideTemplateRepository.findByIdOptional(mapped).orElse(null) : null;
    if (target != null && !target.getTeam().getId().equals(team.getId())) {
      // A stale row pointing at another team's template: create rather than modify it.
      target = null;
    }
    if (target == null) {
      String slug = uniqueRideTemplateSlug(team.getId(), tpl.name());
      target =
          new RideTemplate(
              r.actor(),
              team,
              tpl.name(),
              slug,
              biketeamToMarkdown(tpl.description()),
              contentVisibility(team.getVisibility()),
              Status.PUBLISHED);
      rideTemplateRepository.persistAndFlush(target);
    } else {
      target.setName(tpl.name());
      target.setVisibility(contentVisibility(team.getVisibility()));
      target.setMarkdown(biketeamToMarkdown(tpl.description()));
      rideTemplateRepository.persist(target);
    }
    // Biketeam's increment is already the number its next ride takes, and a re-run brings the one
    // biketeam has reached since (docs/LEDGER_*.md API-108).
    target.setNextNumber(tpl.increment());
    map(r, T_RIDE_TEMPLATE, tpl.id(), target.getId());

    target.getGroups().clear();
    rideTemplateRepository.flush();
    int sortOrder = 0;
    for (BtRideGroupTemplate g : groupsByTemplate.getOrDefault(tpl.id(), List.of())) {
      RideTemplateGroup grp = new RideTemplateGroup(r.actor(), target, g.name());
      grp.setTime(g.meetingTime());
      grp.setAverageSpeed(toFloat(g.averageSpeed()));
      grp.setSortOrder(sortOrder++);
      target.addGroup(grp);
      rideTemplateGroupRepository.persist(grp);
      map(r, T_RIDE_TEMPLATE_GROUP, g.id(), grp.getId());
    }
  }

  private String uniqueRideTemplateSlug(Long teamId, String name) {
    String base = slugify(name);
    String s = base;
    int n = 2;
    while (rideTemplateRepository.existsByTeamAndSlug(teamId, s)) {
      s = base + "-" + n++;
    }
    return s;
  }

  // ─── Posts ────────────────────────────────────────────────────────────────

  private void migratePublications(Run r) {
    List<BtPublication> publications = r.source().publications();
    r.progress().phase(Phase.PUBLICATIONS, publications.size());
    for (BtPublication bt : publications) {
      r.progress().beforeItem();
      if (bt.deletion()) {
        r.progress().count(Counter.PUBLICATIONS, Outcome.SKIPPED);
        r.progress().tick();
        continue;
      }
      try {
        Fetched image = prefetchImage(r, ImageKind.PUBLICATION, bt.id());
        QuarkusTransaction.requiringNew()
            .timeout(120)
            .run(() -> migrateOnePublication(r, bt, image));
        r.progress().count(Counter.PUBLICATIONS, Outcome.MIGRATED);
      } catch (Exception e) {
        LOG.warnf(e, "Failed to migrate publication biketeam.id=%s", bt.id());
        itemFailed(r, Counter.PUBLICATIONS, "PUBLICATION", bt.id(), e);
      }
      r.progress().tick();
    }
  }

  private void migrateOnePublication(Run r, BtPublication bt, Fetched image) {
    Team team = r.team();
    Long mapped = mapRepo.findTriblyId(T_POST, bt.id());
    Post existing =
        mapped != null ? owned(postRepository.findByIdOptional(mapped).orElse(null), team) : null;
    // A post is read in its team's zone: its biketeam instant as a wall time there, which the
    // backend reads back to the same instant (docs/LEDGER_*.md API-60).
    Instant publishedAt = bt.publishedAt() != null ? bt.publishedAt() : Instant.now();
    PostRequest req =
        new PostRequest(
            bt.title(),
            mediaWithExisting(biketeamToMarkdown(bt.content()), existing),
            EventDateTime.local(
                LocalDateTime.ofInstant(publishedAt, EventTimezoneResolver.teamZone(team))),
            mapStatus(bt.publishedStatus()),
            // Publications carry no listed_in_feed flag: biketeam always lists them.
            contentVisibility(team.getVisibility()),
            null,
            null,
            null);
    Post post;
    if (existing != null) {
      postService.updatePost(team.getSlug(), existing.getSlug(), req);
      post = existing;
    } else {
      PostDto created = postService.createPost(team.getSlug(), req);
      post = postRepository.findByIdOptional(TsidUtils.toLong(created.getId())).orElseThrow();
    }
    map(r, T_POST, bt.id(), post.getId());
    attachImage(r, post, ImageKind.PUBLICATION, bt.id(), image);
    backdate("team_entities", post.getId(), bt.publishedAt());
  }

  // ─── Rides ────────────────────────────────────────────────────────────────

  private void migrateRides(Run r, Map<String, Long> routeIds, Map<String, Long> placeIds) {
    List<BtRide> rides = r.source().rides();
    r.progress().phase(Phase.RIDES, rides.size());
    if (rides.isEmpty()) {
      return;
    }
    Map<String, List<BtRideGroup>> groupsByRide = new HashMap<>();
    r.source()
        .rideGroups()
        .forEach(g -> groupsByRide.computeIfAbsent(g.rideId(), k -> new ArrayList<>()).add(g));

    for (BtRide bt : rides) {
      r.progress().beforeItem();
      if (bt.deletion()) {
        r.progress().count(Counter.RIDES, Outcome.SKIPPED);
        r.progress().tick();
        continue;
      }
      try {
        Fetched image = prefetchImage(r, ImageKind.RIDE, bt.id());
        QuarkusTransaction.requiringNew()
            .timeout(120)
            .run(() -> migrateOneRide(r, bt, groupsByRide, routeIds, placeIds, image));
        r.progress().count(Counter.RIDES, Outcome.MIGRATED);
      } catch (Exception e) {
        LOG.warnf(e, "Failed to migrate ride biketeam.id=%s", bt.id());
        itemFailed(r, Counter.RIDES, "RIDE", bt.id(), e);
      }
      r.progress().tick();
    }
  }

  private void migrateOneRide(
      Run r,
      BtRide bt,
      Map<String, List<BtRideGroup>> groupsByRide,
      Map<String, Long> routeIds,
      Map<String, Long> placeIds,
      Fetched image) {
    Team team = r.team();
    List<BtRideGroup> groups = groupsByRide.getOrDefault(bt.id(), List.of());
    EventDateTime dateTime =
        EventDateTime.local(wall(r.zone(), bt.date(), earliestMeetingTime(groups)));
    Long mapped = mapRepo.findTriblyId(T_RIDE, bt.id());
    Ride existing =
        mapped != null ? owned(rideRepository.findByIdOptional(mapped).orElse(null), team) : null;

    // On replay, hand each group back its Pédalons id. Without it RideService.updateRide treats
    // every group as new, drops the old ones and cascade-deletes their participations.
    Set<Long> liveGroupIds =
        existing == null
            ? Set.of()
            : existing.getGroups().stream().map(RideGroup::getId).collect(Collectors.toSet());
    // No leader: RideGroupDto.leader stays null — biketeam had none, and it is never derived from
    // createdBy (the ride's creator, identical across all its groups).
    List<GroupRequest> groupRequests =
        groups.stream()
            .map(
                g ->
                    GroupRequest.builder()
                        .id(existingGroupId(g.id(), liveGroupIds))
                        .name(g.name())
                        .time(g.meetingTime())
                        .averageSpeed(toFloat(g.averageSpeed()))
                        .routeSlug(routeSlugFromBiketeamId(team, routeIds, g.mapId()))
                        .build())
            .toList();
    RideRequest req =
        new RideRequest(
            bt.title(),
            mediaWithExisting(biketeamToMarkdown(bt.description()), existing),
            dateTime,
            mapStatus(bt.publishedStatus()),
            contentVisibility(team.getVisibility(), bt.listedInFeed()),
            null,
            placeIdString(placeIds, bt.startPlaceId()),
            placeIdString(placeIds, bt.endPlaceId()),
            null,
            groupRequests,
            null);

    Ride ride;
    if (existing != null) {
      rideService.updateRide(team.getSlug(), existing.getSlug(), req);
      ride = rideRepository.findByIdOptional(existing.getId()).orElseThrow();
    } else {
      RideDto created = rideService.createRide(team.getSlug(), req);
      ride = rideRepository.findByIdOptional(TsidUtils.toLong(created.getId())).orElseThrow();
    }
    map(r, T_RIDE, bt.id(), ride.getId());

    // updateRide writes the groups in request order and numbers sortOrder with it, so position i
    // here is the group built from groups.get(i).
    List<RideGroup> tribGroups = new ArrayList<>(ride.getGroups());
    tribGroups.sort(Comparator.comparingInt(RideGroup::getSortOrder));
    int paired = Math.min(tribGroups.size(), groups.size());
    if (tribGroups.size() != groups.size()) {
      LOG.warnf(
          "Ride biketeam.id=%s: %d source group(s) but %d Pédalons group(s), pairing the first %d",
          bt.id(), groups.size(), tribGroups.size(), paired);
    }
    for (int i = 0; i < paired; i++) {
      map(r, T_RIDE_GROUP, groups.get(i).id(), tribGroups.get(i).getId());
    }

    attachImage(r, ride, ImageKind.RIDE, bt.id(), image);
    backdate("team_entities", ride.getId(), bt.publishedAt());
  }

  // ─── Trips ────────────────────────────────────────────────────────────────

  private void migrateTrips(Run r, Map<String, Long> routeIds) {
    List<BtTrip> trips = r.source().trips();
    r.progress().phase(Phase.TRIPS, trips.size());
    if (trips.isEmpty()) {
      return;
    }
    Map<String, List<BtTripStage>> stagesByTrip = new HashMap<>();
    r.source()
        .tripStages()
        .forEach(s -> stagesByTrip.computeIfAbsent(s.tripId(), k -> new ArrayList<>()).add(s));

    for (BtTrip bt : trips) {
      r.progress().beforeItem();
      List<BtTripStage> stages = stagesByTrip.getOrDefault(bt.id(), List.of());
      if (bt.deletion()) {
        r.progress().count(Counter.TRIPS, Outcome.SKIPPED);
        stages.forEach(s -> r.progress().count(Counter.TRIP_STAGES, Outcome.SKIPPED));
        r.progress().tick();
        continue;
      }
      String outside = stagesOutsideDates(bt, stages);
      if (outside != null) {
        r.progress().warning("TRIP", bt.id(), Codes.TRIP_STAGES_OUTSIDE_DATES, outside);
      }
      try {
        Fetched image = prefetchImage(r, ImageKind.TRIP, bt.id());
        int pairedStages =
            QuarkusTransaction.requiringNew()
                .timeout(120)
                .call(() -> migrateOneTrip(r, bt, stages, routeIds, image));
        r.progress().count(Counter.TRIPS, Outcome.MIGRATED);
        for (int i = 0; i < stages.size(); i++) {
          r.progress()
              .count(Counter.TRIP_STAGES, i < pairedStages ? Outcome.MIGRATED : Outcome.FAILED);
        }
      } catch (Exception e) {
        LOG.warnf(e, "Failed to migrate trip biketeam.id=%s", bt.id());
        itemFailed(r, Counter.TRIPS, "TRIP", bt.id(), e);
        stages.forEach(s -> r.progress().count(Counter.TRIP_STAGES, Outcome.FAILED));
      }
      r.progress().tick();
    }
  }

  /**
   * The {@link Codes#TRIP_STAGES_OUTSIDE_DATES} message of a trip some of whose stages are dated
   * before its {@code start_date} or after its {@code end_date}, or null when they all fit (a
   * missing date on either side is no bound).
   */
  static @Nullable String stagesOutsideDates(BtTrip bt, List<BtTripStage> stages) {
    LocalDate start = bt.startDate();
    LocalDate end = bt.endDate();
    List<String> outside = new ArrayList<>();
    for (BtTripStage s : stages) {
      LocalDate date = s.date();
      if (date != null
          && ((start != null && date.isBefore(start)) || (end != null && date.isAfter(end)))) {
        outside.add("'" + s.name() + "' (" + date + ")");
      }
    }
    if (outside.isEmpty()) {
      return null;
    }
    return "Trip '"
        + bt.title()
        + "' runs from "
        + (start != null ? start : "?")
        + " to "
        + (end != null ? end : "?")
        + " on biketeam, but "
        + (outside.size() == 1 ? "stage " : "stages ")
        + String.join(", ", outside)
        + (outside.size() == 1 ? " falls" : " fall")
        + " outside those dates. Pédalons ends a trip with its last stage: the biketeam end date is"
        + " lost, and the trip may end before it starts. Fix the dates on biketeam, or on"
        + " Pédalons after the migration.";
  }

  /** @return how many stages were paired with a Pédalons stage */
  private int migrateOneTrip(
      Run r, BtTrip bt, List<BtTripStage> stages, Map<String, Long> routeIds, Fetched image) {
    Team team = r.team();
    EventDateTime dateTime = EventDateTime.local(wall(r.zone(), bt.startDate(), bt.meetingTime()));
    Long mapped = mapRepo.findTriblyId(T_TRIP, bt.id());
    Trip existing =
        mapped != null ? owned(tripRepository.findByIdOptional(mapped).orElse(null), team) : null;

    // Same as ride groups: an id-less StageRequest makes TripService.updateTrip soft-delete the old
    // stage and create a replacement, so every replay would leave another dead stage behind.
    Set<Long> liveStageIds =
        existing == null
            ? Set.of()
            : existing.getStages().stream().map(TripStage::getId).collect(Collectors.toSet());
    List<StageRequest> stageRequests = new ArrayList<>();
    for (int i = 0; i < stages.size(); i++) {
      BtTripStage s = stages.get(i);
      stageRequests.add(
          StageRequest.builder()
              .id(existingStageId(s.id(), liveStageIds))
              .name(s.name())
              .dateTime(
                  EventDateTime.local(
                      wall(r.zone(), s.date(), stageDeparture(i, bt.meetingTime()))))
              .routeSlug(routeSlugFromBiketeamId(team, routeIds, s.mapId()))
              .startPlaceId(null)
              .endPlaceId(null)
              .media(emptyMedia())
              .build());
    }
    TripRequest req =
        new TripRequest(
            bt.title(),
            mediaWithExisting(renderTripDescription(bt), existing),
            dateTime,
            mapStatus(bt.publishedStatus()),
            contentVisibility(team.getVisibility(), bt.listedInFeed()),
            null,
            null,
            stageRequests,
            null);

    Trip trip;
    if (existing != null) {
      tripService.updateTrip(team.getSlug(), existing.getSlug(), req);
      trip = tripRepository.findByIdOptional(existing.getId()).orElseThrow();
    } else {
      TripDto created = tripService.createTrip(team.getSlug(), req);
      trip = tripRepository.findByIdOptional(TsidUtils.toLong(created.getId())).orElseThrow();
    }
    map(r, T_TRIP, bt.id(), trip.getId());

    // Trip.stages has no @SQLRestriction, so soft-deleted stages come along; they all carry
    // sortOrder 0 and would otherwise head the list and steal the mapping.
    List<TripStage> tribStages =
        trip.getStages().stream().filter(s -> !s.isDeleted()).collect(Collectors.toList());
    tribStages.sort(Comparator.comparingInt(TripStage::getSortOrder));
    int paired = Math.min(tribStages.size(), stages.size());
    for (int i = 0; i < paired; i++) {
      map(r, T_TRIP_STAGE, stages.get(i).id(), tribStages.get(i).getId());
    }

    attachImage(r, trip, ImageKind.TRIP, bt.id(), image);
    backdate("team_entities", trip.getId(), bt.publishedAt());
    return paired;
  }

  /** Heading of the section that carries a biketeam trip's notes page. */
  static final String TRIP_NOTES_HEADING = "## Notes";

  /**
   * A biketeam trip's description, followed by its notes page ({@code trip.markdown_page}, served
   * at {@code /{team}/trips/{id}/notes}) under a {@value #TRIP_NOTES_HEADING} heading. Pédalons has
   * no per-trip page, and the notes read as the rest of the trip's text, so they become the tail of
   * its description; the old {@code /notes} URL already redirects to the trip itself.
   *
   * <p>The whole text is rebuilt from the source on every run, never appended to what an earlier run
   * wrote, so a replay does not stack a second section. The notes are already Markdown: line endings
   * are normalised, nothing else — unlike the plain-text description.
   */
  static String renderTripDescription(BtTrip bt) {
    String description = biketeamToMarkdown(bt.description());
    String notes = normalizeNewlines(bt.markdownPage()).strip();
    if (notes.isEmpty()) {
      return description;
    }
    description = description.strip();
    String section = TRIP_NOTES_HEADING + "\n\n" + notes;
    return description.isEmpty() ? section : description + "\n\n" + section;
  }

  // ─── Asset attachment helpers ─────────────────────────────────────────────

  /**
   * Attaches the ride, trip or publication image the source has for {@code biketeamEntityId}.
   *
   * <p>After upload we (a) read pixel dimensions from the local file and (b) append a
   * {@code ::asset{id="..."}} directive to the entity's markdown. Without the directive, Pédalons'
   * MediaEditor wouldn't render the image and {@code AssetService.updateAssets} would purge it on
   * the first edit-save (it only keeps images referenced from markdown).
   *
   * <p>The mapping key keeps the legacy directory name ({@code ride-images:<id>}), so an image the
   * dump import already uploaded is recognised and not uploaded — nor downloaded — again.
   */
  private void attachImage(
      Run r, TeamEntity entity, ImageKind kind, String biketeamEntityId, Fetched fetched) {
    SourceFile image = r.source().image(kind, biketeamEntityId);
    if (image == null) {
      return;
    }
    String key = imageKey(kind, biketeamEntityId);
    Long alreadyMapped = reusableImage(r, key, entity.getId());
    if (alreadyMapped != null) {
      // Idempotent replay: ensure the directive is present even if the asset was migrated
      // previously.
      ensureAssetDirective(entity, alreadyMapped);
      r.progress().count(Counter.IMAGES, Outcome.MIGRATED);
      return;
    }
    try {
      Path file = fetched.path(image);
      try (InputStream in = Files.newInputStream(file)) {
        AssetWithFile awf = assetService.addAsset(entity, AssetType.IMAGE, image.fileName());
        Files.copy(in, awf.file().toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        assetService.uploadAssetFile(awf.asset());
        readImageDimensions(file, awf.asset());
        ensureAssetDirective(entity, awf.asset().getId());
        map(r, T_ASSET, key, awf.asset().getId());
        r.progress().count(Counter.IMAGES, Outcome.MIGRATED);
      }
    } catch (IOException e) {
      LOG.warnf(e, "Failed to upload image %s for entity %s", image.fileName(), biketeamEntityId);
      r.progress().count(Counter.IMAGES, Outcome.FAILED);
      r.progress()
          .warning(
              "IMAGE",
              biketeamEntityId,
              e instanceof SourceFileUnavailableException
                  ? Codes.FILE_DOWNLOAD_FAILED
                  : Codes.IMAGE_FAILED,
              message(e));
    }
  }

  /** The mapping type of the entity an image of {@code kind} hangs off. */
  private static String entityType(ImageKind kind) {
    return switch (kind) {
      case RIDE -> T_RIDE;
      case TRIP -> T_TRIP;
      case PUBLICATION -> T_POST;
    };
  }

  /**
   * The image of a ride, trip or publication, downloaded outside any transaction — unless the
   * asset already mapped for it will be reused, in which case nothing is fetched. Reads the mapping
   * in a short transaction of its own; the element's transaction checks it again ({@link
   * #attachImage}).
   */
  private Fetched prefetchImage(Run r, ImageKind kind, String biketeamEntityId) {
    SourceFile image = r.source().image(kind, biketeamEntityId);
    if (image == null) {
      return Fetched.NONE;
    }
    String key = imageKey(kind, biketeamEntityId);
    boolean reusable =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  Long entityId = mapRepo.findTriblyId(entityType(kind), biketeamEntityId);
                  return entityId != null && reusableImage(r, key, entityId) != null;
                });
    return reusable ? Fetched.NONE : Fetched.of(image);
  }

  /**
   * The image asset already mapped under {@code key}, or null. A mapping row is only trusted when
   * the asset belongs to the target team and hangs off {@code entityId}: the key is global, and may
   * still point at an asset of an earlier target — a trashed team, in another domain — which a
   * directive must never reference.
   */
  private @Nullable Long reusableImage(Run r, String key, Long entityId) {
    Long assetId = mapRepo.findTriblyId(T_ASSET, key);
    if (assetId == null) {
      return null;
    }
    fr.pedalons.domain.asset.Asset asset = em.find(fr.pedalons.domain.asset.Asset.class, assetId);
    if (asset == null
        || !asset.getTeam().getId().equals(r.team().getId())
        || asset.getTeamEntity() == null
        || asset.getTeamEntity().isDeleted()
        || !asset.getTeamEntity().getId().equals(entityId)) {
      return null;
    }
    return assetId;
  }

  /**
   * A source file fetched ahead of the transaction that uses it — biketeam's files come over HTTP,
   * and no HTTP call may run inside a transaction: a slow download would time the element's
   * transaction out and hold a database connection meanwhile. The failure, if any, is kept and
   * rethrown where the file is used, so it is reported exactly as before.
   */
  record Fetched(@Nullable Path path, @Nullable IOException error) {

    static final Fetched NONE = new Fetched(null, null);

    /**
     * Downloads {@code file}. A missing file is kept as this element's failure; an export that
     * cannot serve it ({@link BiketeamExportException}, unchecked) is not caught, and ends the
     * attempt.
     */
    static Fetched of(SourceFile file) {
      try {
        return new Fetched(file.open(), null);
      } catch (IOException e) {
        return new Fetched(null, e);
      }
    }

    /**
     * The prefetched copy, or its download failure. Falls back to opening {@code file} only when
     * nothing was prefetched because the mapping looked reusable and no longer is — a race with a
     * concurrent change.
     */
    Path path(SourceFile file) throws IOException {
      if (error != null) {
        throw error;
      }
      return path != null ? path : file.open();
    }
  }

  private void readImageDimensions(Path image, fr.pedalons.domain.asset.Asset asset) {
    try (InputStream in = Files.newInputStream(image)) {
      java.awt.image.BufferedImage bi = javax.imageio.ImageIO.read(in);
      if (bi != null) {
        asset.setWidth(bi.getWidth());
        asset.setHeight(bi.getHeight());
      }
    } catch (IOException e) {
      LOG.debugf("Could not read dimensions for %s: %s", image, e.getMessage());
    }
  }

  /** Append {@code ::asset{id="<tsid>"}} to the entity markdown if not already present. */
  private void ensureAssetDirective(TeamEntity entity, long assetId) {
    String tsid = TsidUtils.toString(assetId);
    String directive = "::asset{id=\"" + tsid + "\"}";
    String md = entity.getMarkdown() == null ? "" : entity.getMarkdown();
    if (md.contains(directive)) {
      return;
    }
    String separator = md.isEmpty() ? "" : "\n\n";
    entity.setMarkdown(md + separator + directive);
  }

  // ─── Creation timestamps ──────────────────────────────────────────────────

  /**
   * Restores the biketeam creation date on a row we just wrote. {@code BaseEntity.createdAt} is a
   * {@code @CreationTimestamp} mapped {@code updatable = false}: Hibernate stamps it on insert and
   * never writes it again, so neither the entity setter nor an HQL bulk update reaches it. Plain
   * SQL does.
   */
  private void backdate(String table, long id, @Nullable Instant createdAt) {
    if (createdAt == null) {
      return;
    }
    em.createNativeQuery(
            "update " + table + " set created_at = :ts, updated_at = :ts where id = :id")
        .setParameter("ts", OffsetDateTime.ofInstant(createdAt, ZoneOffset.UTC))
        .setParameter("id", id)
        .executeUpdate();
  }

  // ─── Mapping keys ─────────────────────────────────────────────────────────
  //
  // The one place that knows how a biketeam row is keyed in biketeam_migration_map. The worker's
  // reset forgets rows by these keys, and the URL table reads them: neither rebuilds a key itself.

  /** {@code biketeam_id} of the {@link #T_TEAM_PAGE} row of a team's FAQ page. */
  public static String faqPageKey(String biketeamTeamId) {
    return biketeamTeamId + FAQ_PAGE_KEY_SUFFIX;
  }

  /** {@code biketeam_id} of the {@link #T_ASSET} row of a team's logo. */
  public static String logoKey(String biketeamTeamId) {
    return LOGO_ASSET_KEY_PREFIX + biketeamTeamId;
  }

  /**
   * {@code biketeam_id} of the {@link #T_ASSET} row of the image of a ride, trip or publication.
   * Keeps the legacy directory name ({@code ride-images:<id>}), so that an image the dump import
   * already uploaded is recognised.
   */
  public static String imageKey(ImageKind kind, String biketeamEntityId) {
    return kind.legacyDirectory() + ":" + biketeamEntityId;
  }

  /**
   * Every mapping key {@code source} can have produced — the team, its pages, logo and content, and
   * the images, legacy keys included. What a reset forgets, besides the rows tagged with the team.
   */
  public static List<BiketeamMigrationMap.Key> mappingKeys(BiketeamSource source) {
    String teamId = source.team().id();
    List<BiketeamMigrationMap.Key> keys = new ArrayList<>();
    keys.add(new BiketeamMigrationMap.Key(T_TEAM, teamId));
    keys.add(new BiketeamMigrationMap.Key(T_TEAM_PAGE, teamId));
    keys.add(new BiketeamMigrationMap.Key(T_TEAM_PAGE, faqPageKey(teamId)));
    keys.add(new BiketeamMigrationMap.Key(T_ASSET, logoKey(teamId)));
    source.places().forEach(p -> keys.add(new BiketeamMigrationMap.Key(T_PLACE, p.id())));
    source.maps().forEach(m -> keys.add(new BiketeamMigrationMap.Key(T_ROUTE, m.id())));
    source
        .rideTemplates()
        .forEach(t -> keys.add(new BiketeamMigrationMap.Key(T_RIDE_TEMPLATE, t.id())));
    source
        .rideGroupTemplates()
        .forEach(g -> keys.add(new BiketeamMigrationMap.Key(T_RIDE_TEMPLATE_GROUP, g.id())));
    for (BtPublication p : source.publications()) {
      keys.add(new BiketeamMigrationMap.Key(T_POST, p.id()));
      keys.add(new BiketeamMigrationMap.Key(T_ASSET, imageKey(ImageKind.PUBLICATION, p.id())));
    }
    for (BtRide r : source.rides()) {
      keys.add(new BiketeamMigrationMap.Key(T_RIDE, r.id()));
      keys.add(new BiketeamMigrationMap.Key(T_ASSET, imageKey(ImageKind.RIDE, r.id())));
    }
    source.rideGroups().forEach(g -> keys.add(new BiketeamMigrationMap.Key(T_RIDE_GROUP, g.id())));
    for (BtTrip t : source.trips()) {
      keys.add(new BiketeamMigrationMap.Key(T_TRIP, t.id()));
      keys.add(new BiketeamMigrationMap.Key(T_ASSET, imageKey(ImageKind.TRIP, t.id())));
    }
    source
        .tripStages()
        .forEach(st -> keys.add(new BiketeamMigrationMap.Key(T_TRIP_STAGE, st.id())));
    return keys;
  }

  // ─── Mapping helpers ──────────────────────────────────────────────────────

  /** Records a mapping row, tagged with the biketeam team on the live path. */
  private void map(Run r, String entityType, String biketeamId, long triblyId) {
    mapRepo.upsert(entityType, biketeamId, triblyId, null, r.liveTeamId());
  }

  /**
   * A mapped entity is only trusted when it belongs to the target team and is not in the trash: a
   * stale mapping row then yields a duplicate instead of modifying — or failing on — another team's
   * content, and an element trashed on Pédalons is created again, its mapping row rewritten
   * (docs/plans/2026-09-22-biketeam-live-migration.md, biketeam is authoritative for the content).
   * The services refuse to update a trashed entity ({@code NotFoundException}), so reusing it would
   * fail the element on every replay.
   */
  private static <T extends TeamEntity> @Nullable T owned(@Nullable T entity, Team team) {
    if (entity == null || entity.isDeleted() || !entity.getTeam().getId().equals(team.getId())) {
      return null;
    }
    return entity;
  }

  /**
   * Counts one failed element and reports why — unless the failure is not the element's: an export
   * that cannot serve the job ({@link BiketeamExportException}, e.g. biketeam unreachable while a
   * file downloads) is rethrown, and ends the attempt so the worker retries it. A job must never
   * succeed with the elements an outage cost it.
   */
  private static void itemFailed(
      Run r, Counter counter, String entityType, String biketeamId, Exception e) {
    rethrowIfExportFailure(e);
    r.progress().count(counter, Outcome.FAILED);
    r.progress().warning(entityType, biketeamId, failureCode(e), message(e));
  }

  /**
   * Rethrows the {@link BiketeamExportException} behind {@code e}, however wrapped — and the {@link
   * BiketeamJobLostException} a heartbeat written mid-download may raise: neither is this element's
   * failure, both end the attempt.
   */
  static void rethrowIfExportFailure(Throwable e) {
    for (Throwable t = e; t != null; t = t.getCause()) {
      if (t instanceof BiketeamExportException export) {
        throw export;
      }
      if (t instanceof BiketeamJobLostException lost) {
        throw lost;
      }
      if (t.getCause() == t) {
        break;
      }
    }
  }

  /** The warning code of an element that failed, from the first recognisable cause. */
  static String failureCode(Throwable e) {
    for (Throwable t = e; t != null; t = t.getCause()) {
      if (t instanceof SourceFileUnavailableException) {
        return Codes.FILE_DOWNLOAD_FAILED;
      }
      if (t instanceof PedalonsException pe) {
        if (pe.getErrorCode() == ErrorCode.GPX_EMPTY) {
          return Codes.GPX_EMPTY;
        }
        // A track over GpxLimits.MAX_TRACK_DISTANCE_METERS (SEC-6) is a GPX the import refuses.
        if (pe.getErrorCode() == ErrorCode.GPX_FAILURE
            || pe.getErrorCode() == ErrorCode.GPX_TOO_LONG) {
          return Codes.GPX_FAILURE;
        }
      }
      if (t.getCause() == t) {
        break;
      }
    }
    return Codes.ITEM_FAILED;
  }

  private static String message(Throwable e) {
    Throwable root = e;
    while (root.getCause() != null && root.getCause() != root) {
      root = root.getCause();
    }
    String m = root.getMessage();
    String text = root.getClass().getSimpleName() + (m == null ? "" : ": " + m);
    return text.length() <= 500 ? text : text.substring(0, 500);
  }

  private static @Nullable Point<G2D> toPoint(@Nullable Double lat, @Nullable Double lng) {
    if (lat == null || lng == null) {
      return null;
    }
    return point(WGS84, g(lng, lat));
  }

  private static SurfaceType mapSurface(@Nullable String biketeamType) {
    if (biketeamType == null) {
      return SurfaceType.ROAD;
    }
    return switch (biketeamType.toUpperCase(Locale.ROOT)) {
      case "GRAVEL" -> SurfaceType.GRAVEL;
      case "MTB" -> SurfaceType.MTB;
      default -> SurfaceType.ROAD;
    };
  }

  /**
   * Biketeam's {@code WindDirection} enum writes its Java names — {@code NORTH_EAST} — which the
   * legacy mapping never matched, expecting {@code NORTHEAST}: the four diagonals were lost. Both
   * spellings are accepted.
   */
  static @Nullable WindDirection mapWindDirection(@Nullable String biketeamWd) {
    if (biketeamWd == null) {
      return null;
    }
    return switch (biketeamWd.toUpperCase(Locale.ROOT).replace("_", "")) {
      case "NORTH" -> WindDirection.NORTH;
      case "NORTHEAST" -> WindDirection.NORTH_EAST;
      case "EAST" -> WindDirection.EAST;
      case "SOUTHEAST" -> WindDirection.SOUTH_EAST;
      case "SOUTH" -> WindDirection.SOUTH;
      case "SOUTHWEST" -> WindDirection.SOUTH_WEST;
      case "WEST" -> WindDirection.WEST;
      case "NORTHWEST" -> WindDirection.NORTH_WEST;
      default -> null;
    };
  }

  /**
   * Biketeam's five team visibilities collapse onto Pédalons' three. Both PRIVATE flavours mean
   * "members only", which is exactly {@code TEAM}; the unlisted-ness of PRIVATE_UNLISTED has no
   * Pédalons counterpart and is dropped. USER marks a personal training space: biketeam never lists
   * it, yet {@code Team.isPublic()} lets anyone with the link read it, so PUBLIC_UNLISTED is the
   * faithful translation. An unknown value maps to the most restrictive option.
   */
  static Visibility mapTeamVisibility(@Nullable String biketeamVisibility) {
    if (biketeamVisibility == null) {
      return Visibility.TEAM;
    }
    return switch (biketeamVisibility.toUpperCase(Locale.ROOT)) {
      case "PUBLIC" -> Visibility.PUBLIC;
      case "PUBLIC_UNLISTED", "USER" -> Visibility.PUBLIC_UNLISTED;
      case "PRIVATE", "PRIVATE_UNLISTED" -> Visibility.TEAM;
      default -> Visibility.TEAM;
    };
  }

  /**
   * Visibility of content that biketeam always lists — routes, posts, ride templates. Only the team
   * can hide it.
   */
  private static Visibility contentVisibility(Visibility teamVisibility) {
    return contentVisibility(teamVisibility, true);
  }

  /**
   * Biketeam has no per-entity visibility beyond {@code listed_in_feed}, which hides a ride or trip
   * from the team feed while leaving a direct link working — exactly {@code PUBLIC_UNLISTED}.
   *
   * <p>The team's own unlisted-ness is deliberately not pushed down onto its content. Marking the
   * items of an unlisted team PUBLIC_UNLISTED would empty the team's own feed today — the team's
   * pages list a PUBLIC_UNLISTED team's items, but team-scoped listings still require {@code
   * te.visibility = 'PUBLIC'} — and it would stick: promoting that team to PUBLIC later would leave
   * its whole feed hidden, where biketeam would have shown it.
   */
  private static Visibility contentVisibility(Visibility teamVisibility, boolean listedInFeed) {
    if (teamVisibility == Visibility.TEAM) {
      return Visibility.TEAM;
    }
    return listedInFeed ? Visibility.PUBLIC : Visibility.PUBLIC_UNLISTED;
  }

  private static Status mapStatus(@Nullable String biketeamStatus) {
    if (biketeamStatus == null) {
      return Status.DRAFT;
    }
    return switch (biketeamStatus.toUpperCase(Locale.ROOT)) {
      case "PUBLISHED" -> Status.PUBLISHED;
      default -> Status.DRAFT;
    };
  }

  /**
   * A biketeam bare date and time, read in the team's zone. Biketeam stored {@code time without
   * time zone} and bare dates and resolved both against {@code team_configuration.timezone} at
   * render time; the source carries that zone.
   */
  static Instant at(ZoneId zone, @Nullable LocalDate date, @Nullable LocalTime time) {
    return wall(zone, date, time).atZone(zone).toInstant();
  }

  /**
   * The same biketeam date and time as a wall time, for the requests of rides, trips and stages:
   * the backend reads it in the zone it resolves for the entity — the start place's or the route's,
   * else the team's, which is biketeam's (docs/LEDGER_*.md API-60). Identical to {@link #at} for an
   * entity located in the team's zone.
   */
  static LocalDateTime wall(ZoneId zone, @Nullable LocalDate date, @Nullable LocalTime time) {
    LocalDate d = date != null ? date : LocalDate.now(zone);
    LocalTime t = time != null ? time : LocalTime.MIDNIGHT;
    return d.atTime(t);
  }

  /**
   * Departure time of a trip stage. Biketeam's {@code trip_stage} carries a bare {@code date} and no
   * time at all — its only time is {@code trip.meeting_time}, the rendezvous of the whole trip —
   * whereas Pédalons' {@code TripStage.dateTime} is an {@code Instant} that {@code TripStageCard}
   * and {@code StageDetailPage} both render down to the minute. Left unset every stage would read
   * "00:00".
   *
   * <p>So the first stage takes the trip's meeting time, which is exactly what it meant, and the
   * later ones get 8am — a plain convention for a departure on the road, not a claim about the
   * source data, which holds nothing on the subject. Stages arrive sorted by biketeam's own
   * comparator (date, then name), so index 0 is the first day.
   */
  private static LocalTime stageDeparture(int index, @Nullable LocalTime meetingTime) {
    if (index == 0 && meetingTime != null) {
      return meetingTime;
    }
    return LATER_STAGE_DEPARTURE;
  }

  private static @Nullable LocalTime earliestMeetingTime(List<BtRideGroup> groups) {
    return groups.stream()
        .map(BtRideGroup::meetingTime)
        .filter(Objects::nonNull)
        .min(Comparator.naturalOrder())
        .orElse(null);
  }

  private static @Nullable Float toFloat(@Nullable Double d) {
    return d == null ? null : d.floatValue();
  }

  private @Nullable String existingGroupId(String biketeamGroupId, Set<Long> liveGroupIds) {
    return liveEntityId(T_RIDE_GROUP, biketeamGroupId, liveGroupIds);
  }

  private @Nullable String existingStageId(String biketeamStageId, Set<Long> liveStageIds) {
    return liveEntityId(T_TRIP_STAGE, biketeamStageId, liveStageIds);
  }

  /**
   * The Pédalons id of an already-migrated child row, as a TSID string, or null when it must be
   * created. A mapping row is only trusted when the target still belongs to the parent — a stale one
   * would make the update call fail with {@code NotFoundException}.
   */
  private @Nullable String liveEntityId(String entityType, String biketeamId, Set<Long> liveIds) {
    Long triblyId = mapRepo.findTriblyId(entityType, biketeamId);
    return triblyId != null && liveIds.contains(triblyId) ? TsidUtils.toString(triblyId) : null;
  }

  private @Nullable String routeSlugFromBiketeamId(
      Team team, Map<String, Long> routeIds, @Nullable String biketeamMapId) {
    if (biketeamMapId == null) return null;
    Long triblyId = routeIds.get(biketeamMapId);
    if (triblyId == null) {
      triblyId = mapRepo.findTriblyId(T_ROUTE, biketeamMapId);
    }
    if (triblyId == null) return null;
    Route route = owned(routeRepository.findByIdOptional(triblyId).orElse(null), team);
    return route == null ? null : route.getSlug();
  }

  private static @Nullable String placeIdString(Map<String, Long> placeIds, @Nullable String btId) {
    if (btId == null) return null;
    Long t = placeIds.get(btId);
    return t != null ? TsidUtils.toString(t) : null;
  }

  private MediaDto emptyMedia() {
    return MediaDto.builder().build();
  }

  /**
   * Build the MediaDto for an update call. Preserves the existing entity's IMAGE assets across the
   * replay by ensuring (a) every existing IMAGE asset has a {@code ::asset{id="..."}} directive in
   * the request markdown, and (b) every existing asset is included in {@code assets.images}. Both
   * conditions are required for {@code AssetService.updateAssets} not to purge them.
   */
  private MediaDto mediaWithExisting(
      @Nullable String sourceMarkdown, @Nullable TeamEntity existing) {
    String src = sourceMarkdown == null ? "" : sourceMarkdown;
    if (existing == null) {
      return new MediaDto(src, AssetsDto.builder().build());
    }
    String mergedMarkdown = mergeAssetDirectives(src, existing.getMarkdown());
    AssetsDto existingAssets = assetService.getAssetsDto(existing);
    // Backfill: directives for image assets that pre-exist but aren't yet referenced in markdown.
    StringBuilder mdBuilder = new StringBuilder(mergedMarkdown);
    for (fr.pedalons.dto.common.asset.AssetDto img : existingAssets.images()) {
      String directive = "::asset{id=\"" + img.id() + "\"}";
      if (mdBuilder.indexOf(directive) < 0) {
        if (mdBuilder.length() > 0) {
          mdBuilder.append("\n\n");
        }
        mdBuilder.append(directive);
      }
    }
    return new MediaDto(mdBuilder.toString(), existingAssets);
  }

  private static final java.util.regex.Pattern ASSET_DIRECTIVE_RE =
      java.util.regex.Pattern.compile("::asset\\{[^}]*\\}");

  private static String mergeAssetDirectives(String src, @Nullable String existingMd) {
    if (existingMd == null || existingMd.isEmpty()) {
      return src;
    }
    StringBuilder out = new StringBuilder(src);
    java.util.regex.Matcher m = ASSET_DIRECTIVE_RE.matcher(existingMd);
    while (m.find()) {
      String directive = m.group();
      if (out.indexOf(directive) < 0) {
        if (out.length() > 0) {
          out.append("\n\n");
        }
        out.append(directive);
      }
    }
    return out.toString();
  }

  private static String slugify(String name) {
    String s =
        name.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "-").replaceAll("(^-+)|(-+$)", "");
    return s.isEmpty() ? "item" : s;
  }

  private static @Nullable String truncate(@Nullable String s, int max) {
    if (s == null) return null;
    return s.length() <= max ? s : s.substring(0, max);
  }

  /**
   * Convert biketeam plain-text descriptions to Markdown that renders the same way. Biketeam
   * treated every {@code \n} as a visible line break; in Markdown, a lone {@code \n} is collapsed.
   * We convert each isolated {@code \n} to {@code "  \n"} (two trailing spaces + LF = hard break)
   * and leave existing paragraph breaks ({@code \n\n}) untouched.
   */
  private static String biketeamToMarkdown(@Nullable String s) {
    return normalizeNewlines(s).replaceAll("(?<!\\n)\\n(?!\\n)", "  \n");
  }

  /** For source columns that already hold Markdown and need no line-break rewriting. */
  private static String normalizeNewlines(@Nullable String s) {
    if (s == null || s.isEmpty()) return "";
    return s.replace("\r\n", "\n").replace("\r", "\n");
  }
}
