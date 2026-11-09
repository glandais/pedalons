package fr.pedalons.service.migration.live;

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
import fr.pedalons.service.migration.BiketeamSource;
import fr.pedalons.service.migration.SourceFile;
import fr.pedalons.service.migration.SourceFileUnavailableException;
import fr.pedalons.service.migration.live.snapshot.BiketeamFileFetcher;
import fr.pedalons.service.migration.live.snapshot.BiketeamSnapshot;
import fr.pedalons.service.migration.live.snapshot.BiketeamSnapshot.FileRef;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.DateTimeException;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Stream;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The live source: a biketeam export snapshot, plus its files fetched on demand.
 *
 * <p>Translates the snapshot's JSON shape into {@link fr.pedalons.service.migration.BiketeamModel}
 * — {@code deleted} → {@code deletion}, {@code startPoint.lat} → {@code startPointLat}… — so the
 * mapping reads it exactly as it read the dump. Nested lists keep the order biketeam exported them
 * in, which is its display order (§6.3 of the plan).
 *
 * <p>Files are downloaded only when {@link SourceFile#open()} is called, into this source's own
 * temporary directory. Each is used once, right after it is opened — a GPX by the route pipeline, an
 * image by the asset upload — so only the most recent download is kept: a team of 2 600 routes
 * would otherwise pile a gigabyte of GPX on disk. {@link #close()} removes the directory.
 */
public final class SnapshotBiketeamSource implements BiketeamSource {

  private static final Logger LOG = Logger.getLogger(SnapshotBiketeamSource.class);

  /** Biketeam's historical zone, when a team's own is missing or unreadable. */
  static final ZoneId FALLBACK_ZONE = ZoneId.of("Europe/Paris");

  private final BiketeamSnapshot snapshot;
  private final BiketeamSnapshot.Team team;
  private final BiketeamFileFetcher fetcher;
  private final Path tempDir;
  private final ZoneId zone;
  private final String filePathPrefix;

  private final Map<String, FileRef> gpxByMap = new HashMap<>();
  private final Map<String, FileRef> rideImages = new HashMap<>();
  private final Map<String, FileRef> tripImages = new HashMap<>();
  private final Map<String, FileRef> publicationImages = new HashMap<>();

  private int downloads;
  private @Nullable Path lastDownload;

  /**
   * @param tempDir where downloads go; created if missing, deleted on {@link #close()}
   */
  public SnapshotBiketeamSource(
      BiketeamSnapshot snapshot, BiketeamFileFetcher fetcher, Path tempDir) {
    this.snapshot = snapshot;
    this.team = Objects.requireNonNull(snapshot.team(), "snapshot without a team");
    this.fetcher = fetcher;
    this.tempDir = tempDir;
    this.zone = zoneOf(team);
    this.filePathPrefix = "/internal/pedalons/teams/" + team.id() + "/files/";
    snapshot.mapsOrEmpty().stream()
        .filter(m -> m.gpx() != null && !m.deleted())
        .forEach(m -> gpxByMap.put(m.id(), m.gpx()));
    snapshot.ridesOrEmpty().stream()
        .filter(r -> r.image() != null && !r.deleted())
        .forEach(r -> rideImages.put(r.id(), r.image()));
    snapshot.tripsOrEmpty().stream()
        .filter(t -> t.image() != null && !t.deleted())
        .forEach(t -> tripImages.put(t.id(), t.image()));
    snapshot.publicationsOrEmpty().stream()
        .filter(p -> p.image() != null && !p.deleted())
        .forEach(p -> publicationImages.put(p.id(), p.image()));
  }

  public BiketeamSnapshot snapshot() {
    return snapshot;
  }

  private static ZoneId zoneOf(BiketeamSnapshot.Team team) {
    String tz = team.timezone();
    if (tz == null || tz.isBlank()) {
      LOG.warnf(
          "Biketeam team '%s' has no timezone — reading its dates in %s", team.id(), FALLBACK_ZONE);
      return FALLBACK_ZONE;
    }
    try {
      return ZoneId.of(tz.trim());
    } catch (DateTimeException e) {
      LOG.warnf(
          "Biketeam team '%s' has an unreadable timezone '%s' — reading its dates in %s",
          team.id(), tz, FALLBACK_ZONE);
      return FALLBACK_ZONE;
    }
  }

  @Override
  public BtTeam team() {
    return new BtTeam(
        team.id(),
        team.name(),
        team.city(),
        team.country(),
        team.createdAt(),
        team.visibility(),
        false);
  }

  @Override
  public @Nullable BtTeamDescription teamDescription() {
    BiketeamSnapshot.Description d = team.description();
    if (d == null) {
      return null;
    }
    return new BtTeamDescription(
        d.description(),
        d.addressStreetLine(),
        d.addressPostalCode(),
        d.addressPostalCity(),
        d.phoneNumber(),
        d.email(),
        d.facebook(),
        d.twitter(),
        d.instagram(),
        d.other());
  }

  @Override
  public @Nullable String teamMarkdownPage() {
    return team.markdownPage();
  }

  @Override
  public ZoneId zone() {
    return zone;
  }

  @Override
  public List<BtPlace> places() {
    return snapshot.placesOrEmpty().stream()
        .map(p ->
            new BtPlace(
                p.id(),
                team.id(),
                p.name(),
                p.address(),
                p.link(),
                p.lat(),
                p.lng(),
                p.startPlace(),
                p.endPlace()))
        .toList();
  }

  @Override
  public List<BtMap> maps() {
    return snapshot.mapsOrEmpty().stream()
        .map(m ->
            new BtMap(
                m.id(),
                team.id(),
                m.name(),
                m.permalink(),
                m.length(),
                m.type(),
                m.positiveElevation(),
                m.negativeElevation(),
                m.postedAt(),
                m.startPoint() == null ? null : m.startPoint().lat(),
                m.startPoint() == null ? null : m.startPoint().lng(),
                m.endPoint() == null ? null : m.endPoint().lat(),
                m.endPoint() == null ? null : m.endPoint().lng(),
                m.windDirection(),
                m.deleted(),
                m.tags() == null ? List.of() : m.tags()))
        .toList();
  }

  @Override
  public List<BtRideTemplate> rideTemplates() {
    return snapshot.rideTemplatesOrEmpty().stream()
        .map(t ->
            new BtRideTemplate(
                t.id(),
                team.id(),
                t.name(),
                t.description(),
                t.type(),
                t.increment(),
                t.startPlaceId(),
                t.endPlaceId()))
        .toList();
  }

  @Override
  public List<BtRideGroupTemplate> rideGroupTemplates() {
    List<BtRideGroupTemplate> out = new ArrayList<>();
    for (BiketeamSnapshot.RideTemplate t : snapshot.rideTemplatesOrEmpty()) {
      for (BiketeamSnapshot.RideTemplateGroup g : orEmpty(t.groups())) {
        out.add(
            new BtRideGroupTemplate(g.id(), t.id(), g.name(), g.averageSpeed(), g.meetingTime()));
      }
    }
    return out;
  }

  @Override
  public List<BtPublication> publications() {
    return snapshot.publicationsOrEmpty().stream()
        .map(p ->
            new BtPublication(
                p.id(),
                team.id(),
                p.publishedStatus(),
                p.title(),
                p.publishedAt(),
                p.content(),
                p.image() != null,
                p.deleted()))
        .toList();
  }

  @Override
  public List<BtRide> rides() {
    return snapshot.ridesOrEmpty().stream()
        .map(r ->
            new BtRide(
                r.id(),
                team.id(),
                r.permalink(),
                r.date(),
                r.title(),
                r.description(),
                r.type(),
                r.publishedStatus(),
                r.publishedAt(),
                r.startPlaceId(),
                r.endPlaceId(),
                r.listedInFeed(),
                r.deleted()))
        .toList();
  }

  @Override
  public List<BtRideGroup> rideGroups() {
    List<BtRideGroup> out = new ArrayList<>();
    for (BiketeamSnapshot.Ride r : snapshot.ridesOrEmpty()) {
      for (BiketeamSnapshot.RideGroup g : orEmpty(r.groups())) {
        out.add(
            new BtRideGroup(
                g.id(), r.id(), g.name(), g.averageSpeed(), g.meetingTime(), g.mapId()));
      }
    }
    return out;
  }

  @Override
  public List<BtTrip> trips() {
    return snapshot.tripsOrEmpty().stream()
        .map(t ->
            new BtTrip(
                t.id(),
                team.id(),
                t.permalink(),
                t.startDate(),
                t.endDate(),
                t.meetingTime(),
                t.type(),
                t.publishedStatus(),
                t.publishedAt(),
                t.title(),
                t.description(),
                t.startPlaceId(),
                t.endPlaceId(),
                t.markdownPage(),
                t.listedInFeed(),
                t.deleted()))
        .toList();
  }

  @Override
  public List<BtTripStage> tripStages() {
    List<BtTripStage> out = new ArrayList<>();
    for (BiketeamSnapshot.Trip t : snapshot.tripsOrEmpty()) {
      for (BiketeamSnapshot.TripStage s : orEmpty(t.stages())) {
        out.add(new BtTripStage(s.id(), t.id(), s.date(), s.name(), s.mapId(), s.alternative()));
      }
    }
    return out;
  }

  @Override
  public @Nullable SourceFile gpx(String mapId) {
    FileRef ref = gpxByMap.get(mapId);
    return ref == null ? null : new RemoteFile(ref);
  }

  @Override
  public @Nullable SourceFile image(ImageKind kind, String entityId) {
    Map<String, FileRef> refs =
        switch (kind) {
          case RIDE -> rideImages;
          case TRIP -> tripImages;
          case PUBLICATION -> publicationImages;
        };
    FileRef ref = refs.get(entityId);
    return ref == null ? null : new RemoteFile(ref);
  }

  @Override
  public @Nullable SourceFile logo() {
    FileRef ref = team.logo();
    return ref == null ? null : new RemoteFile(ref);
  }

  @Override
  public void close() {
    if (!Files.exists(tempDir)) {
      return;
    }
    try (Stream<Path> walk = Files.walk(tempDir)) {
      walk.sorted(Comparator.reverseOrder()).forEach(SnapshotBiketeamSource::deleteQuietly);
    } catch (IOException e) {
      LOG.warnf(e, "Could not clean %s", tempDir);
    }
  }

  private static <T> List<T> orEmpty(@Nullable List<T> list) {
    return list == null ? List.of() : list;
  }

  private static void deleteQuietly(@Nullable Path path) {
    if (path == null) {
      return;
    }
    try {
      Files.deleteIfExists(path);
    } catch (IOException e) {
      LOG.debugf("Could not delete %s: %s", path, e.getMessage());
    }
  }

  /**
   * Checks a {@code FileRef.path} before anything is fetched from it: it must name this team's file
   * endpoint, and nothing that could walk out of it. Biketeam resolves the file itself from the
   * path's segments; this only stops a malformed snapshot from pointing Pédalons elsewhere.
   */
  boolean isAcceptablePath(String path) {
    return path.startsWith(filePathPrefix)
        && !path.contains("..")
        && !path.contains("?")
        && !path.contains("#")
        && !path.contains("\\")
        && !path.contains("//");
  }

  /** A file of the export, fetched on first {@link #open()}. */
  private final class RemoteFile implements SourceFile {

    private final FileRef ref;
    private @Nullable Path local;

    RemoteFile(FileRef ref) {
      this.ref = ref;
    }

    @Override
    public String fileName() {
      return ref.fileName();
    }

    @Override
    public @Nullable String fingerprint() {
      String md5 = md5();
      return md5 == null ? null : ref.size() + ":" + md5;
    }

    @Override
    public @Nullable String md5() {
      String md5 = ref.md5();
      return md5 == null || md5.isBlank() ? null : md5.trim().toLowerCase(Locale.ROOT);
    }

    @Override
    public Path open() throws IOException {
      if (local != null && Files.exists(local)) {
        return local;
      }
      if (!isAcceptablePath(ref.path())) {
        throw new SourceFileUnavailableException("Refusing file path " + ref.path());
      }
      // Only the last download is kept; see the class javadoc.
      deleteQuietly(lastDownload);
      lastDownload = null;
      Files.createDirectories(tempDir);
      Path target = tempDir.resolve((downloads++) + "-" + safeName(ref.fileName()));
      fetcher.download(ref.path(), target);
      verify(target);
      local = target;
      lastDownload = target;
      return target;
    }

    /** The bytes must be the ones the snapshot described, or the fingerprint would lie. */
    private void verify(Path file) throws IOException {
      long size = Files.size(file);
      if (size != ref.size()) {
        deleteQuietly(file);
        throw new SourceFileUnavailableException(
            "Size mismatch for " + ref.path() + ": " + size + " bytes, expected " + ref.size());
      }
      String expected = md5();
      if (expected == null) {
        return;
      }
      String actual = md5Of(file);
      if (!expected.equals(actual)) {
        deleteQuietly(file);
        throw new SourceFileUnavailableException("MD5 mismatch for " + ref.path());
      }
    }
  }

  private static String safeName(String fileName) {
    String name = fileName.replaceAll("[^A-Za-z0-9._-]", "_");
    if (name.isBlank() || name.startsWith(".")) {
      name = "file" + name;
    }
    return name.length() <= 120 ? name : name.substring(name.length() - 120);
  }

  static String md5Of(Path file) throws IOException {
    try (InputStream in = Files.newInputStream(file)) {
      MessageDigest md = MessageDigest.getInstance("MD5");
      byte[] buffer = new byte[64 * 1024];
      int read;
      while ((read = in.read(buffer)) != -1) {
        md.update(buffer, 0, read);
      }
      return HexFormat.of().formatHex(md.digest());
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("MD5 unavailable", e);
    }
  }
}
