package fr.pedalons.service.admin;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.dto.admin.AdminAuthMethodStatsDto;
import fr.pedalons.dto.admin.AdminCalendarStatsDto;
import fr.pedalons.dto.admin.AdminGpsServiceStatsDto;
import fr.pedalons.dto.admin.AdminKeyCountDto;
import fr.pedalons.dto.admin.AdminMonthCountDto;
import fr.pedalons.dto.admin.AdminPasskeyStatsDto;
import fr.pedalons.dto.admin.AdminPlatformStatsDto;
import fr.pedalons.dto.admin.AdminPushPlatformStatsDto;
import fr.pedalons.dto.admin.AdminTeamStatsDto;
import fr.pedalons.dto.admin.AdminUserStatsDto;
import fr.pedalons.repository.platform.DomainRepository;
import fr.pedalons.repository.platform.PlatformStatsRepository;
import fr.pedalons.repository.platform.PlatformStatsRepository.GpsConnectionCounts;
import fr.pedalons.repository.platform.PlatformStatsRepository.GpsSyncCounts;
import fr.pedalons.repository.platform.PlatformStatsRepository.KeyCount;
import fr.pedalons.repository.platform.PlatformStatsRepository.UserCounts;
import fr.pedalons.service.security.annotation.Admin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/** Usage statistics of the platform administration: counts only, nobody is named. */
@ApplicationScoped
public class AdminPlatformStatsService {

  /** Calendar months of sign-ups, the current one included. */
  static final int SIGNUP_MONTHS = 12;

  @Inject PlatformStatsRepository repository;

  @Inject DomainRepository domainRepository;

  /**
   * @param domainId limits the figures to one domain; null for all of them
   * @throws NotFoundException when the domain is unknown or deleted
   */
  @Admin
  public AdminPlatformStatsDto getPlatformStats(@Nullable String domainId) {
    return platformStats(domainId, Instant.now());
  }

  AdminPlatformStatsDto platformStats(@Nullable String domainId, Instant now) {
    boolean all = domainId == null || domainId.isBlank();
    long id = 0;
    if (!all) {
      id = TsidUtils.toLong(domainId);
      domainRepository
          .find("id = ?1 and deleted = false", id)
          .firstResultOptional()
          .orElseThrow(NotFoundException::new);
    }

    UserCounts u = repository.users(all, id, now);
    var auth = repository.authMethods(all, id);
    var passkeys = repository.passkeys(all, id, now);

    YearMonth current = YearMonth.from(now.atZone(ZoneOffset.UTC));
    YearMonth first = current.minusMonths(SIGNUP_MONTHS - 1L);
    Map<String, Long> signups =
        repository.signupsSince(all, id, first.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant());
    List<AdminMonthCountDto> months = new ArrayList<>();
    for (YearMonth m = first; !m.isAfter(current); m = m.plusMonths(1)) {
      months.add(new AdminMonthCountDto(m.toString(), signups.getOrDefault(m.toString(), 0L)));
    }

    var teams =
        new AdminTeamStatsDto(
            repository.activeTeams(all, id),
            repository.deletedTeams(all, id),
            keys(repository.teamsByTier(all, id)),
            keys(repository.membershipsByRole(all, id)),
            keys(repository.usersByTeamCount(all, id)));

    Map<String, GpsSyncCounts> syncs = new java.util.HashMap<>();
    for (GpsSyncCounts s : repository.gpsRouteSyncs(all, id)) {
      syncs.put(s.service(), s);
    }
    List<AdminGpsServiceStatsDto> gps = new ArrayList<>();
    for (GpsConnectionCounts c : repository.gpsConnections(all, id, now)) {
      GpsSyncCounts s = syncs.get(c.service());
      gps.add(
          new AdminGpsServiceStatsDto(
              c.service(),
              c.connections(),
              c.users(),
              c.autoSync(),
              c.reconnectRequired(),
              c.usedLast30Days(),
              s == null ? 0 : s.total(),
              s == null ? 0 : s.succeeded(),
              s == null ? 0 : s.failed()));
    }

    var calendar = repository.calendarFeeds(all, id, now);

    return new AdminPlatformStatsDto(
        now,
        all ? null : TsidUtils.toString(id),
        new AdminUserStatsDto(
            u.total(),
            u.deleted(),
            u.emailVerified(),
            u.termsAccepted(),
            u.platformAdmins(),
            u.withAvatar(),
            u.neverLoggedIn(),
            u.activeLast7Days(),
            u.activeLast30Days(),
            u.activeLast90Days()),
        new AdminAuthMethodStatsDto(
            auth.passwordOnly(), auth.passkeyOnly(), auth.passwordAndPasskey(), auth.neither()),
        new AdminPasskeyStatsDto(passkeys.total(), passkeys.usedLast30Days()),
        months,
        teams,
        gps,
        repository.usersWithGpsService(all, id),
        repository.pushDevices(all, id, now).stream()
            .map(p ->
                new AdminPushPlatformStatsDto(
                    p.platform(), p.devices(), p.users(), p.seenLast7Days()))
            .toList(),
        keys(repository.clientsLast30Days(all, id, now)),
        new AdminCalendarStatsDto(
            calendar.tokens(), calendar.usedEver(), calendar.usedLast7Days()));
  }

  private static List<AdminKeyCountDto> keys(List<KeyCount> rows) {
    return rows.stream().map(r -> new AdminKeyCountDto(r.key(), r.count())).toList();
  }
}
