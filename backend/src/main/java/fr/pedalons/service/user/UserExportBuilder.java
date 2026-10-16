package fr.pedalons.service.user;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectWriter;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.notification.NotificationSettings;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.users.export.AccountExport;
import fr.pedalons.dto.users.export.ContentExport;
import fr.pedalons.dto.users.export.ExportManifest;
import fr.pedalons.dto.users.export.FeedbackExport;
import fr.pedalons.dto.users.export.MembershipExport;
import fr.pedalons.dto.users.export.MembershipExport.MissingFile;
import fr.pedalons.dto.users.export.ModerationExport;
import fr.pedalons.dto.users.export.NotificationExport;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.ad.AdRepository;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.repository.auth.DeviceCodeRepository;
import fr.pedalons.repository.auth.PasskeyRepository;
import fr.pedalons.repository.auth.WebAuthnChallengeRepository;
import fr.pedalons.repository.calendar.CalendarTokenRepository;
import fr.pedalons.repository.comment.CommentRepository;
import fr.pedalons.repository.common.AllPublicationRepository;
import fr.pedalons.repository.feedback.FeedbackReportRepository;
import fr.pedalons.repository.gps.GpsOAuthStateRepository;
import fr.pedalons.repository.gps.GpsRouteSyncRepository;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.moderation.ContentReportRepository;
import fr.pedalons.repository.moderation.UserBlockRepository;
import fr.pedalons.repository.notification.NotificationDeliveryRepository;
import fr.pedalons.repository.notification.NotificationPreferenceRepository;
import fr.pedalons.repository.notification.NotificationRepository;
import fr.pedalons.repository.notification.NotificationSettingsRepository;
import fr.pedalons.repository.notification.NotificationTeamMuteRepository;
import fr.pedalons.repository.notification.PushDeviceRepository;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ride.RideGroupRepository;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.repository.ridetemplate.RideTemplateRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.repository.team.TeamPageRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.repository.trip.TripParticipationRepository;
import fr.pedalons.repository.trip.TripStageRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.gpx.GpxPreviewService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.BufferedOutputStream;
import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.Callable;
import java.util.stream.Collectors;
import java.util.zip.Deflater;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * Builds the ZIP for one GDPR data export.
 *
 * <p>Two invariants hold throughout, and both matter:
 *
 * <ol>
 *   <li><b>No transaction is open while bytes are written.</b> Each section loads inside its own
 *       short transaction, is drained into records, and is serialized with nothing held. A single
 *       transaction spanning the whole build would pin a JDBC connection for minutes of storage I/O.
 *   <li><b>Nothing is buffered whole.</b> Binaries stream from storage straight into the ZIP, so
 *       heap is bounded by the largest single JSON section, not by the size of the export.
 * </ol>
 */
@ApplicationScoped
public class UserExportBuilder {

  private static final Logger LOG = Logger.getLogger(UserExportBuilder.class);

  private static final String AVATAR_PATH = "files/avatar";
  private static final String ASSETS_PATH = "files/assets/";
  private static final String PREVIEWS_PATH = "files/gpx-previews/";

  @Inject ObjectMapper objectMapper;
  @Inject StorageService storageService;
  @Inject AssetService assetService;
  @Inject UserAvatarService userAvatarService;
  @Inject GpxPreviewService gpxPreviewService;

  @Inject UserRepository userRepository;
  @Inject AssetRepository assetRepository;
  @Inject UserTeamRepository userTeamRepository;
  @Inject AuthSessionRepository authSessionRepository;
  @Inject PasskeyRepository passkeyRepository;
  @Inject CalendarTokenRepository calendarTokenRepository;
  @Inject GpsServiceConnectionRepository gpsServiceConnectionRepository;

  @Inject GpsRouteSyncRepository gpsRouteSyncRepository;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject DeviceCodeRepository deviceCodeRepository;
  @Inject GpsOAuthStateRepository gpsOAuthStateRepository;
  @Inject WebAuthnChallengeRepository webAuthnChallengeRepository;
  @Inject RideParticipationRepository rideParticipationRepository;
  @Inject TripParticipationRepository tripParticipationRepository;
  @Inject TeamRepository teamRepository;
  @Inject AllPublicationRepository allPublicationRepository;
  @Inject TripStageRepository tripStageRepository;
  @Inject RouteRepository routeRepository;
  @Inject AdRepository adRepository;
  @Inject TeamPageRepository teamPageRepository;
  @Inject PlaceRepository placeRepository;
  @Inject CommentRepository commentRepository;
  @Inject RideGroupRepository rideGroupRepository;
  @Inject RideTemplateRepository rideTemplateRepository;
  @Inject GpxPreviewRepository gpxPreviewRepository;
  @Inject NotificationRepository notificationRepository;
  @Inject NotificationDeliveryRepository notificationDeliveryRepository;
  @Inject NotificationPreferenceRepository notificationPreferenceRepository;
  @Inject PushDeviceRepository pushDeviceRepository;
  @Inject NotificationSettingsRepository notificationSettingsRepository;
  @Inject NotificationTeamMuteRepository notificationTeamMuteRepository;
  @Inject UserBlockRepository userBlockRepository;
  @Inject ContentReportRepository contentReportRepository;
  @Inject FeedbackReportRepository feedbackReportRepository;

  @ConfigProperty(name = "pedalons.export.temp-dir")
  Optional<String> configuredTempDir;

  private ObjectWriter writer;

  @PostConstruct
  void init() {
    // The injected mapper carries PedalonsJacksonConfig: GeolatteGeomModule (so PostGIS geometry
    // serializes as GeoJSON for free) and NON_NULL. Pretty-printed because a human opens these.
    writer = objectMapper.writerWithDefaultPrettyPrinter();
  }

  /**
   * Writes the export to a temp file and returns its path. The caller owns the file and must delete
   * it.
   */
  public Path build(ExportJobContext ctx) throws IOException {
    Path zipFile = Files.createTempFile(tempDir(), "export-" + ctx.exportTsid() + "-", ".zip");
    List<MissingFile> missing = new ArrayList<>();
    Map<String, Integer> counts = new LinkedHashMap<>();

    try (ZipOutputStream zip =
        new ZipOutputStream(new BufferedOutputStream(Files.newOutputStream(zipFile), 64 * 1024))) {
      // JSON and GPX compress well; JPEG and FIT do not. BEST_SPEED is the right trade here.
      zip.setLevel(Deflater.BEST_SPEED);

      writeText(zip, "README.txt", readme(ctx));

      writeSection(zip, "account/profile.json", counts, () -> profile(ctx));
      writeSection(zip, "account/sessions.json", counts, () -> sessions(ctx));
      writeSection(zip, "account/passkeys.json", counts, () -> passkeys(ctx));
      writeSection(zip, "account/calendar-token.json", counts, () -> calendarToken(ctx));
      writeSection(zip, "account/gps-connections.json", counts, () -> gpsConnections(ctx));
      writeSection(zip, "account/gps-route-syncs.json", counts, () -> gpsRouteSyncs(ctx));
      writeSection(zip, "account/auth-tokens.json", counts, () -> authTokens(ctx));
      writeSection(zip, "account/device-codes.json", counts, () -> deviceCodes(ctx));
      writeSection(zip, "account/oauth-states.json", counts, () -> handshakeStates(ctx));
      writeSection(
          zip, "account/notification-preferences.json", counts, () -> notificationPreferences(ctx));
      writeSection(
          zip, "account/notification-settings.json", counts, () -> notificationSettings(ctx));
      writeSection(zip, "account/push-devices.json", counts, () -> pushDevices(ctx));
      writeSection(zip, "account/blocked-users.json", counts, () -> blockedUsers(ctx));
      writeSection(zip, "account/reports.json", counts, () -> reports(ctx));
      writeSection(zip, "account/feedback.json", counts, () -> feedback(ctx));

      writeSection(zip, "memberships/teams.json", counts, () -> memberships(ctx));
      writeSection(zip, "participations/rides.json", counts, () -> rideParticipations(ctx));
      writeSection(zip, "participations/trips.json", counts, () -> tripParticipations(ctx));

      writeSection(zip, "notifications/inbox.json", counts, () -> inbox(ctx));

      writeSection(zip, "content/teams.json", counts, () -> teams(ctx));
      writeSection(zip, "content/publications.json", counts, () -> publications(ctx));
      writeSection(zip, "content/trip-stages.json", counts, () -> tripStages(ctx));
      writeSection(zip, "content/routes.json", counts, () -> routes(ctx));
      writeSection(zip, "content/ads.json", counts, () -> ads(ctx));
      writeSection(zip, "content/team-pages.json", counts, () -> teamPages(ctx));
      writeSection(zip, "content/places.json", counts, () -> places(ctx));
      writeSection(zip, "content/comments.json", counts, () -> comments(ctx));
      writeSection(zip, "content/ride-groups.json", counts, () -> rideGroups(ctx));
      writeSection(zip, "content/ride-templates.json", counts, () -> rideTemplates(ctx));
      writeSection(zip, "content/gpx-previews.json", counts, () -> gpxPreviews(ctx));

      // Asset metadata and binary references are collected together so a row and its bytes agree on
      // the path in the ZIP.
      AssetBundle assets = inTransaction(() -> assetBundle(ctx));
      counts.put("content/assets.json", assets.metadata().size());
      writeJson(zip, "content/assets.json", assets.metadata());

      List<BinaryRef> binaries = new ArrayList<>(assets.binaries());
      binaries.addAll(inTransaction(() -> avatarRef(ctx)));
      binaries.addAll(inTransaction(() -> previewRefs(ctx)));
      for (BinaryRef ref : binaries) {
        streamInto(zip, ref, missing);
      }
      counts.put("files", binaries.size() - missing.size());

      writeJson(
          zip,
          "manifest.json",
          new ExportManifest(
              Instant.now(), ctx.exportTsid(), ctx.siteName(), ctx.userTsid(), counts, missing));
    } catch (IOException | RuntimeException e) {
      Files.deleteIfExists(zipFile);
      throw e;
    }
    return zipFile;
  }

  // ---------------------------------------------------------------- sections

  private AccountExport.Profile profile(ExportJobContext ctx) {
    return AccountExport.Profile.from(loadUser(ctx));
  }

  /** The job holds only an id; every section that needs the row re-reads it in its own transaction. */
  private User loadUser(ExportJobContext ctx) {
    return userRepository
        .findByIdOptional(ctx.userId())
        .orElseThrow(
            () -> new IllegalStateException("User vanished mid-export: " + ctx.userTsid()));
  }

  private List<AccountExport.Session> sessions(ExportJobContext ctx) {
    return authSessionRepository.findAllByUserId(ctx.userId()).stream()
        .map(AccountExport.Session::from)
        .toList();
  }

  private List<AccountExport.PasskeyEntry> passkeys(ExportJobContext ctx) {
    return passkeyRepository.findByUserId(ctx.userId()).stream()
        .map(AccountExport.PasskeyEntry::from)
        .toList();
  }

  private List<AccountExport.CalendarTokenEntry> calendarToken(ExportJobContext ctx) {
    return calendarTokenRepository.findByUserId(ctx.userId()).stream()
        .map(AccountExport.CalendarTokenEntry::from)
        .toList();
  }

  private List<AccountExport.GpsConnection> gpsConnections(ExportJobContext ctx) {
    return gpsServiceConnectionRepository.findByUser(ctx.userId()).stream()
        .map(AccountExport.GpsConnection::from)
        .toList();
  }

  private List<AccountExport.GpsRouteSyncEntry> gpsRouteSyncs(ExportJobContext ctx) {
    return gpsRouteSyncRepository.findByUser(ctx.domainId(), ctx.userId()).stream()
        .map(AccountExport.GpsRouteSyncEntry::from)
        .toList();
  }

  private List<AccountExport.AuthTokenEntry> authTokens(ExportJobContext ctx) {
    return authTokenRepository.findByUser(ctx.domainId(), ctx.userId()).stream()
        .map(AccountExport.AuthTokenEntry::from)
        .toList();
  }

  private List<AccountExport.DeviceCodeEntry> deviceCodes(ExportJobContext ctx) {
    return deviceCodeRepository.findByUser(ctx.domainId(), ctx.userId()).stream()
        .map(AccountExport.DeviceCodeEntry::from)
        .toList();
  }

  private List<AccountExport.HandshakeState> handshakeStates(ExportJobContext ctx) {
    List<AccountExport.HandshakeState> states = new ArrayList<>();
    gpsOAuthStateRepository.findByUser(ctx.domainId(), ctx.userId()).stream()
        .map(AccountExport.HandshakeState::from)
        .forEach(states::add);
    webAuthnChallengeRepository.findByUserId(ctx.userId()).stream()
        .map(AccountExport.HandshakeState::from)
        .forEach(states::add);
    return states;
  }

  private List<NotificationExport.Preference> notificationPreferences(ExportJobContext ctx) {
    return notificationPreferenceRepository.findByUser(ctx.userId()).stream()
        .map(NotificationExport.Preference::from)
        .toList();
  }

  private NotificationExport.Settings notificationSettings(ExportJobContext ctx) {
    return new NotificationExport.Settings(
        notificationSettingsRepository
            .findByUser(ctx.userId())
            .map(NotificationSettings::isEmailDigest)
            .orElse(false),
        notificationTeamMuteRepository.findByUser(ctx.userId()).stream()
            .map(NotificationExport.MutedTeam::from)
            .toList());
  }

  private List<NotificationExport.PushDeviceEntry> pushDevices(ExportJobContext ctx) {
    return pushDeviceRepository.findByUser(ctx.userId()).stream()
        .map(NotificationExport.PushDeviceEntry::from)
        .toList();
  }

  private List<ModerationExport.BlockEntry> blockedUsers(ExportJobContext ctx) {
    return userBlockRepository.findByBlocker(ctx.userId()).stream()
        .map(ModerationExport.BlockEntry::from)
        .toList();
  }

  private List<ModerationExport.ReportEntry> reports(ExportJobContext ctx) {
    return contentReportRepository.findByReporter(ctx.domainId(), ctx.userId()).stream()
        .map(ModerationExport.ReportEntry::from)
        .toList();
  }

  private List<FeedbackExport> feedback(ExportJobContext ctx) {
    return feedbackReportRepository.findByUser(ctx.domainId(), ctx.userId()).stream()
        .map(FeedbackExport::from)
        .toList();
  }

  /** Two queries whatever the size of the inbox: the entries, then all their deliveries. */
  private List<NotificationExport.InboxEntry> inbox(ExportJobContext ctx) {
    Map<Long, List<NotificationExport.Delivery>> deliveries =
        notificationDeliveryRepository.findByRecipient(ctx.userId(), ctx.domainId()).stream()
            .collect(
                Collectors.groupingBy(
                    d -> d.getNotification().getId(),
                    Collectors.mapping(NotificationExport.Delivery::from, Collectors.toList())));
    return notificationRepository.findAllByRecipient(ctx.userId(), ctx.domainId()).stream()
        .map(
            n ->
                NotificationExport.InboxEntry.from(
                    n, deliveries.getOrDefault(n.getId(), List.of())))
        .toList();
  }

  private List<MembershipExport.Membership> memberships(ExportJobContext ctx) {
    return userTeamRepository.findByUserId(ctx.userId()).stream()
        .filter(ut -> ut.getTeam().getDomain().getId().equals(ctx.domainId()))
        .map(MembershipExport.Membership::from)
        .toList();
  }

  private List<MembershipExport.RideParticipationEntry> rideParticipations(ExportJobContext ctx) {
    return rideParticipationRepository.findByUser(ctx.domainId(), ctx.userId()).stream()
        .map(MembershipExport.RideParticipationEntry::from)
        .toList();
  }

  private List<MembershipExport.TripParticipationEntry> tripParticipations(ExportJobContext ctx) {
    return tripParticipationRepository.findByUser(ctx.domainId(), ctx.userId()).stream()
        .map(MembershipExport.TripParticipationEntry::from)
        .toList();
  }

  private List<ContentExport.TeamEntry> teams(ExportJobContext ctx) {
    return teamRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.TeamEntry::from)
        .toList();
  }

  private List<ContentExport.PublicationEntry> publications(ExportJobContext ctx) {
    return allPublicationRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.PublicationEntry::from)
        .toList();
  }

  private List<ContentExport.TripStageEntry> tripStages(ExportJobContext ctx) {
    return tripStageRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.TripStageEntry::from)
        .toList();
  }

  private List<ContentExport.RouteEntry> routes(ExportJobContext ctx) {
    return routeRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.RouteEntry::from)
        .toList();
  }

  private List<ContentExport.AdEntry> ads(ExportJobContext ctx) {
    return adRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.AdEntry::from)
        .toList();
  }

  private List<ContentExport.TeamPageEntry> teamPages(ExportJobContext ctx) {
    return teamPageRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.TeamPageEntry::from)
        .toList();
  }

  private List<ContentExport.PlaceEntry> places(ExportJobContext ctx) {
    return placeRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.PlaceEntry::from)
        .toList();
  }

  private List<ContentExport.CommentEntry> comments(ExportJobContext ctx) {
    return commentRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.CommentEntry::from)
        .toList();
  }

  private List<ContentExport.RideGroupEntry> rideGroups(ExportJobContext ctx) {
    return rideGroupRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.RideGroupEntry::from)
        .toList();
  }

  private List<ContentExport.RideTemplateEntry> rideTemplates(ExportJobContext ctx) {
    return rideTemplateRepository.findByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.RideTemplateEntry::from)
        .toList();
  }

  private List<ContentExport.GpxPreviewEntry> gpxPreviews(ExportJobContext ctx) {
    return gpxPreviewRepository.findAllByCreator(ctx.domainId(), ctx.userId()).stream()
        .map(ContentExport.GpxPreviewEntry::from)
        .toList();
  }

  // ---------------------------------------------------------------- binaries

  /** Asset rows and their storage keys, resolved together so metadata and bytes cannot disagree. */
  private record AssetBundle(List<ContentExport.AssetEntry> metadata, List<BinaryRef> binaries) {}

  /** One file to copy from storage into the ZIP. */
  private record BinaryRef(String pathInZip, String storageKey) {}

  private AssetBundle assetBundle(ExportJobContext ctx) {
    List<Asset> assets = assetRepository.findByCreator(ctx.domainId(), ctx.userId());
    List<ContentExport.AssetEntry> metadata = new ArrayList<>(assets.size());
    List<BinaryRef> binaries = new ArrayList<>(assets.size());
    for (Asset asset : assets) {
      // Namespaced by asset id: two uploads may share a file name, and route GPX/FIT all arrive as
      // "original.gpx" / "route.fit".
      String path =
          ASSETS_PATH + TsidUtils.toString(asset.getId()) + "/" + safeName(asset.getFileName());
      metadata.add(ContentExport.AssetEntry.from(asset, path));
      binaries.add(
          new BinaryRef(path, assetService.getAssetKey(asset.getTeam(), asset.getFileId())));
    }
    return new AssetBundle(metadata, binaries);
  }

  private List<BinaryRef> avatarRef(ExportJobContext ctx) {
    String key = userAvatarService.getAvatarKeyFromUrl(loadUser(ctx).getAvatarUrl());
    // Avatars are stored as the resized 256x256 JPEG; the original upload is discarded at upload
    // time, so this is the only copy that exists.
    return key == null ? List.of() : List.of(new BinaryRef(AVATAR_PATH + ".jpg", key));
  }

  private List<BinaryRef> previewRefs(ExportJobContext ctx) {
    List<BinaryRef> refs = new ArrayList<>();
    for (GpxPreview preview : gpxPreviewRepository.findAllByCreator(ctx.domainId(), ctx.userId())) {
      String dir = PREVIEWS_PATH + preview.getPublicId() + "/";
      gpxPreviewService
          .exportKeys(preview)
          .forEach((fileName, key) -> refs.add(new BinaryRef(dir + fileName, key)));
    }
    return refs;
  }

  /**
   * Copies one storage object into the ZIP. A missing object is recorded and skipped, never fatal:
   * one absent file must not cost the user the whole export, and {@code manifest.json} says which
   * ones went missing so an incomplete export never looks complete.
   */
  private void streamInto(ZipOutputStream zip, BinaryRef ref, List<MissingFile> missing)
      throws IOException {
    zip.putNextEntry(new ZipEntry(ref.pathInZip()));
    try (InputStream in = storageService.retrieve(ref.storageKey())) {
      in.transferTo(zip);
    } catch (RuntimeException e) {
      LOG.warnf(e, "Export: storage object missing for %s", ref.storageKey());
      missing.add(new MissingFile(ref.pathInZip(), e.getClass().getSimpleName()));
    } finally {
      zip.closeEntry();
    }
  }

  // ---------------------------------------------------------------- plumbing

  private <T> void writeSection(
      ZipOutputStream zip, String path, Map<String, Integer> counts, Callable<T> loader)
      throws IOException {
    T data = inTransaction(loader);
    counts.put(path, data instanceof List<?> list ? list.size() : 1);
    writeJson(zip, path, data);
  }

  /**
   * Runs one loader in its own short transaction. {@code requiringNew} rather than
   * {@code @Transactional} on the method: this class is called from a scheduler with no transaction
   * of its own, and a {@code this.}-qualified call would bypass the CDI interceptor anyway.
   */
  private <T> T inTransaction(Callable<T> loader) {
    return QuarkusTransaction.requiringNew().call(loader);
  }

  private void writeJson(ZipOutputStream zip, String path, Object data) throws IOException {
    zip.putNextEntry(new ZipEntry(path));
    writer.writeValue(new ShieldedOutputStream(zip), data);
    zip.closeEntry();
  }

  private void writeText(ZipOutputStream zip, String path, String text) throws IOException {
    zip.putNextEntry(new ZipEntry(path));
    zip.write(text.getBytes(StandardCharsets.UTF_8));
    zip.closeEntry();
  }

  /**
   * Keeps Jackson from closing the ZIP.
   *
   * <p>{@code JsonGenerator.Feature.AUTO_CLOSE_TARGET} is on by default, so the first {@code
   * writeValue} would close the whole {@link ZipOutputStream} and every later entry would throw.
   */
  private static final class ShieldedOutputStream extends FilterOutputStream {

    ShieldedOutputStream(OutputStream out) {
      super(out);
    }

    /** FilterOutputStream's default delegates byte-at-a-time — pathologically slow. */
    @Override
    public void write(byte[] b, int off, int len) throws IOException {
      out.write(b, off, len);
    }

    @Override
    public void close() throws IOException {
      flush();
    }
  }

  private Path tempDir() throws IOException {
    Path dir =
        configuredTempDir
            .map(Path::of)
            .orElseGet(() -> Path.of(System.getProperty("java.io.tmpdir"), "pedalons-exports"));
    Files.createDirectories(dir);
    return dir;
  }

  private static String safeName(String fileName) {
    String base = fileName.replaceAll("[^a-zA-Z0-9-_. ]", "_").strip();
    return base.isEmpty() ? "file" : base;
  }

  private String readme(ExportJobContext ctx) {
    return """
    Export de vos données personnelles — %s
    Généré le %s pour %s.

    CONTENU

      account/          Votre compte : profil, sessions, clés d'accès (passkeys),
                        connexions GPS et réseaux sociaux, parcours envoyés à vos
                        services GPS (automatiquement ou à la main) et leur identifiant
                        chez ces services, jetons d'authentification,
                        choix de notifications (dont le résumé quotidien et les équipes
                        dont vous avez coupé les annonces), appareils inscrits aux
                        notifications push, membres que vous avez bloqués et
                        signalements que vous avez faits.
      memberships/      Les équipes dont vous êtes membre.
      participations/   Les sorties et voyages auxquels vous vous êtes inscrit.
      notifications/    Les notifications reçues ces derniers mois, et pour chacune les
                        envois par e-mail ou push qu'elle a donnés.
      content/          Ce que vous avez publié : sorties, articles, voyages, parcours,
                        annonces, pages, lieux, commentaires, modèles de sortie.
      files/            Vos fichiers : photo de profil, images et documents envoyés,
                        fichiers GPX et FIT de vos parcours.
      manifest.json     Le décompte de chaque section, et la liste des fichiers
                        introuvables au moment de la génération (normalement vide).

    CE QUI A ÉTÉ VOLONTAIREMENT EXCLU

    Les données d'identification ne sont pas exportées, car ce fichier peut être copié,
    transféré ou stocké sans protection. Sont donc absents :

      - le hachage de votre mot de passe ;
      - les jetons de session (refresh tokens) et leurs empreintes ;
      - le matériel cryptographique de vos passkeys (identifiant brut et clé publique) ;
      - le jeton de votre calendrier ICS (récupérable à tout moment depuis l'application) ;
      - les jetons d'accès et de rafraîchissement de vos connexions GPS (Garmin, Wahoo,
        Hammerhead…), qui donneraient accès à ces comptes tiers ;
      - les valeurs à usage unique des échanges OAuth et WebAuthn en cours ;
      - le jeton push de chacun de vos appareils, qui est l'adresse où lui envoyer
        une notification.

    Les métadonnées de chacun de ces éléments (dates, appareils, services concernés) sont
    bien présentes : seule la valeur secrète est retirée.

    À PROPOS DES PARCOURS

    content/routes.json décrit chaque parcours et ses points d'intérêt, avec un résumé par
    trace (distance, dénivelé, nombre de points). Le tracé complet n'y est pas recopié : il
    se trouve déjà, à l'identique, dans les fichiers GPX sous files/.

    Les fichiers JSON sont encodés en UTF-8. Les dates sont en UTC, au format ISO 8601.
    Les données géographiques sont au format GeoJSON (longitude, latitude).
    """
        .formatted(ctx.siteName(), Instant.now(), ctx.email());
  }
}
