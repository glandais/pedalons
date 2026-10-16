package fr.pedalons.service.user;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.ad.AdContact;
import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.domain.auth.DeviceCode;
import fr.pedalons.domain.auth.Passkey;
import fr.pedalons.domain.auth.WebAuthnChallenge;
import fr.pedalons.domain.calendar.CalendarToken;
import fr.pedalons.domain.feedback.ErrorOccurrence;
import fr.pedalons.domain.feedback.FeedbackReport;
import fr.pedalons.domain.gps.GpsOAuthState;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.user.User;
import fr.pedalons.repository.comment.CommentRepository;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.repository.moderation.ContentReportRepository;
import fr.pedalons.repository.moderation.UserBlockRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.gps.sync.GpsRouteSyncService;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.notification.NotificationService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.jboss.logging.Logger;

/**
 * Erases the personal data of a deleted account, for good.
 *
 * <p>The {@code users} row itself stays: some thirty foreign keys point at it, from the rides,
 * routes and posts the member created for their team. Those belong to the team and outlive the
 * member, so the row is <em>anonymized</em> instead — no email, name, avatar, credential or
 * preference left, nothing that identifies the person. What is personal and not the team's goes
 * outright:
 *
 * <ul>
 *   <li>sessions, credentials, social and GPS links, calendar token — everything that signs in or
 *       reaches a third party;
 *   <li>team memberships, and registrations to rides and trips still to come (past ones stay: they
 *       are the history of the ride, and the participant lists already hide deleted accounts);
 *   <li>ads, which are personal listings: soft-deleted, their text and location blanked, their
 *       photos deleted — and the record of the ads this member wrote to;
 *   <li>comments, except a top-level comment others answered, which stays as a blank tombstone so
 *       their replies keep their thread (see {@link CommentRepository});
 *   <li>blocks made or received, and reports about the member; the reports they filed or decided
 *       stay, without their name;
 *   <li>notifications, push devices, data exports, GPX previews, the avatar file.
 * </ul>
 *
 * <p>Run synchronously by {@link UserService#deleteUser}, so the promise made to the member — the
 * privacy policy, the confirmation screen, the store listings — holds the moment they confirm.
 * {@link AccountErasureScheduler} catches up on accounts flagged deleted before this existed, and
 * on any erasure that failed.
 */
@ApplicationScoped
public class AccountErasureService {

  private static final Logger LOG = Logger.getLogger(AccountErasureService.class);

  /** RFC 2606 reserves {@code .invalid}: no mail can ever be delivered to an erased account. */
  static final String ERASED_EMAIL_DOMAIN = "erased.invalid";

  /** What remains of an erased member wherever their content is still shown. */
  static final String ERASED_DISPLAY_NAME = "Ancien membre";

  /** The title left on an erased member's ads — deleted, so only organizers could ever see it. */
  static final String ERASED_AD_NAME = "Annonce supprimée";

  /** Rows owned by one user and worth nothing without them, deleted by {@code user}. */
  private static final List<Class<?>> OWNED_BY_USER =
      List.of(
          AuthSession.class,
          AuthToken.class,
          DeviceCode.class,
          // Issues already published stay in the private feedback repository; they name the member
          // by an id that no longer leads to anyone.
          ErrorOccurrence.class,
          FeedbackReport.class,
          Passkey.class,
          WebAuthnChallenge.class,
          CalendarToken.class,
          GpsOAuthState.class,
          // Before the connections: the tracking rows of the routes sent to them (API-120).
          GpsRouteSync.class,
          GpsServiceConnection.class,
          UserTeam.class);

  @Inject EntityManager em;
  @Inject UserRepository userRepository;
  @Inject CommentRepository commentRepository;
  @Inject UserBlockRepository userBlockRepository;
  @Inject ContentReportRepository contentReportRepository;
  @Inject NotificationService notificationService;
  @Inject UserExportService userExportService;
  @Inject UserAvatarService userAvatarService;
  @Inject GpxPreviewService gpxPreviewService;
  @Inject GpsServiceConnectionRepository gpsServiceConnectionRepository;
  @Inject GpsRouteSyncService gpsRouteSyncService;

  /** The time the GPS clean-up of one account may take, all services together. */
  static final Duration GPS_CLEANUP_BUDGET = Duration.ofSeconds(20);

  /**
   * Removes from the member's GPS services, as far as possible, the routes the automatic sync
   * placed there (docs/LEDGER_*.md API-120 §4.6) — while the connections and their tokens are still
   * there, so before {@link #erase}. <b>To be called with no transaction open</b>: it calls the
   * services, and a transaction held across those calls would keep its locks and run into its
   * timeout. Best effort and bounded ({@link #GPS_CLEANUP_BUDGET}), failures logged and ignored: an
   * erasure never waits on a GPS service.
   */
  public void removeSyncedRoutes(Long userId) {
    record Target(Long domainId, Long connectionId) {}
    List<Target> targets;
    try {
      targets =
          QuarkusTransaction.requiringNew()
              .call(
                  () -> {
                    User user = userRepository.findById(userId);
                    if (user == null || isErased(user)) {
                      return List.<Target>of();
                    }
                    Long domainId = user.getDomain().getId();
                    return gpsServiceConnectionRepository.findByUser(userId).stream()
                        .map(c -> new Target(domainId, c.getId()))
                        .toList();
                  });
    } catch (RuntimeException e) {
      LOG.warnf("Synced routes of user %d not removed before erasure: %s", userId, e.getMessage());
      return;
    }
    Instant deadline = Instant.now().plus(GPS_CLEANUP_BUDGET);
    for (Target target : targets) {
      try {
        gpsRouteSyncService.removeAutoSyncedRoutes(
            target.domainId(), target.connectionId(), deadline);
      } catch (RuntimeException e) {
        LOG.warnf(
            "Synced routes of connection %d not removed before erasure: %s",
            target.connectionId(), e.getMessage());
      }
    }
  }

  /** Whether an account has already been through {@link #erase}. */
  public static boolean isErased(User user) {
    return user.getEmail().endsWith("@" + ERASED_EMAIL_DOMAIN);
  }

  /**
   * Flags the account deleted and erases its personal data, in the caller's transaction or a new
   * one. Idempotent: an account already erased is left alone.
   */
  @Transactional
  public void erase(User user) {
    if (isErased(user)) {
      return;
    }
    Long userId = user.getId();
    // First, and flushed: the comment statements below recognise a tombstone by its author's flag.
    user.setDeleted(true);
    userRepository.persistAndFlush(user);

    for (Class<?> owned : OWNED_BY_USER) {
      em.createQuery("delete from " + owned.getSimpleName() + " e where e.user.id = :userId")
          .setParameter("userId", userId)
          .executeUpdate();
    }
    forgetFutureRegistrations(userId);
    em.createQuery("update RideGroup g set g.leader = null where g.leader.id = :userId")
        .setParameter("userId", userId)
        .executeUpdate();

    forgetAds(userId);
    forgetComments(userId);
    forgetModeration(userId);

    notificationService.forgetUser(userId);
    userExportService.forgetUser(userId);
    gpxPreviewService.forgetCreator(user.getDomain().getId(), userId);
    userAvatarService.forgetAvatar(user);

    anonymize(user);
    LOG.infof("Account %s erased", TsidUtils.toString(userId));
  }

  /** Accounts flagged deleted but not erased yet, for {@link AccountErasureScheduler}. */
  @Transactional
  public List<Long> findPendingErasure() {
    return em.createQuery(
            "select u.id from User u where u.deleted = true and u.email not like :erased",
            Long.class)
        .setParameter("erased", "%@" + ERASED_EMAIL_DOMAIN)
        .getResultList();
  }

  /** {@link #erase} by id, each in its own transaction, so one failure does not hold the rest. */
  @Transactional(Transactional.TxType.REQUIRES_NEW)
  public void eraseById(Long userId) {
    erase(userRepository.findById(userId));
  }

  private void forgetFutureRegistrations(Long userId) {
    Instant now = Instant.now();
    em.createQuery(
            "delete from RideParticipation p where p.user.id = :userId and p.rideGroup.id in"
                + " (select g.id from RideGroup g where g.ride.dateTime > :now)")
        .setParameter("userId", userId)
        .setParameter("now", now)
        .executeUpdate();
    em.createQuery(
            "delete from TripParticipation p where p.user.id = :userId and p.trip.id in"
                + " (select t.id from Trip t where t.dateTime > :now)")
        .setParameter("userId", userId)
        .setParameter("now", now)
        .executeUpdate();
  }

  /**
   * Soft-deletes the member's ads and strips what they said. Not a hard delete: an ad is a {@code
   * TeamEntity}, which a dozen tables reference. The photos go through {@code orphanRemoval}, whose
   * entity-level delete lets {@code AssetRemoveListener} remove the stored files.
   */
  private void forgetAds(Long userId) {
    List<Ad> ads =
        em.createQuery("select a from Ad a where a.createdBy.id = :userId", Ad.class)
            .setParameter("userId", userId)
            .getResultList();
    for (Ad ad : ads) {
      ad.setDeleted(true);
      ad.setName(ERASED_AD_NAME);
      ad.setMarkdown("");
      ad.setPrice(null);
      ad.setLocationGeometry(null);
      ad.setLocationDescription(null);
      ad.getAssets().clear();
    }
    em.flush();
    // Who wrote to which ad: rate-limiting and abuse metadata, about this member.
    em.createQuery(
            "delete from " + AdContact.class.getSimpleName() + " c where c.createdBy.id = :u")
        .setParameter("u", userId)
        .executeUpdate();
  }

  /** Order matters: see {@link CommentRepository} for what each statement leaves behind. */
  private void forgetComments(Long userId) {
    List<Long> answeredThreads = commentRepository.findParentIdsOfRepliesBy(userId);
    commentRepository.deleteRepliesBy(userId);
    commentRepository.deleteUnansweredRootsBy(userId);
    commentRepository.blankContentBy(userId);
    commentRepository.deleteEmptyTombstones(answeredThreads);
  }

  /**
   * Blocks made or received go. Reports about the member go too — their excerpt is the member's own
   * content. Reports the member filed or decided stay, for the decision they record, without them.
   */
  private void forgetModeration(Long userId) {
    userBlockRepository.deleteByUser(userId);
    contentReportRepository.deleteTargeting(userId);
    contentReportRepository.forgetReporterAndResolver(userId);
  }

  private void anonymize(User user) {
    user.setEmail(TsidUtils.toString(user.getId()) + "@" + ERASED_EMAIL_DOMAIN);
    user.setDisplayName(ERASED_DISPLAY_NAME);
    user.setPasswordHash(null);
    user.setLastLoginAt(null);
    user.setUnitSystem(null);
    user.setTheme(null);
    user.setLanguage(null);
    user.setTimezone(null);
    user.setContactableByMembers(null);
    user.setEmailVerified(false);
    user.setEmailVerifiedAt(null);
    user.setPlatformRole(null);
    userRepository.persist(user);
  }
}
