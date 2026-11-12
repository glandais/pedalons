package fr.pedalons.service.limits;

import fr.pedalons.common.Crons;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.domain.limits.PlannerSave;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.PlannerQuotaDetails;
import fr.pedalons.dto.limits.response.PlannerQuotaDto;
import fr.pedalons.enums.PlannerQuotaScope;
import fr.pedalons.repository.limits.PlannerSaveRepository;
import fr.pedalons.repository.limits.RouterDailyCallRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.DateTimeException;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import org.jspecify.annotations.Nullable;

/**
 * The route planner quotas of the free plan (docs/LEDGER_*.md BILL-10).
 *
 * <p>Each save of a track drawn in the planner is one row of {@code planner_saves}; a quota is the
 * rows since the first day of the month — in the team's zone for a team, in {@link Crons#ZONE} for
 * the personal quota of the GPX tools. The rule is {@code saves of the month < quota}, checked twice:
 * once early by {@code require…Room}, before any work, so a spent quota costs nothing; then by
 * {@code record…Save}, in the transaction of the save, under a lock and with the insert of the row —
 * two concurrent saves cannot both take the last one, and a refused or rolled-back save counts
 * nothing.
 *
 * <p>The route calculation is refused once the quota is spent ({@link #requireTeamRoom}, {@link
 * #requirePersonalRoom}), and bounded per user and UTC day whatever the plan ({@link
 * #admitRouting}).
 *
 * <p>A platform admin is exempt from all of it, and their saves are not counted.
 */
@ApplicationScoped
public class PlannerQuota {

  @Inject PlanLimits planLimits;

  @Inject PlannerSaveRepository plannerSaveRepository;

  @Inject RouterDailyCallRepository routerDailyCallRepository;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject LimitsClock clock;

  // ==================== Reading ====================

  /** Where the team's quota stands this month. One query when it has one, none otherwise. */
  public PlannerQuotaDto teamQuota(Team team) {
    Month month = month(zoneOf(team));
    Integer limit = planLimits.forTeam(team).plannerMonthly();
    long used =
        limit == null ? 0 : plannerSaveRepository.countTeamSince(team.getId(), month.start());
    return new PlannerQuotaDto(limit, (int) used, month.resetsOn());
  }

  /** Where the user's personal quota (the GPX tools) stands this month. Two queries at most. */
  public PlannerQuotaDto personalQuota(User user) {
    Long domainId = user.getDomain().getId();
    Month month = month(ZoneId.of(Crons.ZONE));
    Integer limit = planLimits.personalPlannerQuota(user.getId(), domainId);
    long used =
        limit == null
            ? 0
            : plannerSaveRepository.countPersonalSince(domainId, user.getId(), month.start());
    return new PlannerQuotaDto(limit, (int) used, month.resetsOn());
  }

  // ==================== Team ====================

  /**
   * Refuses when the team's quota is already spent: before the work of a save, and before a route
   * calculation for the team.
   *
   * @throws ForbiddenException {@code PLANNER_QUOTA_REACHED}, scope TEAM
   */
  public void requireTeamRoom(Team team) {
    if (pedalonsContext.isPlatformAdmin()) {
      return;
    }
    Integer limit = planLimits.forTeam(team).plannerMonthly();
    if (limit == null) {
      return;
    }
    Month month = month(zoneOf(team));
    requireBelowTeam(team, limit, month);
  }

  /**
   * Counts one save of a drawn track for the team, refusing it when the quota is spent. Must run in
   * the transaction of the save: the row commits or rolls back with it. The lock it takes is held
   * until that transaction ends, so call it at the end of the save.
   *
   * @param routeId the route saved, for a diagnosis
   * @throws ForbiddenException {@code PLANNER_QUOTA_REACHED}, scope TEAM
   */
  public void recordTeamSave(Team team, @Nullable Long routeId) {
    if (pedalonsContext.isPlatformAdmin()) {
      return;
    }
    Integer limit = planLimits.forTeam(team).plannerMonthly();
    if (limit == null) {
      return;
    }
    plannerSaveRepository.lockUntilEndOfTransaction("planner_saves:team:" + team.getId());
    Month month = month(zoneOf(team));
    requireBelowTeam(team, limit, month);
    plannerSaveRepository.persist(
        new PlannerSave(
            pedalonsContext.getDomainId(),
            pedalonsContext.getUserId(),
            team.getId(),
            clock.now(),
            routeId));
  }

  private void requireBelowTeam(Team team, int limit, Month month) {
    long used = plannerSaveRepository.countTeamSince(team.getId(), month.start());
    if (used >= limit) {
      throw new ForbiddenException(
          ErrorCode.PLANNER_QUOTA_REACHED,
          new PlannerQuotaDetails(
              PlannerQuotaScope.TEAM, limit, used, month.resetsOn(), team.getName()));
    }
  }

  // ==================== Personal (the GPX tools) ====================

  /**
   * Refuses when the caller's personal quota is already spent: before the work of a save in the GPX
   * tools, and before a route calculation without a team.
   *
   * @throws ForbiddenException {@code PLANNER_QUOTA_REACHED}, scope PERSONAL
   */
  public void requirePersonalRoom() {
    if (pedalonsContext.isPlatformAdmin()) {
      return;
    }
    Integer limit = planLimits.personalPlannerQuota(pedalonsContext.getUserId());
    if (limit == null) {
      return;
    }
    requireBelowPersonal(limit, month(ZoneId.of(Crons.ZONE)));
  }

  /**
   * Counts one save of a drawn track in the GPX tools for the caller, refusing it when the quota is
   * spent. Must run in the transaction of the save, at its end (see {@link #recordTeamSave}).
   *
   * @param previewId the preview saved, for a diagnosis
   * @throws ForbiddenException {@code PLANNER_QUOTA_REACHED}, scope PERSONAL
   */
  public void recordPersonalSave(@Nullable Long previewId) {
    if (pedalonsContext.isPlatformAdmin()) {
      return;
    }
    Long userId = pedalonsContext.getUserId();
    Integer limit = planLimits.personalPlannerQuota(userId);
    if (limit == null) {
      return;
    }
    plannerSaveRepository.lockUntilEndOfTransaction("planner_saves:user:" + userId);
    requireBelowPersonal(limit, month(ZoneId.of(Crons.ZONE)));
    plannerSaveRepository.persist(
        new PlannerSave(pedalonsContext.getDomainId(), userId, null, clock.now(), previewId));
  }

  private void requireBelowPersonal(int limit, Month month) {
    long used =
        plannerSaveRepository.countPersonalSince(
            pedalonsContext.getDomainId(), pedalonsContext.getUserId(), month.start());
    if (used >= limit) {
      throw new ForbiddenException(
          ErrorCode.PLANNER_QUOTA_REACHED,
          new PlannerQuotaDetails(PlannerQuotaScope.PERSONAL, limit, used, month.resetsOn(), null));
    }
  }

  // ==================== The daily routing cap ====================

  /**
   * Counts one route calculation for the caller on today's UTC day, refusing it past the daily cap.
   * In a transaction of its own: a calculation is counted when admitted, whatever happens next.
   *
   * @throws TooManyRequestsException {@code ROUTING_DAILY_LIMIT_REACHED}, retry at the next UTC day
   */
  public void admitRouting() {
    if (pedalonsContext.isPlatformAdmin()) {
      return;
    }
    Long userId = pedalonsContext.getUserId();
    Instant now = clock.now();
    LocalDate today = LocalDate.ofInstant(now, ZoneOffset.UTC);
    int cap = planLimits.routerDailyPerUser();
    boolean admitted =
        QuarkusTransaction.requiringNew()
            .call(() -> routerDailyCallRepository.admit(userId, today, cap));
    if (!admitted) {
      long retryAfter =
          Duration.between(now, today.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant())
              .toSeconds();
      throw new TooManyRequestsException(ErrorCode.ROUTING_DAILY_LIMIT_REACHED, retryAfter);
    }
  }

  // ==================== The month ====================

  /** The first instant of the current month in {@code zone}, and the first day of the next one. */
  record Month(Instant start, LocalDate resetsOn) {}

  Month month(ZoneId zone) {
    LocalDate first = LocalDate.ofInstant(clock.now(), zone).withDayOfMonth(1);
    return new Month(first.atStartOfDay(zone).toInstant(), first.plusMonths(1));
  }

  private static ZoneId zoneOf(Team team) {
    try {
      return ZoneId.of(team.getTimezone());
    } catch (DateTimeException | NullPointerException e) {
      return ZoneId.of(Crons.ZONE);
    }
  }
}
