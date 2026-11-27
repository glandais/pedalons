package fr.pedalons.repository.platform;

import fr.pedalons.domain.auth.AuthSession;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

/**
 * Usage of the platform, counted on what the database already holds. Counts only — no row names or
 * identifies anyone, and nothing new is collected. Every query takes the optional domain filter as
 * a pair of parameters ({@code allDomains}, {@code domainId}) so that no null is ever bound.
 *
 * <p>Accounts that are deleted and domains that are deleted are left out, except where a field says
 * otherwise. A table without a {@code domain_id} is filtered through its account.
 */
@ApplicationScoped
public class PlatformStatsRepository {

  /** Counts of the accounts; see {@code AdminUserStatsDto}. */
  public record UserCounts(
      long total,
      long deleted,
      long emailVerified,
      long termsAccepted,
      long platformAdmins,
      long withAvatar,
      long neverLoggedIn,
      long activeLast7Days,
      long activeLast30Days,
      long activeLast90Days) {}

  public record AuthMethodCounts(
      long passwordOnly, long passkeyOnly, long passwordAndPasskey, long neither) {}

  public record PasskeyCounts(long total, long usedLast30Days) {}

  public record KeyCount(String key, long count) {}

  public record GpsConnectionCounts(
      String service,
      long connections,
      long users,
      long autoSync,
      long reconnectRequired,
      long usedLast30Days) {}

  public record GpsSyncCounts(String service, long total, long succeeded, long failed) {}

  public record PushCounts(String platform, long devices, long users, long seenLast7Days) {}

  public record CalendarCounts(long tokens, long usedEver, long usedLast7Days) {}

  @Inject EntityManager em;

  public UserCounts users(boolean allDomains, long domainId, Instant now) {
    Object[] r =
        (Object[])
            filtered(
                    em.createNativeQuery(
                        """
                        select count(*) filter (where not u.deleted),
                               count(*) filter (where u.deleted),
                               count(*) filter (where not u.deleted and u.email_verified),
                               count(*) filter (where not u.deleted and u.terms_accepted_at is not null),
                               count(*) filter (where not u.deleted and u.platform_role is not null),
                               count(*) filter (where not u.deleted and u.avatar_url is not null),
                               count(*) filter (where not u.deleted and u.last_login_at is null),
                               count(*) filter (where not u.deleted and u.last_login_at >= :d7),
                               count(*) filter (where not u.deleted and u.last_login_at >= :d30),
                               count(*) filter (where not u.deleted and u.last_login_at >= :d90)
                          from users u
                          join domains d on d.id = u.domain_id and d.deleted = false
                         where (:allDomains = true or u.domain_id = :domainId)
                        """),
                    allDomains,
                    domainId)
                .setParameter("d7", ago(now, 7))
                .setParameter("d30", ago(now, 30))
                .setParameter("d90", ago(now, 90))
                .getSingleResult();
    return new UserCounts(
        n(r[0]), n(r[1]), n(r[2]), n(r[3]), n(r[4]), n(r[5]), n(r[6]), n(r[7]), n(r[8]), n(r[9]));
  }

  public AuthMethodCounts authMethods(boolean allDomains, long domainId) {
    Object[] r =
        (Object[])
            filtered(
                    em.createNativeQuery(
                        """
                        select count(*) filter (where pw and not pk),
                               count(*) filter (where pk and not pw),
                               count(*) filter (where pw and pk),
                               count(*) filter (where not pw and not pk)
                          from (select u.password_hash is not null as pw,
                                       exists (select 1 from passkeys p where p.user_id = u.id) as pk
                                  from users u
                                  join domains d on d.id = u.domain_id and d.deleted = false
                                 where u.deleted = false
                                   and (:allDomains = true or u.domain_id = :domainId)) x
                        """),
                    allDomains,
                    domainId)
                .getSingleResult();
    return new AuthMethodCounts(n(r[0]), n(r[1]), n(r[2]), n(r[3]));
  }

  public PasskeyCounts passkeys(boolean allDomains, long domainId, Instant now) {
    Object[] r =
        (Object[])
            filtered(
                    em.createNativeQuery(
                        """
                        select count(*), count(*) filter (where p.last_used_at >= :d30)
                          from passkeys p
                          join users u on u.id = p.user_id and u.deleted = false
                          join domains d on d.id = u.domain_id and d.deleted = false
                         where (:allDomains = true or u.domain_id = :domainId)
                        """),
                    allDomains,
                    domainId)
                .setParameter("d30", ago(now, 30))
                .getSingleResult();
    return new PasskeyCounts(n(r[0]), n(r[1]));
  }

  /** Accounts created since {@code since}, per calendar month (UTC, {@code YYYY-MM}). */
  public Map<String, Long> signupsSince(boolean allDomains, long domainId, Instant since) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        filtered(
                em.createNativeQuery(
                    """
                    select to_char(u.created_at at time zone 'UTC', 'YYYY-MM'), count(*)
                      from users u
                      join domains d on d.id = u.domain_id and d.deleted = false
                     where u.deleted = false
                       and u.created_at >= :since
                       and (:allDomains = true or u.domain_id = :domainId)
                     group by 1
                    """),
                allDomains,
                domainId)
            .setParameter("since", odt(since))
            .getResultList();
    return rows.stream()
        .collect(java.util.stream.Collectors.toMap(r -> (String) r[0], r -> n(r[1])));
  }

  public long activeTeams(boolean allDomains, long domainId) {
    return teamCount(allDomains, domainId, false);
  }

  public long deletedTeams(boolean allDomains, long domainId) {
    return teamCount(allDomains, domainId, true);
  }

  private long teamCount(boolean allDomains, long domainId, boolean deleted) {
    return n(
        filtered(
                em.createNativeQuery(
                    """
                    select count(*)
                      from teams t
                      join domains d on d.id = t.domain_id and d.deleted = false
                     where t.deleted = :deleted
                       and (:allDomains = true or t.domain_id = :domainId)
                    """),
                allDomains,
                domainId)
            .setParameter("deleted", deleted)
            .getSingleResult());
  }

  public List<KeyCount> teamsByTier(boolean allDomains, long domainId) {
    return keyCounts(
        filtered(
            em.createNativeQuery(
                """
                select t.tier, count(*)
                  from teams t
                  join domains d on d.id = t.domain_id and d.deleted = false
                 where t.deleted = false
                   and (:allDomains = true or t.domain_id = :domainId)
                 group by t.tier
                 order by t.tier
                """),
            allDomains,
            domainId));
  }

  public List<KeyCount> membershipsByRole(boolean allDomains, long domainId) {
    return keyCounts(
        filtered(
            em.createNativeQuery(
                """
                select ut.role, count(*)
                  from user_teams ut
                  join teams t on t.id = ut.team_id and t.deleted = false
                  join users u on u.id = ut.user_id and u.deleted = false
                  join domains d on d.id = u.domain_id and d.deleted = false
                 where (:allDomains = true or u.domain_id = :domainId)
                 group by ut.role
                 order by ut.role
                """),
            allDomains,
            domainId));
  }

  /** Accounts per number of active teams: keys "0", "1", "2", "3+" (all four, in that order). */
  public List<KeyCount> usersByTeamCount(boolean allDomains, long domainId) {
    Object[] r =
        (Object[])
            filtered(
                    em.createNativeQuery(
                        """
                        select count(*) filter (where c = 0),
                               count(*) filter (where c = 1),
                               count(*) filter (where c = 2),
                               count(*) filter (where c >= 3)
                          from (select (select count(*)
                                          from user_teams ut
                                          join teams t on t.id = ut.team_id and t.deleted = false
                                         where ut.user_id = u.id) as c
                                  from users u
                                  join domains d on d.id = u.domain_id and d.deleted = false
                                 where u.deleted = false
                                   and (:allDomains = true or u.domain_id = :domainId)) x
                        """),
                    allDomains,
                    domainId)
                .getSingleResult();
    return List.of(
        new KeyCount("0", n(r[0])),
        new KeyCount("1", n(r[1])),
        new KeyCount("2", n(r[2])),
        new KeyCount("3+", n(r[3])));
  }

  public List<GpsConnectionCounts> gpsConnections(boolean allDomains, long domainId, Instant now) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        filtered(
                em.createNativeQuery(
                    """
                    select c.service_type,
                           count(*),
                           count(distinct c.user_id),
                           count(*) filter (where c.auto_sync),
                           count(*) filter (where c.sync_reconnect_required_at is not null),
                           count(*) filter (where c.last_used_at >= :d30)
                      from gps_service_connections c
                      join users u on u.id = c.user_id and u.deleted = false
                      join domains d on d.id = u.domain_id and d.deleted = false
                     where (:allDomains = true or u.domain_id = :domainId)
                     group by c.service_type
                     order by c.service_type
                    """),
                allDomains,
                domainId)
            .setParameter("d30", ago(now, 30))
            .getResultList();
    return rows.stream()
        .map(r ->
            new GpsConnectionCounts((String) r[0], n(r[1]), n(r[2]), n(r[3]), n(r[4]), n(r[5])))
        .toList();
  }

  public List<GpsSyncCounts> gpsRouteSyncs(boolean allDomains, long domainId) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        filtered(
                em.createNativeQuery(
                    """
                    select c.service_type,
                           count(*),
                           count(*) filter (where s.synced_at is not null),
                           count(*) filter (where s.last_error is not null)
                      from gps_route_syncs s
                      join gps_service_connections c on c.id = s.connection_id
                      join users u on u.id = c.user_id and u.deleted = false
                      join domains d on d.id = u.domain_id and d.deleted = false
                     where (:allDomains = true or u.domain_id = :domainId)
                     group by c.service_type
                    """),
                allDomains,
                domainId)
            .getResultList();
    return rows.stream()
        .map(r -> new GpsSyncCounts((String) r[0], n(r[1]), n(r[2]), n(r[3])))
        .toList();
  }

  public long usersWithGpsService(boolean allDomains, long domainId) {
    return n(
        filtered(
                em.createNativeQuery(
                    """
                    select count(distinct c.user_id)
                      from gps_service_connections c
                      join users u on u.id = c.user_id and u.deleted = false
                      join domains d on d.id = u.domain_id and d.deleted = false
                     where (:allDomains = true or u.domain_id = :domainId)
                    """),
                allDomains,
                domainId)
            .getSingleResult());
  }

  public List<PushCounts> pushDevices(boolean allDomains, long domainId, Instant now) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        filtered(
                em.createNativeQuery(
                    """
                    select p.platform,
                           count(*),
                           count(distinct p.user_id),
                           count(*) filter (where p.last_seen_at >= :d7)
                      from push_devices p
                      join users u on u.id = p.user_id and u.deleted = false
                      join domains d on d.id = u.domain_id and d.deleted = false
                     where (:allDomains = true or u.domain_id = :domainId)
                     group by p.platform
                     order by p.platform
                    """),
                allDomains,
                domainId)
            .setParameter("d7", ago(now, 7))
            .getResultList();
    return rows.stream()
        .map(r -> new PushCounts((String) r[0], n(r[1]), n(r[2]), n(r[3])))
        .toList();
  }

  /**
   * Distinct accounts per kind of client among the sessions used since 30 days: the device client
   * of a paired device or an OAuth application first, then the user agent.
   */
  public List<KeyCount> clientsLast30Days(boolean allDomains, long domainId, Instant now) {
    return keyCounts(
        filtered(
                em.createNativeQuery(
                    """
                    select kind, count(distinct user_id)
                      from (select s.user_id,
                                   case
                                     when s.device_client is not null
                                          and starts_with(s.device_client, :oauthPrefix) then 'OAUTH'
                                     when s.device_client is not null then lower(s.device_client)
                                     when s.user_agent like 'Dart/%' then 'MOBILE_APP'
                                     when s.user_agent ~ '(Mobile|Android|iPhone|iPad)'
                                       then 'WEB_MOBILE'
                                     else 'WEB_DESKTOP'
                                   end as kind
                              from auth_sessions s
                              join users u on u.id = s.user_id and u.deleted = false
                              join domains d on d.id = u.domain_id and d.deleted = false
                             where s.last_used_at >= :d30
                               and (:allDomains = true or u.domain_id = :domainId)) x
                     group by kind
                     order by kind
                    """),
                allDomains,
                domainId)
            .setParameter("oauthPrefix", AuthSession.OAUTH_CLIENT_PREFIX)
            .setParameter("d30", ago(now, 30)));
  }

  public CalendarCounts calendarFeeds(boolean allDomains, long domainId, Instant now) {
    Object[] r =
        (Object[])
            filtered(
                    em.createNativeQuery(
                        """
                        select count(*),
                               count(*) filter (where c.last_used_at is not null),
                               count(*) filter (where c.last_used_at >= :d7)
                          from calendar_tokens c
                          join users u on u.id = c.user_id and u.deleted = false
                          join domains d on d.id = u.domain_id and d.deleted = false
                         where (:allDomains = true or u.domain_id = :domainId)
                        """),
                    allDomains,
                    domainId)
                .setParameter("d7", ago(now, 7))
                .getSingleResult();
    return new CalendarCounts(n(r[0]), n(r[1]), n(r[2]));
  }

  private static Query filtered(Query query, boolean allDomains, long domainId) {
    return query.setParameter("allDomains", allDomains).setParameter("domainId", domainId);
  }

  private static List<KeyCount> keyCounts(Query query) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows = query.getResultList();
    return rows.stream().map(r -> new KeyCount((String) r[0], n(r[1]))).toList();
  }

  private static OffsetDateTime ago(Instant now, int days) {
    return odt(now.minus(java.time.Duration.ofDays(days)));
  }

  private static OffsetDateTime odt(Instant instant) {
    return OffsetDateTime.ofInstant(instant, ZoneOffset.UTC);
  }

  private static long n(Object value) {
    return ((Number) value).longValue();
  }
}
