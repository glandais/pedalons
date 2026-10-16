package fr.pedalons.service.config;

import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.config.AnalyticsConfigDto;
import fr.pedalons.dto.config.ConfigDto;
import fr.pedalons.dto.config.MapCenterDto;
import fr.pedalons.dto.config.MapTerrainDto;
import fr.pedalons.dto.config.WebPushConfigDto;
import fr.pedalons.infrastructure.push.FcmClient;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.ResolvedSite;
import fr.pedalons.service.security.annotation.Public;
import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.Optional;
import java.util.regex.Pattern;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class ConfigService {

  /** Roughly a département / county — the useful scale for a site rooted on one team. */
  private static final double TEAM_CENTER_ZOOM = 9;

  @Inject DomainResolver domainResolver;

  @Inject TeamRepository teamRepository;

  @Inject MapConfig mapConfig;

  @Inject MapStyleService mapStyleService;

  @Inject FcmClient fcm;

  /** The Firebase web app's public settings: all four, or no web push. */
  @ConfigProperty(name = "pedalons.push.web.api-key")
  Optional<String> webApiKey;

  @ConfigProperty(name = "pedalons.push.web.app-id")
  Optional<String> webAppId;

  @ConfigProperty(name = "pedalons.push.web.messaging-sender-id")
  Optional<String> webMessagingSenderId;

  @ConfigProperty(name = "pedalons.push.web.vapid-key")
  Optional<String> webVapidKey;

  /**
   * Oldest mobile build this server still serves, blank when no floor is enforced.
   *
   * <p>Semantically a version rather than a map setting, but it rides on {@code ConfigDto} because
   * that is the one document the app reads at startup (D6).
   *
   * <p>{@code Optional} rather than {@code defaultValue = ""}: the property is declared as {@code
   * ${MIN_SUPPORTED_APP_VERSION:}}, so with no floor configured it resolves to the empty string —
   * which SmallRye hands to the converter as {@code null} and then rejects on a bare {@code String}
   * injection point (SRCFG00040), failing startup.
   */
  @ConfigProperty(name = "pedalons.mobile.min-supported-app-version")
  Optional<String> minSupportedAppVersion;

  /**
   * Same-origin path of the audience counter, blank or absent when the deployment measures nothing
   * (docs/LEDGER_*.md API-117). {@code Optional} for the same reason as {@link
   * #minSupportedAppVersion}: the property resolves to the empty string when unset.
   */
  @ConfigProperty(name = "pedalons.analytics.count-path")
  Optional<String> analyticsCountPath;

  /**
   * Whether the automatic route sync runs on this deployment (docs/LEDGER_*.md API-120): the same
   * property that starts the planner and the worker ({@code GpsRouteSyncPlanner#isEnabled}).
   */
  @ConfigProperty(name = "pedalons.gps-sync.enabled", defaultValue = "false")
  boolean gpsAutoSyncEnabled;

  @Public
  public ConfigDto getConfig() {
    ResolvedSite site = domainResolver.getResolvedSite();
    // Resolved once and read twice: the site's team gives both the pinned slug and the map centre,
    // so the cartography fields cost no query the endpoint was not already paying.
    Optional<Team> siteTeam = siteTeam(site);
    return new ConfigDto(
        site.effectiveHost(),
        site.effectiveName(),
        site.singleTeam(),
        // Read off the parent domain, not the alias: the flag governs the GPX tools, which are
        // team-independent and so belong to whoever owns the users.
        site.domain().isEnableGpxPlanner(),
        siteTeam.map(Team::getSlug).orElse(null),
        mapStyleService.styles(site.effectiveBaseUrl()),
        mapConfig.tileServerBaseUrl(),
        defaultCenter(siteTeam.map(Team::getGeometry).orElse(null)),
        terrain(),
        minSupportedAppVersion.filter(version -> !version.isBlank()).orElse(null),
        webPush(),
        analytics(analyticsCountPath),
        gpsAutoSyncEnabled);
  }

  /**
   * A path of unreserved characters, starting with one slash and never two: nothing a browser could
   * resolve to another host.
   */
  static final Pattern SAME_ORIGIN_PATH = Pattern.compile("/[A-Za-z0-9._~-][A-Za-z0-9._~/-]*");

  /**
   * The audience counter, or null when the deployment configures none.
   *
   * <p>Only a path on the site's own origin is handed out: the counter is served beside the site on
   * every domain, and a full URL — or a protocol-relative {@code //host} — would send every page
   * view to whatever host it names. Browsers also read a backslash as a slash and drop tabs and
   * newlines inside a URL, so {@code /\host} and {@code /<TAB>/host} leave the origin too: the
   * path is checked against a whitelist ({@link #SAME_ORIGIN_PATH}), not against a list of escapes.
   * A value of another shape is a misconfiguration, so the counter stays off rather than counting
   * somewhere unexpected.
   */
  static @Nullable AnalyticsConfigDto analytics(Optional<String> countPath) {
    if (isBlank(countPath)) {
      return null;
    }
    String path = countPath.get().trim();
    if (!SAME_ORIGIN_PATH.matcher(path).matches()) {
      Log.warnf("pedalons.analytics.count-path is not a same-origin path, counter off: %s", path);
      return null;
    }
    return new AnalyticsConfigDto(path);
  }

  /**
   * The browser's side of the push channel, or null when a browser could not receive anything: the
   * channel itself is off (no service account), or the web app is not configured. Handing the site a
   * configuration the server cannot send to would register devices that never get a message.
   */
  private @Nullable WebPushConfigDto webPush() {
    String projectId = fcm.projectId();
    if (projectId == null
        || isBlank(webApiKey)
        || isBlank(webAppId)
        || isBlank(webMessagingSenderId)
        || isBlank(webVapidKey)) {
      return null;
    }
    return new WebPushConfigDto(
        webApiKey.get().trim(),
        projectId,
        webAppId.get().trim(),
        webMessagingSenderId.get().trim(),
        webVapidKey.get().trim());
  }

  private static boolean isBlank(Optional<String> value) {
    return value.isEmpty() || value.get().isBlank();
  }

  /**
   * The elevation source, or null when the deployment configures none.
   *
   * <p>A blank URL is the same as no URL: it is what an unset {@code MAP_TERRAIN_URL} resolves to,
   * and a client handed an empty string would request the site's own root as a TileJSON.
   */
  private @Nullable MapTerrainDto terrain() {
    MapConfig.Terrain terrain = mapConfig.terrain();
    return terrain
        .url()
        .filter(url -> !url.isBlank())
        .map(url -> new MapTerrainDto(url, terrain.maxZoom()))
        .orElse(null);
  }

  /**
   * The team's own location when the site roots on a single team, the deployment default otherwise.
   *
   * <p>This is the only genuinely per-tenant map setting, and it is derived from a column that
   * already exists ({@code Team.geometry}), so no migration is involved. A per-<em>domain</em>
   * centre — for a multi-team domain covering one region — would need a Flyway migration adding
   * columns to {@code domains}; that has deliberately not been done here.
   */
  private MapCenterDto defaultCenter(@Nullable Point<G2D> teamGeometry) {
    MapConfig.DefaultCenter fallback = mapConfig.defaultCenter();
    if (teamGeometry == null || teamGeometry.isEmpty()) {
      return new MapCenterDto(fallback.lat(), fallback.lon(), fallback.zoom());
    }
    G2D position = teamGeometry.getPosition();
    // A site that knows its team knows its region: open closer than the country-wide fallback.
    return new MapCenterDto(position.getLat(), position.getLon(), TEAM_CENTER_ZOOM);
  }

  private Optional<Team> siteTeam(ResolvedSite site) {
    Long pinnedTeamId = site.pinnedTeamId();
    if (pinnedTeamId != null) {
      // Pinned alias: guard against a soft-deleted pinned team, fall back to no pinning.
      return teamRepository.findActiveById(pinnedTeamId);
    }
    if (site.singleTeam()) {
      // Native single-team domain: no explicit pin, but the site still roots on its one team, so
      // expose its slug too. The frontend treats both modes identically (clean team-rooted URLs).
      return teamRepository.findFirstByDomain(site.domain().getId());
    }
    return Optional.empty();
  }
}
