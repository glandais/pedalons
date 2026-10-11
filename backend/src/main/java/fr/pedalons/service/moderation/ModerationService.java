package fr.pedalons.service.moderation;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.comment.Comment;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.moderation.ContentReport;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.dashboard.response.TeamDashboardReportsDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.moderation.request.ModerationDecisionRequest;
import fr.pedalons.dto.moderation.response.ModerationItemDto;
import fr.pedalons.dto.moderation.response.ModerationQueueResponse;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.enums.ReportQueueStatus;
import fr.pedalons.enums.ReportReason;
import fr.pedalons.enums.ReportStatus;
import fr.pedalons.enums.ReportTargetType;
import fr.pedalons.repository.comment.CommentRepository;
import fr.pedalons.repository.moderation.ContentReportRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.comment.CommentService;
import fr.pedalons.service.comment.CommentThreads;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Admin;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.team.TeamService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.hibernate.Hibernate;
import org.jspecify.annotations.Nullable;

/**
 * The moderation queues and the decisions taken from them.
 *
 * <p>Two queues over the same reports: a team's, for its organizers and administrators, and the
 * platform's, for {@code PLATFORM_ADMIN}, over the whole domain. Reports are grouped by target and
 * team — one item per reported thing, however many members reported it. A publication or a comment
 * belongs to one team; a member does not, and a member reported in two teams is two items, each
 * decided on its own (docs/LEDGER_*.md MOD-1). The reporters' identities appear in the platform
 * queue only.
 *
 * <p>A moderator never sees, nor decides about, a report that targets them — their own content, or
 * themselves as a member. A platform admin sees everything.
 */
@ApplicationScoped
public class ModerationService {

  /** How many decided targets the {@code RESOLVED} half of a queue shows. */
  public static final int RESOLVED_LIMIT = 100;

  @Inject PedalonsQueryContext pedalonsContext;
  @Inject TeamService teamService;
  @Inject ContentReportRepository reportRepository;
  @Inject CommentRepository commentRepository;
  @Inject UserTeamRepository userTeamRepository;
  @Inject CommentService commentService;
  @Inject PublicationEndCalculator publicationEndCalculator;

  // ------------------------------------------------------------------ team queue

  /** The team's queue, without reporters. For its organizers, administrators and platform admins. */
  @Logged
  @Transactional
  public ModerationQueueResponse teamQueue(String teamSlug, @Nullable ReportQueueStatus status) {
    Team team = teamService.getTeam(teamSlug);
    User moderator = requireTeamModerator(team);
    return queue(team.getId(), excludedTarget(moderator), status, false);
  }

  /**
   * The reports tile of the team's dashboard: how many targets of the open queue wait, and the
   * latest report — two queries, whatever the size of the queue, where {@link #teamQueue} loads it
   * all. Same exclusion as the queue: a moderator is never told about a report on themselves.
   */
  public TeamDashboardReportsDto teamOpenSummary(Team team) {
    User moderator = requireTeamModerator(team);
    Long excluded = excludedTarget(moderator);
    Long domainId = pedalonsContext.getDomainId();
    return TeamDashboardReportsDto.from(
        reportRepository.countOpenTargets(domainId, team.getId(), excluded),
        reportRepository.findLatestOpen(domainId, team.getId(), excluded).orElse(null));
  }

  /** Decides about one target of the team's queue. */
  @Logged
  @Transactional
  public void resolveTeamReports(String teamSlug, ModerationDecisionRequest request) {
    Team team = teamService.getTeam(teamSlug);
    User moderator = requireTeamModerator(team);
    resolve(team.getId(), excludedTarget(moderator), request, moderator);
  }

  // ------------------------------------------------------------------ platform queue

  /** The whole domain's queue, reporters included. */
  @Admin
  @Transactional
  public ModerationQueueResponse platformQueue(@Nullable ReportQueueStatus status) {
    return queue(null, null, status, true);
  }

  /**
   * Decides about one item of the platform queue: the target in the request's team, or in every
   * team it was reported in when the request names none.
   */
  @Admin
  @Transactional
  public void resolvePlatformReports(ModerationDecisionRequest request) {
    String teamSlug = request.teamSlug();
    Long teamId = teamSlug == null ? null : teamService.getTeam(teamSlug).getId();
    resolve(teamId, null, request, pedalonsContext.getUser());
  }

  // ------------------------------------------------------------------ access

  private User requireTeamModerator(Team team) {
    User user = pedalonsContext.getUser();
    if (user.isPlatformAdmin()) {
      return user;
    }
    boolean moderates =
        userTeamRepository
            .findByUserAndTeam(user.getId(), team.getId())
            .map(userTeam -> userTeam.getRole().isOrganizer())
            .orElse(false);
    if (!moderates) {
      throw new ForbiddenException();
    }
    return user;
  }

  /** Whom the caller must not see reports about: themselves, unless they are a platform admin. */
  private static @Nullable Long excludedTarget(User moderator) {
    return moderator.isPlatformAdmin() ? null : moderator.getId();
  }

  // ------------------------------------------------------------------ decisions

  private void resolve(
      @Nullable Long teamId,
      @Nullable Long excludedTargetUserId,
      ModerationDecisionRequest request,
      User moderator) {
    ReportTargetType type = request.targetType();
    Long targetId = TsidUtils.toLong(request.targetId());
    List<ContentReport> reports =
        reportRepository.findOpenByTarget(
            pedalonsContext.getDomainId(), teamId, excludedTargetUserId, type, targetId);
    if (reports.isEmpty()) {
      throw new NotFoundException(ErrorCode.NOT_FOUND);
    }
    // Content belongs to one team, so do all its reports. A member does not, but nothing is
    // removed nor restored about a member: the first report's team serves.
    Team team = reports.getFirst().getTeam();
    Instant now = Instant.now();
    ReportStatus outcome =
        switch (request.action()) {
          case REMOVE_CONTENT -> {
            remove(team, type, targetId, moderator, now);
            yield ReportStatus.REMOVED;
          }
          case DISMISS -> {
            restore(team, type, targetId);
            yield ReportStatus.DISMISSED;
          }
        };
    for (ContentReport report : reports) {
      report.setStatus(outcome);
      report.setResolvedBy(moderator);
      report.setResolvedAt(now);
    }
  }

  /**
   * The same gesture as the {@code delete*} of the services — a soft delete for a publication, the
   * comment deletion of {@link CommentService} for a comment — without their access rules: deciding
   * from the queue is what allows it.
   */
  private void remove(
      Team team, ReportTargetType type, Long targetId, User moderator, Instant now) {
    switch (type) {
      // A member is removed from the team's member page, by an administrator.
      case MEMBER -> throw new BadRequestException(ErrorCode.BAD_REQUEST);
      case COMMENT ->
          commentRepository
              .findByTeamIdAndId(team.getId(), targetId)
              .ifPresent(
                  comment -> {
                    List<Long> removed = new ArrayList<>(commentService.removeComment(comment));
                    removed.remove(targetId);
                    // The replies went with it: their own reports are decided too.
                    reportRepository.resolveOpen(
                        team.getId(),
                        ReportTargetType.COMMENT,
                        removed,
                        ReportStatus.REMOVED,
                        moderator,
                        now);
                  });
      case POST, AD, RIDE, TRIP, ROUTE ->
          reportRepository
              .findTeamEntity(team.getId(), targetId)
              .ifPresent(
                  entity -> {
                    entity.setDeleted(true);
                    if (entity instanceof Route route) {
                      // Its rides and stages lose its length (docs/LEDGER_*.md API-87).
                      publicationEndCalculator.refreshUsersOf(route);
                    }
                    // Decided: the reports no longer hide it. Should a platform admin undelete it,
                    // no open report is left to dismiss — it must not stay hidden for good.
                    entity.setModerationHiddenAt(null);
                    // Its comments went with it: their open reports are decided too, rather than
                    // left in the queue pointing at a removed publication.
                    reportRepository.resolveOpenCommentsOf(
                        team.getId(), entity.getId(), ReportStatus.REMOVED, moderator, now);
                  });
    }
  }

  /** Shows the content again, if the reports had hidden it. */
  private void restore(Team team, ReportTargetType type, Long targetId) {
    switch (type) {
      case MEMBER -> {
        // Nothing is hidden about a member.
      }
      case COMMENT ->
          commentRepository
              .findByTeamIdAndId(team.getId(), targetId)
              .ifPresent(comment -> comment.setModerationHiddenAt(null));
      case POST, AD, RIDE, TRIP, ROUTE ->
          reportRepository
              .findTeamEntity(team.getId(), targetId)
              .ifPresent(entity -> entity.setModerationHiddenAt(null));
    }
  }

  // ------------------------------------------------------------------ queue items

  /** One queue item: a member reported in two teams is two items (docs/LEDGER_*.md MOD-1). */
  private record TargetKey(ReportTargetType type, Long id, Long teamId) {}

  /**
   * One item per target and team, in the order of the reports (most recent first). Four queries whatever the
   * size of the queue: the reports with their teams and users, the publications and the comments
   * they are about — plus the list of targets for the resolved half, and the trips of the stages
   * commented on when there are any.
   */
  private ModerationQueueResponse queue(
      @Nullable Long teamId,
      @Nullable Long excludedTargetUserId,
      @Nullable ReportQueueStatus status,
      boolean withReporters) {
    Long domainId = pedalonsContext.getDomainId();
    boolean resolved = status == ReportQueueStatus.RESOLVED;
    List<ContentReport> reports =
        resolved
            ? reportRepository.findResolved(domainId, teamId, excludedTargetUserId, RESOLVED_LIMIT)
            : reportRepository.findOpen(domainId, teamId, excludedTargetUserId);

    Map<TargetKey, List<ContentReport>> byTarget = new LinkedHashMap<>();
    Set<Long> entityIds = new HashSet<>();
    Set<Long> commentIds = new HashSet<>();
    for (ContentReport report : reports) {
      TargetKey key =
          new TargetKey(report.getTargetType(), report.getTargetId(), report.getTeam().getId());
      byTarget.computeIfAbsent(key, k -> new ArrayList<>()).add(report);
      switch (report.getTargetType()) {
        case COMMENT -> commentIds.add(report.getTargetId());
        case MEMBER -> {
          // The member is the report's target user, already loaded.
        }
        case POST, AD, RIDE, TRIP, ROUTE -> entityIds.add(report.getTargetId());
      }
    }
    Map<Long, TeamEntity> entities = new HashMap<>();
    for (TeamEntity entity : reportRepository.findTeamEntities(domainId, entityIds)) {
      entities.put(entity.getId(), entity);
    }
    Map<Long, Comment> comments = new HashMap<>();
    for (Comment comment : commentRepository.findByIdsWithEntity(domainId, commentIds)) {
      comments.put(comment.getId(), comment);
    }

    List<ModerationItemDto> items = new ArrayList<>(byTarget.size());
    byTarget.forEach(
        (key, targetReports) ->
            items.add(toItem(key, targetReports, entities, comments, resolved, withReporters)));
    return new ModerationQueueResponse(items, items.size());
  }

  private static ModerationItemDto toItem(
      TargetKey key,
      List<ContentReport> reports,
      Map<Long, TeamEntity> entities,
      Map<Long, Comment> comments,
      boolean resolved,
      boolean withReporters) {
    List<ContentReport> chronological =
        reports.stream().sorted(Comparator.comparing(ContentReport::getCreatedAt)).toList();
    ContentReport first = chronological.getFirst();
    ContentReport last = chronological.getLast();
    Team team = first.getTeam();

    TeamEntity content = null;
    boolean hidden = false;
    switch (key.type()) {
      case COMMENT -> {
        Comment comment = comments.get(key.id());
        if (comment != null) {
          hidden = comment.getModerationHiddenAt() != null;
          // A comment on a stage opens its trip: see CommentThreads.
          content = CommentThreads.publicationOf(comment);
        }
      }
      case MEMBER -> {
        // Nothing to open but the member.
      }
      case POST, AD, RIDE, TRIP, ROUTE -> {
        TeamEntity entity = entities.get(key.id());
        if (entity != null) {
          hidden = entity.getModerationHiddenAt() != null;
          content = Hibernate.unproxy(entity, TeamEntity.class);
        }
      }
    }

    ReportStatus status = ReportStatus.OPEN;
    if (resolved) {
      status =
          reports.stream()
              .filter(r -> r.getResolvedAt() != null)
              .max(Comparator.comparing(r -> Objects.requireNonNull(r.getResolvedAt())))
              .map(ContentReport::getStatus)
              .orElse(first.getStatus());
    }

    List<ReportReason> reasons =
        chronological.stream().map(ContentReport::getReason).distinct().sorted().toList();
    List<String> messages =
        chronological.stream()
            .map(ContentReport::getMessage)
            .filter(m -> m != null && !m.isBlank())
            .map(Objects::requireNonNull)
            .toList();
    List<PublicUserDto> reporters = null;
    if (withReporters) {
      Map<Long, PublicUserDto> distinct = new LinkedHashMap<>();
      for (ContentReport report : chronological) {
        User reporter = report.getReporter();
        if (reporter != null) {
          distinct.putIfAbsent(reporter.getId(), PublicUserDto.from(reporter));
        }
      }
      reporters = List.copyOf(distinct.values());
    }

    return new ModerationItemDto(
        key.type(),
        TsidUtils.toString(key.id()),
        team.getSlug(),
        team.getName(),
        PublicUserDto.from(first.getTargetUser()),
        content != null ? content.getName() : null,
        content != null ? contentType(content) : null,
        content != null ? content.getSlug() : null,
        first.getExcerpt(),
        reports.size(),
        reasons,
        messages,
        first.getCreatedAt(),
        last.getCreatedAt(),
        hidden,
        status,
        reporters);
  }

  private static @Nullable ReportTargetType contentType(TeamEntity entity) {
    return switch (entity) {
      case Post ignored -> ReportTargetType.POST;
      case Ad ignored -> ReportTargetType.AD;
      case Ride ignored -> ReportTargetType.RIDE;
      case Trip ignored -> ReportTargetType.TRIP;
      case Route ignored -> ReportTargetType.ROUTE;
      default -> null;
    };
  }
}
