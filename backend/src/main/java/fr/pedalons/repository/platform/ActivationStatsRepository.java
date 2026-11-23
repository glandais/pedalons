package fr.pedalons.repository.platform;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.sql.Date;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

/**
 * Activation of new accounts, counted on what the database already holds (docs/LEDGER_*.md
 * API-213): per sign-up week (ISO week, Monday, UTC) and per domain, how many accounts were
 * created, how many verified their address, how many joined a team and how many signed up to a
 * ride within 7 days of their creation. Counts only — no row names anyone, and nothing new is
 * collected.
 *
 * <p>Deliberately cross-domain: the platform administration is the only reader, and the domain is
 * a column of the result. Deleted accounts are left out (their memberships and participations are
 * gone with them). A team created by the account counts as joined (its creator becomes its
 * administrator); a membership or a participation removed since — a team left, a ride quit — is
 * no longer in the database and no longer counts.
 */
@ApplicationScoped
public class ActivationStatsRepository {

  /** One sign-up week of one domain. */
  public record ActivationRow(
      long domainId,
      String domainName,
      LocalDate weekStart,
      long signedUp,
      long verified,
      long joinedTeam,
      long joinedRide) {}

  @Inject EntityManager em;

  /** The weeks starting on or after {@code since}, newest first, then by domain name. */
  public List<ActivationRow> weeklyActivation(Instant since) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        em.createNativeQuery(
                """
                select u.domain_id,
                       d.name,
                       cast(date_trunc('week', u.created_at at time zone 'UTC') as date) as week,
                       count(*),
                       count(*) filter (where u.email_verified),
                       count(*) filter (where exists (
                         select 1 from user_teams ut
                          where ut.user_id = u.id
                            and ut.joined_at < u.created_at + interval '7 days')),
                       count(*) filter (where exists (
                         select 1 from ride_participations rp
                          where rp.user_id = u.id
                            and rp.registered_at < u.created_at + interval '7 days'))
                  from users u
                  join domains d on d.id = u.domain_id
                 where u.deleted = false
                   and d.deleted = false
                   and u.created_at >= :since
                 group by u.domain_id, d.name, week
                 order by week desc, d.name, u.domain_id
                """)
            .setParameter("since", OffsetDateTime.ofInstant(since, ZoneOffset.UTC))
            .getResultList();
    return rows.stream()
        .map(r ->
            new ActivationRow(
                ((Number) r[0]).longValue(),
                (String) r[1],
                toLocalDate(r[2]),
                ((Number) r[3]).longValue(),
                ((Number) r[4]).longValue(),
                ((Number) r[5]).longValue(),
                ((Number) r[6]).longValue()))
        .toList();
  }

  private static LocalDate toLocalDate(Object value) {
    if (value instanceof LocalDate date) {
      return date;
    }
    return ((Date) value).toLocalDate();
  }
}
