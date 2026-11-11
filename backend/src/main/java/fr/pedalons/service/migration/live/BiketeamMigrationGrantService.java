package fr.pedalons.service.migration.live;

import fr.pedalons.common.TokenUtils;
import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.migration.BiketeamMigrationJob;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.migration.BiketeamMigrationConfirmDto;
import fr.pedalons.dto.migration.BiketeamMigrationPreviewDto;
import fr.pedalons.enums.BiketeamMigrationBlockReason;
import fr.pedalons.enums.BiketeamMigrationStatus;
import fr.pedalons.enums.BiketeamMigrationTargetState;
import fr.pedalons.repository.migration.BiketeamMigrationJobRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.PersistenceException;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.Optional;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The browser side of the biketeam live migration (docs/plans/2026-09-22-biketeam-live-migration.md
 * §4): the preview of a signed biketeam request, and its confirmation by a signed-in Pédalons user,
 * which mints the single-use grant biketeam then redeems over HTTPS.
 *
 * <p>The target domain is the one the page is served on — {@link DomainResolver#getDomain()}, the
 * <em>parent</em> domain when the request arrived through an alias.
 */
@ApplicationScoped
public class BiketeamMigrationGrantService {

  private static final Logger LOG = Logger.getLogger(BiketeamMigrationGrantService.class);

  /** Grants are recognisable in logs and leaks: {@code bmg_} + 43 base64url characters. */
  static final String GRANT_PREFIX = "bmg_";

  @Inject BiketeamLiveMigrationConfig config;
  @Inject BiketeamRequestTokenVerifier verifier;
  @Inject BiketeamTargetResolver targetResolver;
  @Inject BiketeamMigrationJobRepository jobRepository;
  @Inject DomainResolver domainResolver;
  @Inject PedalonsQueryContext pedalonsContext;

  /**
   * What the request says and what it would land on. Public: a visitor who is not signed in yet has
   * to see what they are being asked before signing in, as with invitations. When someone is signed
   * in, it also says whether they can confirm.
   */
  @Public
  @Transactional
  public BiketeamMigrationPreviewDto preview(String requestToken) {
    ensureEnabled();
    BiketeamRequestToken token = verifier.verify(requestToken);
    Domain domain = domainResolver.getDomain();
    BiketeamTargetResolver.Target target = targetResolver.evaluate(domain.getId(), token.teamId());
    User user = pedalonsContext.getUserNullable();
    BiketeamMigrationBlockReason blockReason = blockReason(token, target, domain, user);
    return new BiketeamMigrationPreviewDto(
        token.requestId(),
        token.teamId(),
        token.teamName(),
        token.requestedBy(),
        token.expiresAt(),
        token.summary(),
        domain.getName(),
        target.slug(),
        target.state(),
        target.state() == BiketeamMigrationTargetState.EXISTING_MIGRATED
                || target.state() == BiketeamMigrationTargetState.SLUG_CONFLICT
            ? target.teamName()
            : null,
        // What the worker sets aside (Prepared.create), from the same evaluation.
        target.trashed() ? target.teamName() : null,
        blockReason == null,
        blockReason,
        token.cancelUrl());
  }

  /** The first reason that applies, in the contract's order; null when the user can confirm. */
  private @Nullable BiketeamMigrationBlockReason blockReason(
      BiketeamRequestToken token,
      BiketeamTargetResolver.Target target,
      Domain domain,
      @Nullable User user) {
    if (target.state() == BiketeamMigrationTargetState.SLUG_CONFLICT) {
      return BiketeamMigrationBlockReason.SLUG_CONFLICT;
    }
    if (target.state() == BiketeamMigrationTargetState.MIGRATED_IN_OTHER_DOMAIN) {
      return BiketeamMigrationBlockReason.MIGRATED_IN_OTHER_DOMAIN;
    }
    Optional<BiketeamMigrationJob> row = jobRepository.findByRequestId(token.requestId());
    if (row.isPresent() && isUsed(row.get(), domain, user)) {
      return BiketeamMigrationBlockReason.REQUEST_ALREADY_USED;
    }
    if (jobRepository.findActiveByBiketeamTeamId(token.teamId()).isPresent()) {
      return BiketeamMigrationBlockReason.MIGRATION_RUNNING;
    }
    if (user == null) {
      return BiketeamMigrationBlockReason.LOGIN_REQUIRED;
    }
    if (target.state() == BiketeamMigrationTargetState.EXISTING_MIGRATED
        && !targetResolver.mayAdminister(user, requireTeamId(target))) {
      return BiketeamMigrationBlockReason.NOT_TEAM_ADMIN;
    }
    return null;
  }

  /**
   * Only a consumed row — a job, created by biketeam's trigger — is used for good. A row never
   * redeemed, whether still GRANTED or EXPIRED (its grant lapsed; the hourly sweep or a late
   * trigger marked it so), can be re-confirmed while the request token is valid, by the user who
   * confirmed it, on the same domain: the answer does not depend on whether the sweep already ran.
   * Without a user, only a consumed row counts as used — whoever signs in may well be its owner.
   */
  private static boolean isUsed(BiketeamMigrationJob row, Domain domain, @Nullable User user) {
    if (row.getStatus().isJob()) {
      return true;
    }
    if (!row.getDomain().getId().equals(domain.getId())) {
      return true;
    }
    return user != null && !row.getUser().getId().equals(user.getId());
  }

  /**
   * Re-checks everything the preview checked — nothing is believed from the client — then records
   * the request and mints its grant. A second confirmation by the same user of a row not yet
   * redeemed (double click, back button, a grant that lapsed) mints a new grant that replaces the
   * first, and a lapsed row is GRANTED again.
   */
  @Logged
  @Transactional
  public BiketeamMigrationConfirmDto confirm(String requestToken) {
    ensureEnabled();
    BiketeamRequestToken token = verifier.verify(requestToken);
    Domain domain = domainResolver.getDomain();
    User user = pedalonsContext.getUser();
    BiketeamTargetResolver.Target target = targetResolver.evaluate(domain.getId(), token.teamId());

    if (target.state() == BiketeamMigrationTargetState.SLUG_CONFLICT) {
      throw new ConflictException(ErrorCode.BIKETEAM_SLUG_CONFLICT);
    }
    if (target.state() == BiketeamMigrationTargetState.MIGRATED_IN_OTHER_DOMAIN) {
      throw new ConflictException(ErrorCode.BIKETEAM_MIGRATED_IN_OTHER_DOMAIN);
    }
    Optional<BiketeamMigrationJob> existing = jobRepository.findByRequestId(token.requestId());
    if (existing.isPresent() && isUsed(existing.get(), domain, user)) {
      throw new ConflictException(ErrorCode.BIKETEAM_REQUEST_ALREADY_USED);
    }
    if (jobRepository.findActiveByBiketeamTeamId(token.teamId()).isPresent()) {
      throw new ConflictException(ErrorCode.BIKETEAM_MIGRATION_RUNNING);
    }
    if (target.state() == BiketeamMigrationTargetState.EXISTING_MIGRATED
        && !targetResolver.mayAdminister(user, requireTeamId(target))) {
      throw new ForbiddenException(ErrorCode.BIKETEAM_NOT_TEAM_ADMIN);
    }

    String grant = GRANT_PREFIX + TokenUtils.generateSecureToken();
    String grantHash = TokenUtils.hashToken(grant);
    Instant expiresAt = Instant.now().plus(config.grantTtl());
    if (existing.isPresent()) {
      BiketeamMigrationJob row = existing.get();
      row.setStatus(BiketeamMigrationStatus.GRANTED);
      row.setGrantHash(grantHash);
      row.setGrantExpiresAt(expiresAt);
    } else {
      BiketeamMigrationJob row =
          new BiketeamMigrationJob(
              domain,
              user,
              token.teamId(),
              truncate(token.teamName(), 250),
              token.requestId(),
              token.returnUrl(),
              domain.getBaseUrl(),
              grantHash,
              expiresAt);
      try {
        // Flushed here: uk_biketeam_migrations_request catches a concurrent confirmation of the
        // same request, and that is a 409, not the exception mapper's generic 500.
        jobRepository.persistAndFlush(row);
      } catch (PersistenceException e) {
        throw new ConflictException(ErrorCode.BIKETEAM_REQUEST_ALREADY_USED, e);
      }
    }
    LOG.infof(
        "Biketeam migration of '%s' confirmed on %s (request %s)",
        token.teamId(), domain.getDomain(), token.requestId());
    String redirectUrl = token.returnUrl() + "?request=" + token.requestId() + "&grant=" + grant;
    return new BiketeamMigrationConfirmDto(redirectUrl, expiresAt);
  }

  private void ensureEnabled() {
    if (!config.isEnabled()) {
      throw new NotFoundException();
    }
  }

  private static Long requireTeamId(BiketeamTargetResolver.Target target) {
    Long teamId = target.teamId();
    if (teamId == null) {
      throw new IllegalStateException("Target " + target.state() + " without a team");
    }
    return teamId;
  }

  private static String truncate(String value, int max) {
    return value.length() <= max ? value : value.substring(0, max);
  }
}
