package fr.pedalons.service.notification;

import fr.pedalons.domain.comment.Comment;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.moderation.ContentReport;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ride.RideParticipation;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamInvitation;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.ReportStatus;
import fr.pedalons.enums.Status;
import fr.pedalons.repository.comment.CommentRepository;
import fr.pedalons.repository.moderation.ContentReportRepository;
import fr.pedalons.repository.moderation.UserBlockRepository;
import fr.pedalons.repository.post.PostRepository;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.repository.ride.RideParticipationRepository.RegisteredStart;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.team.TeamInvitationRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.repository.trip.TripParticipationRepository;
import fr.pedalons.repository.trip.TripRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.comment.CommentThreads;
import fr.pedalons.service.notification.event.CommentOnPublication;
import fr.pedalons.service.notification.event.CommentReplied;
import fr.pedalons.service.notification.event.ContentReported;
import fr.pedalons.service.notification.event.NotificationEvent;
import fr.pedalons.service.notification.event.PostPublished;
import fr.pedalons.service.notification.event.RideCancelled;
import fr.pedalons.service.notification.event.RideGroupRemoved;
import fr.pedalons.service.notification.event.RideJoined;
import fr.pedalons.service.notification.event.RidePublished;
import fr.pedalons.service.notification.event.RideReminder;
import fr.pedalons.service.notification.event.RideUpdated;
import fr.pedalons.service.notification.event.TeamInvited;
import fr.pedalons.service.notification.event.TripCancelled;
import fr.pedalons.service.notification.event.TripPublished;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.jspecify.annotations.Nullable;

/**
 * Decides, for one event, what it is about and who hears of it — or that it no longer matters.
 *
 * <p>Reloads every entity rather than trusting the payload: between the business commit and this
 * tick a ride may have been unpublished, deleted, or its date may have passed. Each of those is an
 * {@link Optional#empty()}, which the dispatcher records as {@code SKIPPED}.
 *
 * <p>The switch below has no {@code default}: {@link NotificationEvent} is sealed, so a new event
 * record does not compile until it is handled here.
 */
@ApplicationScoped
public class NotificationRecipientResolver {

  /** Longest quote kept in the snapshot; the column holds 500. */
  static final int EXCERPT_LENGTH = 280;

  @Inject RideRepository rideRepository;
  @Inject TripRepository tripRepository;
  @Inject PostRepository postRepository;
  @Inject CommentRepository commentRepository;
  @Inject UserTeamRepository userTeamRepository;
  @Inject RideParticipationRepository rideParticipationRepository;
  @Inject TripParticipationRepository tripParticipationRepository;
  @Inject TeamInvitationRepository invitationRepository;
  @Inject UserRepository userRepository;
  @Inject ContentReportRepository contentReportRepository;
  @Inject UserBlockRepository userBlockRepository;

  /**
   * What the notification points at, and who receives it. The actor is not yet removed.
   *
   * <p>The subject is described by value rather than by entity: an invitation is about a team,
   * which is not a {@link TeamEntity}.
   */
  public record Resolution(
      Team team,
      NotificationSubjectType subjectType,
      String subjectSlug,
      String subjectName,
      @Nullable Instant subjectDateTime,
      /** The zone {@code subjectDateTime} reads in — the subject's (docs/LEDGER_*.md API-60). */
      @Nullable String subjectTimezone,
      @Nullable String excerpt,
      List<NotificationChange> changes,
      List<User> recipients,
      /**
       * Recipient id → the start that concerns them, where it is not {@code subjectDateTime}: a
       * registered rider whose group leaves at its own time (docs/LEDGER_*.md NOTIF-13). Stored
       * on their inbox row; everyone else reads the event's.
       */
      Map<Long, Instant> recipientDateTimes,
      /**
       * Whether the team's webhook hears of it, for a type relayed there at all. False for a
       * change of a group's own time alone: the ride the team channel announced has not moved.
       */
      boolean relayedToTeam) {

    Resolution(
        Team team,
        NotificationSubjectType subjectType,
        String subjectSlug,
        String subjectName,
        @Nullable Instant subjectDateTime,
        @Nullable String subjectTimezone,
        @Nullable String excerpt,
        List<NotificationChange> changes,
        List<User> recipients) {
      this(
          team,
          subjectType,
          subjectSlug,
          subjectName,
          subjectDateTime,
          subjectTimezone,
          excerpt,
          changes,
          recipients,
          Map.of(),
          true);
    }

    /** The same, about another start: the one every recipient shares, a group's. */
    Resolution withSubjectDateTime(Instant dateTime) {
      return new Resolution(
          team,
          subjectType,
          subjectSlug,
          subjectName,
          dateTime,
          subjectTimezone,
          excerpt,
          changes,
          recipients,
          recipientDateTimes,
          relayedToTeam);
    }

    /** The start each recipient reads: their own if they have one, else the subject's. */
    public @Nullable Instant dateTimeFor(User recipient) {
      Instant own = recipientDateTimes.get(recipient.getId());
      return own != null ? own : subjectDateTime;
    }

    static Resolution of(
        TeamEntity subject,
        NotificationSubjectType type,
        @Nullable String excerpt,
        List<User> recipients) {
      return new Resolution(
          subject.getTeam(),
          type,
          subject.getSlug(),
          subject.getName(),
          subject.getDateTime(),
          // The stored zone, else the team's for a row an older backend wrote without one.
          subject.getDateTime() != null ? subject.zone().getId() : null,
          excerpt,
          List.of(),
          recipients);
    }
  }

  public Optional<Resolution> resolve(NotificationEvent event) {
    Instant now = Instant.now();
    return switch (event) {
      case RidePublished e ->
          live(rideRepository.findById(e.rideId()), Status.PUBLISHED, now)
              .map(ride -> toTeam(ride, NotificationSubjectType.RIDE));
      case RideCancelled e ->
          live(rideRepository.findById(e.rideId()), Status.CANCELLED, now).map(this::toRegistered);
      case TripPublished e ->
          live(tripRepository.findById(e.tripId()), Status.PUBLISHED, now)
              .map(trip -> toTeam(trip, NotificationSubjectType.TRIP));
      case TripCancelled e ->
          live(tripRepository.findById(e.tripId()), Status.CANCELLED, now)
              .map(
                  trip ->
                      Resolution.of(
                          trip,
                          NotificationSubjectType.TRIP,
                          null,
                          tripParticipationRepository.findRegisteredMemberUsers(trip.getId())));
      // A post has no date to have passed: its dateTime is when it was published.
      case PostPublished e ->
          Optional.ofNullable(postRepository.findById(e.postId()))
              .filter(post -> !post.isDeleted() && post.getStatus() == Status.PUBLISHED)
              .map(post -> toTeam(post, NotificationSubjectType.POST));
      case CommentReplied e -> resolveReply(commentRepository.findById(e.commentId()));
      // A ride moved since the reminder was queued has another reminder of its own coming.
      case RideReminder e ->
          live(rideRepository.findById(e.rideId()), Status.PUBLISHED, now)
              .filter(ride -> ride.getDateTime().equals(e.dateTime()))
              .map(this::toRegistered);
      case RideUpdated e ->
          live(rideRepository.findById(e.rideId()), Status.PUBLISHED, now)
              .flatMap(ride -> resolveUpdate(ride, e));
      case RideGroupRemoved e ->
          live(rideRepository.findById(e.rideId()), Status.PUBLISHED, now)
              .map(ride -> resolveGroupRemoved(ride, e));
      case RideJoined e ->
          resolveJoin(rideParticipationRepository.findById(e.participationId()), now);
      case CommentOnPublication e ->
          resolveCommentOnPublication(commentRepository.findById(e.commentId()));
      case TeamInvited e -> resolveInvitation(invitationRepository.findById(e.invitationId()));
      case ContentReported e -> resolveReport(contentReportRepository.findById(e.reportId()));
    };
  }

  private Resolution toTeam(TeamEntity subject, NotificationSubjectType type) {
    return Resolution.of(
        subject, type, null, userTeamRepository.findActiveMemberUsers(subject.getTeam().getId()));
  }

  /**
   * The ride's registered riders, each told the start of their own group: the reminder, the
   * cancellation (docs/LEDGER_*.md NOTIF-13). The event keeps the ride's date — the team's webhook
   * reads it, and so does a rider whose group leaves with the ride.
   */
  private Resolution toRegistered(Ride ride) {
    return toRegistered(ride, rideParticipationRepository.findRegisteredMemberStarts(ride.getId()));
  }

  private static Resolution toRegistered(Ride ride, List<RegisteredStart> registered) {
    Resolution base =
        Resolution.of(
            ride,
            NotificationSubjectType.RIDE,
            null,
            registered.stream().map(RegisteredStart::user).toList());
    return new Resolution(
        base.team(),
        base.subjectType(),
        base.subjectSlug(),
        base.subjectName(),
        base.subjectDateTime(),
        base.subjectTimezone(),
        base.excerpt(),
        base.changes(),
        base.recipients(),
        ownStarts(ride, registered),
        true);
  }

  /** Rider id → their group's start, for those whose group does not leave with the ride. */
  private static Map<Long, Instant> ownStarts(Ride ride, List<RegisteredStart> registered) {
    Map<Long, Instant> starts = new HashMap<>();
    for (RegisteredStart rider : registered) {
      if (!rider.startAt().equals(ride.getDateTime())) {
        starts.put(rider.user().getId(), rider.startAt());
      }
    }
    return starts;
  }

  /**
   * The net effect of the edits since the event was queued. None — an edit undone, or a change of
   * name only — notifies nobody.
   *
   * <p>A new meeting point concerns every registered rider; a new time only those whose own group
   * leaves at another time than before — the ride's date moved, a group with its own time stays
   * put, and a group's time moved alone is news to its riders only (docs/LEDGER_*.md NOTIF-13).
   * Each is told the new start of their group. An event queued without the groups' previous starts
   * (an older release) compares the ride's date and tells every registered rider, as it used to.
   *
   * <p>The change list is the event's, shared by its recipients: when the meeting point and one
   * group's time both moved, the riders of the other groups read both. The team's webhook hears of
   * a change of the ride itself only — its date or its meeting point.
   */
  private Optional<Resolution> resolveUpdate(Ride ride, RideUpdated event) {
    boolean rideMoved = !ride.getDateTime().equals(event.previousDateTime());
    Long startPlaceId = ride.getStart() != null ? ride.getStart().getId() : null;
    boolean placeMoved = !Objects.equals(startPlaceId, event.previousStartPlaceId());
    List<RegisteredStart> registered =
        rideParticipationRepository.findRegisteredMemberStarts(ride.getId());
    Map<Long, Instant> previousGroupStarts = event.previousGroupStarts();
    List<RegisteredStart> retimed =
        previousGroupStarts == null
            ? (rideMoved ? registered : List.of())
            : registered.stream()
                .filter(
                    rider -> {
                      // A group created since was joined at its current time: nothing moved.
                      Instant previous = previousGroupStarts.get(rider.groupId());
                      return previous != null && !previous.equals(rider.startAt());
                    })
                .toList();
    List<NotificationChange> changes = new ArrayList<>();
    if (rideMoved || !retimed.isEmpty()) {
      changes.add(NotificationChange.DATE_TIME);
    }
    if (placeMoved) {
      changes.add(NotificationChange.START_PLACE);
    }
    if (changes.isEmpty()) {
      return Optional.empty();
    }
    Resolution base = toRegistered(ride, placeMoved ? registered : retimed);
    return Optional.of(
        new Resolution(
            base.team(),
            base.subjectType(),
            base.subjectSlug(),
            base.subjectName(),
            base.subjectDateTime(),
            base.subjectTimezone(),
            null,
            List.copyOf(changes),
            base.recipients(),
            base.recipientDateTimes(),
            rideMoved || placeMoved));
  }

  /**
   * The riders the removed group had, still in the team. One who registered again to another group
   * of the ride since has already found out, and is left alone. The group's name travels as the
   * excerpt and its start as the date — the group itself is gone.
   */
  private Resolution resolveGroupRemoved(Ride ride, RideGroupRemoved event) {
    Set<Long> registeredAgain =
        rideParticipationRepository.findRegisteredMemberUsers(ride.getId()).stream()
            .map(User::getId)
            .collect(Collectors.toSet());
    List<User> removed =
        event.userIds().stream()
            .filter(id -> !registeredAgain.contains(id))
            .map(userRepository::findById)
            .filter(Objects::nonNull)
            .filter(user -> !user.isDeleted())
            .toList();
    // The time they had registered for: the group's, the ride's for an event without it.
    Instant groupStart = event.groupStartAt();
    return Resolution.of(
            ride,
            NotificationSubjectType.RIDE,
            excerpt(event.groupName()),
            stillMembers(removed, ride.getTeam()))
        .withSubjectDateTime(groupStart != null ? groupStart : ride.getDateTime());
  }

  /**
   * The ride's creator and the leader of the group joined — the two people for whom a new rider
   * changes something. Registrations are hard-deleted: a rider who left before this tick is not
   * found. The group's name travels as the excerpt, its start as the date.
   */
  private Optional<Resolution> resolveJoin(@Nullable RideParticipation participation, Instant now) {
    if (participation == null) {
      return Optional.empty();
    }
    RideGroup group = participation.getRideGroup();
    return live(group.getRide(), Status.PUBLISHED, now)
        .map(
            ride -> {
              List<User> organisers = new ArrayList<>();
              organisers.add(ride.getCreatedBy());
              if (group.getLeader() != null) {
                organisers.add(group.getLeader());
              }
              // Who organises that group hears when it leaves (docs/LEDGER_*.md NOTIF-13).
              return Resolution.of(
                      ride,
                      NotificationSubjectType.RIDE,
                      excerpt(group.getName()),
                      stillMembers(organisers, ride.getTeam()))
                  .withSubjectDateTime(group.getStartAt());
            });
  }

  /**
   * The author of what was commented on. Same rules as a reply: the thread must not be on a draft,
   * and the author must still belong to the team.
   */
  private Optional<Resolution> resolveCommentOnPublication(@Nullable Comment comment) {
    if (comment == null || comment.getParent() != null) {
      return Optional.empty();
    }
    // A stage's thread is its trip's: the trip's author is told (docs/LEDGER_*.md API-11).
    TeamEntity subject = CommentThreads.publicationOf(comment);
    NotificationSubjectType type = subjectType(subject);
    if (type == null || subject.isDeleted() || subject.getStatus() == Status.DRAFT) {
      return Optional.empty();
    }
    List<User> recipients = stillMembers(List.of(subject.getCreatedBy()), subject.getTeam());
    // An author who blocked the commenter hears nothing from them.
    recipients.removeIf(
        author -> userBlockRepository.isBlocked(author.getId(), comment.getCreatedBy().getId()));
    return Optional.of(Resolution.of(subject, type, excerpt(comment.getContent()), recipients));
  }

  /**
   * The account the invited address belongs to on the team's domain, if there is one. The only type
   * whose recipient is, by definition, not a member — so the membership guard is inverted: someone
   * who joined in the meantime has nothing left to accept.
   */
  private Optional<Resolution> resolveInvitation(@Nullable TeamInvitation invitation) {
    if (invitation == null || !invitation.isPending() || invitation.isLapsed()) {
      return Optional.empty();
    }
    Team team = invitation.getTeam();
    if (team.isDeleted()) {
      return Optional.empty();
    }
    List<User> recipients =
        userRepository
            .findByEmailAndDomain(
                invitation.getDomainId(), invitation.getEmail().toLowerCase(Locale.ROOT))
            // Unverified, the account may be someone else's claim on the address: telling it who
            // invited whom to which team would leak exactly what the invitation token protects.
            .filter(user -> !user.isDeleted() && user.isEmailVerified())
            .filter(
                user -> userTeamRepository.findByUserAndTeam(user.getId(), team.getId()).isEmpty())
            .map(List::of)
            .orElse(List.of());
    return Optional.of(
        new Resolution(
            team,
            NotificationSubjectType.TEAM,
            team.getSlug(),
            team.getName(),
            null,
            null,
            null,
            List.of(),
            recipients));
  }

  /**
   * The moderators of the team a report was filed in, and the platform admins of its domain — never
   * a reporter nor the member the report is about. The event coalesces a burst of reports on one
   * target, so "a reporter" is every author of an open report on it, not only the first. When that member moderates the team, only the
   * team's other administrators hear of it; with none left, the platform admins alone do.
   *
   * <p>No excerpt: a push shows on the lock screen, and the subject is the team, whose queue the
   * notification opens. A report already decided, or gone with its team, notifies nobody.
   */
  private Optional<Resolution> resolveReport(@Nullable ContentReport report) {
    if (report == null || report.getStatus() != ReportStatus.OPEN) {
      return Optional.empty();
    }
    Team team = report.getTeam();
    if (team.isDeleted()) {
      return Optional.empty();
    }
    Long targetUserId = report.getTargetUser().getId();
    // The event stands for a burst: every report filed on this target in this team while it was
    // pending folded into it, and this is only the first. None of their authors is told of it.
    Set<Long> reporterIds =
        contentReportRepository.findOpenReporterIds(
            team.getId(), report.getTargetType(), report.getTargetId());
    if (report.getReporter() != null) {
      reporterIds.add(report.getReporter().getId());
    }
    List<UserTeam> moderators = userTeamRepository.findModerators(team.getId());
    boolean targetModerates =
        moderators.stream().anyMatch(ut -> ut.getUser().getId().equals(targetUserId));
    List<User> recipients = new ArrayList<>();
    for (UserTeam moderator : moderators) {
      if (!targetModerates || moderator.getRole().isAdmin()) {
        recipients.add(moderator.getUser());
      }
    }
    recipients.addAll(userRepository.findPlatformAdmins(team.getDomain().getId()));
    recipients.removeIf(
        user -> user.getId().equals(targetUserId) || reporterIds.contains(user.getId()));
    return Optional.of(
        new Resolution(
            team,
            NotificationSubjectType.REPORT,
            team.getSlug(),
            team.getName(),
            null,
            null,
            null,
            List.of(),
            recipients));
  }

  /** The live users of {@code candidates} who still belong to {@code team}. */
  private List<User> stillMembers(List<@Nullable User> candidates, Team team) {
    List<User> members = new ArrayList<>();
    for (User user : candidates) {
      if (user != null
          && !user.isDeleted()
          && userTeamRepository.findByUserAndTeam(user.getId(), team.getId()).isPresent()) {
        members.add(user);
      }
    }
    return members;
  }

  /**
   * A ride or trip still in the status the event announced, not deleted, and not in the past. The
   * date rule is what keeps a retroactive entry — or a mass import — from waking anyone up.
   */
  private static <T extends TeamEntity> Optional<T> live(
      @Nullable T entity, Status expected, Instant now) {
    return Optional.ofNullable(entity)
        .filter(e -> !e.isDeleted() && e.getStatus() == expected)
        .filter(e -> e.getDateTime().isAfter(now));
  }

  /**
   * The author of the parent comment, provided they are still a member of the team. Comments are
   * hard-deleted, so a reply removed before this tick is simply not found. A thread on a draft is
   * skipped: a draft is read by organisers only, and checking that per recipient buys little.
   */
  private Optional<Resolution> resolveReply(@Nullable Comment reply) {
    if (reply == null || reply.getParent() == null) {
      return Optional.empty();
    }
    // Unproxied, and a stage's thread resolved to its trip: see CommentThreads.
    TeamEntity subject = CommentThreads.publicationOf(reply);
    NotificationSubjectType type = subjectType(subject);
    if (type == null || subject.isDeleted() || subject.getStatus() == Status.DRAFT) {
      return Optional.empty();
    }
    User parentAuthor = reply.getParent().getCreatedBy();
    boolean stillMember =
        !parentAuthor.isDeleted()
            && userTeamRepository
                .findByUserAndTeam(parentAuthor.getId(), subject.getTeam().getId())
                .isPresent()
            // A member who blocked the replier hears nothing from them.
            && !userBlockRepository.isBlocked(parentAuthor.getId(), reply.getCreatedBy().getId());
    return Optional.of(
        Resolution.of(
            subject,
            type,
            excerpt(reply.getContent()),
            stillMember ? List.of(parentAuthor) : List.of()));
  }

  private static @Nullable NotificationSubjectType subjectType(TeamEntity entity) {
    return switch (entity) {
      case Ride ignored -> NotificationSubjectType.RIDE;
      case Trip ignored -> NotificationSubjectType.TRIP;
      case Post ignored -> NotificationSubjectType.POST;
      case Route ignored -> NotificationSubjectType.ROUTE;
      default -> null;
    };
  }

  static String excerpt(String content) {
    String flat = content.strip().replaceAll("\\s+", " ");
    return flat.length() <= EXCERPT_LENGTH
        ? flat
        : flat.substring(0, EXCERPT_LENGTH - 1).stripTrailing() + "…";
  }
}
