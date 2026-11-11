package fr.pedalons.repository.team;

import fr.pedalons.domain.team.TeamInvitation;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.InvitationStatus;
import fr.pedalons.repository.common.BaseRepository;
import fr.pedalons.repository.query.PedalonsQuery;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@ApplicationScoped
public class TeamInvitationRepository implements BaseRepository<TeamInvitation> {

  public Optional<TeamInvitation> findByTokenHash(String tokenHash) {
    return find("tokenHash = ?1", tokenHash).firstResultOptional();
  }

  public Optional<TeamInvitation> findPendingByTeamAndEmail(Long teamId, String email) {
    return find(
            "team.id = ?1 and email = ?2 and status = ?3", teamId, email, InvitationStatus.PENDING)
        .firstResultOptional();
  }

  public PedalonsPage<TeamInvitation> findByTeam(
      Long teamId, int page, int size, InvitationStatus status) {
    PedalonsQuery query =
        new PedalonsQuery()
            .and("team.id = :teamId", Map.of("teamId", teamId))
            .order("createdAt desc");
    if (status != null) {
      query.and("status = :status", Map.of("status", status));
    }
    return getPage(query, page, size);
  }

  /**
   * The invitations still waiting for this address, newest first.
   *
   * <p>Lapsed ones are filtered out here rather than left to the caller: the nightly sweep is what
   * marks them {@code EXPIRED}, so between midnight and 3 AM a still-{@code PENDING} row can be past
   * its date, and offering someone an invitation that the accept call will then refuse is worse than
   * not showing it.
   */
  public List<TeamInvitation> findPendingForEmail(Long domainId, String email) {
    return find(
            "domainId = ?1 and email = ?2 and status = ?3 and expiresAt > ?4 order by createdAt"
                + " desc",
            domainId,
            email,
            InvitationStatus.PENDING,
            Instant.now())
        .list();
  }

  /**
   * How many invitations this inviter has sent since {@code minutes} ago, across every team.
   *
   * <p>Per inviter rather than per team, for the same reason the ad-contact relay counts per sender:
   * what the threshold protects is the domain's sending reputation, and one account consumes that
   * whichever team it is inviting to.
   */
  public long countRecentByCreator(Long userId, int minutes) {
    return count(
        "createdBy.id = ?1 and createdAt > ?2",
        userId,
        Instant.now().minus(minutes, ChronoUnit.MINUTES));
  }

  /** The second dimension: without it, three admins of one team simply add up their quotas. */
  public long countRecentByTeam(Long teamId, int minutes) {
    return count(
        "team.id = ?1 and createdAt > ?2",
        teamId,
        Instant.now().minus(minutes, ChronoUnit.MINUTES));
  }

  /**
   * How many invitations have been aimed at this address recently, whoever sent them and whatever
   * team they were for. The only counter that protects a person rather than the system.
   */
  public long countRecentByEmail(Long domainId, String email, int minutes) {
    return count(
        "domainId = ?1 and email = ?2 and createdAt > ?3",
        domainId,
        email,
        Instant.now().minus(minutes, ChronoUnit.MINUTES));
  }

  /**
   * The team's invitations still waiting for an answer, bar the one for {@code exceptEmail} — which
   * a new invitation to that address revokes and replaces, so it must not be counted twice. A
   * lapsed one the nightly sweep has not marked yet is not counted: its accept would be refused.
   * What a new invitation adds to the member count under the free plan's cap (docs/LEDGER_*.md
   * BILL-10).
   */
  public long countPendingByTeam(Long teamId, String exceptEmail) {
    return count(
        "team.id = ?1 and status = ?2 and expiresAt > ?3 and email <> ?4",
        teamId,
        InvitationStatus.PENDING,
        Instant.now(),
        exceptEmail);
  }

  /** Marks lapsed invitations, which is also what frees the (team, email) slot for a re-invite. */
  public long expireOverdue() {
    return update(
        "status = ?1 where status = ?2 and expiresAt < ?3",
        InvitationStatus.EXPIRED,
        InvitationStatus.PENDING,
        Instant.now());
  }

  /**
   * Marks one lapsed invitation as expired, independently of the caller's transaction:
   * {@code requireRedeemable} throws right after calling this, and letting that rollback also undo
   * the mark would leave the row PENDING forever, no different from never having checked it.
   */
  @Transactional(Transactional.TxType.REQUIRES_NEW)
  public void markExpiredIndependently(Long id) {
    update(
        "status = ?1 where id = ?2 and status = ?3",
        InvitationStatus.EXPIRED,
        id,
        InvitationStatus.PENDING);
  }

  /** Retention sweep. Terminal rows only — a pending invitation is never swept. */
  public long deleteOldTerminal(int days) {
    return delete(
        "status <> ?1 and updatedAt < ?2",
        InvitationStatus.PENDING,
        Instant.now().minus(days, ChronoUnit.DAYS));
  }
}
